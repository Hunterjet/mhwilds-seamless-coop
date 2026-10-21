-- Composition root (implementation plan §6). start(env) wires every module. `env` carries REFramework's globals
-- (re, sdk, imgui, json, io, reframework, seamless_net) plus a clock, so offline tests can pass fakes.
local version = require("seamless_coop.core.version")
local log_mod = require("seamless_coop.core.log")
local events = require("seamless_coop.core.events")
local scheduler = require("seamless_coop.core.scheduler")
local config = require("seamless_coop.core.config")
local hotkeys = require("seamless_coop.core.hotkeys")
local util = require("seamless_coop.core.util")
local registry = require("seamless_coop.compat.registry")
local build_check = require("seamless_coop.compat.build_check")
local sdk_env = require("seamless_coop.game.sdk_env")
local story_mod = require("seamless_coop.game.story")
local party_mod = require("seamless_coop.game.party")
local transport = require("seamless_coop.net.transport")
local loopback = require("seamless_coop.net.loopback")
local handshake = require("seamless_coop.net.handshake")
local discovery = require("seamless_coop.net.discovery")
local panel = require("seamless_coop.ui.panel")

local M = {}

local DATA = "seamless_coop/"

-- Loopback test peers for single-PC testing of the handshake and its failure modes (developer tools).
M.FAKE_KINDS = {
    compatible = {},
    old_mod = { mod = "0.0.1" },
    other_build = { build_delta = 1 },
    old_protocol = { proto = 0 },
    wrong_identity = { expect_other = true },
    silent = { silent = true },
}

local function reframework_revision(rf)
    if not rf then return "unknown" end
    for _, name in ipairs({ "get_tag_long", "get_tag", "get_commit_hash" }) do
        local ok, v = pcall(function() return rf[name](rf) end)
        if ok and type(v) == "string" and v ~= "" then return v:sub(1, 64) end
    end
    return "unknown"
end

local function json_store(env, path)
    return {
        load = function()
            local ok, v = pcall(env.json.load_file, path)
            if ok and type(v) == "table" then return v end
            return nil
        end,
        save = function(values)
            local ok, res = pcall(env.json.dump_file, path, values)
            return ok and res ~= false
        end,
    }
end

local function open_log(env, logger)
    local state = json_store(env, DATA .. "logs/state.json")
    -- Writing state.json first also creates the logs folder (io.open does not create folders).
    local slot = log_mod.next_slot(state.load, state.save, 5)
    if not env.io then return nil end
    local ok, fh = pcall(env.io.open, DATA .. "logs/session-" .. slot .. ".log", "w")
    if ok and fh then
        logger:add_sink(log_mod.file_sink(fh))
        return fh
    end
    return nil
end

function M.set_enabled(app, on)
    app.cfg:set("enabled", on)
    app.cfg:save()
    if app.link then app.link:set_enabled(on, "kill_switch") end
    app.log:info("seamless features %s", on and "on" or "off (kill switch)")
end

function M.add_fake(app, kind)
    local spec = M.FAKE_KINDS[kind]
    if not spec or not app.link then return nil end
    app.fake_seq = (app.fake_seq or 0) + 1
    local n = app.fake_seq
    local id = "loop:fake" .. n
    local hunter = string.format("%08x-0000-4000-8000-%012x", n, n)
    local ep = app.hub:endpoint(id)
    local link = handshake.new({
        transport = ep,
        clock = app.env.clock,
        local_info = function()
            return { mod = spec.mod or version.mod, build = (app.build.steam or 0) + (spec.build_delta or 0),
                     ref = "loopback", hunter = hunter, story = app.story_point(), caps = { "party" }, proto = spec.proto }
        end,
        local_state = function() return { st = "idle", story = app.story_point() } end,
        proto = spec.proto,
    })
    link:add_candidate("loop:local", { label = "you" })
    app.link:add_candidate(id, {
        label = string.format("Test peer %d (%s)", n, kind),
        expected_hunter = spec.expect_other and "ffffffff-ffff-ffff-ffff-ffffffffffff" or hunter,
    })
    app.fakes[id] = { link = link, kind = kind, silent = spec.silent == true }
    app.log:info("dev: added loopback test peer %d (%s)", n, kind)
    return id
end

function M.remove_fakes(app)
    for id in pairs(app.fakes) do
        app.link:remove_candidate(id, "left_party")
        app.hub:remove_endpoint(id)
    end
    app.fakes = {}
end

-- Diagnostics for bug reports (spec F6.4). No player names, short IDs only.
function M.diagnostics(app)
    local peers = {}
    for _, p in pairs(app.link and app.link.peers or {}) do
        peers[#peers + 1] = { id = p.log_id, state = p.state, reasons = p.reasons, rtt_ms = p.clock.rtt_avg,
                              mod = p.hello and p.hello.mod, build = p.hello and p.hello.build }
    end
    return {
        mod = version.mod, protocol = version.protocol, reframework = app.ref,
        game_build = app.build.steam, build_status = app.build.status,
        plugin = app.plugin_version, net_status = app.net_status,
        gate = { enabled = app.decision.enabled, reason = app.decision.reason, failures = app.report.failures,
                 features = app.decision.features },
        peers = peers, link_stats = app.link and app.link.stats,
        tasks = app.sched:status(),
        log = app.log:lines(80),
    }
end

function M.write_diagnostics(app)
    local ok = pcall(app.env.json.dump_file, DATA .. "diagnostics.json", M.diagnostics(app))
    app.log:info("diagnostics %s", ok and "written to reframework/data/seamless_coop/diagnostics.json" or "could not be written")
    return ok
end

function M.start(env)
    local app = { env = env, fakes = {}, members = {} }

    local cfg = config.new(json_store(env, DATA .. "config.json"))
    if not json_store(env, DATA .. "config.json").load() then cfg:save() end
    app.cfg = cfg

    local logger = log_mod.new({ level = cfg:get("log_level"), clock = env.clock })
    app.log = logger
    app.log_file = open_log(env, logger)
    logger:info("Seamless Co-op %s starting (protocol %d)", version.mod, version.protocol)
    for _, w in ipairs(cfg.warnings) do logger:warn("%s", w) end

    local bus = events.new({ on_error = function(topic, err) logger:error("event %s: %s", topic, tostring(err)) end })
    local sched = scheduler.new({
        clock = env.clock,
        on_fault = function(task, err) logger:error("task %s failed: %s", task.name, tostring(err)) end,
        on_disabled = function(task) logger:error("task %s disabled after repeated faults", task.name) end,
    })
    app.bus, app.sched = bus, sched

    -- seamless_net.dll (optional: without it the mod shows status but has no side channel)
    local net = env.seamless_net
    if net then
        local okv, v = pcall(net.version)
        app.plugin_version = okv and type(v) == "table" and v.plugin or "?"
    end
    local steam_build
    if net then
        local okb, b = pcall(net.game_build)
        if okb and math.type(b) == "integer" then steam_build = b end
    end
    app.build = {
        steam = steam_build,
        status = build_check.build_status(steam_build, version.verified_builds),
        label = steam_build and version.verified_builds[steam_build] or nil,
    }
    app.ref = reframework_revision(env.reframework)

    -- Build gate (spec F5.1)
    app.report = build_check.resolve(registry, sdk_env.new(env.sdk))
    app.decision = build_check.decide(registry, app.report, app.build.status)
    for _, f in ipairs(app.report.failures) do logger:warn("registry: %s [%s]", f.reason, f.feature) end
    logger:info("game build %s (%s), REFramework %s, seamless_net %s", tostring(steam_build or "?"), app.build.status,
        app.ref, app.plugin_version or "not loaded")

    app.actions = {
        set_enabled = function(on) M.set_enabled(app, on) end,
        add_fake = function(kind) return M.add_fake(app, kind) end,
        remove_fakes = function() M.remove_fakes(app) end,
        write_diagnostics = function() return M.write_diagnostics(app) end,
    }

    local ui_failed = false
    env.re.on_draw_ui(function()
        local ok, err = pcall(panel.draw, app, env.imgui)
        if not ok and not ui_failed then
            ui_failed = true
            logger:error("panel: %s", tostring(err))
        end
    end)

    local function close_log()
        logger:flush()
        if app.log_file then pcall(app.log_file.close, app.log_file) end
        app.log_file = nil
    end

    if not app.decision.enabled then
        logger:error("disabled: %s", app.decision.reason)
        env.re.on_script_reset(close_log)
        return app
    end

    local feats = app.decision.features
    app.story = feats.story.on and story_mod.new(env.sdk, app.report.resolved) or nil
    app.party = feats.party.on and party_mod.new(env.sdk, app.report.resolved) or nil
    app.story_point = function() return app.story and app.story.progress() or -1 end

    -- Transports: Steam (plugin) for real peers, loopback for test peers. 150 +/- 30 ms one way mimics two countries.
    app.hub = loopback.new_hub({ clock = env.clock, latency_ms = 150, jitter_ms = 30 })
    local steam_tr = net and transport.plugin(net) or transport.null("seamless_net.dll not loaded")
    app.transport = transport.composite({
        { prefix = "loop:", transport = app.hub:endpoint("loop:local") },
        { prefix = "", transport = steam_tr },
    })

    app.link = handshake.new({
        transport = app.transport,
        clock = env.clock,
        log = logger,
        bus = bus,
        local_info = function()
            return { mod = version.mod, build = steam_build or 0, ref = app.ref, hunter = app.self_hunter,
                     story = app.story_point(), caps = { "party" } }
        end,
        local_state = function() return { st = "idle", story = app.story_point() } end,
    })
    if not cfg:get("enabled") then app.link:set_enabled(false, "kill_switch") end

    if app.party then
        local last_sig, next_refresh = nil, 0
        sched:every("party", 1.0, function(now)
            local members = app.party.members() or {}
            app.members = members
            for _, m in ipairs(members) do
                if m.self then app.self_hunter = m.hunter end
            end
            local sig = party_mod.signature(members)
            if sig == last_sig and now < next_refresh then return end
            last_sig, next_refresh = sig, now + 5.0
            local friends = {}
            if net then
                local okf, f = pcall(net.friends_in_game)
                if okf and type(f) == "table" then friends = f end
            end
            local wanted = discovery.match(members, friends)
            for id, meta in pairs(wanted) do app.link:add_candidate(id, meta) end
            for id in pairs(app.link.peers) do
                if id:sub(1, 5) ~= "loop:" and not wanted[id] then app.link:remove_candidate(id, "left_party") end
            end
        end)
    end

    sched:on_frame("link", function() app.link:tick() end)
    sched:on_frame("test_peers", function()
        for _, f in pairs(app.fakes) do
            if not f.silent then f.link:tick() end
        end
    end)
    sched:on_frame("events", function() bus:flush() end)
    sched:every("log_flush", 5.0, function() logger:flush() end)
    if net then
        sched:every("net_status", 2.0, function()
            local ok, s = pcall(net.status)
            if not ok or type(s) ~= "table" then return end
            local prev = app.net_status
            app.net_status = s
            if not prev or prev.steam ~= s.steam or prev.relay ~= s.relay then
                logger:info("side channel: steam %s, relay status %s%s", tostring(s.steam), tostring(s.relay),
                    s.reason and (" (" .. tostring(s.reason) .. ")") or "")
            end
            local b = s.backup
            if b and (not prev or not prev.backup or prev.backup.state ~= b.state) then
                logger:info("save backup: %s (%s, %s files)", tostring(b.state), tostring(b.message), tostring(b.files))
            end
        end)
    end

    -- Unattended check of the handshake inside the game's Lua runtime (dev_selftest, off by default).
    if cfg:get("dev_selftest") then
        sched:after("selftest_start", 1.0, function()
            for _, kind in ipairs({ "compatible", "old_mod", "other_build", "old_protocol", "wrong_identity", "silent" }) do
                M.add_fake(app, kind)
            end
        end)
        sched:after("selftest_report", 8.0, function()
            local parts = {}
            for id, f in pairs(app.fakes) do
                local p = app.link.peers[id]
                parts[#parts + 1] = string.format("%s=%s%s%s", f.kind, p.state,
                    #p.reasons > 0 and ("(" .. table.concat(p.reasons, ",") .. ")") or "",
                    p.clock.rtt_avg and string.format(" rtt=%dms", math.floor(p.clock.rtt_avg + 0.5)) or "")
            end
            table.sort(parts)
            logger:info("selftest: %s", table.concat(parts, "; "))
            M.write_diagnostics(app)
            M.remove_fakes(app)
        end)
    end

    local watcher = hotkeys.watcher(function(vk)
        local ok, down = pcall(env.reframework.is_key_down, env.reframework, vk)
        return ok and down == true
    end)
    local kill, kerr = hotkeys.parse(cfg:get("hotkey_kill_switch"))
    if not kill then logger:warn("kill switch hotkey: %s", kerr) end
    sched:on_frame("hotkeys", function()
        if watcher:pressed(kill) then M.set_enabled(app, not cfg:get("enabled")) end
    end)

    env.re.on_frame(function() sched:tick() end)
    env.re.on_config_save(function()
        if cfg.dirty then cfg:save() end
    end)
    env.re.on_script_reset(function()
        pcall(app.link.shutdown, app.link)
        logger:info("script reset")
        close_log()
    end)
    logger:info("started")
    return app
end

return M
