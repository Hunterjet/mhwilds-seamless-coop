local t = require("lib.t")
local protocol = require("seamless_coop.net.protocol")
local json = require("seamless_coop.core.json")

local HUNTER = "0a1b2c3d-0000-4000-8000-00000000abcd"

local function hello(over)
    local d = { mod = "0.1.0", proto = protocol.VERSION, build = 24705561, ref = "x", hunter = HUNTER, story = 250,
                caps = json.array({ "party" }), t = 1000 }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

t.test("protocol: HELLO round trip", function()
    local s = assert(protocol.encode("HELLO", 7, 99, hello()))
    local m = assert(protocol.decode(s))
    t.eq(m.t, "HELLO")
    t.eq(m.s, 7)
    t.eq(m.i, 99)
    t.eq(m.p, protocol.VERSION)
    t.eq(m.d.hunter, HUNTER)
    t.eq(m.d.caps[1], "party")
end)

t.test("protocol: encode validates outgoing payloads", function()
    t.no(protocol.encode("HELLO", 1, 1, hello({ hunter = "not-a-guid" })))
    t.no(protocol.encode("HELLO", 1, 1, hello({ story = 1.5 })))
    t.no(protocol.encode("NOPE", 1, 1, {}))
    t.no(protocol.encode("HEARTBEAT", 1, 1, { st = "dancing", story = 1, t = 1 }))
    t.ok(protocol.encode("HEARTBEAT", 1, 1, { st = "idle", story = -1, t = 1 }))
end)

t.test("protocol: decode rejects bad envelopes and payloads", function()
    local function env(e) return assert(json.encode(e)) end
    local good = { p = protocol.VERSION, t = "BYE", s = 1, i = 1, d = { reason = "shutdown" } }
    t.ok(protocol.decode(env(good)))
    local cases = {
        { p = "1", t = "BYE", s = 1, i = 1, d = { reason = "shutdown" } },
        { p = 1, t = "BYE", s = -1, i = 1, d = { reason = "shutdown" } },
        { p = 1, t = "BYE", s = 1, d = { reason = "shutdown" } },
        { p = 1, t = "BYE", s = 1, i = 1, d = { reason = "because" } },
        { p = 1, t = "WHAT", s = 1, i = 1, d = {} },
        { p = 1, t = "BYE", s = 1, i = 1 },
    }
    for i, c in ipairs(cases) do t.no(protocol.decode(env(c)), "case " .. i) end
    t.no(protocol.decode("[1,2]"))
    t.no(protocol.decode("garbage"))
    t.no(protocol.decode(string.rep("x", protocol.MAX_BYTES + 1)))
end)

t.test("protocol: other protocol versions only get the frozen types through", function()
    local function env(e) return assert(json.encode(e)) end
    t.ok(protocol.decode(env({ p = 99, t = "HELLO", s = 1, i = 1, d = hello({ proto = 99 }) })))
    t.ok(protocol.decode(env({ p = 99, t = "BYE", s = 1, i = 1, d = { reason = "shutdown" } })))
    local m, err = protocol.decode(env({ p = 99, t = "HEARTBEAT", s = 1, i = 1, d = { st = "idle", story = 1, t = 1 } }))
    t.no(m)
    t.eq(err, "protocol mismatch")
end)

t.test("protocol: unknown fields are ignored for forward compatibility", function()
    local s = assert(json.encode({ p = protocol.VERSION, t = "BYE", s = 1, i = 1, d = { reason = "shutdown", future = 1 } }))
    t.ok(protocol.decode(s))
end)

t.test("protocol: NOTICE args must be short scalars", function()
    t.ok(protocol.encode("NOTICE", 1, 1, { code = "join_refused", args = json.array({ "behind", 250, true }) }))
    t.no(protocol.encode("NOTICE", 1, 1, { code = "bad code!", args = json.array({}) }))
    t.no(protocol.encode("NOTICE", 1, 1, { code = "x", args = json.array({ { nested = 1 } }) }))
end)
