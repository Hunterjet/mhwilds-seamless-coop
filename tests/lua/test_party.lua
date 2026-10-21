local t = require("lib.t")
local fakes = require("fakes.reframework")
local build_check = require("seamless_coop.compat.build_check")
local registry = require("seamless_coop.compat.registry")
local sdk_env = require("seamless_coop.game.sdk_env")
local party = require("seamless_coop.game.party")
local story = require("seamless_coop.game.story")

local function member(over)
    local m = { valid = true, self = false, hunter = fakes.guid(0x0a1b2c3d, 1, 2, { 3, 4, 5, 6, 7, 8, 9, 10 }), name = "Ann",
                platform = 5, index = 1, progress = 250, sync = false }
    for k, v in pairs(over or {}) do m[k] = v end
    return m
end

local function adapters(game)
    local report = build_check.resolve(registry, sdk_env.new(game.sdk))
    t.ok(report.core_ok)
    t.eq(#report.failures, 0, "registry fully resolved by the fake game")
    return party.new(game.sdk, report.resolved), story.new(game.sdk, report.resolved)
end

t.test("party: reads valid Link Party members and formats hunter IDs", function()
    local game = fakes.game({ members = {
        member({ self = true, name = "Me", index = 0, hunter = fakes.guid(1, 2, 3, { 0, 0, 0, 0, 0, 0, 0, 255 }) }),
        member(),
        member({ valid = false, name = "Ghost" }),
    } })
    local p = adapters(game)
    local list = p.members()
    t.eq(#list, 2)
    t.ok(list[1].self)
    t.eq(list[1].hunter, "00000001-0002-0003-0000-0000000000ff")
    t.eq(list[2].hunter, "0a1b2c3d-0001-0002-0304-05060708090a")
    t.eq(list[2].name, "Ann")
    t.eq(list[2].platform, 5)
    t.eq(list[2].progress, 250)
end)

t.test("party: unavailable while the network manager does not exist", function()
    local game = fakes.game({ members = { member() } })
    local p = adapters(game)
    game.singletons["app.NetworkManager"] = nil
    t.eq(p.members(), nil)
end)

t.test("party: signature changes only with membership", function()
    local a = { { hunter = "x" }, { hunter = "y", self = true } }
    local b = { { hunter = "y", self = true }, { hunter = "x" } }
    t.eq(party.signature(a), party.signature(b))
    t.ok(party.signature(a) ~= party.signature({ { hunter = "x" } }))
end)

t.test("story: progress point from MissionManager", function()
    local game = fakes.game({ progress = 300 })
    local _, s = adapters(game)
    t.eq(s.progress(), 300)
    t.eq(s.party_sync_progress(), 0)
    game.singletons["app.MissionManager"] = nil
    t.eq(s.progress(), -1)
end)

t.test("sdk_env: guid fallback to ToString and array fallback to get_size/get_element", function()
    local g = { get_field = function() error("no fields") end,
                call = function(_, m) return m == "ToString()" and "ABCDEF00-0000-0000-0000-000000000000" or nil end }
    t.eq(sdk_env.guid_to_string(g), "abcdef00-0000-0000-0000-000000000000")
    t.eq(sdk_env.guid_to_string(nil), nil)
    local arr = { get_elements = function() error("x") end, get_size = function() return 2 end,
                  get_element = function(_, i) return "e" .. i end }
    t.same(sdk_env.array_items(arr), { "e0", "e1" })
    t.same(sdk_env.array_items(nil), {})
end)
