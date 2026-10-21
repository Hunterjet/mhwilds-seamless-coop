-- Per-peer clock estimator. Every message carries the sender's send time `t` (ms, sender clock) and, once the sender
-- has heard from us, `echo` (our last `t` it received) and `held` (ms it held that before replying). That is enough
-- for an NTP-style estimate of round-trip time and clock offset; peers can be ~300 ms apart (spec N8).
local M = {}

local Clock = {}
Clock.__index = Clock

function M.new_clock(opts)
    opts = opts or {}
    return setmetatable({ samples = {}, max_samples = opts.max_samples or 16, alpha = opts.alpha or 0.2 }, Clock)
end

-- t1 = our send time (echoed), t3 = peer send time, held = peer hold time, t4 = our receive time. All ms.
-- Returns false if the sample is unusable (negative RTT after hold correction).
function Clock:add_sample(t1, t3, held, t4)
    local rtt = (t4 - t1) - held
    if rtt < 0 then return false end
    local offset = ((t3 - held - t1) + (t3 - t4)) / 2 -- peer clock minus our clock
    local s = self.samples
    s[#s + 1] = { rtt = rtt, offset = offset }
    if #s > self.max_samples then table.remove(s, 1) end
    self.rtt_avg = self.rtt_avg and (self.rtt_avg + self.alpha * (rtt - self.rtt_avg)) or rtt
    local best = s[1]
    for i = 2, #s do
        if s[i].rtt < best.rtt then best = s[i] end
    end
    self.rtt_min = best.rtt
    self.offset = best.offset
    return true
end

function Clock:has_estimate()
    return self.offset ~= nil
end

-- Converts a peer timestamp to our clock (ms).
function Clock:to_local(peer_ms)
    return peer_ms - (self.offset or 0)
end

-- Converts one of our timestamps to the peer's clock (ms).
function Clock:to_peer(local_ms)
    return local_ms + (self.offset or 0)
end

return M
