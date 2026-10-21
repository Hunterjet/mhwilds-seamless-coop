-- Offline Lua test runner. Usage (from the repo root):
--   build\release\tests\lua_runner.exe tests\lua\run.lua .
-- The interpreter is built from REFramework's own Lua 5.4.3 sources, so behaviour matches the game.
local root = arg[1] or "."
package.path = root .. "/src/lua/?.lua;" .. root .. "/tests/lua/?.lua;" .. package.path

local t = require("lib.t")

local FILES = {
    "test_json", "test_util_log", "test_events", "test_scheduler", "test_config", "test_hotkeys",
    "test_protocol", "test_peers", "test_loopback", "test_handshake", "test_build_check", "test_discovery",
    "test_party", "test_main",
}

local only = arg[2]
for _, name in ipairs(FILES) do
    if not only or name == only then
        t.current_file = name
        local ok, err = xpcall(require, debug.traceback, name)
        if not ok then
            t.failed = t.failed + 1
            t.failures[#t.failures + 1] = string.format("[%s] failed to load\n    %s", name, tostring(err))
        end
    end
end

for _, f in ipairs(t.failures) do io.stderr:write("FAIL ", f, "\n") end
print(string.format("Lua tests: %d passed, %d failed (%s)", t.passed, t.failed, _VERSION))
os.exit(t.failed == 0 and 0 or 1)
