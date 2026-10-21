-- In-process fake network for single-PC testing (implementation plan §12): any number of endpoints, configurable
-- latency/jitter/drop per link, ordered delivery for reliable messages. Endpoints implement the transport interface.
local M = {}

local Hub = {}
Hub.__index = Hub

-- Deterministic LCG so tests are reproducible.
local function rng(seed)
    local state = seed or 1
    return function()
        state = (1103515245 * state + 12345) % 2147483648
        return state / 2147483648
    end
end

-- opts: clock (fn -> seconds), latency_ms (0), jitter_ms (0), drop (0..1, unreliable only), seed
function M.new_hub(opts)
    opts = opts or {}
    return setmetatable({
        clock = opts.clock or os.clock,
        default = { latency_ms = opts.latency_ms or 0, jitter_ms = opts.jitter_ms or 0, drop = opts.drop or 0 },
        links = {},
        endpoints = {},
        queue = {},
        last_reliable = {},
        rand = rng(opts.seed),
        sent = 0,
        dropped = 0,
    }, Hub)
end

local function link_key(a, b)
    if a < b then return a .. "|" .. b end
    return b .. "|" .. a
end

function Hub:set_link(a, b, params)
    self.links[link_key(a, b)] = params
end

function Hub:link(a, b)
    return self.links[link_key(a, b)] or self.default
end

local Endpoint = {}
Endpoint.__index = Endpoint

function Hub:endpoint(id)
    local ep = setmetatable({ hub = self, id = id, allowed = {}, closed = {} }, Endpoint)
    self.endpoints[id] = ep
    return ep
end

function Hub:remove_endpoint(id)
    self.endpoints[id] = nil
end

function Endpoint:local_id()
    return self.id
end

function Endpoint:allow(peer, on)
    self.allowed[peer] = on and true or nil
end

function Endpoint:close(peer)
    self.closed[peer] = true
end

function Endpoint:send(to, data, reliable)
    local hub = self.hub
    if not hub.endpoints[to] then return false, "no route" end
    if type(data) ~= "string" then return false, "payload must be a string" end
    local l = hub:link(self.id, to)
    hub.sent = hub.sent + 1
    if not reliable and l.drop > 0 and hub.rand() < l.drop then
        hub.dropped = hub.dropped + 1
        return true
    end
    local at = hub.clock() + (l.latency_ms + l.jitter_ms * hub.rand()) / 1000
    if reliable then
        local key = self.id .. ">" .. to
        at = math.max(at, hub.last_reliable[key] or at)
        hub.last_reliable[key] = at
    end
    hub.queue[#hub.queue + 1] = { from = self.id, to = to, data = data, at = at, n = hub.sent }
    return true
end

function Endpoint:poll(max)
    local hub, now, out = self.hub, self.hub.clock(), {}
    local due = {}
    for i, m in ipairs(hub.queue) do
        if m.to == self.id and m.at <= now then due[#due + 1] = i end
    end
    table.sort(due, function(a, b)
        local ma, mb = hub.queue[a], hub.queue[b]
        if ma.at == mb.at then return ma.n < mb.n end
        return ma.at < mb.at
    end)
    local take = {}
    for k = 1, math.min(#due, max or #due) do take[due[k]] = true end
    local kept = {}
    for i, m in ipairs(hub.queue) do
        if take[i] then
            out[#out + 1] = m
        else
            kept[#kept + 1] = m
        end
    end
    hub.queue = kept
    table.sort(out, function(a, b)
        if a.at == b.at then return a.n < b.n end
        return a.at < b.at
    end)
    local result = {}
    for i, m in ipairs(out) do result[i] = { from = m.from, data = m.data } end
    return result
end

function Endpoint:status()
    return { kind = "loopback", id = self.id, queued = #self.hub.queue }
end

return M
