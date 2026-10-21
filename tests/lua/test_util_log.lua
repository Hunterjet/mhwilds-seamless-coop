local t = require("lib.t")
local util = require("seamless_coop.core.util")
local log = require("seamless_coop.core.log")

t.test("util: short ids and redaction never show full Steam IDs", function()
    t.eq(util.short_id("76561198012345678"), "...5678")
    t.eq(util.short_id("1234"), "1234")
    t.eq(util.short_id(nil), "?")
    t.eq(util.redact("peer 76561198012345678 said hi"), "peer ...5678 said hi")
    t.eq(util.redact("no ids here 12345"), "no ids here 12345")
end)

t.test("log: levels, ring buffer order and sinks", function()
    local c = t.clock(1)
    local l = log.new({ level = "info", clock = c.fn, ring_size = 3 })
    local sunk = {}
    l:add_sink({ write = function(line) sunk[#sunk + 1] = line end })
    l:debug("hidden")
    l:info("one %d", 1)
    l:warn("two")
    l:error("three")
    l:info("four")
    t.eq(#sunk, 4)
    local lines = l:lines()
    t.eq(#lines, 3)
    t.ok(lines[1]:find("WARN  two"))
    t.ok(lines[3]:find("INFO  four"))
    t.eq(#l:lines(1), 1)
    t.ok(l:lines(1)[1]:find("four"))
    t.eq(l.warnings, 1)
    t.eq(l.errors, 1)
end)

t.test("log: redacts Steam IDs and survives bad format strings", function()
    local l = log.new({ clock = function() return 0 end })
    l:info("id %s", "76561198012345678")
    l:info("bad %d", "not a number")
    local lines = l:lines()
    t.ok(lines[1]:find("%.%.%.5678"))
    t.no(lines[1]:find("76561198012345678"))
    t.ok(lines[2]:find("bad %%d"))
end)

t.test("log: session slots rotate through 1..keep", function()
    local state
    local load = function() return state end
    local save = function(s) state = s end
    local seen = {}
    for i = 1, 7 do seen[i] = log.next_slot(load, save, 5) end
    t.same(seen, { 1, 2, 3, 4, 5, 1, 2 })
    state = { next = 99 }
    t.eq(log.next_slot(load, save, 5), 1)
end)
