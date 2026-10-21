#include "save_backup.hpp"

#include <catch2/catch_test_macros.hpp>

#include <fstream>
#include <random>

namespace fs = std::filesystem;
using namespace seamless;

namespace {

struct TempDir {
    fs::path path;
    TempDir() {
        std::random_device rd;
        path = fs::temp_directory_path() / ("seamless-test-" + std::to_string(rd()));
        fs::create_directories(path);
    }
    ~TempDir() {
        std::error_code ec;
        fs::remove_all(path, ec);
    }
};

void write(const fs::path& p, const std::string& text) {
    fs::create_directories(p.parent_path());
    std::ofstream{p, std::ios::binary} << text;
}

std::string read(const fs::path& p) {
    std::ifstream f{p, std::ios::binary};
    return {std::istreambuf_iterator<char>{f}, {}};
}

} // namespace

TEST_CASE("settings are parsed from the mod's config.json text") {
    CHECK(parse_backup_settings("").enabled);
    CHECK(parse_backup_settings("").keep == 10);
    const auto s = parse_backup_settings(R"({
    "enabled": true,
    "save_backup_on_launch": false,
    "save_backups_to_keep": 3
})");
    CHECK_FALSE(s.enabled);
    CHECK(s.keep == 3);
    CHECK(parse_backup_settings(R"({"save_backups_to_keep": 999})").keep == 50);
    CHECK(parse_backup_settings(R"({"save_backups_to_keep": 0})").keep == 1);
    CHECK(parse_backup_settings(R"({"save_backups_to_keep": 5.0, "x": 1})").keep == 5);
}

TEST_CASE("stamps are UTC and recognised") {
    CHECK(utc_stamp(0) == "19700101-000000");
    CHECK(is_stamp("20261021-101500"));
    CHECK_FALSE(is_stamp("2026102-101500"));
    CHECK_FALSE(is_stamp("20261021_101500"));
    CHECK_FALSE(is_stamp("win64_save"));
}

TEST_CASE("backup copies the save folder recursively without touching it") {
    TempDir tmp;
    const auto saves = tmp.path / "remote";
    write(saves / "win64_save" / "data000.bin", "slot0");
    write(saves / "win64_save" / "data001.bin", "slot1");
    const auto root = tmp.path / "backups";

    const auto r = backup_saves(saves, root, "20261021-101500", 10);
    REQUIRE(r.ok);
    CHECK(r.files == 2);
    CHECK(r.bytes == 10);
    CHECK(read(root / "20261021-101500" / "win64_save" / "data000.bin") == "slot0");
    CHECK(read(saves / "win64_save" / "data001.bin") == "slot1");
}

TEST_CASE("rotation keeps the newest backups and only deletes stamp-named folders") {
    TempDir tmp;
    const auto saves = tmp.path / "remote";
    write(saves / "a.bin", "a");
    const auto root = tmp.path / "backups";
    fs::create_directories(root / "my notes");
    for (const char* stamp : {"20261021-100000", "20261021-100001", "20261021-100002"}) {
        REQUIRE(backup_saves(saves, root, stamp, 2).ok);
    }
    CHECK_FALSE(fs::exists(root / "20261021-100000"));
    CHECK(fs::exists(root / "20261021-100001"));
    CHECK(fs::exists(root / "20261021-100002"));
    CHECK(fs::exists(root / "my notes"));
}

TEST_CASE("backup refuses bad inputs") {
    TempDir tmp;
    CHECK_FALSE(backup_saves(tmp.path / "missing", tmp.path / "b", "20261021-100000", 5).ok);
    write(tmp.path / "remote" / "a.bin", "a");
    CHECK_FALSE(backup_saves(tmp.path / "remote", tmp.path / "b", "../escape", 5).ok);
    CHECK_FALSE(backup_saves(tmp.path / "remote", tmp.path / "remote" / "inside", "20261021-100000", 5).ok);
    REQUIRE(backup_saves(tmp.path / "remote", tmp.path / "b", "20261021-100000", 5).ok);
    CHECK_FALSE(backup_saves(tmp.path / "remote", tmp.path / "b", "20261021-100000", 5).ok); // already exists
}
