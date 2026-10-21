#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace seamless {

struct Friend {
    std::uint64_t id = 0;
    std::string name;
};

struct ReceivedMessage {
    std::uint64_t from = 0;
    int channel = 0;
    std::string data;
};

// The Steam features the plugin needs. FlatSteam implements it with the game's steam_api64.dll; tests use a fake.
class SteamBackend {
public:
    virtual ~SteamBackend() = default;

    // False if steam_api64.dll or a required export is missing (reason() says which).
    [[nodiscard]] virtual bool available() const = 0;
    [[nodiscard]] virtual std::string reason() const = 0;

    virtual std::uint64_t local_id() = 0;
    virtual int app_build() = 0;
    virtual std::optional<std::filesystem::path> user_data_folder() = 0;
    virtual std::vector<Friend> friends_in_app(std::uint32_t app_id) = 0;

    // Returns the Steam EResult (1 = OK).
    virtual int send(std::uint64_t to, const void* data, std::uint32_t size, int flags, int channel) = 0;
    virtual void receive(int channel, int max, std::vector<ReceivedMessage>& out) = 0;
    virtual bool accept(std::uint64_t peer) = 0;
    virtual bool close(std::uint64_t peer) = 0;

    // ESteamNetworkingAvailability of the relay network (100 = current), or 0 if unknown.
    virtual int relay_status() = 0;
};

} // namespace seamless
