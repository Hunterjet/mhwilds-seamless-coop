#include "channel.hpp"
#include "steam_types.hpp"

#include <catch2/catch_test_macros.hpp>

#include <deque>
#include <set>

using namespace seamless;

namespace {

constexpr std::uint64_t kAlice = 76561198000000001ull;
constexpr std::uint64_t kBob = 76561198000000002ull;
constexpr std::uint64_t kMallory = 76561198000000666ull;

struct FakeSteam final : SteamBackend {
    bool ok = true;
    int send_result = steam::kResultOk;
    std::vector<std::tuple<std::uint64_t, std::string, int, int>> sent;
    std::deque<ReceivedMessage> inbox;
    std::multiset<std::uint64_t> accepted;
    std::vector<std::uint64_t> closed;

    bool available() const override { return ok; }
    std::string reason() const override { return ok ? "" : "fake unavailable"; }
    std::uint64_t local_id() override { return kAlice; }
    int app_build() override { return 24705561; }
    std::optional<std::filesystem::path> user_data_folder() override { return std::nullopt; }
    std::vector<Friend> friends_in_app(std::uint32_t) override { return {}; }
    int send(std::uint64_t to, const void* data, std::uint32_t size, int flags, int channel) override {
        sent.emplace_back(to, std::string{static_cast<const char*>(data), size}, flags, channel);
        return send_result;
    }
    void receive(int channel, int max, std::vector<ReceivedMessage>& out) override {
        while (max-- > 0 && !inbox.empty()) {
            auto m = inbox.front();
            inbox.pop_front();
            m.channel = channel;
            out.push_back(std::move(m));
        }
    }
    bool accept(std::uint64_t peer) override {
        accepted.insert(peer);
        return true;
    }
    bool close(std::uint64_t peer) override {
        closed.push_back(peer);
        return true;
    }
    int relay_status() override { return steam::kAvailabilityCurrent; }
};

struct Fixture {
    FakeSteam steam;
    double now = 0.0;
    Channel channel{steam, 2246, [this] { return now; }};
};

} // namespace

TEST_CASE_METHOD(Fixture, "send requires the peer to be allow-listed") {
    CHECK(channel.send(kBob, "hi", true) == Channel::SendError::NotAllowed);
    channel.allow(kBob, true);
    CHECK(channel.send(kBob, "hi", true) == Channel::SendError::None);
    REQUIRE(steam.sent.size() == 1);
    const auto& [to, data, flags, ch] = steam.sent[0];
    CHECK(to == kBob);
    CHECK(data == "hi");
    CHECK(ch == 2246);
    CHECK((flags & steam::kSendReliable) != 0);
    CHECK((flags & steam::kSendAutoRestartBrokenSession) != 0);
}

TEST_CASE_METHOD(Fixture, "unreliable sends do not set the reliable flag") {
    channel.allow(kBob, true);
    CHECK(channel.send(kBob, "hb", false) == Channel::SendError::None);
    CHECK((std::get<2>(steam.sent[0]) & steam::kSendReliable) == 0);
}

TEST_CASE_METHOD(Fixture, "allowing a peer accepts its pending session; removing it stops traffic") {
    channel.allow(kBob, true);
    CHECK(steam.accepted.count(kBob) == 1);
    channel.allow(kBob, false);
    CHECK(channel.send(kBob, "hi", true) == Channel::SendError::NotAllowed);
}

TEST_CASE_METHOD(Fixture, "messages larger than the limit are refused both ways") {
    channel.allow(kBob, true);
    const std::string big(4097, 'x');
    CHECK(channel.send(kBob, big, true) == Channel::SendError::TooLarge);
    steam.inbox.push_back({kBob, 0, big});
    CHECK(channel.poll(16).empty());
    CHECK(channel.stats().dropped_size == 1);
}

TEST_CASE_METHOD(Fixture, "poll drops messages from peers that are not allow-listed") {
    channel.allow(kBob, true);
    steam.inbox.push_back({kMallory, 0, "evil"});
    steam.inbox.push_back({kBob, 0, "hello"});
    const auto got = channel.poll(16);
    REQUIRE(got.size() == 1);
    CHECK(got[0].from == kBob);
    CHECK(got[0].data == "hello");
    CHECK(channel.stats().dropped_not_allowed == 1);
    CHECK(channel.stats().received == 1);
}

TEST_CASE_METHOD(Fixture, "incoming messages are rate limited per peer") {
    channel.allow(kBob, true);
    for (int i = 0; i < 100; ++i) {
        steam.inbox.push_back({kBob, 0, "x"});
    }
    const auto got = channel.poll(100);
    CHECK(got.size() == 60); // burst
    CHECK(channel.stats().dropped_rate == 40);
    now += 1.0;
    for (int i = 0; i < 40; ++i) {
        steam.inbox.push_back({kBob, 0, "x"});
    }
    CHECK(channel.poll(100).size() == 30); // 30/s refill
}

TEST_CASE_METHOD(Fixture, "outgoing messages are rate limited per peer") {
    channel.allow(kBob, true);
    int ok = 0;
    for (int i = 0; i < 100; ++i) {
        ok += channel.send(kBob, "x", false) == Channel::SendError::None ? 1 : 0;
    }
    CHECK(ok == 60);
    CHECK(channel.stats().dropped_out_rate == 40);
}

TEST_CASE_METHOD(Fixture, "steam failures are reported and counted") {
    channel.allow(kBob, true);
    steam.send_result = 2; // k_EResultFail
    CHECK(channel.send(kBob, "x", true) == Channel::SendError::SteamError);
    CHECK(channel.stats().send_failed == 1);
    steam.ok = false;
    CHECK(channel.send(kBob, "x", true) == Channel::SendError::SteamUnavailable);
    CHECK(channel.poll(8).empty());
}

TEST_CASE_METHOD(Fixture, "poll re-accepts allow-listed sessions about once per second") {
    channel.allow(kBob, true);
    channel.allow(kAlice, true);
    steam.accepted.clear();
    channel.poll(1);
    CHECK(steam.accepted.size() == 2);
    channel.poll(1);
    CHECK(steam.accepted.size() == 2);
    now += 1.5;
    channel.poll(1);
    CHECK(steam.accepted.size() == 4);
}

TEST_CASE_METHOD(Fixture, "clear forgets every peer") {
    channel.allow(kBob, true);
    channel.clear();
    CHECK(channel.allowed_count() == 0);
    CHECK_FALSE(channel.is_allowed(kBob));
}
