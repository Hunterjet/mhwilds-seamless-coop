local t = require("lib.t")
local scheduler = require("seamless_coop.core.scheduler")

t.test("scheduler: every/after/on_frame run at the right times", function()
    local c = t.clock(10)
    local s = scheduler.new({ clock = c.fn })
    local log = {}
    s:every("e", 1.0, function() log[#log + 1] = "e" end)
    s:after("a", 0.5, function() log[#log + 1] = "a" end)
    s:on_frame("f", function() log[#log + 1] = "f" end)
    s:tick()
    t.same(log, { "e", "f" })
    c.advance(0.6)
    s:tick()
    t.same(log, { "e", "f", "a", "f" })
    c.advance(0.5)
    s:tick()
    t.same(log, { "e", "f", "a", "f", "e", "f" })
    t.eq(#s:status(), 2) -- the one-shot task is gone
end)

t.test("scheduler: every() can start after a delay and catches up without bursts", function()
    local c = t.clock(0)
    local s = scheduler.new({ clock = c.fn })
    local n = 0
    s:every("e", 1.0, function() n = n + 1 end, { delay = 2 })
    s:tick()
    t.eq(n, 0)
    c.advance(10)
    s:tick()
    s:tick()
    t.eq(n, 1)
end)

t.test("scheduler: repeated faults disable only the faulty task", function()
    local c = t.clock(0)
    local disabled = {}
    local s = scheduler.new({ clock = c.fn, max_faults = 3, fault_window = 60,
                              on_disabled = function(task) disabled[#disabled + 1] = task.name end })
    local good = 0
    s:on_frame("bad", function() error("nope") end)
    s:on_frame("good", function() good = good + 1 end)
    for _ = 1, 5 do
        s:tick()
        c.advance(1)
    end
    t.same(disabled, { "bad" })
    t.eq(good, 5)
    local st = s:status()
    t.ok(st[1].disabled)
    t.ok(st[1].last_error:find("nope"))
end)

t.test("scheduler: faults outside the window are forgotten", function()
    local c = t.clock(0)
    local s = scheduler.new({ clock = c.fn, max_faults = 3, fault_window = 10 })
    local task = s:every("flaky", 6, function() error("x") end)
    for _ = 1, 10 do
        s:tick()
        c.advance(6)
    end
    t.no(task.disabled)
end)

t.test("scheduler: cancel and re-enable", function()
    local c = t.clock(0)
    local s = scheduler.new({ clock = c.fn, max_faults = 1 })
    local n = 0
    local task = s:on_frame("x", function() n = n + 1 end)
    s:cancel(task)
    s:tick()
    t.eq(n, 0)
    local bad = s:on_frame("bad", function() error("x") end)
    s:tick()
    t.ok(bad.disabled)
    s:enable(bad)
    t.no(bad.disabled)
end)
