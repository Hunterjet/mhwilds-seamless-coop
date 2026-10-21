-- Seamless Co-op for Monster Hunter Wilds — read-only research probe.
--
-- Records calls to selected game methods and changes in key game state to
--   reframework/data/seamless_coop/traces/trace-<utc date>-<utc time>.jsonl
-- It never changes game state: every hook lets the original method run unchanged (CALL_ORIGINAL), and the state
-- snapshots only call getters / read fields. Arguments are logged as numbers, enum values or type names only — never
-- strings, GUIDs or player identifiers.
--
-- REFramework menu (Insert key) > "Seamless Co-op probe": status, pause, marks. F8 adds a mark at any time.
-- Part of https://github.com/Hunterjet/mhwilds-seamless-coop (MIT). Research tool, not the mod itself.

local VERSION = "0.1.1"

local CFG = {
    snapshot_interval = 1.0, -- seconds between state checks (a line is written only when something changed)
    census_interval = 5.0,   -- seconds between network packet census lines
    flush_interval = 1.0,    -- seconds between file flushes
    rate_limit = 20,         -- max logged calls per method per second; the rest are counted
    hot_per_sec = 30,        -- a method called more often than this for `hot_windows` seconds in a row is muted
    hot_windows = 3,
    max_hooks_per_type = 150,
    mark_key = 0x77,         -- VK_F8
    toast_seconds = 2.5,
}

-- Method selection per type:
--   methods  = exact names (all overloads), always hooked
--   patterns = Lua patterns on the method name (vetoed by GETTERS and `exclude`)
--   census   = exact names whose calls are only counted per (session type, packet type) — for very frequent methods
local GETTERS = {
    "^get", "^Get", "^is", "^Is", "^check", "^Check", "^can", "^has", "^update", "^Update", "^lateUpdate",
    "^onUpdate", "^ToString", "^Equals", "^GetHashCode", "^Finalize", "^%.c?ctor", "^op_", "^add_", "^remove_",
}
local VERBS = {
    "^start%u", "^end%u", "^request%u", "^req%u", "^on%u", "^notify%u", "^load%u", "^unload%u",
    "^retry", "^restart", "^clear%u", "^fail",
}

local TARGETS = {
    { type = "app.MissionManager", patterns = VERBS,
      -- per-frame methods seen in the first trace (2026-10-21)
      exclude = { "^onMissionContinueFlag$", "^onMainSideMissionClearUpdate$" },
      methods = {
        "reqSeamlessQuestSessionExecuteEvent", "reqUpdateProgressId", "reqUpdatePartySyncProgressId",
        "reqUpdateMemberListProgressId", "reqUpdateMemberListProgressIdAtAllClearedMain", "changeActiveManageMission",
        "updateMissionManageIDToActiveMission", "setPartySyncInfo", "setupPartySyncInfo", "resetPartySyncInfo",
        "setPackHost", "setNetStoryPackageFlagList", "resetNetStoryPackageFlag", "evSetStoryPackageFlag",
        "evNetJoinMember", "applyLateJoinSyncPacket", "applyMissionLateJoinSyncPacket", "createLateJoinSyncPacket",
        "createMissionLateJoinSyncPacket", "setActiveMissionPlLayout",
        "updateSaveStoryPackageFlag", "set_IsQuestJoinFailedLoading", "setStoryPackageFlagOverride",
        "resetAllStoryPackageFlagOverride",
    } },
    { type = "app.cQuestDirector", exclude = { "^clearItemWorkGGM$" }, methods = {
        "acceptQuest", "goQuest", "updateMaxJoinNum", "setQuestSyncParam", "notifyInviteJoinReady",
        "notifyInviteJoinFailed", "notifyHostChangeQuestSession", "notifyLeaveMemberQuestSession",
        "notifyLeaveQuestSession", "requestQuestStartDemoLoad", "clearQuestStartDemoInfo", "addQuestStartLayoutInfo",
    }, patterns = {
        "^start%u", "^end%u", "^request%u", "^req%u", "^on%u", "^notify%u", "^accept", "^go%u", "^clear%u",
        "^fail", "^retry", "^cancel", "^leave", "^join", "^setup", "^finish",
    } },
    { type = "app.MissionController", patterns = {
        "^start%u", "^end%u", "^change%u", "^set%u", "^clear%u", "^req%u", "^on%u", "^notify%u",
    } },
    { type = "app.cStoryFsmController", patterns = {
        "^start%u", "^end%u", "^add%u", "^req%u", "^set%u", "^remove%u", "^unload", "^restart",
    } },
    { type = "app.cMissionHaltController", patterns = {
        "^start", "^end", "^req", "^set%u", "^on%u", "^notify", "^halt", "^Halt",
    } },
    { type = "app.Net_Party", patterns = { "." }, census = { "receiveNetPacket" } },
    { type = "app.NetworkRequestManager", methods = {
        "createSession", "searchSession", "joinSession", "leaveSession", "updateSession", "reserveCreateRescue",
        "autoMatching", "inviteLinkParty", "inviteLinkPartyQuest", "inviteLinkPartySync", "acceptInviteLinkParty",
        "acceptInviteLinkPartyQuest", "acceptInviteLinkPartySync", "leaveLinkPartySync", "removeInviteLinkPartyQuest",
        "removeInviteLinkPartySync", "createSessionCallback", "searchSessionCallback", "joinSessionCallback",
        "callbackInvitationJoinLinkParty",
    } },
    { type = "app.Net_UserInfoManager", methods = { "onJoinMember", "onLeaveMember" } },
    { type = "app.Net_LateJoinSync", patterns = { "." } },
    { type = "app.NetworkManager", census = { "receiveNetPacket", "sendSnapShot" } },
    { type = "app.DemoMediator", methods = {
        "requestPlay", "requestLoad", "requestSkip", "execSkip", "requestStop", "requestForceStop",
        "requestForceUnloadAll", "onPlayStart", "onPlayEnd", "onPlayStartTimeline", "onPlayEndTimeline",
        "notifyCutSkipEnd", "notifyPlayStart", "notifyPlayEnd", "receiveNetPacket_End", "receiveNetPacket_Skip",
        "play", "load", "unload", "startStartFsm", "startEndFsm", "endStartFsm", "endEndFsm", "RequestFlowChange",
    } },
    { type = "app.cGameSceneTransition", patterns = { "^start", "^request", "^req%u", "^on%u", "^change%u" } },
}

---------------------------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------------------------
local state = {
    file = nil, path = nil, err = nil, lines = 0, paused = false, t0 = os.clock(),
    hooks_ok = 0, hooks_failed = 0, failed = {}, missing = {}, handles = {},
    census = {}, last_snapshot_str = nil, marks = 0, mark_label = "", key_down = false,
    next_snapshot = 0, next_census = 0, next_flush = 0, errors = 0, last_error = nil,
}

local function rel() return math.floor((os.clock() - state.t0) * 1000 + 0.5) / 1000 end
local function utc() local ok, v = pcall(os.time); return ok and v or nil end

---------------------------------------------------------------------------------------------------------------------
-- Minimal JSON encoder (stable, no dependencies)
---------------------------------------------------------------------------------------------------------------------
local encode
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function enc_str(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end
encode = function(v)
    local t = type(v)
    if v == nil then return "null"
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return math.type(v) == "integer" and tostring(v) or string.format("%.6g", v)
    elseif t == "string" then return enc_str(v)
    elseif t == "table" then
        local n = #v
        if n > 0 or next(v) == nil then
            local parts = {}
            for i = 1, n do parts[i] = encode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local parts = {}
        for i, k in ipairs(keys) do parts[i] = enc_str(k) .. ":" .. encode(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return enc_str(tostring(v))
end

---------------------------------------------------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------------------------------------------------
local function open_trace()
    local okd, stamp = pcall(os.date, "!%Y%m%d-%H%M%S")
    local name = "trace-" .. ((okd and stamp) or tostring(math.floor(os.clock()))) .. ".jsonl"
    for _, dir in ipairs({ "seamless_coop/traces/", "reframework/data/seamless_coop/traces/" }) do
        local fh = io.open(dir .. name, "a")
        if fh then
            state.file, state.path = fh, dir .. name
            return
        end
    end
    state.err = "could not open a trace file (run tools/deploy.ps1 -Probe to create reframework/data/seamless_coop/traces)"
end

local function emit(rec, force)
    if state.paused and not force then return end
    state.lines = state.lines + 1
    if state.file then state.file:write(encode(rec), "\n") end
end

---------------------------------------------------------------------------------------------------------------------
-- Argument rendering
---------------------------------------------------------------------------------------------------------------------
local PRIM = {
    ["System.Boolean"] = "b", ["System.Byte"] = "u8", ["System.SByte"] = "i8", ["System.Int16"] = "i16",
    ["System.UInt16"] = "u16", ["System.Int32"] = "i32", ["System.UInt32"] = "u32", ["System.Int64"] = "i64",
    ["System.UInt64"] = "u64",
}

local function short_type(name)
    local s = (name or "?"):gsub("^System%.", ""):gsub("^app%.", "")
    return s
end

local function arg_kind(ptype)
    if ptype == nil then return "?" end
    local fname = ptype:get_full_name()
    if PRIM[fname] then return PRIM[fname] end
    local parent = ptype:get_parent_type()
    if parent and parent:get_full_name() == "System.Enum" then
        local vf = ptype:get_field("value__")
        local vt = vf and vf:get_type()
        return "e" .. (PRIM[vt and vt:get_full_name() or ""] or "i32")
    end
    if ptype:is_value_type() then return "vt:" .. short_type(fname) end
    return "obj"
end

local function as_int(ptr, kind)
    local v = sdk.to_int64(ptr)
    if kind == "b" then return (v & 1) == 1 end
    if kind == "u8" then return v & 0xFF end
    if kind == "i8" then v = v & 0xFF; return v >= 0x80 and v - 0x100 or v end
    if kind == "u16" then return v & 0xFFFF end
    if kind == "i16" then v = v & 0xFFFF; return v >= 0x8000 and v - 0x10000 or v end
    if kind == "u32" then return v & 0xFFFFFFFF end
    if kind == "i32" then v = v & 0xFFFFFFFF; return v >= 0x80000000 and v - 0x100000000 or v end
    return v
end

local function render_arg(ptr, kind)
    if ptr == nil then return nil end
    if kind == "obj" then
        local obj = sdk.to_managed_object(ptr)
        if obj == nil then return nil end
        local td = obj:get_type_definition()
        return "@" .. short_type(td and td:get_full_name())
    end
    if kind:sub(1, 3) == "vt:" then return "<" .. kind:sub(4) .. ">" end
    if kind == "?" then return "?" end
    if kind:sub(1, 1) == "e" then return as_int(ptr, kind:sub(2)) end
    return as_int(ptr, kind)
end

---------------------------------------------------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------------------------------------------------
local function on_call(h, args)
    h.calls = h.calls + 1
    if h.census then
        local st = render_arg(args[h.base], h.kinds[1])
        local pkt = h.nparams >= 3 and render_arg(args[h.base + 2], "obj") or nil
        local key = h.short .. "|" .. tostring(st) .. "|" .. tostring(pkt)
        state.census[key] = (state.census[key] or 0) + 1
        return
    end
    local now = os.clock()
    if now - h.win_start >= 1.0 then
        if h.muted then
            h.win_start, h.win_count, h.suppressed = now, 0, 0
        else
            if h.win_count > CFG.hot_per_sec then h.hot = h.hot + 1 else h.hot = 0 end
            if h.hot >= CFG.hot_windows then
                h.muted = true
                emit({ t = rel(), k = "muted", m = h.label, rate = h.win_count })
            elseif h.suppressed > 0 then
                emit({ t = rel(), k = "suppressed", m = h.label, n = h.suppressed })
            end
            h.win_start, h.win_count, h.suppressed = now, 0, 0
        end
    end
    h.win_count = h.win_count + 1
    if h.muted then return end
    if h.win_count > CFG.rate_limit then
        h.suppressed = h.suppressed + 1
        return
    end
    local a = {}
    for i = 1, h.nparams do
        local ok, v = pcall(render_arg, args[h.base + i - 1], h.kinds[i])
        a[i] = ok and v or "<err>"
    end
    emit({ t = rel(), k = "call", m = h.label, a = a })
end

local function make_handle(type_name, m, is_census)
    local ptypes = m:get_param_types() or {}
    local names, kinds = {}, {}
    for i, p in ipairs(ptypes) do
        names[i] = short_type(p:get_full_name())
        local ok, k = pcall(arg_kind, p)
        kinds[i] = ok and k or "?"
    end
    local short = short_type(type_name) .. "." .. m:get_name()
    return {
        label = short .. "(" .. table.concat(names, ",") .. ")", short = short, kinds = kinds, nparams = #ptypes,
        base = m:is_static() and 2 or 3, census = is_census, calls = 0, win_start = 0, win_count = 0, suppressed = 0,
        hot = 0, muted = false,
    }
end

local function list_match(name, list)
    for _, p in ipairs(list or {}) do
        if name:find(p) then return true end
    end
    return false
end

local function post_hook(retval) return retval end

local function install_target(t)
    local td = sdk.find_type_definition(t.type)
    if td == nil then
        state.missing[#state.missing + 1] = t.type
        return
    end
    local explicit, census = {}, {}
    for _, n in ipairs(t.methods or {}) do explicit[n] = true end
    for _, n in ipairs(t.census or {}) do census[n] = true end
    local count = 0
    for _, m in ipairs(td:get_methods() or {}) do
        local name = m:get_name()
        local selected = census[name] or explicit[name]
            or (list_match(name, t.patterns) and not list_match(name, GETTERS) and not list_match(name, t.exclude))
        if selected and count < CFG.max_hooks_per_type then
            local h = make_handle(t.type, m, census[name] == true)
            local ok, err = pcall(sdk.hook, m, function(args)
                local ok2, e = pcall(on_call, h, args)
                if not ok2 then
                    state.errors = state.errors + 1
                    state.last_error = h.label .. ": " .. tostring(e)
                end
                return sdk.PreHookResult.CALL_ORIGINAL
            end, post_hook)
            if ok then
                count = count + 1
                state.hooks_ok = state.hooks_ok + 1
                state.handles[#state.handles + 1] = h
            else
                state.hooks_failed = state.hooks_failed + 1
                state.failed[#state.failed + 1] = h.label .. ": " .. tostring(err)
            end
        end
    end
end

---------------------------------------------------------------------------------------------------------------------
-- State snapshots (getters only)
---------------------------------------------------------------------------------------------------------------------
local function g(obj, name, ...)
    if obj == nil then return nil end
    local ok, v = pcall(obj.call, obj, name, ...)
    if not ok then return "<err>" end
    if type(v) == "userdata" then return "<obj>" end
    return v
end

local function fld(obj, name)
    if obj == nil then return nil end
    local ok, v = pcall(obj.get_field, obj, name)
    if not ok then return "<err>" end
    if type(v) == "userdata" then return "<obj>" end
    return v
end

local mission_util = sdk.find_type_definition("app.MissionUtil")
local expect_main = mission_util and mission_util:get_method("getExpectLoadMainMissionId")

local function snapshot()
    local s = {}
    local mm = sdk.get_managed_singleton("app.MissionManager")
    if mm then
        s.progress = g(mm, "getProgressId")
        s.partySyncProgress = g(mm, "getPartySyncProgressId")
        s.memberListProgress = g(mm, "getMemberListProgressId")
        s.oldActiveManageId = g(mm, "getOldActiveMissionManageID")
        s.activeQuestType = g(mm, "getActiveQuestMissionType")
        s.activeStage = g(mm, "getActiveStageType")
        s.packHost = g(mm, "get_IsPackHost")
        s.canPartySyncHere = g(mm, "getCanPartySyncInfoInCurrentStage")
        s.goQuestSeamless = g(mm, "get_IsGoQuestSeamless")
        s.waitingSeamlessSession = g(mm, "get_IsWaitingSeamlessQuestSession")
        s.joinFailedLoading = g(mm, "get_IsQuestJoinFailedLoading")
        s.isMissionQuest = fld(mm, "_IsMissionQuest")
        s.keepDrawOthers = fld(mm, "_KeepDrawOtherPlayerFlag")
        s.partySyncMission = fld(mm, "_MissionIdForPartySyncSet")
        local okq, qd = pcall(mm.call, mm, "get_QuestDirector")
        if okq and qd then
            s.qGoMission = g(qd, "get_GoQuestMissionID")
            s.qIsGo = g(qd, "isGoQuest")
            s.qGoSeamless = g(qd, "IsGoSeamless")
            s.qWaitingSeamless = g(qd, "IsWaitingSeamlessQuestSession")
            s.qMaxJoin = g(qd, "get_MaxJoinNum")
            s.qStartDemo = g(qd, "isQuestStartDemoEnable")
        end
    end
    if expect_main then
        local ok, v = pcall(expect_main.call, expect_main, nil)
        s.nextMainMission = ok and v or "<err>"
    end
    local dm = sdk.get_managed_singleton("app.DemoMediator")
    if dm then
        s.demoEvent = g(dm, "get_CurrentTimelineEventID")
        s.demoBusyLoad = g(dm, "get_IsBusyLoad")
        s.demoRequestPlaying = g(dm, "isExistRequestPlaying")
        s.demoWaitSkip = g(dm, "get_WaitSkipRequest")
    end
    local nm = sdk.get_managed_singleton("app.NetworkManager")
    if nm then
        local okp, party = pcall(nm.call, nm, "get_Party")
        if okp and party then
            s.syncJoining = g(party, "get_IsJoiningSync")
            s.syncBreak = g(party, "get_IsBreakPartySync")
            s.inPartyMemberQuest = g(party, "isInPartyMemberQuest")
            s.syncLeaveStoryEvent = fld(party, "_IsLeaveStoryEvent")
            s.syncNoHost = fld(party, "_IsNoHostPartySync")
            s.syncLeaveToJoin = fld(party, "_IsLeaveToJoinSync")
        end
        local oku, uim = pcall(nm.call, nm, "get_UserInfoManager")
        if oku and uim then
            s.membersLobby = g(uim, "getMemberNum", 1)
            s.membersQuest = g(uim, "getMemberNum", 2)
            s.membersLink = g(uim, "getMemberNum", 3)
        end
    end
    local str = encode(s)
    if str ~= state.last_snapshot_str then
        state.last_snapshot_str = str
        emit({ t = rel(), k = "state", utc = utc(), s = s })
    end
end

local function flush_census()
    if next(state.census) == nil then return end
    emit({ t = rel(), k = "census", d = state.census })
    state.census = {}
end

local function add_mark(source)
    state.marks = state.marks + 1
    emit({ t = rel(), k = "mark", n = state.marks, utc = utc(), src = source, label = state.mark_label }, true)
    state.toast_text = "Probe: mark #" .. state.marks .. " saved"
    state.toast_until = os.clock() + CFG.toast_seconds
end

---------------------------------------------------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------------------------------------------------
open_trace()
for _, t in ipairs(TARGETS) do
    local ok, err = pcall(install_target, t)
    if not ok then state.failed[#state.failed + 1] = t.type .. ": " .. tostring(err) end
end
do
    local labels = {}
    for i, h in ipairs(state.handles) do labels[i] = h.label end
    local okg, game = pcall(function() return reframework:get_game_name() end)
    local okt, tdb = pcall(sdk.get_tdb_version)
    emit({ t = rel(), k = "start", v = VERSION, utc = utc(), game = okg and game or nil, tdb = okt and tdb or nil,
           hooks_ok = state.hooks_ok, hooks_failed = state.hooks_failed, missing = state.missing }, true)
    emit({ t = rel(), k = "hooked", list = labels }, true)
    if #state.failed > 0 then emit({ t = rel(), k = "hook_failed", list = state.failed }, true) end
    if state.file then state.file:flush() end
end

re.on_frame(function()
    local now = os.clock()
    if now >= state.next_snapshot then
        state.next_snapshot = now + CFG.snapshot_interval
        local ok, err = pcall(snapshot)
        if not ok then state.errors, state.last_error = state.errors + 1, "snapshot: " .. tostring(err) end
    end
    if now >= state.next_census then
        state.next_census = now + CFG.census_interval
        flush_census()
    end
    if now >= state.next_flush then
        state.next_flush = now + CFG.flush_interval
        if state.file then state.file:flush() end
    end
    local okk, down = pcall(function() return reframework:is_key_down(CFG.mark_key) end)
    down = okk and down or false
    if down and not state.key_down then add_mark("F8") end
    state.key_down = down
    if state.toast_until and now < state.toast_until then
        pcall(draw.text, state.toast_text, 40, 40, 0xFFFFFFFF)
    end
end)

re.on_draw_ui(function()
    if not imgui.tree_node("Seamless Co-op probe " .. VERSION) then return end
    imgui.text("Read-only research probe. It never changes the game.")
    imgui.text("Trace: " .. (state.path or ("NOT WRITING - " .. tostring(state.err))))
    imgui.text(string.format("Lines: %d   Hooks: %d ok, %d failed   Marks: %d   Errors: %d",
        state.lines, state.hooks_ok, state.hooks_failed, state.marks, state.errors))
    local changed, v = imgui.checkbox("Paused", state.paused)
    if changed then
        emit({ t = rel(), k = v and "paused" or "resumed", utc = utc() }, true)
        state.paused = v
    end
    local c2, label = imgui.input_text("Mark label", state.mark_label)
    if c2 then state.mark_label = label end
    if imgui.button("Add mark (F8)") then add_mark("button") end
    if imgui.tree_node("Busiest methods") then
        local sorted = {}
        for _, h in ipairs(state.handles) do
            if h.calls > 0 then sorted[#sorted + 1] = h end
        end
        table.sort(sorted, function(a, b) return a.calls > b.calls end)
        for i = 1, math.min(15, #sorted) do
            imgui.text(string.format("%8d  %s%s", sorted[i].calls, sorted[i].label, sorted[i].muted and "  [muted]" or ""))
        end
        imgui.tree_pop()
    end
    if (#state.failed > 0 or #state.missing > 0 or state.last_error) and imgui.tree_node("Problems") then
        for _, m in ipairs(state.missing) do imgui.text("missing type: " .. m) end
        for i = 1, math.min(20, #state.failed) do imgui.text("hook failed: " .. state.failed[i]) end
        if state.last_error then imgui.text("last error: " .. state.last_error) end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)

re.on_script_reset(function()
    flush_census()
    emit({ t = rel(), k = "stop", utc = utc() }, true)
    if state.file then state.file:close() end
end)
