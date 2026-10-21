# Remote two-player testing

> How multiplayer gets tested when the second PC is a **remote tester's laptop in another country**. We have no remote
> access to it: the tester installs builds and follows short, scripted sessions, then sends logs back.

## Setup at a glance

| | PC-A (developer) | PC-B (remote tester) |
|---|---|---|
| Who | Project developer, works with the coding agent | Volunteer tester (not a developer), different country and time zone |
| Installs | Full dev setup ([dev-environment.md](../dev-environment.md)): REFramework nightly **+ C# API + re-engine-mcp**, toolchain | **End-user components only**: the pinned REFramework `dinput8.dll` plus our release zip (or probe scripts in Phase 1). No C# API, no re-engine-mcp, no dev tools. |
| Access | Direct | None. Everything goes through the tester kit, a written session script, and the logs the tester sends back. |
| Characters | Main + two test characters: **pair** (kept in step with the tester) and **probe** (solo RE work) | Main + one **pair** test character |

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

## Tester kit (`tools/tester-kit/`; current: v0.2, released as a GitHub pre-release)

v0.2 = REFramework + read-only probe 0.1.3 + the Seamless Co-op test build (Phase 2: panel, save backup at launch,
side channel; no gameplay changes). The installer enables `dev_selftest` on first install, so every launch logs one
`selftest:` line, including a Steam self-loop that checks the tester's relay path.

| File | Purpose |
|---|---|
| `README-TESTER.md` | Plain-language steps: install, start, what a successful start looks like, F8 marks, sending logs, uninstall, troubleshooting |
| `install.cmd` / `install.ps1` | Finds the game through Steam's library config and checks the game build. Backs up `dinput8.dll` and **copies** the save folder into `reframework\data\seamless_coop\kit_save_backups\` (outside the plugin's rotation). Installs the pinned REFramework (download + SHA-256 check of zip and DLL), the probe and the mod test build (`mod\reframework\...`) into `reframework\`. Writes an install manifest. Never modifies saves. |
| `uninstall.cmd` / `uninstall.ps1` | Removes the probe and the mod; restores the `dinput8.dll` from before the *first* install (or removes it if there was none) |
| `collect-logs.cmd` / `collect-logs.ps1` | Zips probe traces, the mod's session logs, `diagnostics.json`, `config.json`, install manifests and the REFramework log onto the desktop; redacts the OS user name, computer name and full Steam IDs (keeps the last 4 digits) |
| `SESSION-NN.md` | The script for the next session |
| `kit-common.ps1`, `build-kit.ps1` | Shared helpers; kit builder (adds the probe, the mod via `tools/package.ps1 -StageOnly`, and `VERSION.txt`; writes `C:\src\.cache\dist\seamless-coop-tester-kit-<v>.zip`) |

The `.cmd` launchers exist because double-clicking a `.ps1` opens Notepad. They run Windows PowerShell 5.1 with
`-ExecutionPolicy Bypass`, pause on crashes, and tell the tester to extract the zip first. Every script also takes
`-GameDir`, `-SteamDir`, `-OutDir`, `-NoPause` for support and automated tests (v0 was tested on a fake Steam layout:
install, re-install, uninstall, restore of a third-party `dinput8.dll`, wrong build, game running, log redaction).

Delivery: **GitHub pre-releases** on this repository (downloading needs no GitHub account).

## Session plan

| Session | When | Goal | Tester installs |
|---|---|---|---|
| **S0 · Setup & link check** | Now (kit v0.2) | REFramework, probe and mod test build run on PC-B. Private Link Party across countries works. **Mod connection between the PCs (Phase 2 exit check, Part 2b).** Is Environment Link available at the pair point (progress 250, see below)? If yes: what happens to it when one player starts a story assignment (R6). Script: [`SESSION-00.md`](../../tools/tester-kit/SESSION-00.md) | Kit v0.2: REFramework + read-only probe + mod test build |
| **S0b · Linked story baseline** | After S0 (+ solo catch-up homework if Environment Link was refused) | At "Forest Findings" (Ch. 1-3, `001080`), with Environment Link on: one player starts the assignment (R6), then the *Lala Barina* hunt is joined the vanilla way. Traces from both PCs give the vanilla join path that F1 will automate. | Kit v0.2 |
| **S1 · Early-join experiment** | Phase 1 (R8) | Can a linked player enter the leader's story mission before the gate? Record client and server responses. | Kit v0.3 |
| **S2 · Side channel** | Phase 2 | Handshake, heartbeat/RTT, version-mismatch handling, reconnect. The basics are covered by S0 Part 2b; this session adds reconnects, restarts and a forced mismatch | Kit v0.2+ |
| **S3+ · Features** | Phases 3–7 | F1–F4 acceptance on specific story quests (checklists in `story-matrix.md`) | Mod builds |

**Pair point and Environment Link.** The pair characters stop at progress 250: Chapter 1-2 "Back to Camp" (`001040`)
finished, multiplayer unlocked, next assignment "The Beginning" (`001042`). Run 1 showed that Environment Link is
introduced later, by "To the Forest" (Ch. 1-3, `001075`): party-sync progress is still 0 at the pair point
([run1-analysis.md](../re/run1-analysis.md) §4). So S0 checks it first. If it's refused, both players catch up solo
(probe running) to "Forest Findings" and S0b happens there.

Assignment ↔ mission map (Chapter 1, from `MissionManager._MissionSetting._MissionActivityData`; English titles):

| Ch. | Assignment | Missions | Hunt |
|---|---|---|---|
| 1-1 | Desert Trotters | `001030` | Chatacabra |
| 1-2 | Back to Camp | `001040` | — (multiplayer unlocks at its end) |
| 1-2 | The Beginning | `001042` | — |
| 1-2 | Village of Whispering Winds | `001045` `001047` `001050` `001060` `001070` | Quematrice (`001050`) |
| 1-3 | To the Forest | `001075` | — (introduces Environment Link) |
| 1-3 | Forest Findings | `001080` `001090` `001100` | Lala Barina (`001080`) |
| 1-4 | The Investigation Continues | `001110` | — |
| 1-4 | A Hunter's Pride | `001130` `001135` | two hunts (objectives 7 and 5) |
| 1-5 | Pursuit of Solitude | `002140` | — |
| 1-5 | Beyond the Deluge | `002150` | one hunt (objective 3) |

Every session script follows the same template: **goal · prerequisites** (builds, story point, backups) · **steps for
PC-A / PC-B · expected results · what to note · logs to send**.
