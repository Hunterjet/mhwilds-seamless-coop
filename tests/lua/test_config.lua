local t = require("lib.t")
local config = require("seamless_coop.core.config")

local function store(initial)
    local s = { data = initial, saves = 0 }
    s.load = function() return s.data end
    s.save = function(v)
        s.saves = s.saves + 1
        s.data = v
        return true
    end
    return s
end

t.test("config: defaults match the spec", function()
    local cfg = config.new(store(nil))
    t.eq(cfg:get("enabled"), true)
    t.eq(cfg:get("auto_follow"), "story")
    t.eq(cfg:get("skip_mode"), "vote")
    t.eq(cfg:get("save_backups_to_keep"), 10)
    t.eq(cfg:get("hotkey_kill_switch"), "Ctrl+F12")
    t.eq(#cfg.warnings, 0)
end)

t.test("config: valid saved values load, invalid ones fall back with a warning", function()
    local cfg = config.new(store({
        enabled = false, auto_follow = "all", catch_up_distance_m = 80, save_backups_to_keep = 5.0,
        skip_mode = "whatever", log_level = 3, mystery = true, catch_up_distance_m2 = 1,
    }))
    t.eq(cfg:get("enabled"), false)
    t.eq(cfg:get("auto_follow"), "all")
    t.eq(cfg:get("catch_up_distance_m"), 80)
    t.eq(cfg:get("save_backups_to_keep"), 5)
    t.eq(math.type(cfg:get("save_backups_to_keep")), "integer")
    t.eq(cfg:get("skip_mode"), "vote")
    t.eq(cfg:get("log_level"), "info")
    t.eq(#cfg.warnings, 4)
end)

t.test("config: set validates and save persists", function()
    local s = store(nil)
    local cfg = config.new(s)
    t.ok(cfg:set("enabled", false))
    t.ok(cfg.dirty)
    local ok, why = cfg:set("catch_up_distance_m", 5)
    t.no(ok)
    t.eq(why, "out of range")
    t.no(cfg:set("save_backups_to_keep", 2.5))
    t.no(cfg:set("nope", 1))
    t.ok(cfg:save())
    t.no(cfg.dirty)
    t.eq(s.data.enabled, false)
end)
