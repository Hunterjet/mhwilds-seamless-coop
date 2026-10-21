# F1 "story together": design draft (v0, for review)

> Status: **draft for the user's review** (2026-10-21). Builds on [run1-analysis.md](../re/run1-analysis.md) (H2
> confirmed) and [game-model.md](../re/game-model.md). Nothing here is implemented yet. Phase 3 starts after S0/S0b.

## 1. What vanilla does (run 1)

- A main mission is a chain of objectives that runs **locally on each player's PC**. The hunt is one objective range in
  it. Multiplayer exists only for that hunt: at the hunt's start the game creates a quest session and invites the
  Link Party (`inviteLinkPartyQuest`). The mission keeps running after the hunt.
- **Environment Link** (Link Party *sync*) lets party members share a field. It's switched per mission and stage
  (`MissionManager.setPartySyncInfo(mission, stage, on)`) and introduced by `001075` ("To the Forest"). The game leaves
  it on story events (`Net_Party.leaveLinkPartySync(…, PARTY_SYNC_OPTION.LEAVE_StoryEvent)`).
- So "joining a story quest early" isn't possible: there's nothing to join before the gate. What the mod must do is
  **keep the party together while each player's own copy of the mission runs in step**, then regroup at the gate.

## 2. Approach: three layers

| Layer | What it does | How (game's own functions only) | Risk |
|---|---|---|---|
| **L1 Stay together** | Verified modded members at the same story point stay in Environment Link through the leader's mission | Allow party sync for the active mission's stages (`setPartySyncInfo`). Skip the `LEAVE_StoryEvent` leave for verified parties. Re-link (`inviteLinkPartySync` / `joinPartySync`) if it drops anyway | **Unknown** until S0/S0b (R6): the game or server may refuse sync during story events |
| **L2 Same mission, same time** | Everyone's mission starts together and advances together | Leader-authoritative: `MISSION_INTENT` when the leader's next mission becomes active. Followers at the same story point have the same next mission. Objective state is shared via `SEGMENT_STATE`; how followers advance is decision **D1** | Desync of NPC routes/positions (the "stacking" question) |
| **L3 Regroup at the gate** | Followers enter the leader's hunt automatically | Accept the leader's vanilla Link Party quest invite (`acceptInviteLinkPartyQuest` / `checkAndAcceptSyncQuest`) | Low: this is what players already do by hand |

L3 alone is a useful first release ("seamless regroup"). L1 is what makes it *seamless co-op*.

## 3. Experiments before building

| ID | Where | Question | Observe |
|---|---|---|---|
| E1 (R6) | S0 / S0b, two PCs, read-only | What happens to Environment Link when one player starts a story assignment? On whose PC does `leaveLinkPartySync(LEAVE_StoryEvent)` fire? | Probe traces from both PCs, panel status, game messages |
| E2 (R6) | S0b | Can two linked players run the same mission side by side (each their own copy) without the game separating them? | Who sees whom, which NPCs, walk-and-talk positions |
| E3 (R8) | S1, kit v0.3, **first mutating test** | Does keeping the link through a story event (skipping the `LEAVE_StoryEvent` leave) work, or does the client or server undo it? | Errors/kicks, session callbacks, server responses |
| E4 | S1 | Gate: can the follower accept the leader's invite automatically while in the same mission? | Join result codes, quest state on both PCs |

E3 is the first time the mod would change the game's behaviour. It runs only in a private Link Party with the
tester, on test characters, with a save backup made at launch.

## 4. Decisions for you

- **D1: how followers advance objectives (L2).**
  (a) Everyone completes each objective themselves; the mod only shows what the leader is doing. This is the safest
  option, but means more waiting.
  (b) When the leader clears an objective, the mod clears it for followers through the game's own objective routine.
  This is the most seamless, but it advances story progress for players who didn't do the step: a fair-play gray zone.
  (c) Hybrid: mirror travel/escort/"stay close" objectives; talks and choices stay per player (or follow the leader's
  choice, as in shared cutscenes).
  *Recommendation:* (c), with (a) as the fallback for any objective we haven't verified.
- **D2: Steam friends requirement** ([spec C7](../feature-spec.md)). Party members must be Steam friends for the
  side channel. *Recommendation:* accept for v1.
- **D3: scope if E3 fails** (sync can't survive story events): ship L3 + shared cutscenes as "seamless regroup" and
  keep L1 as research.

## 5. Phase 3 MVP proposal

One mission, **"Forest Findings"** (`001080`, Ch. 1-3, Lala Barina; Environment Link already exists there), two
players at the same point:

1. L3 auto-accept at the gate (low risk, immediately useful).
2. L1 on that mission's stages if E1–E3 allow it.
3. L2 with D1 option (a) at first: a panel/overlay line "Leader: <objective>", no automatic advancing.

Exit: both players finish the mission and the hunt together, both saves progress normally, and nothing is left
inconsistent after returning to camp.
