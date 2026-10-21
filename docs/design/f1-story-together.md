# F1 "story together": design (v1)

> Status: **decisions D1–D3 taken by the project owner on 2026-10-21**, plus hard requirement **P1**. Builds on
> [run1-analysis.md](../re/run1-analysis.md) (H2 confirmed) and [game-model.md](../re/game-model.md). Nothing here is
> implemented yet. Phase 3 starts after the two-PC sessions S0/S0b.

## 1. What vanilla does (run 1)

- A main mission is a chain of objectives that runs **locally on each player's PC**. The hunt is one objective range in
  it. Multiplayer exists only for that hunt: at the hunt's start the game creates a quest session and invites the
  Link Party (`inviteLinkPartyQuest`). The mission keeps running after the hunt.
- **Environment Link** (Link Party *sync*) lets party members share a field. It's switched per mission and stage
  (`MissionManager.setPartySyncInfo(mission, stage, on)`) and introduced by `001075` ("To the Forest"). The game leaves
  it on story events (`Net_Party.leaveLinkPartySync(…, PARTY_SYNC_OPTION.LEAVE_StoryEvent)`).
- So "joining a story quest early" isn't possible: there's nothing to join before the gate. The mod has to keep the
  party together and the story **in step** on every PC, then regroup at the gate.

## 2. Decisions

| ID | Decision |
|---|---|
| **D1** | **Follow the leader's story**, as MHW Seamless Co-op does it (tried and popular). Setting, **on by default**: when a follower's story is at the leader's point or **up to 3 assignments behind**, their game records the story steps the leader has taken and they haven't, through the game's own routines, so the story, its people and its monsters match. The game saves them like the player's own progress. Only forward; a story further ahead or further behind is left as it is. **Off** ("keep your story entirely your own") is a **stretch goal**: ship *on* first. |
| **D2** | Party members must be **Steam friends** (spec C7). Accepted. |
| **D3** | If the game breaks the Environment Link at a story event, the mod **re-creates it automatically**. Only if the game refuses even that during a story event do we fall back to regrouping at the hunt (L3). |
| **P1** | **Hard requirement: progress is never lowered.** Under no circumstance does the mod undo or lower the progress of any save, and in particular never touches a save that is more advanced than the leader's. See §5. |

## 3. Approach

| Part | What it does | How (the game's own functions only) | Status |
|---|---|---|---|
| **L1 Stay linked** | Verified modded members stay in Environment Link through the leader's mission | When the game drops the link at a story event, re-invite and auto-accept at once (`inviteLinkPartySync` / `joinPartySync`); allow party sync for the active mission's stages (`setPartySyncInfo`). Keeping the link (skipping the `LEAVE_StoryEvent` leave) is tried only if re-linking proves too slow | Unknown until S0/S0b/S1 (R6, E1–E3) |
| **L2 Follow the leader's story** | Followers' stories advance with the leader's, step by step (D1) | The leader's mod reports each story step; each follower's mod records it through the same game routine at a **safe moment**, forward only (§4–§5) | Needs R9/R10 + E5/E6 |
| **L3 Regroup at the gate** | Followers enter the leader's hunt automatically | Accept the leader's vanilla Link Party quest invite (`acceptInviteLinkPartyQuest` / `checkAndAcceptSyncQuest`) | Low risk: players already do this by hand |
| **G Guest play** *(stretch)* | A player whose story isn't followed (setting off, or a helper who is ahead) plays the leader's mission as a guest before the gate | Same field via L1, the leader's world shown without writing anything to the guest's save | Needs R11 + E7. Until then, such players join at the gate (L3) |

## 4. Follow the leader's story (L2)

### 4.1 Who follows

Story distance is counted in **assignments** (`MissionManager.getMissionManageIdFromProgress(progressId)`). Order and
"same point" use the story progress ID (`getProgressId()`).

| Follower's story vs the leader's | With *Follow* on (default) | With *Follow* off (stretch) |
|---|---|---|
| Same progress ID | Joins; the leader's steps are recorded as they happen | Guest (G), else joins at the gate |
| Behind, ≤ 3 assignments | **Catch-up**: the missing steps are recorded at a safe moment before the mission (§4.3), then as above | Can't join before reaching the quest (vanilla) |
| Behind, > 3 assignments | Left as it is; can't join before reaching the quest (vanilla) | Same |
| **Ahead** (helper) | **Left as it is, never written (P1)**; guest (G), else joins at the gate | Same |

The window is a setting (`follow_max_assignments_behind`, 0–3, default 3). It never goes above 3: MHW's
mod uses the same bound, and a user hard-locked a save there by joining "future" story quests.

### 4.2 Story steps in Wilds (run 1)

What the game itself calls while a story mission runs (counts from the run-1 trace, one probe character, Ch. 1):

| Step | Game routine | Calls |
|---|---|---|
| Objective state / objective cleared | `MissionController.setObjectiveState(objective, OBJECTIVE_STATE)`, `MissionController.setClearObjective(mission, objective, bool)` | 67 / 67 |
| Story-FSM flags of the mission | `cStoryFsmController.setMissionDynamicFlag(int, bool)` (and `MissionManager.updateSaveStoryPackageFlag()`) | 387 (308) |
| Dialogue choice | `cStoryFsmController.setDialogueSelectedIndex(dialogue, mission, DynamicFlag, index, …)` | 5 |
| Hunt accepted / hunt objective cleared | `MissionController.setQuestAccepted()`, `MissionController.clearQuestObjective(objective)` | 3 / 3 |
| Mission cleared | `MissionController.setMissionClear()`, followed by the game's own `reqUpdateProgressId()`, `reqUpdatePartySyncProgressId()`, `reqUpdateMemberListProgressIdAtAllClearedMain()`, `updateMissionManageIDToActiveMission(next)` | 10 |

Also a candidate: the game already brings late quest joiners in line with `MissionManager.createMissionLateJoinSyncPacket` /
`applyMissionLateJoinSyncPacket(cMissionLoadBeforeSync)`. If it covers story missions, it's the most "own routine" way to
sync a follower who arrives mid-mission (R9).

Flow: the leader's mod observes these calls (hooks only capture and post events) and sends `STORY_STEP` messages
(mission, step kind, arguments, leader progress before/after) in order. Each follower's mod checks P1 (§5), queues the
step, and applies it through the same routine when it's safe:
- **Safe moments:** not in a conversation, cutscene, menu, loading screen or results screen. Steps wait in the queue in
  order. MHW's mod learned this the hard way: applying a step mid-conversation soft-locked a player. With shared
  cutscenes and dialogue (F3), the follower watches the same scene anyway, so the queue drains right after it.
- Steps are recorded **as the game records them for the leader**; the mod never writes save files. The game saves the
  follower's progress through its own autosave, as for its own play.

### 4.3 Catch-up (behind by 1–3 assignments)

The follower's save records the missions the leader has cleared and the follower hasn't, oldest first, before the
leader's mission starts for them (at the base camp, at a safe moment). How to record a whole mission that isn't
active on the follower's PC is open (R10): either the game's own mission start → objectives → `setMissionClear` path,
mission by mission, or a routine the game uses itself to mark missions cleared. If no clean way exists, the window
falls back to 0 (same point only) and the panel says so.

### 4.4 Lessons from MHW's "Follow the leader's story"

Each needed a fix in MHW's mod; each needs a Wilds check before release:

| MHW lesson | Wilds check |
|---|---|
| Hunter/Master Rank catch-up | Low Rank mission clears set HR 1–9 in the progress table (`progressDatas`); check the game's routine raises the follower's HR with the step |
| First-clear rewards (e.g. Vitality Mantle) | Story rewards and unlocks come from the game's routine, once, like a vanilla clear |
| Optional quests the leader's save unlocked | Unlocks must come from the follower's own story state, never copied from the leader |
| Per-player collectibles; side quests stay personal | Only main-mission steps are recorded; side missions, collectibles, gathering points, HR, inventory stay per player |
| "Research" progress shared (best in the party) | Wilds has no research gate. Its counterpart is **Hunter Rank**: post-story progress steps need HR 16/21/30/31/41, and rows 6200–6700 are HR 50–100 milestones. **Open (Q9)**, decided before High Rank (Phase 7). The mod never changes anyone's HR |
| Retrying a failed quest must not replay first-time cutscenes | Same rule as spec §9 |
| Never apply steps in conversations or menus | Safe moments (§4.2) |
| A save hard-locked by joining "future" quests | Window ≤ 3 assignments, P1, and helpers never written |

## 5. P1: progress is never lowered (enforcement)

1. **One writer.** Every story write goes through a single module (`features/follow_story`, Phase 3). Nothing else may
   call a story-writing routine; registry entries for those routines are tagged as story writes and checked by a test.
2. **The follower decides, from its own state.** Before each step, the follower's mod reads its *own* current progress
   (it never trusts the leader's description of it). If its story is ahead of the step, the step is dropped. A save that
   is ahead of the leader's is never written to at all.
3. **Strictly forward.** Persistent progress (progress ID, party-sync progress, cleared missions, cleared objectives,
   recorded dialogue choices) may only grow: a step that would lower or overwrite any of it is refused. In-mission
   story-FSM flags are mirrored only while the follower is in the same mission as the leader, at the same point.
4. **Verify after.** After each step the follower re-reads its progress. Anything lower than before turns story following
   off for the session, logs the details and tells the player.
5. **No rollback, ever.** The mod never tries to undo a step, not even its own. Recovery is forward-only, or the player
   restores one of the launch backups (F5.3).
6. **The mod never calls the game's reset routines** (e.g. `MissionManager.resetNetStoryPackageFlag`). Only the game
   itself does that, as part of its own flow.
7. **Tests.** Unit tests for the classification and the forward-only guard (every case of §4.1, kill switch and
   disconnect mid-queue, out-of-order and duplicate steps). An in-game matrix on test characters before release: same
   point, behind 1–3, behind 4+, ahead, leader behind a follower.

## 6. Experiments

| ID | Where | Question | Observe |
|---|---|---|---|
| E1 (R6) | S0 / S0b, two PCs, read-only | What happens to Environment Link when one player starts a story assignment? On whose PC does `leaveLinkPartySync(LEAVE_StoryEvent)` fire? | Probe traces from both PCs, panel status, game messages |
| E2 (R6) | S0b | Can two linked players run the same mission side by side without the game separating them? | Who sees whom, which NPCs, walk-and-talk positions |
| E3 (R8) | S1, kit v0.3, **first mutating test** | After the game drops the link at a story event, can the mod re-create it right away (D3)? If not, can it keep it? | Errors/kicks, session callbacks, how long the gap is |
| E4 | S1 | Can the follower accept the leader's quest invite automatically while in the same mission? | Join result codes, quest state on both PCs |
| E5 (R9) | S1+, test characters | Recording one leader step (an objective) on a same-point follower through the game's routine: does the follower's world follow (objective HUD, NPCs)? | Follower trace, progress before/after, autosave |
| E6 (R10) | Single PC first (probe character), then S2+ | Recording one whole missing mission (catch-up) | Progress table before/after, next mission, HR |
| E7 (R11) | Later | Guest play: a player whose story isn't written shares the leader's mission world | NPCs, objectives, what each PC shows |

Every mutating experiment runs in a private Link Party, on test characters, with a save backup from the same launch.

## 7. Plan

- **Phase 3 MVP** on **"Forest Findings"** (`001080`, Ch. 1-3, Lala Barina; Environment Link already exists there),
  two players **at the same point**, *Follow* on: L3 auto-accept at the gate, L1 automatic re-link, L2 recording of the
  leader's steps with P1. Exit: both finish the mission and the hunt together, both saves progress normally (nothing
  ever lower), nothing inconsistent after returning to camp.
- **Phases 4–6:** catch-up within 3 assignments (if R10 allows), more segment types, the rest of Low Rank.
- **Phase 7:** High Rank; decide Q9 (Hunter Rank gates) first.
- **Stretch:** *Follow* off and guest play before the gate (G), including helpers who are ahead.

## 8. Open questions

- **Q9 (for the project owner, before Phase 7):** post-story steps need a Hunter Rank (16/21/30/31/41). When the leader
  meets the HR and a follower doesn't, should the follower's story still record the step? HR itself is never changed.
- R9–R11 (implementation plan §10).
