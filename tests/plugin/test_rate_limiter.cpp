#include "rate_limiter.hpp"

#include <catch2/catch_test_macros.hpp>

using seamless::TokenBucket;

TEST_CASE("token bucket allows a burst then refills at the configured rate") {
    TokenBucket b{10.0, 3.0};
    CHECK(b.take(0.0));
    CHECK(b.take(0.0));
    CHECK(b.take(0.0));
    CHECK_FALSE(b.take(0.0));
    CHECK_FALSE(b.take(0.05)); // 0.5 token
    CHECK(b.take(0.1));        // 1 token after 0.1 s
    CHECK_FALSE(b.take(0.1));
}

TEST_CASE("token bucket never stores more than the burst") {
    TokenBucket b{100.0, 2.0};
    CHECK(b.take(0.0));
    CHECK(b.take(100.0));
    CHECK(b.take(100.0));
    CHECK_FALSE(b.take(100.0));
}

TEST_CASE("token bucket ignores clocks going backwards") {
    TokenBucket b{1.0, 1.0};
    CHECK(b.take(10.0));
    CHECK_FALSE(b.take(5.0));
    CHECK(b.take(11.0));
}
