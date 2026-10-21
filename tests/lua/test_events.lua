local t = require("lib.t")
local events = require("seamless_coop.core.events")

t.test("events: emit reaches subscribers in order; unsubscribe works", function()
    local bus = events.new()
    local got = {}
    local off = bus:on("x", function(v) got[#got + 1] = "a" .. v end)
    bus:on("x", function(v) got[#got + 1] = "b" .. v end)
    t.eq(bus:emit("x", 1), 2)
    off()
    bus:emit("x", 2)
    t.same(got, { "a1", "b1", "b2" })
    t.eq(bus:emit("nobody"), 0)
end)

t.test("events: a failing handler does not stop the others", function()
    local errors = {}
    local bus = events.new({ on_error = function(topic, err) errors[#errors + 1] = topic end })
    local ran = false
    bus:on("x", function() error("boom") end)
    bus:on("x", function() ran = true end)
    bus:emit("x")
    t.ok(ran)
    t.same(errors, { "x" })
end)

t.test("events: unsubscribing during emit is safe", function()
    local bus = events.new()
    local count = 0
    local off
    off = bus:on("x", function() count = count + 1; off() end)
    bus:on("x", function() count = count + 10 end)
    bus:emit("x")
    bus:emit("x")
    t.eq(count, 21)
end)

t.test("events: post queues until flush, keeps order and nil arguments", function()
    local bus = events.new()
    local got = {}
    bus:on("x", function(a, b, c) got[#got + 1] = { a, b, c } end)
    bus:post("x", 1, nil, 3)
    bus:post("x", 2)
    t.eq(#got, 0)
    t.eq(bus:flush(), 2)
    t.eq(got[1][1], 1)
    t.eq(got[1][2], nil)
    t.eq(got[1][3], 3)
    t.eq(got[2][1], 2)
end)

t.test("events: the queue is bounded", function()
    local bus = events.new({ max_queue = 2 })
    t.ok(bus:post("x"))
    t.ok(bus:post("x"))
    t.no(bus:post("x"))
    t.eq(bus.dropped, 1)
end)
