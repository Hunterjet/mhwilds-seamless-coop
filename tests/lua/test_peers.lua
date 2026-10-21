local t = require("lib.t")
local peers = require("seamless_coop.net.peers")

-- Simulates one exchange: we send at t1 (our clock); the peer (clock = ours + offset) receives after `d1`, holds
-- `held`, replies; we receive after `d2`.
local function exchange(clk, t1, d1, held, d2, offset)
    local t2_peer = t1 + d1 + offset
    local t3_peer = t2_peer + held
    local t4 = t1 + d1 + held + d2
    return clk:add_sample(t1, t3_peer, held, t4)
end

t.test("peers: symmetric delays give exact RTT and offset", function()
    local clk = peers.new_clock()
    t.ok(exchange(clk, 1000, 150, 40, 150, 5000))
    t.eq(clk.rtt_min, 300)
    t.near(clk.offset, 5000, 1e-9)
    t.near(clk:to_local(6000), 1000, 1e-9)
    t.near(clk:to_peer(1000), 6000, 1e-9)
end)

t.test("peers: the lowest-RTT sample wins the offset; RTT average smooths", function()
    local clk = peers.new_clock({ alpha = 0.5 })
    exchange(clk, 0, 300, 10, 100, -2000) -- asymmetric, offset error 100
    exchange(clk, 1000, 120, 10, 120, -2000) -- clean
    exchange(clk, 2000, 200, 10, 400, -2000)
    t.eq(clk.rtt_min, 240)
    t.near(clk.offset, -2000, 1e-9)
    t.ok(clk.rtt_avg > 240 and clk.rtt_avg < 600)
end)

t.test("peers: impossible samples are ignored", function()
    local clk = peers.new_clock()
    t.no(clk:add_sample(1000, 0, 500, 1100))
    t.no(clk:has_estimate())
end)

t.test("peers: only the last N samples count", function()
    local clk = peers.new_clock({ max_samples = 2 })
    exchange(clk, 0, 10, 0, 10, 0)     -- rtt 20 (best, will age out)
    exchange(clk, 100, 50, 0, 50, 7)
    exchange(clk, 200, 60, 0, 60, 7)
    t.eq(clk.rtt_min, 100)
    t.near(clk.offset, 7, 1e-9)
end)
