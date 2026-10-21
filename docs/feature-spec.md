# Seamless Co-op for Monster Hunter Wilds — Feature Specification

> Status: **Draft v0.1** (2026-10-21) · Owner: project lead · Inputs: [research summary](research/00-research-summary.md)
> Companion document: [implementation plan](implementation-plan.md).

## 1. Summary

**Seamless Co-op** lets a Link Party of PC players who all run the mod play Monster Hunter Wilds' **main story together
from the first step of each story quest**. They ride, talk, investigate, fight small monsters, watch story cutscenes and
hunt the large monster as one party. In vanilla, each player must reach the pre-hunt cutscene solo and then regroup.

It is inspired by [Elden Ring Seamless Co-op](https://www.nexusmods.com/eldenring/mods/510) and
[MHW Seamless Co-op](https://www.nexusmods.com/monsterhunterworld/mods/8805), adapted to how Wilds already works
(lobbies, Link Party, Environment Link, crossplay, Support Hunters).

## 2. Problem statement (vanilla Wilds)

- Story ("Assignment") quests are **gated per player**: others can only join once each of them has personally reached
  that quest's gating cutscene. Joiners earn story credit only if they unlocked the quest themselves.
- The pre-hunt part of a story quest is a sequence of **segments**: Seikret travel with Alma/NPCs, walk-and-talk dialogue,
  investigations (tracks, objects), small-monster objectives and story cutscenes. Players do these **alone**.
- The known workaround is "everyone reaches the cutscene solo → all but one *return from quest* → rejoin via Link Party
  quests", which players call tedious and "not seamless at all".
- Wilds' social layer (Lobby, Link Party, Environment Link, Squads, SOS) is hard to understand. Environment Link refuses
  players with less story progress and conflicts with quest posting.

## 3. Goals and non-goals

### Goals (v1.0)
| ID | Goal |
|---|---|
| G1 | Modded Link Party members at the **same story point** can be in the leader's story quest **from its start**. |
| G2 | The party stays **together** through every pre-hunt segment and sees the same NPCs, objectives and events. |
| G3 | Story **cutscenes are watched together**, with a fair way to skip them. |
| G4 | **Zero menu juggling**: followers automatically follow the leader into quests and back to base. |
| G5 | **Safety first**: never corrupt saves, never alter quest data or rewards, fail closed on unknown game builds. |
| G6 | **Transparency**: open source (MIT), clear in-game status, privacy-respecting logs for bug reports. |

### Non-goals (v1.0)
- Advancing the story of players who are **behind** ("follow the leader's story") — explicitly out of scope.
- Relaxing Environment Link's progress lock for **free roam** outside story quests.
- Playing with **non-modded** players or **console** players (crossplay) in seamless mode. Vanilla play with them is unaffected.
- More than 4 players, difficulty/scaling changes, PvP, custom matchmaking or servers, separate save files.
- Any change to quest content, rewards, timers, drops or monster parameters.
- **Ascendance** (2027 expansion) content — the design must make it addable later.

## 4. Platform and compatibility requirements

| ID | Requirement |
|---|---|
| C1 | Steam PC, **latest game version only** (today: Ver. 1.042.x, Steam build 24705561). Online play requires it anyway. |
| C2 | Requires **REFramework** (a tested nightly is recorded in each release's compatibility table). |
| C3 | All party members run the **same mod version** (protocol version + game build checked in a handshake). |
| C4 | On an unknown/unsupported game build, or if required game types/methods are missing, the mod **disables itself** (vanilla behaviour) and says why. |
| C5 | Coexists with ReShade, RenoDX, Fluffy Mod Manager PAK mods and typical REFramework scripts. Mods that change the same systems (e.g. auto-join/SOS mods) are detected and reported. |
| C6 | English first; all strings externalized for later localization in the game's languages. |

## 5. Concepts and terminology

| Term | Meaning |
|---|---|
| **Party** | The players in one Link Party. **Modded party** = members who passed the mod handshake. |
| **Leader** | The party member whose story quest the party plays (normally the one who starts it; the quest's host). |
| **Follower** | Any other modded party member in the leader's quest. |
| **Story point** | A comparable identifier of a player's main-story progress (current main mission + relevant flags). |
| **Helper** | A follower who has already **cleared** the leader's story quest. |
| **Gate** | The point at which vanilla lets other players join (the quest becomes SOS/Link-joinable). |
| **Segment** | A pre-gate part of a story quest: *Travel*, *Talk*, *Investigate*, *Skirmish*, *Cutscene*; then *Hunt* and *Results*. |
| **Main mission** | A main story mission (`MissionTypeList.MAINSTORY`, IDs `MISSION_00CNNN`): a chain of objectives (talk to NPCs, travel, investigate, small monsters, cutscenes). Many missions also **wrap a hunting quest**. In this spec, **"story quest" means the whole main mission**, not only its hunt. |
| **Hunting quest** | The quest wrapped inside a main mission (`MissionData._QuestData`), starting at objective `_QuestStartObjectiveID`. Vanilla allows others to join (SOS / Link Party invite) only from this point. |
| **Closed quest** | A story quest vanilla never allows others to join (e.g. tutorial hunts); see §9. |

## 6. Features

Priorities: **P0** = required for the first playable release, **P1** = required for v1.0, **P2** = nice to have.

### F1 — Seamless story join (P0)
Followers enter the leader's main-story quest from its **beginning**, instead of after the gate.

| Rule | Description |
|---|---|
| F1.1 | Applies to **main-story missions** (`MAINSTORY`). Side, optional, investigation, event and arena quests keep vanilla behaviour (they are already joinable). |
| F1.2 | **Eligibility:** a follower is eligible if their story point equals the leader's (same next main mission), or if they already cleared this mission (**helper**). A follower who is **behind** is **blocked** with a clear message. |
| F1.3 | Seamless join is offered only when **every** member who would join is modded and handshake-verified. Otherwise vanilla rules apply for that quest. |
| F1.4 | Joining uses the **game's own session/quest functions**. The mod never forges packets or edits quest data. |
| F1.5 | **Late join:** a follower can join a story quest already in progress. They arrive next to the leader and are brought up to the current segment. |
| F1.6 | **Closed quests** and special single-player sequences are listed in a compatibility table; followers wait in a "waiting for leader" state (or the quest is marked unsupported) rather than being forced in. |
| F1.7 | **Zone locks** (e.g. "can't leave until Lala Barina is defeated") apply to the whole party, as they would in vanilla. |
| F1.8 | **Story credit:** the leader and every same-point follower receive normal story progress when the quest is cleared. Helpers receive what vanilla gives a helper. |

**Acceptance:** two modded players at the same story point start a Chapter 1 story quest (e.g. "Forest Findings") together.
They travel, investigate and fight small monsters together, see the cutscene, hunt the target together, and both get
the quest cleared and the next quest unlocked. No error dialogs or disconnects occur, and saves stay valid.

### F2 — Together through story segments (P0 presence/travel · P1 NPC/objective sync)
| Rule | Description |
|---|---|
| F2.1 | **Presence:** party members are visible to each other throughout the quest. The story system's "hide remote players" behaviour is suppressed for the modded party. |
| F2.2 | **Travel:** during forced Seikret travel with story NPCs, followers ride along. A follower who falls too far behind gets a **catch-up** prompt or is moved next to the leader, and never triggers the leader's "return to mission area" failure states. |
| F2.3 | **Dialogue:** the leader's story dialogue (voice and subtitles) is presented to followers. Followers cannot advance or skip the leader's dialogue. |
| F2.4 | **Objectives:** objective state (investigate X, defeat N small monsters) is **leader-authoritative**; followers see the same objective HUD, and their kills and interactions count. |
| F2.5 | **NPCs:** story NPCs (Alma, Nata, Olivia, …) are in the same place and act the same on every screen. |
| F2.6 | **Story triggers** (zone entries, interactions, dialogue starts) are resolved by the leader's game; followers' games follow the leader's state. P2: a follower reaching a trigger first can start it for everyone. |

**Acceptance:** in a representative quest from each chapter, followers ride with the party, see the same NPCs, hear the
dialogue, help with small monsters, and nobody gets soft-locked, warped away or warned out of the mission area.

### F3 — Shared story cutscenes (P1)
| Rule | Description |
|---|---|
| F3.1 | When a story cutscene starts for the leader, it plays for all followers in the quest at the same time. Both sides verify it is the **same** cutscene (event ID and identity), not just the same number. |
| F3.2 | **Start barrier:** the cutscene starts when all followers are ready, or after a timeout. A late follower joins at the current point or skips to its end. |
| F3.3 | **Vote-to-skip:** each viewer presses a key to vote. The cutscene is skipped for everyone when all viewers have voted. A setting lets the leader skip for everyone instead. Skipping uses the game's own skip path, so everything the cutscene sets up still happens. |
| F3.4 | Followers who have already seen a cutscene watch with the party by default; a setting lets them skip it locally. |
| F3.5 | After a shared cutscene, followers regain control where the story places them (near the leader). A cutscene never plays twice for anyone, and nobody gets a black screen, falls through terrain, keeps orphaned audio or loses input. |
| F3.6 | Cutscene sharing never marks a cutscene as seen for a player who would not have seen it in a vanilla run of the same quest at the same story point. |

**Acceptance:** for at least five representative story cutscenes (Low and High Rank), every viewer starts within about
1 second of the others, skip-voting works, and none of the F3.5 failures occur.

### F4 — Auto-follow (P1)
| Rule | Description |
|---|---|
| F4.1 | When the leader starts or accepts a quest, followers **automatically join** it. Configurable: *off*, *story quests only* (default), or *all quests*. |
| F4.2 | When the leader returns from a quest, followers return too (configurable). |
| F4.3 | A **"join leader now"** hotkey and panel button are available. |
| F4.4 | Followers use the leader's **start point/camp** where the game allows a choice. |
| F4.5 | The mod never auto-joins while a follower is in a menu, a dialogue or a cutscene. It queues the join and retries when that ends. |

### F5 — Safety net (P0)
| Rule | Description |
|---|---|
| F5.1 | **Build gate:** at startup the mod verifies the game build, REFramework version and every game type/method it uses. If anything fails, **no hooks are installed** and the panel shows "Disabled — unsupported game version". |
| F5.2 | **Handshake:** mod version, protocol version and game build are exchanged. Mismatches are shown per member and disable seamless features with that member. |
| F5.3 | **Save backup at launch:** before the title screen loads a save, the save folder is copied to `reframework/data/seamless_coop/save_backups/<timestamp>/`. The last 10 are kept (configurable). The mod **never writes save files itself**. |
| F5.4 | **Progress guards:** joins that would skip a player's story are refused (MHW users hard-locked saves this way). |
| F5.5 | **Fair-play guard:** the mod never modifies quest definitions, rewards, timers, drops, monster parameters or story flags outside the game's own routines. |
| F5.6 | **Fault containment:** every hook is wrapped. Repeated faults disable the affected feature and show a message instead of crashing the game. |
| F5.7 | **Kill switch:** one setting/hotkey turns all seamless behaviour off instantly (vanilla behaviour). |
| F5.8 | **Logs:** rotating log files (last 5 sessions). The Windows user name is never logged and Steam IDs are truncated. A "copy diagnostics" button helps bug reports. |

### F6 — In-game panel (P0)
| Rule | Description |
|---|---|
| F6.1 | A section in the REFramework menu plus an optional compact overlay. It shows each party member's mod status and version, story point, current state (base / loading / segment / cutscene / hunt) and connection health. |
| F6.2 | Settings (see §7) are persisted in `reframework/data/seamless_coop/config.json`. |
| F6.3 | An **activity timeline** of recent events, such as "Leader started *Forest Findings*", "Joined", "Cutscene shared", "Join refused: behind in story". |
| F6.4 | **Diagnostics:** game build, REFramework version, mod version, hook validation results, network status and last errors. |
| F6.5 | Configurable hotkeys: toggle overlay, join leader, vote skip, kill switch. |

## 7. Settings (defaults)

| Setting | Default | Notes |
|---|---|---|
| `enabled` | on | Kill switch (F5.7). |
| `seamless_story_join` | on | F1. |
| `auto_follow` | `story` | `off` / `story` / `all` (F4.1). |
| `return_with_leader` | on | F4.2. |
| `match_start_point` | on | F4.4. |
| `share_cutscenes` | on | F3. |
| `skip_mode` | `vote` | `vote` / `leader` / `local-if-seen` (F3.3–F3.4). |
| `show_skip_prompt` | on | |
| `catch_up_distance_m` | 60 | F2.2 threshold. |
| `save_backup_on_launch` | on | F5.3. |
| `save_backups_to_keep` | 10 | |
| `overlay_visible` | on | F6.1. |
| `log_level` | `info` | `debug` adds per-event traces. |
| `hotkeys` | F9 join · F10 vote skip · F11 overlay · Ctrl+F12 kill switch | All rebindable. Exact defaults to be checked against the game's keybinds. |

## 8. User flows

1. **Set up:** players form a Link Party as usual. The panel shows "Seamless ready — 3/3 modded, same story point".
   If a member is behind, it shows "Bob is behind (Chapter 2 · *A Hunter's Pride*) — seamless story join unavailable for Bob".
2. **Start:** the leader starts the next story quest (NPC talk or map marker). Followers see "Joining *Forest Findings*…",
   load in, and appear next to the leader.
3. **Segments:** the party rides with Alma, hears the dialogue together, investigates, and fights small monsters. The
   objective HUD matches for everyone.
4. **Cutscene:** "Waiting for party (2/3 ready)…", then the cutscene plays for all. Pressing the skip key shows "Skip: 2/3 voted".
5. **Hunt:** the hunt continues in the same quest with the same party (no SOS, no regroup).
6. **Results:** everyone sees their own results and earns normal progress. Followers return to base with the leader.
7. **Failure paths:** a disconnected follower can rejoin with the "join leader" hotkey (late join). If the mod detects a
   mismatch or unsupported state, it falls back to vanilla and explains why.

## 9. Edge cases and rules

| Situation | Behaviour |
|---|---|
| Member not modded / console member in the Link Party | Seamless features are off for quests involving them; vanilla behaviour. |
| Follower behind in story | Blocked from seamless join (message). They can still use vanilla SOS once they reach the gate. |
| Follower ahead (helper) | May join from the start. Cutscenes are optional for them (F3.4). Their save is not touched. |
| Closed/tutorial quests, prologue, special set pieces | Listed as unsupported in the compatibility table; followers wait. |
| Half-open quests (solo intro then joinable) | Treated like normal story quests where possible; otherwise followers join after the intro. |
| Leader disconnects or leaves | Followers are returned to base (vanilla handles the quest session). The panel explains what happened. |
| Follower in a menu, dialogue or cutscene when the leader starts | The join is queued and retried (F4.5). |
| Quest failure or retry | Party retries together. First-time cutscenes are not replayed on retry. |
| Support Hunters / NPC-only multiplayer setting | Leader's quest uses player-friendly settings while followers are joining. Never forced if the leader chose otherwise. |
| Different game languages | Supported. Only IDs are exchanged, never text. |
| Game update | The mod disables itself until a compatible release is out (C4). |

## 10. Fair-play and safety commitments

1. No changes to quest data, rewards, timers, drop rates, monster stats or unlock state beyond what the game itself
   records when a player plays the content.
2. No forged network traffic toward Capcom services; only the game's own request functions are called.
3. Seamless mode only between consenting, verified modded Link Party members.
4. Never write save files. Back them up at launch.
5. Open source and documented; risks are stated plainly on the mod page (account-ban risk cannot be ruled out for any online mod).

## 11. Non-functional requirements

| ID | Requirement |
|---|---|
| N1 | **Performance:** no measurable FPS impact. Event-driven hooks; per-frame Lua work under ~0.2 ms on a typical PC. |
| N2 | **Network:** side-channel messages are small (< 1 KB typical) and infrequent (event-driven, plus a ~1 Hz heartbeat). |
| N3 | **Robustness:** any desync is detected (state checksums, timeouts) and resolved by the leader's state, a catch-up, or falling back to vanilla. |
| N4 | **Security:** messages are accepted only from verified party members' Steam IDs, with schema validation, size limits and rate limiting. No code or file paths are exchanged. |
| N5 | **Privacy:** logs exclude OS user names and truncate Steam IDs. No telemetry. |
| N6 | **Maintainability:** every game type/method name lives in one validated registry, so a title update is fixed in one place. |
| N7 | **Installability:** a single zip that extracts into the game folder or installs via Fluffy Mod Manager. No launcher and no game file edits. |
| N8 | **Latency:** works between peers on different continents (Steam relay, up to ~300 ms RTT). Timeouts are sized for that, and shared cutscenes use a scheduled start so playback starts within about 250 ms. |

## 12. Release criteria (v1.0)

- Complete Low Rank and High Rank main story with **2 players** using seamless join, segments, cutscenes and auto-follow,
  with no save problems and no unexplained disconnects. The compatibility table covers every main-story quest.
- 3–4 player sessions are smoke-tested across each chapter (documented as "less tested" if needed, as MHW's mod does).
- Build gate, handshake, backups, kill switch, logs and diagnostics are verified.
- Docs: install guide, FAQ, known issues, compatibility table, risk statement.

## 13. Feature parity with MHW Seamless Co-op

| MHW Seamless Co-op | Wilds Seamless Co-op v1 |
|---|---|
| Bypass the cutscene gate | **F1** (core) |
| Watch the leader's cutscenes + vote skip | **F3** |
| Auto-follow host / follow anyone | **F4** (Link Party already notifies; we auto-accept) |
| Match the host's campsite | **F4.4** |
| See the party in town | Largely native in Wilds (lobbies). Pre-gate presence is covered by **F2.1** |
| NPC/prop/story-monster sync | **F2.4–F2.6** |
| Follow the leader's story | **Out of scope** (same-point policy) |
| Save backup, save on return, cloud-conflict fix | **F5.3**. Save-on-return to be evaluated (Wilds autosaves after results) |
| Panel, diagnostics, version checks | **F5/F6** |

## 14. Open questions (resolved in the RE spike — see the implementation plan, Phase 1)

| ID | Question |
|---|---|
| Q1 | Is the story gate enforced only by the client, or does any server-side check apply to joining early? |
| Q2 | Does a quest session exist from the start of a story mission (just not joinable), or only from the gate? |
| Q3 | How is "story point" best read (mission IDs, `StoryPackageFlag`s, save fields)? |
| Q4 | Do followers' own games need to run the mission in lockstep to earn progress, or is clearing the quest enough? |
| Q5 | Can each party member's Steam ID be read from the game (for the P2P side channel)? |
| Q6 | How are story NPCs and the story FSM networked (`cNpcNetworkMasterManager`, `DRAWOFF_REPLICA_PLAYER`)? |
| Q7 | What is the cleanest way to play a specific story cutscene on a follower (story FSM path vs cutscene gallery)? |
| Q8 | How does Environment Link relate to the field instance during story missions (`LEAVE_StoryEvent`)? |
