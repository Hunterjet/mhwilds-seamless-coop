-- Every game type, method, field and enum value the mod uses, tagged by feature (implementation plan D6).
-- build_check resolves all entries at startup; a feature with an unresolved entry is disabled ("fail closed").
-- If a `core` entry fails, the whole mod stays off and installs no hooks (spec F5.1).
local M = {}

-- needs_verified_build: the feature changes game behaviour, so it only runs on a game build listed in
-- core/version.lua. Read-only features also run on unverified builds (with a warning).
M.features = {
    core = { label = "Core", required = true },
    story = { label = "Story point" },
    party = { label = "Link Party members" },
}

M.entries = {
    -- core
    { id = "MissionManager", kind = "type", type = "app.MissionManager", feature = "core" },
    { id = "NetworkManager", kind = "type", type = "app.NetworkManager", feature = "core" },

    -- story: the player's story progress point (docs/re/game-model.md §1)
    { id = "MissionManager.getProgressId", kind = "method", type = "app.MissionManager", sig = "getProgressId()",
      feature = "story" },
    { id = "MissionManager.getPartySyncProgressId", kind = "method", type = "app.MissionManager",
      sig = "getPartySyncProgressId()", feature = "story" },

    -- party: Link Party member list (Net_UserInfoManager lists per session type; R5 notes in game-model.md)
    { id = "NetworkManager.get_UserInfoManager", kind = "method", type = "app.NetworkManager",
      sig = "get_UserInfoManager()", feature = "party" },
    { id = "Net_UserInfoManager.getUserInfoList", kind = "method", type = "app.Net_UserInfoManager",
      sig = "getUserInfoList(app.net_session_manager.SESSION_TYPE)", feature = "party" },
    { id = "SESSION_TYPE.LINK", kind = "enum", type = "app.net_session_manager.SESSION_TYPE", name = "LINK",
      feature = "party" },
    { id = "Net_UserInfoList._ListInfo", kind = "field", type = "app.Net_UserInfoList", name = "_ListInfo",
      feature = "party" },
    { id = "Net_UserInfo.get_IsValid", kind = "method", type = "app.Net_UserInfo", sig = "get_IsValid()", feature = "party" },
    { id = "Net_UserInfo.get_IsSelf", kind = "method", type = "app.Net_UserInfo", sig = "get_IsSelf()", feature = "party" },
    { id = "Net_UserInfo.get_HunterId", kind = "method", type = "app.Net_UserInfo", sig = "get_HunterId()", feature = "party" },
    { id = "Net_UserInfo.get_OnlineId", kind = "method", type = "app.Net_UserInfo", sig = "get_OnlineId()", feature = "party" },
    { id = "Net_UserInfo.get_PlatformId", kind = "method", type = "app.Net_UserInfo", sig = "get_PlatformId()",
      feature = "party" },
    { id = "Net_UserInfo.get_MemberIndex", kind = "method", type = "app.Net_UserInfo", sig = "get_MemberIndex()",
      feature = "party" },
    { id = "Net_UserInfo.get_MemberListProgressId", kind = "method", type = "app.Net_UserInfo",
      sig = "get_MemberListProgressId()", feature = "party" },
    { id = "Net_UserInfo.get_IsPartySync", kind = "method", type = "app.Net_UserInfo", sig = "get_IsPartySync()",
      feature = "party" },
}

return M
