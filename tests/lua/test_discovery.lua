local t = require("lib.t")
local discovery = require("seamless_coop.net.discovery")

local ME = { self = true, hunter = "h-me", name = "Me", platform = 5 }

t.test("discovery: members match Steam friends by display name", function()
    local members = { ME, { hunter = "h-ann", name = "Ann", platform = 5 }, { hunter = "h-bob", name = "Bob", platform = 5 } }
    local friends = { { id = "76561198000000001", name = "Ann" }, { id = "76561198000000002", name = "Zed" } }
    local out = discovery.match(members, friends)
    t.same(out, { ["76561198000000001"] = { label = "Ann", expected_hunter = "h-ann" } })
end)

t.test("discovery: duplicate names yield every candidate (the handshake picks the right one)", function()
    local members = { ME, { hunter = "h-ann", name = "Ann", platform = 5 } }
    local friends = { { id = "76561198000000001", name = "Ann" }, { id = "76561198000000003", name = "Ann" } }
    local out = discovery.match(members, friends)
    t.ok(out["76561198000000001"])
    t.ok(out["76561198000000003"])
end)

t.test("discovery: self, other platforms and incomplete members are skipped", function()
    local members = {
        ME,
        { hunter = "h-ps", name = "Ann", platform = 2 },
        { hunter = nil, name = "Bob", platform = 5 },
        { hunter = "h-x", name = nil, platform = 5 },
    }
    local friends = { { id = "76561198000000001", name = "Ann" }, { id = "76561198000000002", name = "Bob" },
                      { id = "76561198000000009", name = "Me" } }
    t.same(discovery.match(members, friends), {})
    t.same(discovery.match(nil, nil), {})
    t.same(discovery.match(members, { { id = 5, name = "Ann" }, { name = "Bob" } }), {})
end)
