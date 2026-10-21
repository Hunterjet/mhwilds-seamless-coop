-- Small helpers shared by several modules. No game access.
local M = {}

function M.shallow_copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

function M.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Steam IDs and other long numeric IDs are never shown in full (privacy rule): keeps the last 4 digits.
function M.short_id(id)
    local s = tostring(id or "?")
    if #s <= 6 then return s end
    return "..." .. s:sub(-4)
end

-- Replaces full SteamID64 values in free text with their short form.
function M.redact(text)
    return (tostring(text):gsub("7656119%d%d%d%d%d%d(%d%d%d%d)", "...%1"))
end

function M.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function M.sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

return M
