#pragma once

#include <algorithm>

namespace seamless {

// Token bucket: `rate` tokens per second, at most `burst` stored. Time is in seconds from any monotonic clock.
class TokenBucket {
public:
    TokenBucket(double rate, double burst) : m_rate{rate}, m_burst{burst}, m_tokens{burst} {}

    bool take(double now, double cost = 1.0) {
        if (m_last < 0.0) {
            m_last = now;
        }
        m_tokens = std::min(m_burst, m_tokens + std::max(0.0, now - m_last) * m_rate);
        m_last = now;
        if (m_tokens < cost) {
            return false;
        }
        m_tokens -= cost;
        return true;
    }

    [[nodiscard]] double tokens() const { return m_tokens; }

private:
    double m_rate;
    double m_burst;
    double m_tokens;
    double m_last{-1.0};
};

} // namespace seamless
