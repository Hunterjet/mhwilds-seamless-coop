#pragma once

#include "rate_limiter.hpp"
#include "steam_backend.hpp"

#include <cstdint>
#include <functional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace seamless {

// The mod's side channel on top of a SteamBackend (spec N4): only allow-listed peers (verified party members chosen by
// the Lua side) may send or receive, messages are size-limited, and both directions are rate-limited per peer.
class Channel {
public:
    struct Limits {
        std::size_t max_bytes;
        double in_rate;
        double in_burst;
        double out_rate;
        double out_burst;
        double accept_interval;
    };

    static constexpr Limits kDefaultLimits{4096, 30.0, 60.0, 30.0, 60.0, 1.0};

    struct Stats {
        std::uint64_t sent = 0;
        std::uint64_t send_failed = 0;
        std::uint64_t received = 0;
        std::uint64_t dropped_not_allowed = 0;
        std::uint64_t dropped_size = 0;
        std::uint64_t dropped_rate = 0;
        std::uint64_t dropped_out_rate = 0;
    };

    enum class SendError { None, NotAllowed, TooLarge, RateLimited, SteamUnavailable, SteamError };

    using Clock = std::function<double()>;

    Channel(SteamBackend& steam, int channel, Clock clock, Limits limits = kDefaultLimits);

    void allow(std::uint64_t peer, bool on);
    [[nodiscard]] bool is_allowed(std::uint64_t peer) const;
    [[nodiscard]] std::size_t allowed_count() const { return m_peers.size(); }
    void clear();

    SendError send(std::uint64_t to, std::string_view data, bool reliable, int* steam_result = nullptr);
    std::vector<ReceivedMessage> poll(int max);
    void close(std::uint64_t peer);

    [[nodiscard]] const Stats& stats() const { return m_stats; }

    static const char* to_string(SendError e);

private:
    struct Peer {
        TokenBucket in;
        TokenBucket out;
    };

    SteamBackend& m_steam;
    int m_channel;
    Clock m_clock;
    Limits m_limits;
    std::unordered_map<std::uint64_t, Peer> m_peers;
    Stats m_stats{};
    double m_next_accept{0.0};
    std::vector<ReceivedMessage> m_scratch;
};

} // namespace seamless
