# 00 — Research summary & index

> Seamless Co-op for Monster Hunter Wilds · research phase · 2026-10-20/21.
> Every claim below is sourced in the linked notes; this page is the executive summary.

## Notes in this folder

| # | Note | What it covers |
|---|---|---|
| 01 | [Elden Ring Seamless Co-op](01-elden-ring-seamless-coop.md) | Features, settings, architecture, ban-avoidance, maintenance model, reception of LukeYui's mods |
| 02 | [MHW Seamless Co-op](02-mhw-seamless-coop.md) | huntardy's MHW mod (Sept 2026): features, runtime-log architecture, full v1.1→1.6.1 changelog lessons, MHW/Rise context |
| 03 | [Wilds multiplayer & friction](03-wilds-multiplayer-and-friction.md) | Lobbies, Link Party, Environment Link, SOS, story-quest gating, title updates, complaints, workarounds |
| 04 | [Community sentiment (Reddit)](04-community-sentiment-reddit.md) | r/MonsterHunter & r/Eldenring threads with quotes |
| 05 | [Wilds modding ecosystem](05-wilds-modding-ecosystem.md) | REFramework, protection & ban risk, networking stack, mods with source + the game types they use, tools, communities |
| 06 | [RE & native toolchain](06-reverse-engineering-and-native-toolchain.md) | RE MCP servers, RE Engine RE workflow, debugger feasibility, native mod stack options, build tooling |
| 07 | [Agentic tooling](07-agentic-tooling-plugins-skills.md) | Copilot CLI plugins/skills/MCP/LSP and what was installed |
| 08 | [Game install & local environment](08-game-installation-and-local-environment.md) | Paths, versions, DRM, middleware, local mods, dev machine |
| 09 | [Game internals from the enum dump](09-game-internals-enum-dump.md) | Real `app.*` type names for sessions, Link Party, missions, story FSM, cutscenes |

## The problem, confirmed

- **Wilds kept a per-player story gate.** A main-story ("Assignment") quest only becomes joinable once *your own save*
  has reached that quest's pre-hunt cutscene; joiners only get story credit if they unlocked the quest themselves.
  Before the gate are walk-and-talk rides with Alma and NPCs, investigations, small-monster objectives and cutscenes
  (notes 03, 04). Some quests are "closed" (tutorial Chatacabra, Guardian Arkveld) or "half-open".
- The community workaround is tedious: everyone reaches the cutscene solo, all but one "return from quest", then rejoin
  via Link Party quests ([Reddit how-to](https://www.reddit.com/r/MonsterHunter/comments/1j0nra0/howto_coop_story_with_friends/)).
- Demand is loud and explicit: "Multiplayer design is inexcusably bad for 2025" (3.9K votes), "Petition for MHWilds
  seamless coop mod", a Nexus "[Mod Request] Seamless Coop Mod" thread, and Wilds requests on the MHW mod's page (notes 02–04).
- **No Wilds equivalent exists**, and no seamless-co-op mod exists for *any* RE Engine game (notes 01, 05).

## What the reference mods teach

- **Elden Ring Seamless Co-op** (note 01): host-authoritative progression; separate saves, own matchmaking and no EAC
  to avoid bans; scaling options; death/limbo design. Recurring pain: quest/NPC flag desync, cutscene loops, patch
  breakage (1–7 days), version-mismatch confusion, and a single maintainer's bus factor.
- **MHW Seamless Co-op** (note 02): a closed-source native DLL that coordinates through **Steam lobby data** and the game's
  own quest functions. Its 11 releases in 4 weeks show the hard parts: a second gate on the departure screen; cutscene
  sharing (identity check, vote-to-skip, audio, double playback); NPC/prop/story-monster sync; story-progress "following"
  (rank catch-up, first-clear rewards, per-player collectibles); a user who **hard-locked a save by joining future story
  quests**; a Steam Cloud conflict; and overlay conflicts. Reddit praised it but raised **security concerns about a
  closed networking DLL** (note 04).

## What Wilds offers a modder

- **REFramework** (praydog) supports Wilds and already bypasses its integrity checks; the managed type system is
  reachable **by name** through Lua (`sdk.*`) and C++ (`API.hpp`) — far more patch-resilient than MHW's raw offsets.
  It was updated locally to **nightly-01433** (note 08).
- The game's internal model (note 09) already contains the pieces we need: separate **LOBBY / QUEST / LINK** session
  types, **Link Party "sync"** that is explicitly left on story events (`app.Net_Party.PARTY_SYNC_OPTION.LEAVE_StoryEvent`),
  a **late-join snapshot sync**, **NPC network authority** (`HOST`/`FIRST_COME`), a **story FSM** that can hide remote
  players (`DRAWOFF_REPLICA_PLAYER`), and a **cutscene gallery** that can replay any story cutscene.
- Public Lua mods already drive the relevant APIs: `kmy0/BetterSoS` searches/joins quest sessions
  (`app.NetworkRequestManager.joinSession(SESSION_TYPE.QUEST, cJoinQuestSessionInfo…)` →
  `app.cQuestDirector.acceptQuest`); `WetU/MHWs_REF_Scripts` controls cutscenes through `app.DemoMediator` (note 05).
- **Networking:** game traffic is PlayFab Party (DTLS-encrypted) — no wire-level RE. REFramework's Lua has no sockets, so a
  mod-to-mod side channel needs a small **C++ plugin** (Steam P2P through the game's own `steam_api64.dll`).
- **praydog/re-engine-mcp** lets an AI agent inspect and call into the *live* game — a big accelerator for RE.

## Risks that shape the design

- **Ban risk:** Capcom detects/filters modified quests since Ver. 1.020 and suspends accounts "based on play data and
  history" (note 05 addendum). The mod must never alter quest data, rewards or timers, and must use normal game APIs.
- **Server-side gate?** Unknown whether any part of the story gate is enforced by Capcom's servers — the first thing
  the reverse-engineering spike must answer.
- **Patch churn:** online play requires the latest version (Ver. 1.042, Aug 2026) and **Ascendance** (Master Rank,
  new story) arrives in 2027 — build for fast re-validation after every title update.

## Decisions taken with the user (2026-10-21)

| Topic | Decision |
|---|---|
| v1 features | Join story quests from the start · play pre-hunt segments together · shared cutscenes · auto-follow · safety net · in-game panel |
| Progress policy | **Same story point** only; players who are ahead may join as helpers; players behind are blocked |
| Content | Base-game story (Low + High Rank, Ch. 1–6, and title-update story assignments); design for Ascendance later |
| Platform | Steam PC, latest game version only; every party member runs the same mod version |
| Tech | REFramework **Lua** for logic/UI + small **C++ REFramework plugin** for networking/native needs |
| Distribution | **Open source (MIT)** on GitHub + Nexus Mods |
| Testing | Developer PC + a **remote tester's laptop in another country** (no remote access; scheduled, scripted sessions — see [remote-testing](../testing/remote-testing.md)). Developer accepts the online-testing risk; the tester is informed before the first session. |
| Game folder | Agent may write only inside `<game>\reframework\` and replace REFramework's `dinput8.dll` |

## Known research gaps

- Discord (Monster Hunter Modding `discord.gg/gJwMdhK`, Modding Haven `discord.gg/9Vr2SJ3`) cannot be read by the agent —
  automating a user account breaks Discord's ToS. The user can join and relay specific answers.
- The exact gate mechanics, session lifecycle of story missions, and Steam-ID availability in the member list are
  unknown until the live RE spike (implementation plan, Phase 1).
