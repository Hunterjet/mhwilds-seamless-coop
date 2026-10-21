-- Maps Link Party members to side-channel peer IDs (SteamID64 strings).
-- The game exposes no Steam IDs for members (docs/re/game-model.md §4, R5): `OnlineId` is the platform display name.
-- seamless_net lists the player's Steam friends who are in Monster Hunter Wilds right now; a member whose display
-- name matches a friend's persona name becomes a candidate. If exactly one member and one friend are left unmatched
-- (the usual two-player case), they are paired as well. Either way identity is proven by the handshake: the peer's
-- HELLO must carry the member's hunter ID, otherwise it is rejected ("identity").
local M = {}

local function valid_friend(f)
    return type(f) == "table" and type(f.id) == "string" and type(f.name) == "string"
end

-- members: party.members(); friends: { {id, name} }.
-- Returns { [peer_id] = { label, expected_hunter, guessed? } }, { by_name = n, guessed = n }.
function M.match(members, friends)
    local by_name = {}
    for _, f in ipairs(friends or {}) do
        if valid_friend(f) and f.name ~= "" then
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

    local out, info = {}, { by_name = 0, guessed = 0 }
    local used_friend, unmatched = {}, {}
    for _, m in ipairs(members or {}) do
        local same_platform = local_platform == nil or m.platform == local_platform
        if not m.self and same_platform and m.hunter then
            local ids = m.name and by_name[m.name] or nil
            if ids then
                for _, id in ipairs(ids) do
                    out[id] = { label = m.name, expected_hunter = m.hunter }
                    used_friend[id] = true
                end
                info.by_name = info.by_name + 1
            else
                unmatched[#unmatched + 1] = m
            end
        end
    end

    local spare = {}
    for _, f in ipairs(friends or {}) do
        if valid_friend(f) and not used_friend[f.id] then spare[#spare + 1] = f end
    end
    if #unmatched == 1 and #spare == 1 then
        out[spare[1].id] = { label = unmatched[1].name or "?", expected_hunter = unmatched[1].hunter, guessed = true }
        info.guessed = 1
    end
    return out, info
end

return M
