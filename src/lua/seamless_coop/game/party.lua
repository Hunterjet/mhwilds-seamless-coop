-- Party adapter: the Link Party member list (Net_UserInfoManager, session type LINK). Read-only.
-- Member names (the platform display name, `OnlineId`) stay in memory for matching and the panel; they are never
-- logged or sent (spec N5).
local sdk_env = require("seamless_coop.game.sdk_env")

local M = {}

local function call(resolved, id, obj, ...)
    local m = resolved[id]
    if not m or obj == nil then return nil end
    local ok, v = pcall(m.call, m, obj, ...)
    if ok then return v end
    return nil
end

function M.new(sdk, resolved)
    local self = {}

    -- Returns a list of { self, hunter, name, platform, index, progress, sync }, or nil if unavailable.
    function self.members()
        local nm = sdk.get_managed_singleton("app.NetworkManager")
        if not nm then return nil end
        local uim = call(resolved, "NetworkManager.get_UserInfoManager", nm)
        local link = resolved["SESSION_TYPE.LINK"]
        if not uim or link == nil then return nil end
        local list = call(resolved, "Net_UserInfoManager.getUserInfoList", uim, link)
        local field = resolved["Net_UserInfoList._ListInfo"]
        if not list or not field then return nil end
        local okf, arr = pcall(field.get_data, field, list)
        if not okf then return nil end
        local out = {}
        for _, ui in ipairs(sdk_env.array_items(arr)) do
            if call(resolved, "Net_UserInfo.get_IsValid", ui) then
                out[#out + 1] = {
                    self = call(resolved, "Net_UserInfo.get_IsSelf", ui) == true,
                    hunter = sdk_env.guid_to_string(call(resolved, "Net_UserInfo.get_HunterId", ui)),
                    name = call(resolved, "Net_UserInfo.get_OnlineId", ui),
                    platform = math.tointeger(call(resolved, "Net_UserInfo.get_PlatformId", ui)),
                    index = math.tointeger(call(resolved, "Net_UserInfo.get_MemberIndex", ui)),
                    progress = math.tointeger(call(resolved, "Net_UserInfo.get_MemberListProgressId", ui)),
                    sync = call(resolved, "Net_UserInfo.get_IsPartySync", ui) == true,
                }
            end
        end
        return out
    end

    return self
end

-- Stable key for change detection (hunter IDs of valid members, sorted).
function M.signature(members)
    local keys = {}
    for _, m in ipairs(members or {}) do keys[#keys + 1] = (m.hunter or "?") .. (m.self and "*" or "") end
    table.sort(keys)
    return table.concat(keys, ",")
end

return M
