-- Minimal test library for the offline Lua tests (run by tests/lua/run.lua).
local M = { passed = 0, failed = 0, failures = {}, current_file = "?" }

local function repr(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    local parts, n = {}, 0
    for k, val in pairs(v) do
        n = n + 1
        if n > 8 then parts[#parts + 1] = "..." break end
        parts[#parts + 1] = tostring(k) .. "=" .. (type(val) == "table" and "{...}" or repr(val))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end
M.repr = repr

function M.test(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        M.passed = M.passed + 1
    else
        M.failed = M.failed + 1
        M.failures[#M.failures + 1] = string.format("[%s] %s\n    %s", M.current_file, name, tostring(err):gsub("\n", "\n    "))
    end
end

local function fail(msg, level)
    error(msg, (level or 2) + 1)
end

function M.eq(actual, expected, msg)
    if actual ~= expected then
        fail(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", repr(expected), repr(actual)))
    end
end

function M.ok(v, msg)
    if not v then fail(msg or "expected a truthy value") end
end

function M.no(v, msg)
    if v then fail(msg or ("expected a falsy value, got " .. repr(v))) end
end

function M.near(a, b, eps, msg)
    if type(a) ~= "number" or math.abs(a - b) > (eps or 1e-9) then
        fail(string.format("%sexpected %s +/- %s, got %s", msg and (msg .. ": ") or "", tostring(b), tostring(eps), repr(a)))
    end
end

local function deep_eq(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deep_eq(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end
M.deep_eq_raw = deep_eq

function M.same(actual, expected, msg)
    if not deep_eq(actual, expected) then
        fail(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", repr(expected), repr(actual)))
    end
end

function M.raises(fn, pattern)
    local ok, err = pcall(fn)
    if ok then fail("expected an error") end
    if pattern and not tostring(err):find(pattern) then
        fail(string.format("error %s does not match %s", repr(tostring(err)), repr(pattern)))
    end
end

function M.contains(list, value, msg)
    for _, v in ipairs(list) do
        if v == value then return end
    end
    fail(string.format("%s%s not in %s", msg and (msg .. ": ") or "", repr(value), repr(list)))
end

-- A controllable clock for scheduler/handshake/loopback tests.
function M.clock(start)
    local c = { now = start or 0 }
    function c.fn() return c.now end
    function c.advance(dt) c.now = c.now + dt end
    return c
end

return M
