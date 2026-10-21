// seamless_net.dll: REFramework plugin for the Seamless Co-op side channel (implementation plan §7).
// Exposes the global Lua table `seamless_net` to REFramework scripts. Bindings never raise Lua errors (they return
// nil/false + message), so no longjmp ever crosses C++ frames.

#include "channel.hpp"
#include "save_backup.hpp"
#include "steam_flat.hpp"
#include "steam_types.hpp"
#include "version.hpp"

#include <Windows.h>

#include <reframework/API.h>

#include <lua.hpp>

#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <fstream>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>

namespace fs = std::filesystem;

namespace {

using namespace seamless;

const REFrameworkPluginFunctions* g_fns = nullptr;

// Created on first use from the game thread (Lua), when SteamAPI is surely initialised.
std::unique_ptr<FlatSteam> g_steam;
std::unique_ptr<Channel> g_channel;

struct BackupStatus {
    std::mutex mutex;
    std::string state{"pending"};
    std::string message;
    std::string folder;
    std::size_t files = 0;
    std::uintmax_t bytes = 0;
    int removed = 0;
};
// Intentionally leaked: the detached backup thread may outlive static destruction at process exit.
BackupStatus* g_backup = new BackupStatus{};

double now_seconds() {
    using namespace std::chrono;
    return duration<double>(steady_clock::now().time_since_epoch()).count();
}

template <typename... Args>
void log_info(const char* fmt, Args... args) {
    if (g_fns != nullptr && g_fns->log_info != nullptr) {
        g_fns->log_info(fmt, args...);
    }
}

template <typename... Args>
void log_error(const char* fmt, Args... args) {
    if (g_fns != nullptr && g_fns->log_error != nullptr) {
        g_fns->log_error(fmt, args...);
    }
}

fs::path game_dir() {
    std::wstring buf(32768, L'\0');
    const DWORD n = GetModuleFileNameW(nullptr, buf.data(), static_cast<DWORD>(buf.size()));
    buf.resize(n);
    return fs::path{buf}.parent_path();
}

fs::path data_dir() {
    return game_dir() / "reframework" / "data" / "seamless_coop";
}

void ensure_net() {
    if (g_steam) {
        return;
    }
    g_steam = std::make_unique<FlatSteam>();
    g_channel = std::make_unique<Channel>(*g_steam, kChannel, now_seconds);
    if (g_steam->available()) {
        g_steam->init_relay();
        log_info("[seamless_net] Steam networking ready (channel %d)", kChannel);
    } else {
        log_error("[seamless_net] side channel unavailable: %s", g_steam->reason().c_str());
    }
}

// --- save backup worker (spec F5.3) ----------------------------------------------------------------------------------

void set_backup(const char* state, const std::string& message, const BackupResult* r = nullptr) {
    std::scoped_lock lock{g_backup->mutex};
    g_backup->state = state;
    g_backup->message = message;
    if (r != nullptr) {
        g_backup->folder = r->destination.filename().string();
        g_backup->files = r->files;
        g_backup->bytes = r->bytes;
        g_backup->removed = r->removed;
    }
}

void backup_worker() {
    try {
        const auto data = data_dir();
        std::string config_text;
        if (std::ifstream f{data / "config.json"}; f) {
            std::stringstream ss;
            ss << f.rdbuf();
            config_text = ss.str();
        }
        const auto settings = parse_backup_settings(config_text);
        if (!settings.enabled) {
            set_backup("skipped", "disabled in settings");
            return;
        }
        set_backup("waiting", "waiting for Steam");
        FlatSteam steam;
        if (!steam.available()) {
            set_backup("failed", steam.reason());
            return;
        }
        std::optional<fs::path> folder;
        for (int i = 0; i < 240 && !folder; ++i) {
            folder = steam.user_data_folder();
            if (!folder) {
                std::this_thread::sleep_for(std::chrono::milliseconds{500});
            }
        }
        if (!folder) {
            set_backup("failed", "Steam user data folder unavailable");
            return;
        }
        set_backup("running", "copying");
        // GetUserDataFolder returns <Steam>/userdata/<account>/<appid>/local; the game saves in .../remote.
        const auto source = folder->parent_path() / "remote";
        const auto result = backup_saves(source, data / "save_backups", utc_stamp(std::time(nullptr)), settings.keep);
        if (result.ok) {
            set_backup("done", "ok", &result);
            log_info("[seamless_net] save backup: %zu files, %llu bytes (kept %d, removed %d)", result.files,
                     static_cast<unsigned long long>(result.bytes), settings.keep, result.removed);
        } else {
            set_backup("failed", result.message, &result);
            log_error("[seamless_net] save backup failed: %s", result.message.c_str());
        }
    } catch (const std::exception& e) {
        set_backup("failed", e.what());
    } catch (...) {
        set_backup("failed", "unknown error");
    }
}

// --- Lua helpers ---------------------------------------------------------------------------------------------------

bool parse_id(lua_State* L, int idx, std::uint64_t& out) {
    if (lua_type(L, idx) != LUA_TSTRING) {
        return false;
    }
    std::size_t len = 0;
    const char* s = lua_tolstring(L, idx, &len);
    const auto [ptr, ec] = std::from_chars(s, s + len, out);
    return ec == std::errc{} && ptr == s + len && steam::is_individual_steam_id(out);
}

int fail(lua_State* L, const char* message) {
    lua_pushnil(L);
    lua_pushstring(L, message);
    return 2;
}

void set_int(lua_State* L, const char* key, lua_Integer v) {
    lua_pushinteger(L, v);
    lua_setfield(L, -2, key);
}

void set_str(lua_State* L, const char* key, const std::string& v) {
    lua_pushlstring(L, v.data(), v.size());
    lua_setfield(L, -2, key);
}

void set_bool(lua_State* L, const char* key, bool v) {
    lua_pushboolean(L, v ? 1 : 0);
    lua_setfield(L, -2, key);
}

// --- Lua API -------------------------------------------------------------------------------------------------------

int l_version(lua_State* L) {
    lua_createtable(L, 0, 3);
    set_str(L, "plugin", kPluginVersion);
    set_int(L, "api", kLuaApiVersion);
    set_int(L, "channel", kChannel);
    return 1;
}

int l_status(lua_State* L) {
    ensure_net();
    lua_createtable(L, 0, 16);
    set_bool(L, "steam", g_steam->available());
    if (!g_steam->available()) {
        set_str(L, "reason", g_steam->reason());
    }
    set_int(L, "relay", g_steam->available() ? g_steam->relay_status() : 0);
    const auto& st = g_channel->stats();
    set_int(L, "sent", static_cast<lua_Integer>(st.sent));
    set_int(L, "send_failed", static_cast<lua_Integer>(st.send_failed));
    set_int(L, "received", static_cast<lua_Integer>(st.received));
    set_int(L, "dropped_not_allowed", static_cast<lua_Integer>(st.dropped_not_allowed));
    set_int(L, "dropped_size", static_cast<lua_Integer>(st.dropped_size));
    set_int(L, "dropped_rate", static_cast<lua_Integer>(st.dropped_rate));
    set_int(L, "dropped_out_rate", static_cast<lua_Integer>(st.dropped_out_rate));
    set_int(L, "allowed", static_cast<lua_Integer>(g_channel->allowed_count()));
    {
        std::scoped_lock lock{g_backup->mutex};
        lua_createtable(L, 0, 6);
        set_str(L, "state", g_backup->state);
        set_str(L, "message", g_backup->message);
        set_str(L, "folder", g_backup->folder);
        set_int(L, "files", static_cast<lua_Integer>(g_backup->files));
        set_int(L, "bytes", static_cast<lua_Integer>(g_backup->bytes));
        set_int(L, "removed", g_backup->removed);
        lua_setfield(L, -2, "backup");
    }
    return 1;
}

int l_local_id(lua_State* L) {
    ensure_net();
    const auto id = g_steam->available() ? g_steam->local_id() : 0;
    if (!steam::is_individual_steam_id(id)) {
        return fail(L, "local Steam ID unavailable");
    }
    const auto s = std::to_string(id);
    lua_pushlstring(L, s.data(), s.size());
    return 1;
}

int l_game_build(lua_State* L) {
    ensure_net();
    const int build = g_steam->available() ? g_steam->app_build() : 0;
    if (build <= 0) {
        return fail(L, "game build unavailable");
    }
    lua_pushinteger(L, build);
    return 1;
}

int l_friends_in_game(lua_State* L) {
    ensure_net();
    if (!g_steam->available()) {
        return fail(L, "steam unavailable");
    }
    const auto friends = g_steam->friends_in_app(kAppId);
    lua_createtable(L, static_cast<int>(friends.size()), 0);
    lua_Integer i = 1;
    for (const auto& f : friends) {
        lua_createtable(L, 0, 2);
        set_str(L, "id", std::to_string(f.id));
        set_str(L, "name", f.name);
        lua_rawseti(L, -2, i++);
    }
    return 1;
}

int l_allow(lua_State* L) {
    ensure_net();
    std::uint64_t id = 0;
    if (!parse_id(L, 1, id)) {
        return fail(L, "bad steam id");
    }
    g_channel->allow(id, lua_toboolean(L, 2) != 0);
    lua_pushboolean(L, 1);
    return 1;
}

int l_send(lua_State* L) {
    ensure_net();
    std::uint64_t id = 0;
    if (!parse_id(L, 1, id)) {
        return fail(L, "bad steam id");
    }
    if (lua_type(L, 2) != LUA_TSTRING) {
        return fail(L, "data must be a string");
    }
    std::size_t len = 0;
    const char* data = lua_tolstring(L, 2, &len);
    const bool reliable = lua_isnoneornil(L, 3) || lua_toboolean(L, 3) != 0;
    const auto err = g_channel->send(id, std::string_view{data, len}, reliable);
    if (err != Channel::SendError::None) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, Channel::to_string(err));
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int l_poll(lua_State* L) {
    ensure_net();
    int max = 64;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        max = static_cast<int>(std::clamp<lua_Integer>(lua_tointeger(L, 1), 1, 256));
    }
    const auto msgs = g_channel->poll(max);
    lua_createtable(L, static_cast<int>(msgs.size()), 0);
    lua_Integer i = 1;
    for (const auto& m : msgs) {
        lua_createtable(L, 0, 2);
        set_str(L, "from", std::to_string(m.from));
        set_str(L, "data", m.data);
        lua_rawseti(L, -2, i++);
    }
    return 1;
}

int l_close(lua_State* L) {
    ensure_net();
    std::uint64_t id = 0;
    if (!parse_id(L, 1, id)) {
        return fail(L, "bad steam id");
    }
    g_channel->close(id);
    lua_pushboolean(L, 1);
    return 1;
}

constexpr std::array<luaL_Reg, 9> kFunctions{{
    {"version", l_version},
    {"status", l_status},
    {"local_id", l_local_id},
    {"game_build", l_game_build},
    {"friends_in_game", l_friends_in_game},
    {"allow", l_allow},
    {"send", l_send},
    {"poll", l_poll},
    {"close", l_close},
}};

void on_lua_state_created(lua_State* L) {
    if (g_fns != nullptr) {
        g_fns->lock_lua();
    }
    lua_createtable(L, 0, static_cast<int>(kFunctions.size()));
    for (const auto& reg : kFunctions) {
        lua_pushcfunction(L, reg.func);
        lua_setfield(L, -2, reg.name);
    }
    lua_setglobal(L, "seamless_net");
    if (g_fns != nullptr) {
        g_fns->unlock_lua();
    }
}

void on_lua_state_destroyed(lua_State*) {
    // A script reset re-creates the allow-list from Lua.
    if (g_channel) {
        g_channel->clear();
    }
}

} // namespace

extern "C" __declspec(dllexport) void reframework_plugin_required_version(REFrameworkPluginVersion* version) {
    version->major = REFRAMEWORK_PLUGIN_VERSION_MAJOR;
    version->minor = REFRAMEWORK_PLUGIN_VERSION_MINOR;
    version->patch = REFRAMEWORK_PLUGIN_VERSION_PATCH;
}

extern "C" __declspec(dllexport) bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* param) {
    g_fns = param->functions;
    g_fns->on_lua_state_created(on_lua_state_created);
    g_fns->on_lua_state_destroyed(on_lua_state_destroyed);
    log_info("[seamless_net] %s loaded (Lua %s)", kPluginVersion, LUA_RELEASE);
    std::thread{backup_worker}.detach();
    return true;
}
