# Game model — RE spike notes (v0.2)

> **Build:** MH Wilds Steam build 24705561 · REFramework nightly-01433 (`d4611ae`) · captured 2026-10-21.
> **Method:** read-only queries against the live type database via re-engine-mcp (`tools/dev/re-typemap.ps1`, MCP
> `get_type`/`chain`/getters) + the REFramework enum dump + probe traces (`re/probes/`, analysed in
> [run1-analysis.md](run1-analysis.md)). Full schemas are saved locally in `.research-cache/typemap/`
> (gitignored, game-derived).
> **Legend:** ✅ verified on the live game · 🔶 hypothesis (to confirm with probe traces / two-player sessions).
> Answers the implementation plan's research questions R1–R8 incrementally.
>
> **v0.2 (run 1):** H2 confirmed. Hunts are objective ranges inside main missions. The quest session is created when
> the hunt is accepted, right as the monster-reveal cutscene ends. Environment Link is enabled per mission/stage and
> introduced by mission `001075`. Dialogue scenes and cinematics are separate systems. Details in [run1-analysis.md](run1-analysis.md).

## 1. Story progress — R4 (✅ answered)

| Item | Detail |
|---|---|
| Current progress | ✅ `app.MissionManager.getProgressId()` → `Int16`. |
| Progress table | ✅ `MissionManager.progressDatas` : `Tuple<Int16 progressId, MissionIDList.ID started, MissionIDList.ID cleared, Int32 HR>[]`, 66 rows from 100 to 6700. Examples: `(100, 2, -1, -1)` mission 2 started · `(150, -1, 2, 1)` mission 2 cleared at HR 1 · `(250, -1, 3, 1)` · `(300, 7, -1, -1)` … `(6200…6700, -1, -1, HR 50…100)` = post-story HR gates. |
| Next main mission | ✅ static `app.MissionUtil.getExpectLoadMainMissionId()` → `app.MissionIDList.ID`. |
| Mission IDs | ✅ `app.MissionIDList.ID` (764 values) named `MISSION_00CNNN` (C = chapter), e.g. 0 = `MISSION_001010`, 2 = `MISSION_001030`, 3 = `MISSION_001040`, 4 = `MISSION_001042`, 7 = `MISSION_001050`, 18 = `MISSION_002140`. |
| Other progress views | ✅ `getPartySyncProgressId()`, `getMemberListProgressId()`, `getMissionManageIdFromProgress(Int16)`, `getChapterIdFromStoryProgress(…)`, fields `LobbyMemberProgressDatas : Tuple<Int16, MissionManageID.ID>[]`, `PartySyncProgressDatas : Tuple<Int16, MissionID, MissionID, Int32>[]`. |
| Title lookup | ⚠️ `getMissionTitleFromStoryProgress(Int16)` → `Guid`, but its numbering does not match `progressDatas` (150 → "A Desolate Destination", 250 → "Full Circle", 300 → "A Visitor from the West"). **Do not use until understood.** |
| Story flags | ✅ `MissionManager._LocalStoryPackageFlagList` / `_NetStoryPackageFlagList` (`Boolean[]`), `checkLocalStoryPackageFlag` / `checkNetStoryPackageFlag(StoryPackageFlag.TYPE_Fixed, Int32)`, `setNetStoryPackageFlagList(Byte[])`, `getByteNetStoryPackageFlag()`, `get_IsPackHost()` / `setPackHost(Boolean)`. 🔶 With a party in sync, the world follows the **"pack host's"** story flags ("Net" list); each player keeps their own "Local" list. |

**Test character (pair, PC-A) on 2026-10-21:** `getProgressId` = **250** (`MISSION_001040` cleared, HR 1),
`getExpectLoadMainMissionId` = **`MISSION_001042`** (ID 4), memberListProgressId 30, partySyncProgressId 0.
The remote tester's pair character must reach the same values. **Story-point policy for the mod** (spec F1.2):
compare `getProgressId()` (and the next main mission) between members.

## 2. Mission structure (✅ fields; 🔶 meaning)

`app.user_data.MissionData` (one per mission, catalog `MissionManager._Catalog.get_MissionListData()._DataList`):
`_MissionIDSerial`, `_MissionTypeSerial` (`MAINSTORY`…), `_QuestData : app.user_data.QuestData`,
**`_QuestStartObjectiveID` / `_QuestEndObjectiveID`**, `_ClearMissionIDList`, `_OpenFlagMissionList`, `_StoryFlagIDList`,
`_QuestEnvironmentData`, `get_ClearMissionObjectiveList()`.

🔶 → ✅ **A story mission is a chain of objectives. Its hunt ("quest") portion is the objective range
`[_QuestStartObjectiveID.._QuestEndObjectiveID]`** (32 of 72 loaded main missions have one, e.g. `001030 [5..5]`,
`001050 [3..3]`, `001080 [6..6]`, confirmed by `clearQuestObjective(5|3|6)` in run 1).
At the hunt's start the game accepts the quest and creates a quest session without a loading screen ("seamless"):
`cQuestDirector.acceptQuest` → `goQuest`, `qMaxJoin` 1 → 4, `NetworkRequestManager.createSession(QUEST, …)`,
`inviteLinkPartyQuest`. Related members: `MissionManager.reqSeamlessQuestSessionExecuteEvent(MissionIDList.ID)`,
`_SeamlessQuestSessionExecuteEvent`, `get_IsGoQuestSeamless()`, `get_IsWaitingSeamlessQuestSession()`;
`cQuestDirector.IsGoSeamless()`, `IsWaitingSeamlessQuestSession()`. ✅ **This is the vanilla multiplayer gate**: no quest
session exists for others to join until the hunt is accepted, **in the same frame the monster-reveal cutscene ends**.
The mission continues after the hunt objective (hypothesis **H2** confirmed).
`QuestData` also has `_EnableGuestNpc` and `_PartnerNpc` (story partner NPC).

✅ **Assignments** (what the UI calls a story assignment, e.g. "Chapter 1-2 · Village of Whispering Winds") are
`MissionManageID`s that group one or more missions: `MissionManager._MissionSetting._MissionActivityData
._MissionManageDataList[]` (`ManagingMissionData`: `_ParentChapterId`/`_ChildChapterId`, title `_MissionTextID` (Guid →
localised text), `_SettingMissionDataList[].getMissionID()`, `_IsSideMission`, `_ActivityId`). Chapter 1 map:
[remote-testing.md](../testing/remote-testing.md#session-plan). Titles are for humans only; the mod keys on mission IDs.

## 3. Environment Link = Link Party "sync" — R6 (✅ API; 🔶 behaviour)

| Area | Members (`app.Net_Party` unless noted) |
|---|---|
| Join/leave sync | `inviteLinkPartySync(Guid, FieldDef.STAGE)`, `joinPartySync(Guid, Action<bool, STAGE, NETWORK_ERROR_CODE>, bool)`, `leaveLinkPartySync(bool, PARTY_SYNC_OPTION)` (also on `app.NetworkRequestManager`), `onLeaveLinkPartySync()`, `sendPartySyncFlag(bool)` |
| State | `isLinkPartySync(bool)`, `isPartySyncMember(int \| Guid)`, `get_IsJoiningSync()`, `get_IsBreakPartySync()`, fields `_IsLeaveStoryEvent`, `_IsNoHostPartySync`, `_IsLeaveToJoinSync` |
| Eligibility | `isEnableJoinAcceptPartySync(Guid)` → `NETWORK_ERROR_CODE` (🔶 the "less story progress" check) |
| Field instance | `joinExFieldId(STAGE)`, `returnMyExFieldId(STAGE)` (🔶 shared field instance per stage) |
| Story coupling | `PARTY_SYNC_OPTION { NONE, LEAVE_StoryEvent, LEAVE_To_Join_Sync }`; `MissionManager.setPartySyncInfo(MissionID, STAGE, bool)`, `getPartySyncInfo(STAGE)`, `getCanPartySyncInfoInCurrentStage()`, `setupPartySyncInfo()`, `_MissionIdForPartySyncSet` |
| Quest invites | `checkAndAcceptSyncQuest(bool, cActiveQuestData)`, `addQuestInviteNotify(Net_UserInfo, MissionID)`, `recvInvitePartyQuest(…, net_packet.cSysQuestInvite)`, `genQuestInvitePacket()`, `Convert2InviteQuestInfo(cSysQuestInvite, Net_UserInfo)` → `SessionManager.cSearchResultQuest`, `NetworkRequestManager.inviteLinkPartyQuest / acceptInviteLinkPartyQuest(Guid, …)` |
| Drawing others | `MissionManager.IsDrawReplicaPlFromProgress(Int16)`, `isProgressDrawOffSelfFromOthers(Int16)`, `_KeepDrawOtherPlayerFlag`; `cStoryFsmController._EnableSetDrawOffOtherPlayer`; enum `StoryFsmDef.PLAYER_CONTINUE_TYPE.DRAWOFF_REPLICA_PLAYER` |

🔶 **Vanilla behaviour model:** Link Party members can share a field instance ("sync" / Environment Link) if their story
progress allows it. **Starting a story event makes players leave sync** (`LEAVE_StoryEvent`), and story segments can
hide other players by progress. Once the mission reaches its quest portion, a seamless quest session starts, and Link
Party members get a quest invite they can accept. That is exactly the vanilla flow players describe.

✅ **Run 1 additions:** party-sync progress (`PartySyncProgressDatas`: `(id, missionStarted, missionCleared, HR)`) is 0
until mission `001070` is cleared (→ 6). Then 8 = `001080` hunt accepted, 10 = `001080` cleared … 140, then HR
9/16/21/31/41 steps. Mission **`001075` introduces Environment Link**: on activation it calls
`setPartySyncInfo(001075, stage, true)` for stages 0–4 and 9–11. At each hunt's end the game calls
`Net_Party.onLeaveLinkPartySync()` and `MissionManager.resetNetStoryPackageFlag()`.

## 4. Sessions and joining (✅ API)

- `app.NetworkRequestManager`: `createSession(SESSION_TYPE, cCreateSessionInfo, cb)`, `searchSession(SESSION_TYPE, cSearchSessionInfo, cb)`,
  `joinSession(SESSION_TYPE, cJoinSessionInfo | UInt32, cb)`, `leaveSession(SESSION_TYPE, cb, bool)`,
  `updateSession(net_quest_session.cUpdateQuestSessionInfo, cb)`, `reserveCreateRescue(cb)` (SOS), `autoMatching(…)`, plus the
  callbacks `createSessionCallback` / `searchSessionCallback` / `joinSessionCallback(bool, int, byte[])`.
- `app.MissionManager`: `evNetJoinMember(SESSION_TYPE, Int32, Boolean, Guid)`, late join `createLateJoinSyncPacket` /
  `applyLateJoinSyncPacket(net_packet.cQuestLateJoinSync)`, `createMissionLateJoinSyncPacket` /
  `applyMissionLateJoinSyncPacket(net_packet.cMissionLoadBeforeSync)`, a packet dispatch table
  `_Dic : Dictionary<int, Action<cPacketArg>>`, `_IsReceiveLoadBeforeSyncPacket`, `IsQuestJoinFailedLoading`.
- Session types: `app.net_session_manager.SESSION_TYPE { NONE, LOBBY, QUEST, LINK, MEMORIES, LOCAL }`.

### 4.1 Member identity — R5 (✅ answered, 2026-10-21)

- Members per session: `NetworkManager.get_UserInfoManager()` → `Net_UserInfoManager.getUserInfoList(SESSION_TYPE)` →
  `Net_UserInfoList._ListInfo : Net_UserInfo[]` (also fields `_mlInfo` lobby, `_mlkInfo` link, `_mqInfo` quest,
  `_mmInfo` memories). Per member (`Net_UserInfo`): `get_IsValid`, `get_IsSelf`, `get_HunterId : Guid`, `get_UserId : Guid`,
  `get_ShortHunterId`, `get_PlName` (hunter name), `get_OnlineId : String`, `get_PlatformId : Byte` (the local Steam
  player had 5; crossplay console players 2), `get_MemberIndex`, `get_MemberListProgressId`, `get_IsPartyMember`,
  `get_IsPartySync`, `get_UniqueId : via.network.utility.UniqueId`.
- **No Steam ID is exposed.** `OnlineId` is the platform display name (4–13 characters, never numeric).
  `UniqueId` is an opaque native object: `get_Hash()` is a 64-bit hash (18–19 digits, not a SteamID64) and
  `get_ServiceType()` 2 or 4. `NetworkManager.SelfNetworkUniqueIdString()` was empty while offline. Values were only
  inspected as shapes (length/pattern), never recorded.
- **Decision (side channel):** seamless_net lists the player's Steam friends who are in the game (`ISteamFriends`,
  AppID 2246340) and matches their persona name to the member's `OnlineId`. If exactly one member and one friend are
  left over, they're paired as well. The HELLO handshake then proves identity: the peer must present the member's
  hunter ID. Consequence: **the side channel needs Link Party members to be Steam friends** (v1). Verified in game:
  the Steam path works end to end (the selftest's self-loop reached "compatible", RTT ≈ 420 ms).

## 5. Quest director (✅ API)

`app.cQuestDirector` (via `MissionManager.get_QuestDirector()`): `acceptQuest(cActiveQuestData, cQuestAcceptArg, bool, bool)`,
`goQuest(bool, bool, bool, bool)`, `get_GoQuestMissionID()`, **`get_MaxJoinNum()` / `updateMaxJoinNum(UInt32)`**,
`setQuestSyncParam(UInt32, MULTIPLAY_SETTING, bool, bool)`, `notifyInviteJoinReady()` / `notifyInviteJoinFailed()`,
`notifyHostChangeQuestSession(int)`, `notifyLeaveMemberQuestSession(int)`, quest-start cutscene
`getActiveQuestStartDemoId()`, `isQuestStartDemoEnable()`, `requestQuestStartDemoLoad()`.
🔶 `MaxJoinNum` may be how a story quest is held to one player before its gate.

## 6. Cutscenes — R7 (✅ API)

`app.DemoMediator` (singleton): `requestPlay` / `requestLoad` / `requestStop(ace.DemoMediatorBase.cParamBase)`, `requestSkip()`,
`execSkip()`, `updateSkipRequest()`, `get_WaitSkipRequest()`, `isExistEventSkip()`, `get_CurrentTimelineEventID()`,
`checkEventPlaying(TimelineEventDefine.ID, bool)`, `onPlayStart` / `onPlayEnd(cParamBase)`,
`onPlayStartTimeline(Int32)` / `onPlayEndTimeline(Int32)`, `notifyCutSkipEnd()`, **`isMulchEventPlaying(bool)`** ("multi"
event) and **`receiveNetPacket_End` / `receiveNetPacket_Skip(SESSION_TYPE, Int32, Object)`**.
✅ **The engine already synchronises cutscene end and skip over the network** (used for multiplayer quest-start cutscenes).
🔶 Shared story cutscenes (spec F3) can likely reuse this path instead of a custom barrier for the skip/end part.
Also `app.CutSceneGalleryManager` (replay pipeline, `STATE` enum) as a fallback for followers.

✅ **Run 1:** 19 timeline events: `evc####` story cutscenes, `egm####` in-engine scripted events, `evc2xxx` short system
scenes. Lifecycle `requestLoad` → `requestPlay` → `startStartFsm` → `onPlayStart` / `onPlayStartTimeline(id)` → … →
`onPlayEndTimeline(id)` → `endEndFsm` → `unload`. The skip path is `requestSkip` → `execSkip` (→ `notifyCutSkipEnd`).

**Dialogue scenes are a different system**: `app.DialogueManager` (`requestDialogue`, `startDialogue`, `finishDialogue`,
`requestSkipMainDialogue`/`skipMainDialogue`, state `get_IsTalking`, `get_CurrentDialogueType`,
`get_IsMainDialogueTimelineOngoing`), `app.cDialogueTalkPlayer`, `app.cDialogueSkipManager.requestSkip`, and choices via
`app.cDialogueNodeControllerChoice.callback_ChoiceEnd(Int32)`. The story FSM records them with
`cStoryFsmController.setDialogueSelectedIndex(DialogueID, MissionID, DynamicFlag, Int32, …)`.
`app.DialogueType.TYPE { NONE, DEFAULT, FORCE_READ, KEY, GOSSIP, NAGARA }`: KEY = story dialogue scenes,
DEFAULT = ordinary NPC talk, NAGARA = walk-and-talk lines, GOSSIP = ambient chatter.

## 7. Story FSM (✅ API, partial)

`app.cStoryFsmController` (156 fields, 256 methods): `_EnableSetDrawOffOtherPlayer`, `_IsProhibitionStartQuest` /
`ProhibitedStartQuest`, `getHasMainMissionStartTriggerNpcId(MissionIDList.ID)` → NPC that starts a main mission,
`addPlContinueAction(PLAYER_CONTINUE_TYPE[])`, `reqSendNextStoryRoutePoint(cMsgCutSceneStandbyPos)`.
✅ Reach the active one with `MissionManager.getEnableMissionController(MissionIDList.ID)` → `MissionController.StoryFsmCtrl`.
Active player restrictions: `_PlControls : ace.BIT_FLAG64` (`._Value` UInt64, bits = `PLAYER_CONTINUE_TYPE`).
Seikret control: `_PorterControls`, `_PoterAutoChangeParams`; NPC/route control: `_RouteControlList`,
`addStoryRouteController`. Stay-close leash: `cMissionHaltController.haltDialogueAttention / haltDialogueWarning /
haltEvent / haltCancel`. Walk-and-talk analysis: [run1-analysis.md §6](run1-analysis.md).

## 8. Updated hypotheses and approach

1. **H2 is strongly supported** (field first, quest session at the gate). Joinability is controlled by (a) leaving party
   sync on story events and (b) the quest session existing only from `_QuestStartObjectiveID`.
2. Candidate F1/F2 approach for verified modded members at the same `getProgressId()`: **keep party sync alive through
   the story event** (suppress the `LEAVE_StoryEvent` path), keep remote players drawn, and let each player's own story
   FSM run in lockstep with the leader's (side-channel keyframes). At the gate, use vanilla quest invites
   (`checkAndAcceptSyncQuest` / `acceptInviteLinkPartyQuest`) to bring everyone into the leader's seamless quest session.
3. F3 can build on `DemoMediator`'s existing network end/skip packets.
4. Unknowns for the probes and sessions: Are story NPCs and mission objects shared or per-player while in sync? What
   server checks run on `joinPartySync` and on quest join (R3/R8)? How do the story flags of a synced party combine
   (`PackHost`)?

## 9. Next steps

- **Probe scripts** (`re/probes/`): read-only REFramework Lua hooks on the methods above, writing JSONL traces to
  `reframework/data/seamless_coop/traces/`, plus a "mark" button. Played on the developer's **probe** character from
  the start (R1), and on paired characters in session S0 (R6).
- Map `app.cMissionHaltController`, `app.MissionController` / objectives, `app.NpcManager` / `cNpcNetworkMasterManager`,
  `app.Net_UserInfoManager` (member identity, Steam IDs, for R5).
