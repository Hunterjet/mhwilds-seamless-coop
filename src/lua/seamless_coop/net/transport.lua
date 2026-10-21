-- Transport adapters. Every transport offers: send(id, data, reliable) -> ok, err; poll(max) -> { {from, data} };
-- allow(id, on); close(id); local_id(); status().
local M = {}

-- Wraps the seamless_net plugin (Steam Networking Messages through Valve's relay).
function M.plugin(net)
    local t = { net = net }
    function t:send(id, data, reliable) return net.send(id, data, reliable) end
    function t:poll(max) return net.poll(max) or {} end
    function t:allow(id, on) return net.allow(id, on) end
    function t:close(id) return net.close(id) end
    function t:local_id() return net.local_id() end
    function t:status() return net.status() end
    return t
end

-- Routes by peer-id prefix, e.g. { { prefix = "loop:", transport = endpoint }, { prefix = "", transport = steam } }.
-- The first matching route wins; poll() merges all routes.
function M.composite(routes)
    local t = { routes = routes }
    local function route(id)
        for _, r in ipairs(routes) do
            if id:sub(1, #r.prefix) == r.prefix then return r.transport end
        end
        return nil
    end
    function t:send(id, data, reliable)
        local tr = route(id)
        if not tr then return false, "no route" end
        return tr:send(id, data, reliable)
    end
    function t:poll(max)
        local out = {}
        for _, r in ipairs(routes) do
            local remaining = (max or 64) - #out
            if remaining <= 0 then break end
            for _, m in ipairs(r.transport:poll(remaining) or {}) do out[#out + 1] = m end
        end
        return out
    end
    function t:allow(id, on)
        local tr = route(id)
        if tr and tr.allow then return tr:allow(id, on) end
    end
    function t:close(id)
        local tr = route(id)
        if tr and tr.close then return tr:close(id) end
    end
    function t:local_id()
        return routes[#routes].transport:local_id()
    end
    function t:status()
        local s = {}
        for i, r in ipairs(routes) do s[i] = r.transport:status() end
        return s
    end
    return t
end

-- Transport used when seamless_net.dll is missing: never delivers anything.
function M.null(reason)
    local t = { reason = reason }
    function t:send() return false, reason end
    function t:poll() return {} end
    function t:allow() end
    function t:close() end
    function t:local_id() return nil end
    function t:status() return { kind = "none", reason = reason } end
    return t
end

return M
