local t = require("lib.t")
local loopback = require("seamless_coop.net.loopback")
local handshake = require("seamless_coop.net.handshake")
local protocol = require("seamless_coop.net.protocol")
local events = require("seamless_coop.core.events")

local HA = "aaaaaaaa-0000-4000-8000-00000000000a"
local HB = "bbbbbbbb-0000-4000-8000-00000000000b"

-- Two peers A and B over a fake network with `latency` ms one way. opts tweak B or A's expectations.
local function pair(opts)
    opts = opts or {}
    local c = t.clock(100)
    local hub = loopback.new_hub({ clock = c.fn, latency_ms = opts.latency or 150 })
    local ea, eb = hub:endpoint("loop:a"), hub:endpoint("loop:b")
    local info_a = { mod = "0.1.0", build = 24705561, hunter = HA, story = 250 }
    local info_b = { mod = opts.b_mod or "0.1.4", build = opts.b_build or 24705561, hunter = HB, story = 250,
                     proto = opts.b_proto }
    local bus = events.new()
    local states = {}
    bus:on("peer_state", function(p, old) states[#states + 1] = old .. ">" .. p.state end)
    local A = handshake.new({ transport = ea, clock = c.fn, bus = bus, local_info = function() return info_a end, inst = 1 })
    local B = handshake.new({ transport = eb, clock = c.fn, local_info = function() return info_b end, inst = 2,
                              proto = opts.b_proto })
    A:add_candidate("loop:b", { expected_hunter = opts.a_expects or HB, label = "B" })
    B:add_candidate("loop:a", { expected_hunter = HA, label = "A" })
    local env = { c = c, hub = hub, A = A, B = B, ea = ea, eb = eb, states = states, b_ticks = true }
    function env.run(seconds, step)
        step = step or 0.05
        for _ = 1, math.floor(seconds / step + 0.5) do
            c.advance(step)
            env.A:tick()
            if env.b_ticks then env.B:tick() end
        end
    end
    function env.pa() return env.A.peers["loop:b"] end
    function env.pb() return env.B.peers["loop:a"] end
    return env
end

t.test("handshake: compatible peers connect within a second over 150 ms links", function()
    local e = pair()
    e.run(1.0)
    t.eq(e.pa().state, "compatible")
    t.eq(e.pb().state, "compatible")
    t.eq(e.pa().hello.mod, "0.1.4")
    t.eq(e.pa().hello.story, 250)
    t.same(e.states, { "pending>compatible" })
end)

t.test("handshake: heartbeats measure ~300 ms RTT and ~0 offset", function()
    local e = pair()
    e.run(6.0)
    local clk = e.pa().clock
    t.ok(clk:has_estimate())
    t.ok(clk.rtt_min >= 290 and clk.rtt_min <= 410, "rtt " .. tostring(clk.rtt_min))
    t.ok(math.abs(clk.offset) <= 60, "offset " .. tostring(clk.offset))
    t.eq(e.pa().remote_state.st, "idle")
    t.eq(e.pa().remote_state.story, 250)
end)

t.test("handshake: a different mod minor version is incompatible on both sides", function()
    local e = pair({ b_mod = "0.2.0" })
    e.run(1.0)
    t.eq(e.pa().state, "incompatible")
    t.same(e.pa().reasons, { "mod_version" })
    t.eq(e.pb().state, "incompatible")
end)

t.test("handshake: a different game build is incompatible", function()
    local e = pair({ b_build = 24800000 })
    e.run(1.0)
    t.same(e.pa().reasons, { "game_build" })
end)

t.test("handshake: an older protocol is reported, not just dropped", function()
    local e = pair({ b_proto = 0 })
    e.run(1.0)
    t.eq(e.pa().state, "incompatible")
    t.contains(e.pa().reasons, "protocol")
    t.eq(e.pb().state, "incompatible")
end)

t.test("handshake: a peer with the wrong hunter ID fails the identity check", function()
    local e = pair({ a_expects = "cccccccc-0000-4000-8000-00000000000c" })
    e.run(1.0)
    t.eq(e.pa().state, "incompatible")
    t.same(e.pa().reasons, { "identity" })
    t.eq(e.pb().state, "compatible")
end)

t.test("handshake: an unmodded member stays pending with HELLO backoff", function()
    local e = pair()
    e.b_ticks = false
    local sent0 = e.hub.sent
    e.run(30.0, 0.25)
    t.eq(e.pa().state, "pending")
    local hellos = e.hub.sent - sent0
    t.ok(hellos >= 5 and hellos <= 7, "hellos " .. hellos)
end)

t.test("handshake: silence marks the peer lost, then it recovers", function()
    local e = pair()
    e.run(2.0)
    t.eq(e.pa().state, "compatible")
    e.b_ticks = false
    e.run(11.0)
    t.eq(e.pa().state, "lost")
    e.b_ticks = true
    e.run(3.0)
    t.eq(e.pa().state, "compatible")
    t.same(e.states, { "pending>compatible", "compatible>lost", "lost>compatible" })
end)

t.test("handshake: kill switch says BYE, goes quiet, and reconnects when re-enabled", function()
    local e = pair()
    e.run(2.0)
    e.A:set_enabled(false)
    e.run(2.0)
    t.eq(e.pb().state, "left")
    t.eq(e.pb().bye_reason, "kill_switch")
    local sent = e.hub.sent
    e.run(15.0)
    t.eq(e.pb().state, "left") -- nobody pings a peer that turned the mod off
    t.ok(e.hub.sent - sent <= 0, "no traffic while off")
    e.A:set_enabled(true)
    e.run(2.0)
    t.eq(e.pa().state, "compatible")
    t.eq(e.pb().state, "compatible")
end)

t.test("handshake: strangers, garbage and replays are dropped", function()
    local e = pair()
    e.run(1.0)
    local stranger = e.hub:endpoint("loop:x")
    stranger:send("loop:a", assert(protocol.encode("BYE", 1, 5, { reason = "shutdown" })), true)
    e.eb:send("loop:a", "{not json", true)
    local replay = assert(protocol.encode("BYE", 1, 2, { reason = "shutdown" }))
    e.run(0.5)
    local st = e.A.stats
    t.eq(st.unknown_sender, 1)
    t.eq(st.invalid, 1)
    e.eb:send("loop:a", replay, true) -- seq 1 from instance 2 was already used during the handshake
    e.run(0.5)
    t.eq(st.stale, 1)
    t.eq(e.pa().state, "compatible")
end)

t.test("handshake: a restarted peer (new instance) is accepted from sequence 1", function()
    local e = pair()
    e.run(1.0)
    e.B = handshake.new({ transport = e.eb, clock = e.c.fn, inst = 3,
                          local_info = function() return { mod = "0.1.0", build = 24705561, hunter = HB, story = 251 } end })
    e.B:add_candidate("loop:a", { expected_hunter = HA })
    e.run(3.0)
    t.eq(e.pa().state, "compatible")
    t.eq(e.pa().hello.story, 251)
end)

t.test("handshake: removing a candidate says BYE and forgets it", function()
    local e = pair()
    e.run(1.0)
    e.A:remove_candidate("loop:b", "left_party")
    e.run(0.5)
    t.eq(e.A.peers["loop:b"], nil)
    t.eq(e.pb().state, "left")
    t.eq(e.pb().bye_reason, "left_party")
end)

t.test("handshake: reliable and unreliable messages have separate sequence spaces", function()
    local e = pair()
    e.run(1.0)
    e.b_ticks = false
    e.run(0.5) -- let B's in-flight messages land
    local stale0 = e.A.stats.stale
    e.eb:send("loop:a", assert(protocol.encode("HEARTBEAT", e.B.seq.u + 100, 2, { st = "busy", story = 250, t = 5 }, nil, true)), false)
    e.run(0.3)
    e.eb:send("loop:a", assert(protocol.encode("BYE", e.B.seq.r + 1, 2, { reason = "shutdown" })), true)
    e.run(0.3)
    t.eq(e.A.stats.stale, stale0, "the reliable BYE was not mistaken for a stale message")
    t.eq(e.pa().state, "left")
end)

t.test("handshake: an older unreliable message is dropped", function()
    local e = pair()
    e.run(1.0)
    e.b_ticks = false
    e.run(0.5)
    local useq, stale0 = e.B.seq.u, e.A.stats.stale
    e.eb:send("loop:a", assert(protocol.encode("HEARTBEAT", useq + 10, 2, { st = "busy", story = 250, t = 5 }, nil, true)), false)
    e.run(0.3)
    e.eb:send("loop:a", assert(protocol.encode("HEARTBEAT", useq + 5, 2, { st = "quest", story = 250, t = 6 }, nil, true)), false)
    e.run(0.3)
    t.eq(e.A.stats.stale, stale0 + 1)
    t.eq(e.pa().remote_state.st, "busy")
end)

t.test("handshake: summary counts states", function()
    local e = pair()
    e.run(1.0)
    local s = e.A:summary()
    t.eq(s.total, 1)
    t.eq(s.compatible, 1)
end)
