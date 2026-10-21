#include "channel.hpp"

#include "steam_types.hpp"

namespace seamless {

Channel::Channel(SteamBackend& steam, int channel, Clock clock, Limits limits)
    : m_steam{steam}, m_channel{channel}, m_clock{std::move(clock)}, m_limits{limits} {}

void Channel::allow(std::uint64_t peer, bool on) {
    if (on) {
        if (!m_peers.contains(peer)) {
            m_peers.emplace(peer, Peer{TokenBucket{m_limits.in_rate, m_limits.in_burst},
                                       TokenBucket{m_limits.out_rate, m_limits.out_burst}});
            if (m_steam.available()) {
                m_steam.accept(peer);
            }
        }
    } else {
        m_peers.erase(peer);
    }
}

bool Channel::is_allowed(std::uint64_t peer) const {
    return m_peers.contains(peer);
}

void Channel::clear() {
    m_peers.clear();
}

Channel::SendError Channel::send(std::uint64_t to, std::string_view data, bool reliable, int* steam_result) {
    auto it = m_peers.find(to);
    if (it == m_peers.end()) {
        return SendError::NotAllowed;
    }
    if (data.size() > m_limits.max_bytes) {
        return SendError::TooLarge;
    }
    if (!m_steam.available()) {
        return SendError::SteamUnavailable;
    }
    if (!it->second.out.take(m_clock())) {
        ++m_stats.dropped_out_rate;
        return SendError::RateLimited;
    }
    const int flags = (reliable ? steam::kSendReliable : steam::kSendUnreliable) | steam::kSendAutoRestartBrokenSession;
    const int result = m_steam.send(to, data.data(), static_cast<std::uint32_t>(data.size()), flags, m_channel);
    if (steam_result != nullptr) {
        *steam_result = result;
    }
    if (result != steam::kResultOk) {
        ++m_stats.send_failed;
        return SendError::SteamError;
    }
    ++m_stats.sent;
    return SendError::None;
}

std::vector<ReceivedMessage> Channel::poll(int max) {
    std::vector<ReceivedMessage> out;
    if (!m_steam.available() || max <= 0) {
        return out;
    }
    const double now = m_clock();
    if (now >= m_next_accept) {
        // Accept pending sessions from allow-listed peers only (Steam holds a stranger's first message until accepted).
        for (const auto& [peer, _] : m_peers) {
            m_steam.accept(peer);
        }
        m_next_accept = now + m_limits.accept_interval;
    }
    m_scratch.clear();
    m_steam.receive(m_channel, max, m_scratch);
    for (auto& msg : m_scratch) {
        auto it = m_peers.find(msg.from);
        if (it == m_peers.end()) {
            ++m_stats.dropped_not_allowed;
            continue;
        }
        if (msg.data.size() > m_limits.max_bytes) {
            ++m_stats.dropped_size;
            continue;
        }
        if (!it->second.in.take(now)) {
            ++m_stats.dropped_rate;
            continue;
        }
        ++m_stats.received;
        out.push_back(std::move(msg));
    }
    return out;
}

void Channel::close(std::uint64_t peer) {
    if (m_steam.available()) {
        m_steam.close(peer);
    }
}

const char* Channel::to_string(SendError e) {
    switch (e) {
    case SendError::None: return "ok";
    case SendError::NotAllowed: return "peer not allowed";
    case SendError::TooLarge: return "message too large";
    case SendError::RateLimited: return "rate limited";
    case SendError::SteamUnavailable: return "steam unavailable";
    case SendError::SteamError: return "steam send failed";
    }
    return "unknown";
}

} // namespace seamless
