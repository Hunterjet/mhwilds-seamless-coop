#pragma once

#include <cstdint>
#include <ctime>
#include <filesystem>
#include <string>
#include <string_view>

namespace seamless {

// Save backups (spec F5.3): the plugin only ever COPIES the game's save folder; it never writes to it.

struct BackupSettings {
    bool enabled = true;
    int keep = 10;
};

struct BackupResult {
    bool ok = false;
    std::string message;
    std::filesystem::path destination;
    std::size_t files = 0;
    std::uintmax_t bytes = 0;
    int removed = 0;
};

// Reads save_backup_on_launch / save_backups_to_keep from the mod's config.json text. Missing or invalid -> defaults.
BackupSettings parse_backup_settings(std::string_view config_json);

// UTC "YYYYMMDD-HHMMSS".
std::string utc_stamp(std::time_t t);

// True for folder names produced by utc_stamp (only those are ever deleted by rotation).
bool is_stamp(std::string_view name);

// Copies `source` into `backups_root / stamp`, then deletes the oldest stamp-named folders beyond `keep`.
BackupResult backup_saves(const std::filesystem::path& source, const std::filesystem::path& backups_root,
                          const std::string& stamp, int keep);

} // namespace seamless
