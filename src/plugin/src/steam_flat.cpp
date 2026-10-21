#include "steam_flat.hpp"

#include "steam_types.hpp"

#include <Windows.h>

#include <algorithm>
#include <array>
#include <cstring>
#include <initializer_list>

namespace seamless {

namespace {

FARPROC find_first(HMODULE dll, std::initializer_list<const char*> names, std::string& missing) {
    for (const char* n : names) {
        if (auto p = GetProcAddress(dll, n)) {
            return p;
        }
    }
    if (!missing.empty()) {
        missing += ", ";
    }
    missing += *names.begin();
    return nullptr;
}

template <typename T>
void bind(T& fn, HMODULE dll, std::initializer_list<const char*> names, std::string& missing) {
    fn = reinterpret_cast<T>(find_first(dll, names, missing));
}

steam::NetworkingIdentity make_identity(std::uint64_t steam_id) {
    steam::NetworkingIdentity id{};
    id.type = steam::kIdentityTypeSteamId;
    id.size = sizeof(std::uint64_t);
    id.steam_id64 = steam_id;
    return id;
}

} // namespace

FlatSteam::FlatSteam() {
    HMODULE dll = GetModuleHandleW(L"steam_api64.dll");
    if (dll == nullptr) {
        m_reason = "steam_api64.dll is not loaded";
        return;
    }
    std::string missing;
    // Interface accessors: newest known version first; the game ships whatever its SDK had.
    bind(m_user_acc, dll, {"SteamAPI_SteamUser_v023", "SteamAPI_SteamUser_v022", "SteamAPI_SteamUser_v021", "SteamAPI_SteamUser_v020"}, missing);
    bind(m_friends_acc, dll, {"SteamAPI_SteamFriends_v018", "SteamAPI_SteamFriends_v017"}, missing);
    bind(m_apps_acc, dll, {"SteamAPI_SteamApps_v008"}, missing);
    bind(m_messages_acc, dll, {"SteamAPI_SteamNetworkingMessages_SteamAPI_v002"}, missing);
    bind(m_utils_acc, dll, {"SteamAPI_SteamNetworkingUtils_SteamAPI_v004"}, missing);

    bind(m_get_steam_id, dll, {"SteamAPI_ISteamUser_GetSteamID"}, missing);
    bind(m_get_user_data_folder, dll, {"SteamAPI_ISteamUser_GetUserDataFolder"}, missing);
    bind(m_get_friend_count, dll, {"SteamAPI_ISteamFriends_GetFriendCount"}, missing);
    bind(m_get_friend_by_index, dll, {"SteamAPI_ISteamFriends_GetFriendByIndex"}, missing);
    bind(m_get_friend_persona_name, dll, {"SteamAPI_ISteamFriends_GetFriendPersonaName"}, missing);
    bind(m_get_friend_game_played, dll, {"SteamAPI_ISteamFriends_GetFriendGamePlayed"}, missing);
    bind(m_get_app_build_id, dll, {"SteamAPI_ISteamApps_GetAppBuildId"}, missing);
    bind(m_send_message_to_user, dll, {"SteamAPI_ISteamNetworkingMessages_SendMessageToUser"}, missing);
    bind(m_receive_messages_on_channel, dll, {"SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel"}, missing);
    bind(m_accept_session_with_user, dll, {"SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser"}, missing);
    bind(m_close_session_with_user, dll, {"SteamAPI_ISteamNetworkingMessages_CloseSessionWithUser"}, missing);
    bind(m_message_release, dll, {"SteamAPI_SteamNetworkingMessage_t_Release"}, missing);
    bind(m_init_relay_network_access, dll, {"SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess"}, missing);
    bind(m_get_relay_network_status, dll, {"SteamAPI_ISteamNetworkingUtils_GetRelayNetworkStatus"}, missing);

    if (!missing.empty()) {
        m_reason = "steam_api64.dll is missing exports: " + missing;
        return;
    }
    m_ok = true;
}

void* FlatSteam::user() { return m_ok ? m_user_acc() : nullptr; }
void* FlatSteam::friends() { return m_ok ? m_friends_acc() : nullptr; }
void* FlatSteam::apps() { return m_ok ? m_apps_acc() : nullptr; }
void* FlatSteam::messages() { return m_ok ? m_messages_acc() : nullptr; }
void* FlatSteam::net_utils() { return m_ok ? m_utils_acc() : nullptr; }

std::uint64_t FlatSteam::local_id() {
    auto* u = user();
    return u != nullptr ? m_get_steam_id(u) : 0;
}

int FlatSteam::app_build() {
    auto* a = apps();
    return a != nullptr ? m_get_app_build_id(a) : 0;
}

std::optional<std::filesystem::path> FlatSteam::user_data_folder() {
    auto* u = user();
    if (u == nullptr) {
        return std::nullopt;
    }
    std::array<char, 1024> buf{};
    if (!m_get_user_data_folder(u, buf.data(), static_cast<int>(buf.size()))) {
        return std::nullopt;
    }
    buf.back() = '\0';
    // Steam returns the path in UTF-8.
    return std::filesystem::path{std::u8string{reinterpret_cast<const char8_t*>(buf.data())}};
}

std::vector<Friend> FlatSteam::friends_in_app(std::uint32_t app_id) {
    std::vector<Friend> out;
    auto* f = friends();
    if (f == nullptr) {
        return out;
    }
    const int count = m_get_friend_count(f, steam::kFriendFlagImmediate);
    for (int i = 0; i < count && i < 2000; ++i) {
        const std::uint64_t id = m_get_friend_by_index(f, i, steam::kFriendFlagImmediate);
        if (!steam::is_individual_steam_id(id)) {
            continue;
        }
        // FriendGameInfo_t: CGameID (uint64) first; the low 24 bits are the AppID. Oversized buffer on purpose.
        alignas(8) std::array<unsigned char, 64> info{};
        if (!m_get_friend_game_played(f, id, info.data())) {
            continue;
        }
        std::uint64_t game_id = 0;
        std::memcpy(&game_id, info.data(), sizeof(game_id));
        if ((game_id & 0xFFFFFFu) != app_id || ((game_id >> 24) & 0xFFu) != 0) {
            continue;
        }
        const char* name = m_get_friend_persona_name(f, id);
        out.push_back(Friend{id, name != nullptr ? name : ""});
    }
    return out;
}

int FlatSteam::send(std::uint64_t to, const void* data, std::uint32_t size, int flags, int channel) {
    auto* m = messages();
    if (m == nullptr) {
        return 0;
    }
    const auto id = make_identity(to);
    return m_send_message_to_user(m, &id, data, size, flags, channel);
}

void FlatSteam::receive(int channel, int max, std::vector<ReceivedMessage>& out) {
    auto* m = messages();
    if (m == nullptr) {
        return;
    }
    std::array<void*, 64> msgs{};
    const int n = m_receive_messages_on_channel(m, channel, msgs.data(), std::min<int>(max, static_cast<int>(msgs.size())));
    for (int i = 0; i < n; ++i) {
        auto* msg = static_cast<steam::NetworkingMessage*>(msgs[i]);
        if (msg == nullptr) {
            continue;
        }
        ReceivedMessage r{};
        r.from = msg->peer.type == steam::kIdentityTypeSteamId ? msg->peer.steam_id64 : 0;
        r.channel = msg->channel;
        if (msg->data != nullptr && msg->size > 0) {
            r.data.assign(static_cast<const char*>(msg->data), static_cast<std::size_t>(msg->size));
        }
        m_message_release(msg);
        out.push_back(std::move(r));
    }
}

bool FlatSteam::accept(std::uint64_t peer) {
    auto* m = messages();
    if (m == nullptr) {
        return false;
    }
    const auto id = make_identity(peer);
    return m_accept_session_with_user(m, &id);
}

bool FlatSteam::close(std::uint64_t peer) {
    auto* m = messages();
    if (m == nullptr) {
        return false;
    }
    const auto id = make_identity(peer);
    return m_close_session_with_user(m, &id);
}

int FlatSteam::relay_status() {
    auto* u = net_utils();
    return u != nullptr ? m_get_relay_network_status(u, nullptr) : 0;
}

void FlatSteam::init_relay() {
    if (auto* u = net_utils()) {
        m_init_relay_network_access(u);
    }
}

} // namespace seamless
