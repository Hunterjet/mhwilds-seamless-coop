# Run 1 — probe trace analysis (probe character, Chapter 1)

> **Data:** probe v0.1.1 (358 hooks) on the developer's probe character, 2026-10-21, ~62 min: new game → Chatacabra
> (`MISSION_001030`) → Quematrice (`001050`) → Lala Barina hunt (`001080`, mission not finished). Raw trace kept locally
> (`.research-cache/traces/run1/`, gitignored). Reproduce: `python tools/dev/trace_spans.py <trace> --mission-names <Enums_Internal.hpp>`
> and `python tools/dev/trace_summary.py <trace>`.
> **Data quality:** F8 marks were used loosely and are not relied on. Boolean arguments shown as `<err>` in v0.1.1
> line up with `false` values (fixed/diagnosed in v0.1.3). The v0.1.2 dialogue hooks were not active in this run.

## 1. Mission timeline

| Main mission | Active (s) | Cleared (s) | Length | Hunting quest | Notes |
|---|---|---|---|---|---|
| `001010` | 33 | 50 | — | — | opening; cleared after cutscene `evc0001` |
| `001030` | 50 | 794 | 12.4 min | **Chatacabra** (objective 5) | prologue hunt; 8 in-engine events (`egm…`) and cutscenes |
| `001040` | 802 | 911 | 1.8 min | — | at its end the game **auto-joins a public lobby** (`autoMatching(LOBBY)`) = multiplayer unlock |
| `001042` | 911 | 935 | 0.4 min | — | short step (the pair characters stop before it: progress 250) |
| `001045` | 935 | 1392 | 7.6 min | — | walk-and-talk with many "stay close" events, cutscene `evc0100` |
| `001047` | 1392 | 1413 | 0.3 min | — | dialogue choice (dialogue 715) |
| `001050` | 1413 | 1868 | 7.6 min | **Quematrice** (objective 3) | |
| `001060` | 1868 | 1883 | 0.3 min | — | dialogue choice (dialogue 89) |
| `001070` | 1883 | 2157 | 4.6 min | — | walk-and-talk with stay-close *warnings*, cutscenes `evc0008/0009` |
| `001075` | 2169 | 2276 | 1.8 min | — | **Environment Link introduced** (party sync enabled per stage, see §4) |
| `001080` | 2276 | — | — | **Lala Barina** (objective 6) | dialogue choice (501); hunt done, mission still running when the run ended |

## 2. Answer: are main missions decoupled from hunting quests?

**No. There is a hard mapping, but the hunt is only one objective inside a longer mission.**

- Every main mission is a chain of objectives (`MissionController.setObjectiveState`, `setClearObjective`). The catalogue
  (`MissionData`) gives each mission a **quest objective range** `[_QuestStartObjectiveID.._QuestEndObjectiveID]`. Of the
  72 loaded main missions, **32 contain a hunt**, e.g. `001030 [5..5]`, `001050 [3..3]`, `001080 [6..6]`.
- The trace matches exactly. The hunt is accepted from inside the active mission (`acceptQuest` → `goQuest` →
  `MissionController.setQuestAccepted`, with `updateMissionManageIDToActiveMission(<same mission>)`). It ends with
  `MissionController.clearQuestObjective(5 | 3 | 6)`. **The mission then keeps running** (return to camp, talks)
  until `setMissionClear()`, sometimes followed by short dialogue-only missions. That is the "assignment continues almost
  into the next hunt" behaviour you saw.
- **Multiplayer only exists for the hunt objective.** Everything before and after it is ordinary single-player mission
  content running locally. So the mod cannot be "let people into the quest early": before the gate there is no
  quest to join. The mod has to keep players together **in the field** (Environment Link / party sync) while each
  player's mission runs in step, then use the vanilla quest session at the hunt. This confirms hypothesis **H2**
  (implementation plan §9).

## 3. The multiplayer gate (exact)

| Hunt | Pre-hunt cutscene ends | Quest accepted (gate) | Quest session created | Engage monster | Hunt objective cleared |
|---|---|---|---|---|---|
| Chatacabra (`001030`, before MP unlock) | `evc0004` ends 379 s | 582 s | **no** (offline, MP not unlocked) | 391 s (scripted chase first) | 766 s |
| Quematrice (`001050`) | `evc0006` ends **1586.7 s** | **1586.8 s** | yes, ack after ~1.9 s | 1600 s | 1815 s |
| Lala Barina (`001080`) | `evc0011` ends **2854.7 s** | **2854.8 s** | yes, ack after ~1.4 s | 2872 s | 3073 s |

At the gate, the same frame shows: `cQuestDirector.acceptQuest` → `goQuest`, **`qMaxJoin` 1 → 4**,
`goQuestSeamless = true`, `NetworkRequestManager.createSession(QUEST, cCreateQuestSessionInfo)`,
`NetworkRequestManager.inviteLinkPartyQuest` (Link Party invite), then `createSessionCallback(true, 200)` →
`updateSession` → `membersQuest = 1`, `keepDrawOthers = true`. At the hunt's end: `clearQuestObjective` →
`Net_Party.resetQuestInviteState` → `Net_Party.onLeaveLinkPartySync` → `MissionManager.resetNetStoryPackageFlag` →
`qMaxJoin` back to 1. **In story missions, the hunting quest starts the moment the monster-reveal cutscene ends.**
Story progress IDs advance at the gate too (e.g. 250 → 300 when the Quematrice quest was accepted).

## 4. Environment Link (party sync)

- **Progress gate:** `MissionManager.PartySyncProgressDatas` starts at party-sync progress **6 = mission `001070`
  cleared** (then 8 = `001080` quest started, 10 = `001080` cleared, … up to 140, then HR 9/16/21/31/41 steps).
  Before that the value is 0. **Mission `001075` introduces Environment Link.** When it became active, the game called
  `setPartySyncInfo(001075, stage, true)` for stages 0–4 and 9–11, and party-sync progress went 0 → 6.
- **Per-mission, per-stage switch:** `setPartySyncInfo(mission, stage, on)` / `getCanPartySyncInfoInCurrentStage()` decide
  where sync is allowed during a mission (`canPartySyncHere` flipped while moving between areas).
- **Drawing other players:** `keepDrawOthers` is true during hunts and in some missions (`001060`, `001075`), false otherwise.
- **Consequence for testing:** the agreed pair point (progress 250, party-sync progress 0) is **before** Environment Link
  exists. Session S0 must first check whether Environment Link works there. If not, both players continue to mission
  `001075` (≈25 min solo) before testing story behaviour while linked.

## 5. Cutscenes vs. dialogue scenes (your question)

They are **different systems in the backend**:

| What you see | Backend | Evidence |
|---|---|---|
| Full cinematics (skippable) | `app.DemoMediator` timeline events: `evc####` story cutscenes, `egm####` in-engine scripted events, `evc2xxx` short system scenes | 19 events in this run: `onPlayStartTimeline(id)` / `onPlayEndTimeline(id)`. Skip = `requestSkip` → `execSkip` (→ `notifyCutSkipEnd`). 9 skipped, 10 watched (longest `evc0011`, 178 s) |
| Dialogue scenes (forwardable, choices) | `app.DialogueManager` dialogues, typed by `app.DialogueType.TYPE`: **DEFAULT** (normal NPC talk), **KEY** (story dialogue scenes), **FORCE_READ** (cannot skip), **GOSSIP** (ambient chatter), **NAGARA** (lines spoken while you move: walk-and-talk) | choices recorded via `cStoryFsmController.setDialogueSelectedIndex(dialogueId, mission, …, index)` (5 in this run). The story FSM stores them as per-mission dynamic flags |

So a "dialogue cutscene" is a **KEY** dialogue (story-driven, camera-framed), while talking to an NPC on your own is
**DEFAULT**. Probe v0.1.2+ snapshots the current dialogue type, so the next run can label every scene. Design
consequence: cinematics can reuse `DemoMediator`'s existing network end/skip packets; **dialogue scenes need their own
sync** (the leader advances lines and picks options; followers mirror them).

## 6. Walk-and-talk modes (your question)

The three modes you noticed map to separate mechanisms in `app.cStoryFsmController` / `app.cMissionHaltController`:

| Mode | Mechanism (seen in trace) |
|---|---|
| Move freely but stay near the group | `cMissionHaltController` "stay close" leash: `haltDialogueAttention` (≈40 times in `001045`/`001070`/`001080`), `haltDialogueWarning` (3× in `001070`), `haltEvent` (2×). Distance levels `CURRENT_DISTANCE_TYPE { ATTENTION, WARNING, DANGER, ERROR }` |
| Small restricted area | zone halts (`HALT_TYPE { PL_ZONE, PORTER_ZONE, ZONE, … }`, `MissionController.setStoryHaltEnable` ×189) |
| Movement fully locked / Seikret runs by itself | player restriction bits (`_PlControls`, `PLAYER_CONTINUE_TYPE`, e.g. `DISABLE_MOVE_ACTION`, `PORTER_CALL_TYPE_FORCE_DIRECT`) plus Seikret control (`addPorterContinueAction` ×200: speed masks, forced top speed, `DISABLE_MOVE_ALL`) following NPC **route controllers** (`addStoryRouteController`) |

**Multiplayer implications.** Modes 1–2 should work if each player's mission runs locally in step. Followers may need a
relaxed leash, centred on the leader rather than the NPC. **Mode 3 ("stacking"):** each player's Seikret follows the
same NPC route on its own machine, so followers would overlap the leader on screen. Options: formation offsets per party
slot on the route target (MHW Seamless Co-op flies its party in formation), or free riding within a leash for
followers. To be decided after seeing it in a two-player session. Probe v0.1.3 snapshots the restriction bits
(`plControls`) to label each segment.

## 7. Sessions and network traffic

- Multiplayer unlock = end of `001040`: `autoMatching(LOBBY)` → lobby joined (14 members).
- Quest sessions: created at each gate, left with `leaveSession(QUEST)` at mission transitions.
- Lobby packet census (session type 1): `cSysLobbyUserSyncStatus` (most frequent), `cSysFieldIdSync` (field instance
  IDs), `cSysAcceptQuestTypeSync`, `cSysLobbyUserInfoSync/Init`, `cSysHunterRankSync`, `cSysEquipInfoSync`,
  `cSysDisableQuestInfo`, **`cSysProgressNumSync`** (members' story progress), `cSysLoginStatusSync`,
  `cSysLinkSessionStatusSync`, `cSysPartyUpdateStatus`, `cChatStamp`. Quest session (type 2): `cSysDisableQuestInfo`,
  `cSysHunterRankSync`.

## 8. What this changes

1. **F1 (seamless story join)** becomes "seamless story *together*": keep verified modded party members in party
   sync (Environment Link) through story missions, by enabling `setPartySyncInfo` for the active mission's stages and
   suppressing the `LEAVE_StoryEvent` disconnect. At the gate, auto-accept the leader's vanilla quest invite.
2. **The quest gate needs no bypass**: vanilla already creates the session and sends Link Party invites at the right
   moment. The mod only needs to accept automatically and keep players together before and after it.
3. **Lockstep story** (F2): the leader's objective/FSM progress, dialogue progress and choices, NPC routes and
   cutscene starts are the things to mirror.
4. **Testing:** S0 needs the pair point at or after `001075` unless Environment Link already works at progress 250.

## 9. Open items for the next runs

- Run with probe ≥ v0.1.2: dialogue types per scene, line advance/skip, choice timing.
- Run with probe ≥ v0.1.3: `plControls` per walk-and-talk segment; argument errors resolved.
- Two-player S0/S1: what happens to party sync when the leader starts a story mission (`LEAVE_StoryEvent`), whether the
  follower's mission can run in step, and server responses.
