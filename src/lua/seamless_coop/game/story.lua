-- Story adapter: the local player's story progress point (docs/re/game-model.md §1). Read-only.
local M = {}

-- resolved: build_check report.resolved
function M.new(sdk, resolved)
    local self = {}

    -- Story progress ID (e.g. 250 after "Back to Camp"), or -1 when unknown (title screen, loading, feature off).
    function self.progress()
        local m = resolved["MissionManager.getProgressId"]
        if not m then return -1 end
        local mm = sdk.get_managed_singleton("app.MissionManager")
        if not mm then return -1 end
        local ok, v = pcall(m.call, m, mm)
        if ok then return math.tointeger(v) or -1 end
        return -1
    end

    function self.party_sync_progress()
        local m = resolved["MissionManager.getPartySyncProgressId"]
        if not m then return -1 end
        local mm = sdk.get_managed_singleton("app.MissionManager")
        if not mm then return -1 end
        local ok, v = pcall(m.call, m, mm)
        if ok then return math.tointeger(v) or -1 end
        return -1
    end

    return self
end

return M
