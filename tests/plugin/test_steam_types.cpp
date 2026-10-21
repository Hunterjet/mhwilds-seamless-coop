#include "steam_types.hpp"

#include <catch2/catch_test_macros.hpp>

using namespace seamless::steam;

TEST_CASE("individual SteamID64 detection") {
    CHECK(is_individual_steam_id(76561197960265729ull));
    CHECK(is_individual_steam_id(76561198000000001ull));
    CHECK_FALSE(is_individual_steam_id(0));
    CHECK_FALSE(is_individual_steam_id(76561197960265728ull)); // account id 0
    CHECK_FALSE(is_individual_steam_id(103582791429521408ull)); // a group/clan id
}

TEST_CASE("struct layouts match the Steamworks ABI") {
    // Compile-time checks live in steam_types.hpp; these keep them visible in the test report.
    CHECK(sizeof(NetworkingIdentity) == 136);
    CHECK(sizeof(NetworkingMessage) == 216);
}
