-- Maps Link Party members to side-channel peer IDs (SteamID64 strings).
-- The game exposes no Steam IDs for members (docs/re/game-model.md §4, R5): `OnlineId` is the platform display name.
-- seamless_net lists the player's Steam friends who are in Monster Hunter Wilds right now; a member whose display
-- name matches a friend's persona name becomes a candidate. Identity is then proven by the handshake: the peer's
-- HELLO must carry the member's hunter ID, otherwise it is rejected ("identity").
local M = {}

-- members: party.members(); friends: { {id, name} }. Returns { [peer_id] = { label, expected_hunter } }.
function M.match(members, friends)
    local by_name = {}
    for _, f in ipairs(friends or {}) do
        if type(f.name) == "string" and f.name ~= "" and type(f.id) == "string" then
            local list = by_name[f.name]
            if not list then
                list = {}
                by_name[f.name] = list
            end
            list[#list + 1] = f.id
        end
    end
    local local_platform
    for _, m in ipairs(members or {}) do
        if m.self then local_platform = m.platform end
    end
    local out = {}
    for _, m in ipairs(members or {}) do
        local same_platform = local_platform == nil or m.platform == local_platform
        if not m.self and same_platform and m.name and m.hunter then
            for _, id in ipairs(by_name[m.name] or {}) do
                out[id] = { label = m.name, expected_hunter = m.hunter }
            end
        end
    end
    return out
end

return M
