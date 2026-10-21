local t = require("lib.t")
local discovery = require("seamless_coop.net.discovery")

local ME = { self = true, hunter = "h-me", name = "Me", platform = 5 }

t.test("discovery: members match Steam friends by display name", function()
    local members = { ME, { hunter = "h-ann", name = "Ann", platform = 5 }, { hunter = "h-bob", name = "Bob", platform = 5 } }
    local friends = { { id = "76561198000000001", name = "Ann" }, { id = "76561198000000002", name = "Zed" },
                      { id = "76561198000000004", name = "Yan" } }
    local out, info = discovery.match(members, friends)
    t.same(out, { ["76561198000000001"] = { label = "Ann", expected_hunter = "h-ann" } })
    t.same(info, { by_name = 1, guessed = 0 }) -- Bob unmatched but two spare friends: no guess
end)

t.test("discovery: duplicate names yield every candidate (the handshake picks the right one)", function()
    local members = { ME, { hunter = "h-ann", name = "Ann", platform = 5 } }
    local friends = { { id = "76561198000000001", name = "Ann" }, { id = "76561198000000003", name = "Ann" } }
    local out = discovery.match(members, friends)
    t.ok(out["76561198000000001"])
    t.ok(out["76561198000000003"])
end)

t.test("discovery: one unmatched member and one spare friend are paired (two-player fallback)", function()
    local members = { ME, { hunter = "h-ann", name = "Ann-in-game", platform = 5 } }
    local friends = { { id = "76561198000000001", name = "AnnSteam" } }
    local out, info = discovery.match(members, friends)
    t.same(out, { ["76561198000000001"] = { label = "Ann-in-game", expected_hunter = "h-ann", guessed = true } })
    t.eq(info.guessed, 1)
end)

t.test("discovery: self, other platforms and incomplete members are skipped", function()
    local members = {
        ME,
        { hunter = "h-ps", name = "Ann", platform = 2 },
        { hunter = nil, name = "Bob", platform = 5 },
    }
    local friends = { { id = "76561198000000001", name = "Ann" }, { id = "76561198000000002", name = "Bob" },
                      { id = "76561198000000009", name = "Me" } }
    t.same(discovery.match(members, friends), {})
    t.same(discovery.match(nil, nil), {})
    t.same(discovery.match({ ME, { hunter = "h-x", name = "Ann", platform = 5 } }, { { id = 5, name = "Ann" }, { name = "Bob" } }), {})
end)
