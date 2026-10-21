#pragma once

#include "steam_backend.hpp"

#include <cstdint>
#include <string>

namespace seamless {

// SteamBackend over the game's own steam_api64.dll, bound at runtime through its flat-API exports (implementation
// plan D3). Nothing is linked at build time; a missing DLL or export disables the side channel with a reason.
class FlatSteam final : public SteamBackend {
public:
    FlatSteam();

    [[nodiscard]] bool available() const override { return m_ok; }
    [[nodiscard]] std::string reason() const override { return m_reason; }

    std::uint64_t local_id() override;
    int app_build() override;
    std::optional<std::filesystem::path> user_data_folder() override;
    std::vector<Friend> friends_in_app(std::uint32_t app_id) override;

    int send(std::uint64_t to, const void* data, std::uint32_t size, int flags, int channel) override;
    void receive(int channel, int max, std::vector<ReceivedMessage>& out) override;
    bool accept(std::uint64_t peer) override;
    bool close(std::uint64_t peer) override;
    int relay_status() override;

    // Starts relay network setup early so the first message is not delayed (harmless if already running).
    void init_relay();

private:
    using Accessor = void* (*)();

    void* user();
    void* friends();
    void* apps();
    void* messages();
    void* net_utils();

    bool m_ok{false};
    std::string m_reason;

    Accessor m_user_acc{};
    Accessor m_friends_acc{};
    Accessor m_apps_acc{};
    Accessor m_messages_acc{};
    Accessor m_utils_acc{};

    std::uint64_t (*m_get_steam_id)(void*){};
    bool (*m_get_user_data_folder)(void*, char*, int){};
    int (*m_get_friend_count)(void*, int){};
    std::uint64_t (*m_get_friend_by_index)(void*, int, int){};
    const char* (*m_get_friend_persona_name)(void*, std::uint64_t){};
    bool (*m_get_friend_game_played)(void*, std::uint64_t, void*){};
    int (*m_get_app_build_id)(void*){};
    int (*m_send_message_to_user)(void*, const void*, const void*, std::uint32_t, int, int){};
    int (*m_receive_messages_on_channel)(void*, int, void**, int){};
    bool (*m_accept_session_with_user)(void*, const void*){};
    bool (*m_close_session_with_user)(void*, const void*){};
    void (*m_message_release)(void*){};
    void (*m_init_relay_network_access)(void*){};
    int (*m_get_relay_network_status)(void*, void*){};
};

} // namespace seamless
