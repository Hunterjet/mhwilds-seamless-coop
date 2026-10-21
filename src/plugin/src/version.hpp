#pragma once

#include <cstddef>
#include <cstdint>

namespace seamless {

#ifndef SEAMLESS_NET_VERSION
#define SEAMLESS_NET_VERSION "0.0.0"
#endif

inline constexpr const char* kPluginVersion = SEAMLESS_NET_VERSION;

// Lua API revision of the seamless_net table (bump when functions change).
inline constexpr int kLuaApiVersion = 1;

inline constexpr std::uint32_t kAppId = 2246340; // Monster Hunter Wilds

// Steam Networking Messages channel used by the mod (any value works; both sides must agree).
inline constexpr int kChannel = 2246;

// Hard limit for one side-channel message (the Lua protocol uses the same limit).
inline constexpr std::size_t kMaxMessageBytes = 4096;

} // namespace seamless
