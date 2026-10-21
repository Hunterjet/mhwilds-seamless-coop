#pragma once

// Minimal declarations of the Steamworks flat-API types the plugin uses. No Steamworks SDK files are redistributed;
// layouts were checked against Valve's BSD-licensed GameNetworkingSockets headers (steamnetworkingtypes.h) and are
// pinned with static_asserts.

#include <cstddef>
#include <cstdint>

namespace seamless::steam {

#pragma pack(push, 1)
struct NetworkingIdentity {
    std::int32_t type;
    std::int32_t size;
    union {
        std::uint64_t steam_id64;
        char raw[128];
        std::uint32_t reserved[32];
    };
};
#pragma pack(pop)
static_assert(sizeof(NetworkingIdentity) == 136);
static_assert(offsetof(NetworkingIdentity, steam_id64) == 8);

#pragma pack(push, 8)
struct NetworkingMessage {
    void* data;
    std::int32_t size;
    std::uint32_t connection;
    NetworkingIdentity peer;
    std::int64_t connection_user_data;
    std::int64_t time_received_us;
    std::int64_t message_number;
    void (*free_data)(NetworkingMessage*);
    void (*release)(NetworkingMessage*);
    std::int32_t channel;
    std::int32_t flags;
    std::int64_t user_data;
    std::uint16_t lane;
};
#pragma pack(pop)
static_assert(offsetof(NetworkingMessage, size) == 8);
static_assert(offsetof(NetworkingMessage, peer) == 16);
static_assert(offsetof(NetworkingMessage, connection_user_data) == 152);
static_assert(offsetof(NetworkingMessage, channel) == 192);
static_assert(sizeof(NetworkingMessage) == 216);

inline constexpr std::int32_t kIdentityTypeSteamId = 16;

inline constexpr int kSendUnreliable = 0;
inline constexpr int kSendReliable = 8;
inline constexpr int kSendAutoRestartBrokenSession = 32;

inline constexpr int kFriendFlagImmediate = 0x04;

inline constexpr int kResultOk = 1; // EResult k_EResultOK

// ESteamNetworkingAvailability
inline constexpr int kAvailabilityCurrent = 100;

// Individual-account SteamID64 range (universe Public, account type Individual, instance 1).
inline constexpr bool is_individual_steam_id(std::uint64_t id) {
    return (id >> 32) == 0x01100001u && (id & 0xFFFFFFFFu) != 0;
}

} // namespace seamless::steam
