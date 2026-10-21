#include "save_backup.hpp"

#include <algorithm>
#include <regex>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

namespace seamless {

BackupSettings parse_backup_settings(std::string_view config_json) {
    BackupSettings s{};
    const std::string text{config_json};
    std::smatch m;
    static const std::regex enabled_re{R"re("save_backup_on_launch"\s*:\s*(true|false))re"};
    static const std::regex keep_re{R"re("save_backups_to_keep"\s*:\s*(\d{1,4})(?:\.0+)?\s*[,}\r\n])re"};
    if (std::regex_search(text, m, enabled_re)) {
        s.enabled = m[1] == "true";
    }
    if (std::regex_search(text, m, keep_re)) {
        s.keep = std::clamp(std::stoi(m[1]), 1, 50);
    }
    return s;
}

std::string utc_stamp(std::time_t t) {
    std::tm tm{};
    gmtime_s(&tm, &t);
    char buf[32]{};
    std::strftime(buf, sizeof(buf), "%Y%m%d-%H%M%S", &tm);
    return buf;
}

bool is_stamp(std::string_view name) {
    if (name.size() != 15 || name[8] != '-') {
        return false;
    }
    for (std::size_t i = 0; i < name.size(); ++i) {
        if (i != 8 && (name[i] < '0' || name[i] > '9')) {
            return false;
        }
    }
    return true;
}

static bool is_within(const fs::path& child, const fs::path& parent) {
    std::error_code ec;
    const auto c = fs::weakly_canonical(child, ec);
    const auto p = fs::weakly_canonical(parent, ec);
    auto [pi, ci] = std::mismatch(p.begin(), p.end(), c.begin(), c.end());
    return pi == p.end();
}

BackupResult backup_saves(const fs::path& source, const fs::path& backups_root, const std::string& stamp, int keep) {
    BackupResult r{};
    std::error_code ec;
    if (!is_stamp(stamp)) {
        r.message = "invalid backup name";
        return r;
    }
    if (!fs::is_directory(source, ec)) {
        r.message = "save folder not found";
        return r;
    }
    if (is_within(backups_root, source) || is_within(source, backups_root)) {
        r.message = "backup folder overlaps the save folder";
        return r;
    }
    const auto dest = backups_root / stamp;
    if (fs::exists(dest, ec)) {
        r.message = "backup already exists";
        return r;
    }
    fs::create_directories(dest, ec);
    if (ec) {
        r.message = "cannot create backup folder: " + ec.message();
        return r;
    }

    for (auto it = fs::recursive_directory_iterator{source, fs::directory_options::skip_permission_denied, ec};
         !ec && it != fs::recursive_directory_iterator{}; it.increment(ec)) {
        const auto& entry = *it;
        const auto rel = fs::relative(entry.path(), source, ec);
        if (ec) {
            break;
        }
        if (entry.is_symlink(ec)) {
            continue;
        }
        if (entry.is_directory(ec)) {
            fs::create_directories(dest / rel, ec);
        } else if (entry.is_regular_file(ec)) {
            fs::copy_file(entry.path(), dest / rel, fs::copy_options::overwrite_existing, ec);
            if (!ec) {
                ++r.files;
                r.bytes += entry.file_size(ec);
            }
        }
        if (ec) {
            break;
        }
    }
    if (ec) {
        r.message = "copy failed: " + ec.message();
        std::error_code ignore;
        fs::remove_all(dest, ignore);
        return r;
    }

    std::vector<fs::path> backups;
    for (const auto& entry : fs::directory_iterator{backups_root, ec}) {
        if (entry.is_directory() && is_stamp(entry.path().filename().string())) {
            backups.push_back(entry.path());
        }
    }
    std::sort(backups.begin(), backups.end());
    const auto limit = static_cast<std::size_t>(std::max(1, keep));
    while (backups.size() > limit) {
        std::error_code rec;
        fs::remove_all(backups.front(), rec);
        if (!rec) {
            ++r.removed;
        }
        backups.erase(backups.begin());
    }

    r.ok = true;
    r.destination = dest;
    r.message = "ok";
    return r;
}

} // namespace seamless
