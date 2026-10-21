-- REFramework menu panel (spec F6): status, kill switch, build gate, Link Party members and their mod status,
-- developer tools (loopback test peers) and diagnostics. Player names are shown here only (never logged or sent).
local version = require("seamless_coop.core.version")
local util = require("seamless_coop.core.util")
local S = require("seamless_coop.ui.strings_en")

local M = {}

-- imgui colours are 0xAABBGGRR.
local GREEN, RED, YELLOW, GREY = 0xFF66DD66, 0xFF6666FF, 0xFF44CCFF, 0xFFAAAAAA

local STATE_COLOR = { compatible = GREEN, incompatible = RED, pending = GREY, lost = YELLOW, left = GREY }

local function peer_line(p)
    local text = S.peer_states[p.state] or p.state
    if p.state == "incompatible" and #p.reasons > 0 then
        local r = {}
        for i, code in ipairs(p.reasons) do r[i] = S.reasons[code] or code end
        text = text .. ": " .. table.concat(r, ", ")
    end
    if p.state == "compatible" and p.clock.rtt_avg then
        text = text .. string.format(" - %d ms", math.floor(p.clock.rtt_avg + 0.5))
    end
    if p.hello then
        text = text .. string.format(" - mod %s, story %d", p.hello.mod, p.hello.story)
    end
    return text
end

local function draw_status(app, imgui)
    local cfg = app.cfg
    local changed, on = imgui.checkbox(S.enabled_checkbox .. " (" .. cfg:get("hotkey_kill_switch") .. ")", cfg:get("enabled"))
    if changed then app.actions.set_enabled(on) end
    imgui.text_colored(cfg:get("enabled") and S.on or S.off, cfg:get("enabled") and GREEN or YELLOW)

    local b = app.build
    local build_text = b.status == "verified" and S.build_verified or (b.status == "unverified" and S.build_unverified or S.build_unknown)
    imgui.text(string.format("Game build: %s (%s)", tostring(b.steam or "?"), build_text))
    imgui.text(string.format("Mod %s - protocol %d - seamless_net %s - REFramework %s", version.mod, version.protocol,
        app.plugin_version or "not loaded", app.ref))
    if not app.plugin_version then imgui.text_colored(S.no_plugin, YELLOW) end
    local ns = app.net_status
    if ns then
        if ns.steam then
            imgui.text(string.format("Side channel: relay %s - sent %d, received %d, dropped %d",
                ns.relay == 100 and "ready" or ("status " .. tostring(ns.relay)), ns.sent or 0, ns.received or 0,
                (ns.dropped_not_allowed or 0) + (ns.dropped_size or 0) + (ns.dropped_rate or 0)))
        else
            imgui.text_colored("Side channel unavailable: " .. tostring(ns.reason), RED)
        end
        if ns.backup then
            imgui.text(string.format("Save backup: %s%s", ns.backup.state,
                ns.backup.state == "done" and string.format(" (%d files)", ns.backup.files or 0)
                or (ns.backup.message ~= "" and (" - " .. ns.backup.message) or "")))
        end
    end
end

local function draw_party(app, imgui)
    if not imgui.tree_node(S.party_header) then return end
    local members = app.members or {}
    if #members == 0 then imgui.text(S.party_none) end
    local by_hunter = {}
    for _, p in pairs(app.link.peers) do
        if p.expected_hunter then by_hunter[p.expected_hunter] = p end
    end
    for _, m in ipairs(members) do
        local name = m.name or "?"
        if m.self then
            imgui.text(string.format("%s (%s) - story %s", name, S.you, tostring(app.story_point())))
        else
            local p = by_hunter[m.hunter or ""]
            if p then
                imgui.text_colored(string.format("%s - %s", name, peer_line(p)), STATE_COLOR[p.state] or GREY)
            else
                imgui.text_colored(name .. " - not a Steam friend in game (no side channel)", GREY)
            end
        end
    end
    imgui.tree_pop()
end

local function draw_dev(app, imgui)
    if not imgui.tree_node(S.dev_header) then return end
    imgui.text("Single-PC test peers over a fake network (150 ms +/- 30 ms one way).")
    for _, kind in ipairs({ "compatible", "old_mod", "other_build", "old_protocol", "wrong_identity", "silent" }) do
        if imgui.button("Add " .. kind) then app.actions.add_fake(kind) end
        imgui.same_line()
    end
    if imgui.button("Remove all") then app.actions.remove_fakes() end
    for id, f in pairs(app.fakes) do
        local p = app.link.peers[id]
        if p then imgui.text_colored(p.label .. " - " .. peer_line(p), STATE_COLOR[p.state] or GREY) end
    end
    imgui.tree_pop()
end

local function draw_diag(app, imgui)
    if not imgui.tree_node(S.diag_header) then return end
    if imgui.button("Write diagnostics file") then app.actions.write_diagnostics() end
    local feats = {}
    for _, name in ipairs(util.sorted_keys(app.decision.features)) do
        local f = app.decision.features[name]
        feats[#feats + 1] = name .. (f.on and " on" or (" OFF (" .. tostring(f.reason) .. ")"))
    end
    imgui.text("Features: " .. table.concat(feats, ", "))
    for _, f in ipairs(app.report.failures) do imgui.text_colored("missing: " .. f.reason, RED) end
    if app.link then
        local s = app.link.stats
        imgui.text(string.format("Messages: tx %d (failed %d), rx %d, invalid %d, stale %d, unknown sender %d",
            s.tx, s.tx_failed, s.rx, s.invalid, s.stale, s.unknown_sender))
    end
    for _, t in ipairs(app.sched:status()) do
        if t.faults > 0 or t.disabled then
            imgui.text_colored(string.format("task %s: %d faults%s - %s", t.name, t.faults, t.disabled and " (disabled)" or "",
                tostring(t.last_error)), t.disabled and RED or YELLOW)
        end
    end
    if imgui.tree_node(S.log_header) then
        for _, line in ipairs(app.log:lines(25)) do imgui.text(line) end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end

function M.draw(app, imgui)
    if not imgui.tree_node(S.title .. " " .. version.mod) then return end
    if not app.decision.enabled then
        imgui.text_colored(S.disabled, RED)
        imgui.text(tostring(app.decision.reason))
        for _, f in ipairs(app.report.failures) do imgui.text("missing: " .. f.reason) end
        imgui.tree_pop()
        return
    end
    draw_status(app, imgui)
    if app.party then draw_party(app, imgui) end
    if app.cfg:get("dev_tools") then draw_dev(app, imgui) end
    draw_diag(app, imgui)
    imgui.tree_pop()
end

return M
