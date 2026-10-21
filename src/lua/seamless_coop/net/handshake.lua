-- Peer handshake and liveness (spec F5.2, implementation plan §6.2/§8). Owns one record per candidate peer:
--   pending       we send HELLO with backoff (no reply yet: the member may not have the mod)
--   compatible    HELLO/HELLO_ACK received and compatible; heartbeats both ways (~1 Hz)
--   incompatible  HELLO received but mod/protocol/build/identity differ (reasons listed); HELLO every 10 s
--   lost          no message for peer_timeout_s; back to HELLO with backoff
--   left          the peer said BYE (shutdown or kill switch); quiet until it says HELLO again
-- Only candidates (verified party members, or loopback test peers) are accepted as senders.
local json = require("seamless_coop.core.json")
local protocol = require("seamless_coop.net.protocol")
local peers = require("seamless_coop.net.peers")
local version = require("seamless_coop.core.version")
local util = require("seamless_coop.core.util")

local M = {}

M.DEFAULTS = {
    heartbeat_s = 1.0,
    hello_retry_s = 2.0,
    hello_retry_max_s = 10.0,
    peer_timeout_s = 10.0,
    poll_max = 64,
}

M.ZERO_GUID = "00000000-0000-0000-0000-000000000000"

-- Returns ok, reasons (list of codes: protocol, mod_version, game_build, identity).
function M.check_compat(local_info, hello, expected_hunter)
    local reasons = {}
    if hello.proto ~= (local_info.proto or protocol.VERSION) then reasons[#reasons + 1] = "protocol" end
    if version.compat_key(hello.mod) ~= version.compat_key(local_info.mod) then reasons[#reasons + 1] = "mod_version" end
    local lb, rb = local_info.build or 0, hello.build or 0
    if lb > 0 and rb > 0 and lb ~= rb then reasons[#reasons + 1] = "game_build" end
    if expected_hunter and hello.hunter ~= expected_hunter then reasons[#reasons + 1] = "identity" end
    return #reasons == 0, reasons
end

local Link = {}
Link.__index = Link

-- opts:
--   transport   { send(id, data, reliable), poll(max), allow(id, on), close(id), local_id() }
--   clock       fn -> seconds (monotonic)
--   log, bus    core/log and core/events instances
--   local_info  fn -> { mod, build, ref, hunter, story, caps, proto? }
--   local_state fn -> { st, story, ms, seg } (heartbeat payload)
--   config      overrides for M.DEFAULTS
--   inst        instance id (random per game session)
--   proto       protocol version override (loopback test peers only)
function M.new(opts)
    local cfg = util.shallow_copy(M.DEFAULTS)
    for k, v in pairs(opts.config or {}) do cfg[k] = v end
    return setmetatable({
        tr = opts.transport,
        clock = opts.clock,
        log = opts.log,
        bus = opts.bus,
        local_info = opts.local_info,
        local_state = opts.local_state or function()
            return { st = "idle", story = opts.local_info().story or -1 }
        end,
        cfg = cfg,
        inst = opts.inst or math.random(1, 0x7FFFFFFF),
        proto = opts.proto, -- protocol override, only for loopback test peers
        seq = { r = 0, u = 0 }, -- separate sequence spaces for reliable and unreliable messages
        peers = {},
        enabled = true,
        stats = { rx = 0, tx = 0, tx_failed = 0, invalid = 0, stale = 0, unknown_sender = 0, not_ready = 0 },
    }, Link)
end

function Link:now_ms()
    return math.floor(self.clock() * 1000 + 0.5)
end

local function emit(self, topic, ...)
    if self.bus then self.bus:emit(topic, ...) end
end

local function log(self, level, fmt, ...)
    if self.log then self.log[level](self.log, fmt, ...) end
end

local function set_state(self, p, state, now)
    if p.state == state then return end
    local old = p.state
    p.state = state
    p.since = now
    log(self, state == "incompatible" and "warn" or "info", "peer %s: %s -> %s%s", p.log_id, old, state,
        (#p.reasons > 0 and state == "incompatible") and (" (" .. table.concat(p.reasons, ", ") .. ")") or "")
    emit(self, "peer_state", p, old)
end

-- meta: { label = display name for the panel (never logged), expected_hunter = GUID string or nil }
function Link:add_candidate(id, meta)
    meta = meta or {}
    local p = self.peers[id]
    if p then
        p.expected_hunter = meta.expected_hunter or p.expected_hunter
        p.label = meta.label or p.label
        return p
    end
    local now = self.clock()
    p = {
        id = id,
        label = meta.label or util.short_id(id), -- display only (may be a player name: never logged)
        log_id = util.short_id(id),
        expected_hunter = meta.expected_hunter,
        state = "pending",
        since = now,
        reasons = {},
        clock = peers.new_clock(),
        last_rx = nil,
        next_hello = now,
        hello_interval = self.cfg.hello_retry_s,
        next_heartbeat = now,
        last_seq = { r = -1, u = -1 },
        rx = 0,
        invalid = 0,
    }
    self.peers[id] = p
    if self.tr.allow then self.tr:allow(id, true) end
    log(self, "info", "peer %s: candidate added", p.log_id)
    emit(self, "peer_added", p)
    return p
end

function Link:remove_candidate(id, reason)
    local p = self.peers[id]
    if not p then return end
    if self.enabled and (p.state == "compatible" or p.state == "incompatible") then
        self:send(p, "BYE", { reason = reason or "left_party" })
    end
    self.peers[id] = nil
    if self.tr.allow then self.tr:allow(id, false) end
    if self.tr.close then self.tr:close(id) end
    log(self, "info", "peer %s: removed (%s)", p.log_id, reason or "left_party")
    emit(self, "peer_removed", p)
end

function Link:send(p, mtype, d, reliable)
    local unreliable = reliable == false
    local stream = unreliable and "u" or "r"
    self.seq[stream] = self.seq[stream] + 1
    local bytes, err = protocol.encode(mtype, self.seq[stream], self.inst, d, self.proto, unreliable)
    if not bytes then
        log(self, "error", "peer %s: cannot encode %s: %s", p.log_id, mtype, err)
        return false
    end
    local ok, serr = self.tr:send(p.id, bytes, reliable ~= false)
    if ok then
        self.stats.tx = self.stats.tx + 1
    else
        self.stats.tx_failed = self.stats.tx_failed + 1
        p.last_send_error = serr
    end
    return ok
end

-- Adds echo/held so the receiver can measure RTT and clock offset.
local function add_timing(p, d, now_ms)
    d.t = now_ms
    if p.peer_t then
        d.echo = p.peer_t
        d.held = math.max(0, math.min(600000, now_ms - p.peer_t_rx))
    end
    return d
end

function Link:hello_payload(p, now_ms)
    local info = self.local_info()
    local caps = json.array({})
    for i, c in ipairs(info.caps or {}) do caps[i] = c end
    return add_timing(p, {
        mod = info.mod,
        proto = info.proto or protocol.VERSION,
        build = info.build or 0,
        ref = info.ref,
        hunter = info.hunter or M.ZERO_GUID,
        story = info.story or -1,
        caps = caps,
    }, now_ms)
end

function Link:on_hello(p, msg, now)
    local d = msg.d
    p.hello = { mod = d.mod, proto = d.proto, build = d.build, ref = d.ref, story = d.story, hunter = d.hunter, caps = d.caps }
    local ok, reasons = M.check_compat(self.local_info(), d, p.expected_hunter)
    p.reasons = reasons
    if ok then
        if p.state ~= "compatible" then p.next_heartbeat = now end
        set_state(self, p, "compatible", now)
    else
        set_state(self, p, "incompatible", now)
        p.next_hello = now + self.cfg.hello_retry_max_s
    end
end

function Link:on_packet(from, data, now)
    local p = self.peers[from]
    if not p then
        self.stats.unknown_sender = self.stats.unknown_sender + 1
        return
    end
    local msg, err = protocol.decode(data)
    if not msg then
        self.stats.invalid = self.stats.invalid + 1
        p.invalid = p.invalid + 1
        p.last_error = err
        log(self, "debug", "peer %s: dropped invalid message (%s)", p.log_id, tostring(err))
        return
    end
    if msg.i ~= p.remote_inst then
        p.remote_inst = msg.i
        p.last_seq = { r = -1, u = -1 }
    end
    local stream = msg.u == 1 and "u" or "r"
    if msg.s <= p.last_seq[stream] then
        self.stats.stale = self.stats.stale + 1
        return
    end
    p.last_seq[stream] = msg.s
    p.last_rx = now
    p.rx = p.rx + 1
    self.stats.rx = self.stats.rx + 1

    local now_ms = math.floor(now * 1000 + 0.5)
    local d = msg.d
    if math.type(d.t) == "integer" then
        if d.echo and d.held then p.clock:add_sample(d.echo, d.t, d.held, now_ms) end
        p.peer_t, p.peer_t_rx = d.t, now_ms
    end

    if msg.t == "HELLO" or msg.t == "HELLO_ACK" then
        if p.state == "left" or p.state == "lost" then p.hello_interval = self.cfg.hello_retry_s end
        self:on_hello(p, msg, now)
        if msg.t == "HELLO" and self.enabled then self:send(p, "HELLO_ACK", self:hello_payload(p, now_ms)) end
    elseif msg.t == "BYE" then
        p.bye_reason = d.reason
        set_state(self, p, "left", now)
    elseif p.state ~= "compatible" then
        self.stats.not_ready = self.stats.not_ready + 1
    elseif msg.t == "HEARTBEAT" then
        p.remote_state = { st = d.st, story = d.story, ms = d.ms, seg = d.seg }
        emit(self, "peer_heartbeat", p)
    else
        emit(self, "net_message", p, msg)
    end
end

function Link:tick()
    local now = self.clock()
    local batch = self.tr:poll(self.cfg.poll_max) or {}
    if not self.enabled then
        self.stats.ignored = (self.stats.ignored or 0) + #batch
        return
    end
    for _, m in ipairs(batch) do
        self:on_packet(m.from, m.data, now)
    end
    local now_ms = math.floor(now * 1000 + 0.5)
    for _, p in pairs(self.peers) do
        if p.state == "compatible" and p.last_rx and now - p.last_rx > self.cfg.peer_timeout_s then
            p.hello_interval = self.cfg.hello_retry_s
            p.next_hello = now
            set_state(self, p, "lost", now)
        end
        if p.state == "compatible" then
            if now >= p.next_heartbeat then
                local st = self.local_state()
                self:send(p, "HEARTBEAT", add_timing(p, { st = st.st, story = st.story or -1, ms = st.ms, seg = st.seg },
                    now_ms), false)
                p.next_heartbeat = now + self.cfg.heartbeat_s
            end
        elseif p.state ~= "left" and now >= p.next_hello then
            self:send(p, "HELLO", self:hello_payload(p, now_ms))
            if p.state == "incompatible" then
                p.next_hello = now + self.cfg.hello_retry_max_s
            else
                p.next_hello = now + p.hello_interval
                p.hello_interval = math.min(p.hello_interval * 1.5, self.cfg.hello_retry_max_s)
            end
        end
    end
end

-- Kill switch (spec F5.7): says BYE and goes quiet; re-enabling restarts the handshake with every candidate.
function Link:set_enabled(on, reason)
    if on == self.enabled then return end
    local now = self.clock()
    if not on then
        for _, p in pairs(self.peers) do
            if p.state == "compatible" or p.state == "incompatible" then
                self:send(p, "BYE", { reason = reason or "kill_switch" })
            end
        end
        self.enabled = false
        log(self, "info", "side channel off (%s)", reason or "kill_switch")
    else
        self.enabled = true
        for _, p in pairs(self.peers) do
            p.hello_interval = self.cfg.hello_retry_s
            p.next_hello = now
            p.reasons = {}
            set_state(self, p, "pending", now)
        end
        log(self, "info", "side channel on")
    end
end

function Link:shutdown()
    self:set_enabled(false, "shutdown")
end

-- Counts by state, for the panel.
function Link:summary()
    local s = { total = 0, compatible = 0, incompatible = 0, pending = 0, lost = 0, left = 0 }
    for _, p in pairs(self.peers) do
        s.total = s.total + 1
        s[p.state] = (s[p.state] or 0) + 1
    end
    return s
end

return M
