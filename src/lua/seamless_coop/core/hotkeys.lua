-- Hotkey bindings like "Ctrl+F12" or "F9" (spec F6.5), with edge detection.
local M = {}

local VK = {
    BACKSPACE = 0x08, TAB = 0x09, ENTER = 0x0D, PAUSE = 0x13, ESC = 0x1B, SPACE = 0x20,
    PAGEUP = 0x21, PAGEDOWN = 0x22, END = 0x23, HOME = 0x24, INSERT = 0x2D, DELETE = 0x2E,
}
for i = 1, 24 do VK["F" .. i] = 0x6F + i end
for c = string.byte("A"), string.byte("Z") do VK[string.char(c)] = c end
for d = 0, 9 do VK[tostring(d)] = 0x30 + d end

local MODS = { CTRL = 0x11, SHIFT = 0x10, ALT = 0x12 }

-- Returns { key = vk, mods = { vk... }, text = original } or nil + error.
function M.parse(text)
    if type(text) ~= "string" or text == "" then return nil, "empty binding" end
    local parts = {}
    for p in text:gmatch("[^+]+") do parts[#parts + 1] = p:gsub("^%s+", ""):gsub("%s+$", ""):upper() end
    local key = table.remove(parts)
    if not VK[key] then return nil, "unknown key: " .. tostring(key) end
    local mods = {}
    for _, m in ipairs(parts) do
        if not MODS[m] then return nil, "unknown modifier: " .. m end
        mods[#mods + 1] = MODS[m]
    end
    return { key = VK[key], mods = mods, text = text }
end

-- is_down(vk) -> bool (REFramework: reframework:is_key_down). Returns watcher with :pressed(binding).
function M.watcher(is_down)
    local held = {}
    local w = {}
    function w:pressed(b)
        if not b then return false end
        local down = is_down(b.key)
        if down then
            for _, m in ipairs(b.mods) do
                if not is_down(m) then down = false break end
            end
        end
        local was = held[b] or false
        held[b] = down
        return down and not was
    end
    return w
end

return M
