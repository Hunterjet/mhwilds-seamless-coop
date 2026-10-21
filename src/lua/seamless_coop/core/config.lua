-- Settings (spec §7) with validation. Persisted as reframework/data/seamless_coop/config.json through an injected
-- store { load = fn() -> table|nil, save = fn(table) -> bool }.
local M = {}

M.DEFAULTS = {
    enabled = true,
    seamless_story_join = true,
    auto_follow = "story",
    return_with_leader = true,
    match_start_point = true,
    share_cutscenes = true,
    skip_mode = "vote",
    show_skip_prompt = true,
    catch_up_distance_m = 60,
    save_backup_on_launch = true,
    save_backups_to_keep = 10,
    overlay_visible = true,
    log_level = "info",
    hotkey_kill_switch = "Ctrl+F12",
    hotkey_overlay = "F11",
    hotkey_join = "F9",
    hotkey_vote_skip = "F10",
    dev_tools = false,
    dev_selftest = false,
}

local RULES = {
    enabled = { type = "boolean" },
    seamless_story_join = { type = "boolean" },
    auto_follow = { enum = { off = true, story = true, all = true } },
    return_with_leader = { type = "boolean" },
    match_start_point = { type = "boolean" },
    share_cutscenes = { type = "boolean" },
    skip_mode = { enum = { vote = true, leader = true, ["local-if-seen"] = true } },
    show_skip_prompt = { type = "boolean" },
    catch_up_distance_m = { type = "number", min = 10, max = 500 },
    save_backup_on_launch = { type = "boolean" },
    save_backups_to_keep = { type = "number", min = 1, max = 50, integer = true },
    overlay_visible = { type = "boolean" },
    log_level = { enum = { debug = true, info = true, warn = true, error = true } },
    hotkey_kill_switch = { type = "string", max = 24 },
    hotkey_overlay = { type = "string", max = 24 },
    hotkey_join = { type = "string", max = 24 },
    hotkey_vote_skip = { type = "string", max = 24 },
    dev_tools = { type = "boolean" },
    dev_selftest = { type = "boolean" },
}

-- Returns nil if valid, else a reason string.
function M.check(key, value)
    local rule = RULES[key]
    if not rule then return "unknown setting" end
    if rule.enum then
        if not rule.enum[value] then return "not an allowed value" end
        return nil
    end
    if type(value) ~= rule.type then return "expected " .. rule.type end
    if rule.type == "number" then
        if value ~= value then return "not a number" end
        if rule.integer and math.type(value) ~= "integer" and value % 1 ~= 0 then return "expected an integer" end
        if (rule.min and value < rule.min) or (rule.max and value > rule.max) then return "out of range" end
    elseif rule.type == "string" and rule.max and #value > rule.max then
        return "too long"
    end
    return nil
end

local Config = {}
Config.__index = Config

-- Loads and validates. Invalid or unknown entries are dropped (defaults apply) and reported in cfg.warnings.
function M.new(store)
    local self = setmetatable({ store = store, values = {}, warnings = {} }, Config)
    for k, v in pairs(M.DEFAULTS) do self.values[k] = v end
    local loaded = store and store.load and store.load()
    if type(loaded) == "table" then
        for k, v in pairs(loaded) do
            local reason = M.check(k, v)
            if reason then
                self.warnings[#self.warnings + 1] = string.format("config: ignored %s (%s)", tostring(k), reason)
            else
                if RULES[k].integer then v = math.tointeger(v) or v end
                self.values[k] = v
            end
        end
    end
    return self
end

function Config:get(key)
    return self.values[key]
end

-- Returns true, or false + reason.
function Config:set(key, value)
    local reason = M.check(key, value)
    if reason then return false, reason end
    self.values[key] = value
    self.dirty = true
    return true
end

function Config:save()
    if not (self.store and self.store.save) then return false end
    local ok = self.store.save(self.values)
    if ok then self.dirty = false end
    return ok
end

return M
