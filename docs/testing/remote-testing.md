# Remote two-player testing

> How multiplayer gets tested when the second PC is a **remote tester's laptop in another country**. We have no remote
> access to it: the tester installs builds and follows short, scripted sessions, then sends logs back.

## Setup at a glance

| | PC-A (developer) | PC-B (remote tester) |
|---|---|---|
| Who | Project developer, works with the coding agent | Volunteer tester (not a developer), different country and time zone |
| Installs | Full dev setup ([dev-environment.md](../dev-environment.md)): REFramework nightly **+ C# API + re-engine-mcp**, toolchain | **End-user components only**: the pinned REFramework `dinput8.dll` plus our release zip (or probe scripts in Phase 1). No C# API, no re-engine-mcp, no dev tools. |
| Access | Direct | None. Everything goes through the tester kit, a written session script, and the logs the tester sends back. |
| Characters | Main + test characters (a "pair" character, ideally also a "probe" character) | Main + one test character |

## Principles

1. **Single-PC first.** Most work needs no second player: the RE spike (R1–R5, R7), adapters, panel, build gate, and the
   protocol (via the loopback transport). Two-player sessions are milestone events.
2. **Short, scripted sessions** (30–60 min), one goal each, written in plain language and booked in advance.
3. **Both PCs log everything.** After each session the tester runs `collect-logs.ps1` and sends the zip.
   Logs never contain the OS user name or full Steam IDs.
4. **Test characters** in a spare save slot (Wilds has 3 per account), so main saves are never involved and "same story
   point" is easy to arrange.
5. **Private Link Party with just the two players.** Modded builds never go into public lobbies.
6. **Informed consent.** Before the first session the tester is told plainly that any online mod carries account risk
   (see the README risk statement).
7. **Pinned versions.** Each test build states the game build and REFramework nightly it needs. The tester kit installs exactly that.

## Cross-country considerations

- **Latency:** the mod's side channel goes through Steam's relay network, so plan for **100–300 ms RTT**. Every protocol
  step has timeouts sized for that, and the panel shows RTT. Cutscenes use a **scheduled start**: the leader sends
  "start at T", where T = now + half the worst RTT + a margin, using clock offsets estimated from heartbeats. Playback
  then begins within a frame or two on both PCs instead of being skewed by the one-way delay.
- **Language/region:** the tester's game may run in another language. That's a useful check that the mod exchanges only
  IDs, never text.
- **Time zones:** sessions are scheduled; log review is asynchronous; every session ends with a short written result
  (filled-in checklist).

## Story-mission fixtures

- Completed story missions appear **not to be replayable** (their monsters come back as optional quests, which vanilla
  already lets friends join; the Low Rank final boss never returns — [Game8](https://game8.co/games/Monster-Hunter-Wilds/archives/503913)).
  To be confirmed in-game. In practice each test run uses up a story mission on that character, so sessions follow story order.
- **Retry options:** (1) save manually right before a test mission and, if the run fails, quit without saving (only
  works if no autosave happened in between); (2) the mod's launch-time save backups, restored **manually by the player**
  with the game closed (mind Steam Cloud); (3) a fresh test character.
- **Homework before the first joint session:** both players create a test character and play solo until multiplayer
  unlocks (after Chapter 1's "Slimy Situation" Chatacabra hunt, about an hour), then stop at the same point. The
  developer uses a separate **probe** character for solo RE work, so the paired character stays in step with the tester's.

## Tester kit (built during Phases 1–2, in `tools/tester-kit/`)

| File | Purpose |
|---|---|
| `README-TESTER.md` | Plain-language steps: install, start, what a successful start looks like, where logs are, uninstall |
| `install.ps1` | Finds the game through Steam's library config and checks the game build. Backs up `dinput8.dll` and **copies** the save folder into `reframework\data\seamless_coop\save_backups\`. Installs the pinned REFramework (download + SHA-256 check) and our files into `reframework\`. Never modifies saves. |
| `uninstall.ps1` | Removes our files; restores the previous `dinput8.dll` |
| `collect-logs.ps1` | Zips our logs and the REFramework log onto the desktop; redacts the OS user name and full Steam IDs |
| `session-NN.md` | The script for the next session |

Delivery: **GitHub pre-releases** on this repository (downloading needs no GitHub account).

## Session plan

| Session | When | Goal | Tester installs |
|---|---|---|---|
| **S0 · Setup & smoke** | End of single-PC Phase 1 work | REFramework runs on PC-B. Private Link Party across countries works. Read-only probe traces from both PCs during Environment Link in the field, and when the leader starts a story mission while linked (R6). | Kit v0: REFramework + read-only probe scripts |
| **S1 · Early-join experiment** | Phase 1 (R8) | Can a linked player enter the leader's story mission before the gate? Record client and server responses. | Kit v0.1 |
| **S2 · Side channel** | Phase 2 | Handshake, heartbeat/RTT, version-mismatch handling, reconnect | First mod build |
| **S3+ · Features** | Phases 3–7 | F1–F4 acceptance on specific story quests (checklists in `story-matrix.md`) | Mod builds |

Every session script follows the same template: **goal · prerequisites** (builds, story point, backups) · **steps for
PC-A / PC-B · expected results · what to note · logs to send**.
