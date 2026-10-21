local t = require("lib.t")
local fakes = require("fakes.reframework")
local json = require("seamless_coop.core.json")
local protocol = require("seamless_coop.net.protocol")

local ANN_ID = "76561198000000001"

local function member(over)
    local m = { valid = true, self = false, hunter = fakes.guid(0x0a1b2c3d, 1, 2, { 3, 4, 5, 6, 7, 8, 9, 10 }), name = "Ann",
                platform = 5, index = 1, progress = 250, sync = false }
    for k, v in pairs(over or {}) do m[k] = v end
    return m
end

local function boot(opts)
    opts = opts or {}
    package.loaded["seamless_coop.main"] = nil
    local main = require("seamless_coop.main")
    local w = {
        store = opts.store or fakes.data_store(),
        game = fakes.game({ members = opts.members, remove_types = opts.remove_types }),
        re = fakes.re(),
        imgui = fakes.imgui(),
        c = t.clock(10),
        keys = {},
    }
    if opts.config then w.store.files["seamless_coop/config.json"] = opts.config end
    local env = {
        re = w.re.api, sdk = w.game.sdk, imgui = w.imgui, json = w.store.json, io = w.store.io,
        reframework = {
            is_key_down = function(_, vk) return w.keys[vk] == true end,
            get_tag = function() return "nightly-01433" end,
        },
        seamless_net = opts.net, clock = w.c.fn,
    }
    w.app = main.start(env)
    function w.frames(seconds, dt)
        dt = dt or 0.05
        for _ = 1, math.floor(seconds / dt + 0.5) do
            w.c.advance(dt)
            w.re.run("frame")
        end
    end
    function w.draw()
        w.imgui.calls = {}
        w.re.run("draw")
    end
    return w
end

t.test("main: starts without the plugin and explains what is missing", function()
    local w = boot()
    t.ok(w.app.decision.enabled)
    t.eq(w.app.build.status, "unknown")
    t.eq(w.app.ref, "nightly-01433")
    t.ok(w.store.files["seamless_coop/config.json"], "defaults written on first run")
    t.eq(w.store.files["seamless_coop/config.json"].enabled, true)
    t.ok(w.store.files["seamless_coop/logs/session-1.log"], "log file opened")
    w.frames(1)
    w.draw()
    t.ok(w.imgui.has_text("not loaded"))
    t.ok(w.imgui.has_text("Game build: %?"))
end)

t.test("main: a Link Party member who is a Steam friend becomes a candidate and gets a HELLO", function()
    local net = fakes.net({ friends = { { id = ANN_ID, name = "Ann" } } })
    local w = boot({ net = net, members = { member({ self = true, name = "Me", index = 0 }), member() } })
    t.eq(w.app.build.status, "verified")
    w.frames(1.5)
    local p = w.app.link.peers[ANN_ID]
    t.ok(p, "candidate added")
    t.eq(p.state, "pending")
    t.eq(p.expected_hunter, "0a1b2c3d-0001-0002-0304-05060708090a")
    t.ok(net.allowed[ANN_ID])
    t.ok(#net.sent >= 1)
    local hello = assert(protocol.decode(net.sent[1].data))
    t.eq(hello.t, "HELLO")
    t.eq(hello.d.story, 250)
    t.eq(hello.d.build, 24705561)
    t.eq(hello.d.hunter, "0a1b2c3d-0001-0002-0304-05060708090a") -- our own hunter id (self entry)
    w.draw()
    t.ok(w.imgui.has_text("Ann %- no reply yet"))
    -- the log never contains the member's name or full Steam ID
    for _, line in ipairs(w.app.log:lines()) do
        t.no(line:find("Ann"), line)
        t.no(line:find(ANN_ID), line)
    end
end)

t.test("main: a reply from the friend makes the member compatible; leaving the party removes them", function()
    local net = fakes.net({ friends = { { id = ANN_ID, name = "Ann" } } })
    local me = member({ self = true, name = "Me", index = 0, hunter = fakes.guid(1, 1, 1, { 1, 1, 1, 1, 1, 1, 1, 1 }) })
    local ann = member()
    local w = boot({ net = net, members = { me, ann } })
    w.frames(1.5)
    local reply = assert(protocol.encode("HELLO", 1, 77, {
        mod = "0.1.0-dev", proto = protocol.VERSION, build = 24705561, ref = "x",
        hunter = "0a1b2c3d-0001-0002-0304-05060708090a", story = 250, caps = json.array({ "party" }), t = 5,
    }))
    net.inbox = { { from = ANN_ID, data = reply } }
    w.frames(0.2)
    t.eq(w.app.link.peers[ANN_ID].state, "compatible")
    w.draw()
    t.ok(w.imgui.has_text("Ann %- modded %- compatible"))
    w.game.members = { me }
    w.frames(6)
    t.eq(w.app.link.peers[ANN_ID], nil)
    t.no(net.allowed[ANN_ID])
end)

t.test("main: loopback test peers cover compatible, mismatch and silent cases", function()
    local w = boot({ net = fakes.net(), config = { dev_tools = true } })
    local a = w.app.actions.add_fake("compatible")
    local b = w.app.actions.add_fake("old_mod")
    local c = w.app.actions.add_fake("old_protocol")
    local d = w.app.actions.add_fake("silent")
    local e = w.app.actions.add_fake("wrong_identity")
    local f = w.app.actions.add_fake("other_build")
    w.frames(2)
    local peers = w.app.link.peers
    t.eq(peers[a].state, "compatible")
    t.ok(peers[a].clock.rtt_avg and peers[a].clock.rtt_avg >= 250, "simulated cross-country RTT")
    t.eq(peers[b].state, "incompatible")
    t.same(peers[b].reasons, { "mod_version" })
    t.contains(peers[c].reasons, "protocol")
    t.eq(peers[d].state, "pending")
    t.same(peers[e].reasons, { "identity" })
    t.same(peers[f].reasons, { "game_build" })
    w.draw()
    t.ok(w.imgui.has_text("Test peer 1 %(compatible%)"))
    w.app.actions.remove_fakes()
    t.eq(next(w.app.link.peers), nil)
end)

t.test("main: Ctrl+F12 toggles the kill switch and persists it", function()
    local w = boot({ net = fakes.net() })
    local id = w.app.actions.add_fake("compatible")
    w.frames(2)
    t.eq(w.app.link.peers[id].state, "compatible")
    w.keys[0x11], w.keys[0x7B] = true, true
    w.frames(0.1)
    t.eq(w.app.cfg:get("enabled"), false)
    t.eq(w.store.files["seamless_coop/config.json"].enabled, false)
    t.no(w.app.link.enabled)
    w.frames(0.5)
    t.eq(w.app.fakes[id].link.peers["loop:local"].state, "left")
    w.keys[0x7B] = false
    w.frames(0.1)
    w.keys[0x7B] = true
    w.frames(2)
    t.eq(w.app.cfg:get("enabled"), true)
    t.eq(w.app.link.peers[id].state, "compatible")
end)

t.test("main: starts switched off when the saved setting says so", function()
    local w = boot({ net = fakes.net(), config = { enabled = false } })
    t.no(w.app.link.enabled)
    w.draw()
    t.ok(w.imgui.has_text("Off %(vanilla"))
end)

t.test("main: missing core game types disable the mod but keep the panel", function()
    local w = boot({ net = fakes.net(), remove_types = { "app.MissionManager" } })
    t.no(w.app.decision.enabled)
    t.eq(w.app.link, nil)
    w.draw()
    t.ok(w.imgui.has_text("Disabled"))
    t.ok(w.imgui.has_text("app.MissionManager"))
    t.eq(#w.re.frame, 0, "no per-frame work when disabled")
end)

t.test("main: missing party entries disable only the party feature", function()
    local w = boot({ net = fakes.net(), remove_types = { "app.Net_UserInfoList" } })
    t.ok(w.app.decision.enabled)
    t.no(w.app.decision.features.party.on)
    t.eq(w.app.party, nil)
    w.frames(1)
end)

t.test("main: diagnostics and script reset", function()
    local w = boot({ net = fakes.net() })
    w.frames(3)
    t.ok(w.app.actions.write_diagnostics())
    local diag = w.store.files["seamless_coop/diagnostics.json"]
    t.eq(diag.game_build, 24705561)
    t.eq(diag.net_status.backup.state, "done")
    w.re.run("reset")
    t.ok(w.store.files["seamless_coop/logs/session-1.log"].closed)
end)

t.test("main: dev_selftest reports every test peer's outcome in the log", function()
    local w = boot({ net = fakes.net(), config = { dev_selftest = true } })
    w.frames(10)
    local found
    for _, line in ipairs(w.app.log:lines()) do
        if line:find("selftest: ") then found = line end
    end
    t.ok(found, "selftest line logged")
    t.ok(found:find("compatible=compatible rtt=%d+ms"), found)
    t.ok(found:find("old_mod=incompatible%(mod_version%)"), found)
    t.ok(found:find("silent=pending"), found)
    t.ok(found:find("wrong_identity=incompatible%(identity%)"), found)
    t.ok(w.store.files["seamless_coop/diagnostics.json"])
    t.eq(next(w.app.fakes), nil)
end)

t.test("main: the log rotates through five session files across restarts", function()
    local store = fakes.data_store()
    for _ = 1, 6 do
        local w = boot({ store = store })
        w.re.run("reset")
    end
    for i = 1, 5 do t.ok(store.files["seamless_coop/logs/session-" .. i .. ".log"], "slot " .. i) end
    t.eq(store.files["seamless_coop/logs/session-6.log"], nil)
    t.eq(store.files["seamless_coop/logs/state.json"].next, 2)
end)
