<!-- Research note: Elden Ring Seamless Co-op (LukeYui/Yui). Compiled 2026-10-20/21 by a research sub-agent (web + GitHub); citations inline. Treat '[inferred]' items as unverified. -->

# Elden Ring Seamless Co-op: Deep Research Report

## Overview & stats

"Seamless Co-op" is a free Elden Ring mod by a developer going by **Yui** (formerly/also credited as **LukeYui**; Polygon's interview used she/her pronouns — [polygon.com, Apr 11 2025](https://www.polygon.com/news/557559/dark-souls-remastered-seamless-co-op-mod/)). It is hosted on Nexus Mods at [nexusmods.com/eldenring/mods/510](https://www.nexusmods.com/eldenring/mods/510), original upload **27 May 2022**, still labeled **beta** as of its last tracked update (v1.9.0, 21 Jan 2025; a v2.0.1 "experimental" build followed on GitHub) ([Wayback snapshot, Jun 2025](https://web.archive.org/web/20250601011342/https://www.nexusmods.com/eldenring/mods/510?tab=files)). The GitHub mirror has moved from the historical `LukeYui` handle to the current account **`yuiamoroll`**: `github.com/LukeYui/EldenRingSeamlessCoopRelease` now 302-redirects to `github.com/yuiamoroll/EldenRingSeamlessCoopRelease` (1.6k stars, 73 forks, verified directly, Oct 2026).

**Popularity trajectory** (figures vary by source/date — presented as a timeline, not a single number):
- **~2 million unique downloads** by 17 June 2024 ([ScreenRant](https://screenrant.com/elden-ring-coop-mod-fromsoftware-multiplayer-changes/), citing PCGamer)
- **3.6 million total downloads**, "the next most popular [mod] has just ⅓ as many, at 1.2 million," per PC Gamer's Wes Fenlon, mid-2024 ([pcgamer.com](https://www.pcgamer.com/games/rpg/fromsoftwares-says-elden-rings-seamless-co-op-mod-is-definitely-not-something-we-actively-oppose-and-may-even-consider-ideas-like-that-with-our-future-games/))
- **"over 8.6 million installs"** per PCGamesN's Dark Souls 3 announcement piece (undated precisely, contextually early 2025 — [pcgamesn.com](https://www.pcgamesn.com/dark-souls-3/seamless-coop-mod))
- **Endorsements**: 71,915 (Jun 2025 snapshot) → 77,332 (Sept 2025 snapshot); **23,965 Nexus comments/posts** by Sept 2025 ([Wayback](https://web.archive.org/web/20250911070433/https://www.nexusmods.com/eldenring/mods/510?tab=files)). Exact live unique/total-download counters render client-side and are not captured by Wayback snapshots, so no single authoritative current figure could be verified directly.

**Industry validation**: when PC Gamer interviewed FromSoftware president **Hidetaka Miyazaki** for the Shadow of the Erdtree cover story, he was asked directly about the mod and said: *"It's definitely not something we actively oppose or want to downplay... That's not to say we won't consider other ways like you and your friend played, from beginning to end, total co-op—that's not to say we won't consider ideas like that with our future games."* ([pcgamer.com](https://www.pcgamer.com/games/rpg/fromsoftwares-says-elden-rings-seamless-co-op-mod-is-definitely-not-something-we-actively-oppose-and-may-even-consider-ideas-like-that-with-our-future-games/)). This is a strong, verified signal that this exact design space is being watched by the original developers, directly relevant to the MH Wilds project's premise.

## Feature list (complete)

From the full Nexus description ([Wayback, 21 Dec 2025 snapshot](https://web.archive.org/web/20251221040514/https://www.nexusmods.com/eldenring/mods/510)) and version articles:

- Play from tutorial to final boss in one unbroken co-op session, up to **6 players** (host + 5) in the open world.
- Death respawns at the last Site of Grace rested at; **the session is never terminated** by death.
- Defeating bosses/clearing areas no longer ends co-op or sends phantoms home.
- All fog walls/barriers that normally gate multiplayer zones, and their teleports, are removed.
- Torrent (whistle) usable by all players simultaneously.
- Map waypoint markers synchronize across the party.
- **NPC dialogue and "talk events" synchronize.**
- Resting at a Site of Grace **resets world state for everyone** (respawns enemies etc.).
- Game-progression events completed in co-op also progress each player's own (solo) world.
- Custom peer-to-peer netcode "overhaul," rewritten onto **Steam's newer networking API**, replacing reliance on From's own net code (completed v1.4.0, see Update model below).
- **EAC (Easy Anti-Cheat) fully disabled** by the launcher — enables using other mods together and eliminates EAC-related disconnect/packet-loss bugs.
- Faster reconnection — guests can rejoin the host "from anywhere in the world."
- **Scaling customization**: separate health/damage/posture multipliers for regular enemies vs. bosses.
- If one player rests at a grace while others are mid-boss-fight, those players are pulled out of the boss room.
- **Death during a boss fight/invasion → limbo/spectate mode** until the whole party wipes or someone rests at a grace (an `always_spectate_on_death` option later made this apply to *all* deaths, not just boss fights — v1.9.5 changelog).
- **"Rot" debuff system**: dying in co-op can inflict one of 5 random stacking rot debuffs, curable only at a grace — explicitly designed to stop one player death-farming while others keep enemies from respawning.
- **Invasions (optional, `allow_invaders`)**: other players can invade as an "evil spirit" via a dedicated item; host can't warp/rest while an invader is present; invader cooldown was increased from 5 to 10 minutes (v1.9.2) to curb griefing.
- v2.0.0 (experimental) added **PvP/PvE modes** — Teams/Brawl PvP, Easy/Medium gauntlet PvE waves, boss-rush arenas accessible via shrines — and raised the theoretical cap to **127 players** (only tested to 15) ([Nexus article #275](https://web.archive.org/web/20250530055826/https://www.nexusmods.com/eldenring/mods/510?tab=articles)).
- Friendly-fire/PvP toggle via the **Judicator's Rulebook** item.
- Steam achievements still work.
- Community-contributed **localization/translations**, loadable via `mod_language_override`.
- Full **Shadow of the Erdtree DLC** support (required a full rewrite/extended beta after DLC launch).
- Separate save file extension (**`.co2`** by default, configurable) — vanilla `.sl2` saves are untouched.
- A **cross-mod, cross-title cheater ban list** (`GLOBALBLOCKSYNC`/`GLOBALRESTRICTSYNC`, downloaded at launch) — see Technical architecture.

## Session/UX flow

**Install**: download manually from Nexus or the GitHub releases mirror, drop `ersc_launcher.exe` plus a `SeamlessCoop` folder (containing `ersc.dll`, `ersc_settings.ini`, locale files) into the game's `Game` folder; edit the password in the ini; launch via `ersc_launcher.exe` instead of the normal exe ([Nexus description](https://web.archive.org/web/20251221040514/https://www.nexusmods.com/eldenring/mods/510); community docs at [ersc-docs.github.io/how-to-install-and-update](https://ersc-docs.github.io/how-to-install-and-update/)). Players can also run it through **ModEngine2** by adding `"SeamlessCoop/ersc.dll"` to that loader's `external_dlls` list, which is required if combining it with other DLL-injected mods ([ersc-docs.github.io/seamless-modding](https://raw.githubusercontent.com/ersc-docs/ersc-docs.github.io/cb400c10fccaabc67d8cfb001d29540b42b1b25b/pages/seamless-modding.md)).

**In-session ritual**, driven entirely by six new inventory items auto-granted at the next Site of Grace rest (confirmed IDs from [ersc-docs FAQ](https://ersc-docs.github.io/faq/)):

| Item | ID | Function |
|---|---|---|
| Tiny Great Pot | 8380001 | Host: open a lobby/session |
| Effigy of Malenia | 8380002 | Guest: join as cooperator |
| Challenger's Lynchpin ("hairpin") | 8380003 | Join a random matching session as an invader |
| Separation Mist | 8380004 | Leave; if used by host, disbands everyone |
| Judicator's Rulebook | 8380005 | Toggle friendly fire / PvP modes |
| Rune Decanter | 8380006 | Rune-arc-related shop item |

Matching requires: identical **password**, identical **Elden Ring version**, identical **mod version**, identical **mod-set/regulation.bin** if using other mods, both parties signed into Steam online (not offline mode) and not blocking each other ([ersc-docs FAQ](https://ersc-docs.github.io/faq/)). "Failed, no session found" is explicitly the most common support request and is 95% of the time a version mismatch, not a password typo.

**Progression/authority model** (directly relevant to MH Wilds design), per the community FAQ:
- **Host's world is authoritative.** "Wanderer's progression will not sync if Host has progressed less than the Wanderers."
- NG and NG+ characters can play together.
- Shop/crafting-kit unlocks (e.g., Twin Maiden Husks) are gated by the **host's** unlocks.
- Loot is split into **instanced drops** (randomized per player individually) vs. **persistent-enemy drops** (bosses/scarabs — shared once collected when everyone is in the area).
- Explicit warning: "Quest progression can be erratic. Best to be solo when doing anything... make a backup save before playing," because event flags toggled in a session can persist and create mismatched/ruined progression across characters.

## Settings (ersc_settings.ini)

Confirmed directly from the official install guide and a live community mirror ([ersc-docs.github.io install guide](https://ersc-docs.github.io/how-to-install-and-update/); [carrolldeo/EldenRingConnect mirror](https://raw.githubusercontent.com/carrolldeo/EldenRingConnect/main/SeamlessCoop/ersc_settings.ini)):

```ini
[GAMEPLAY]
allow_invaders = 1          ; other players can invade and fight you/your party
death_debuffs = 1           ; Rot Essence debuff on death, cured at a grace
allow_summons = 1           ; spirit ashes usable in multiplayer
overhead_player_display = 3 ; 0=Normal 1=None 2=Ping 3=Soul level 4=Death count (added later)

[SCALING]
enemy_health_scaling = 35   ; % of VANILLA per-player scaling formula applied, for trash enemies
enemy_damage_scaling = 0
enemy_posture_scaling = 15
boss_health_scaling = 100   ; same but for bosses
boss_damage_scaling = 0
boss_posture_scaling = 20

[PASSWORD]
cooppassword = <shared secret, must match exactly for all players>

[SAVE]
save_file_extension = co2  ; alphanumeric, ≤120 chars — lets you run parallel save "tracks"

[LANGUAGE]
mod_language_override =    ; blank = follow game language; else load a custom locale file
```

Important nuance confirmed by both the Nexus text and PC Gamer's later Nightreign coverage: scaling values are **relative to the vanilla per-player scaling curve**, not an absolute add — "if an enemy gets 25% more health per player in the base game, setting health_scaling to 50 would mean a gain of 12.5% health" ([pcgamer.com](https://www.pcgamer.com/games/rpg/elden-ring-nightreigns-seamless-co-op-mod-now-allows-up-to-6-players-but-wont-add-any-more-as-the-game-just-becomes-comically-easy/)). The enemy/boss split lets groups keep trash fights fast while still scaling the fights that matter.

## Technical architecture & ban-avoidance

**Launch/injection**: `ersc_launcher.exe` starts the game **without triggering Easy Anti-Cheat** at all — the install guide's own verification step is "if there is no EAC splash screen on launch, the mod was installed correctly" ([ersc-docs how-to-install](https://ersc-docs.github.io/how-to-install-and-update/)). The actual payload is a DLL (`ersc.dll`) that can be loaded either by the dedicated launcher or by **ModEngine2** (the established open-source DLL/asset-override loader used across the FromSoftware modding community), confirming the mod is architecturally a conventional injected-DLL hook, not a game-file patch.

**Netcode**: the mod description states an "overhaul to Elden Ring's Peer-to-Peer connection system, using Steam's newer networking API." The v1.4.0 changelog elaborates this was a deliberate rewrite: *"The mod previously relied on a lot of Elden Ring's own networking backend... As of this update, I'm happy to announce that the game is now running on seamless co-op's own networking system"* ([Nexus article #212](https://web.archive.org/web/20250530055826/https://www.nexusmods.com/eldenring/mods/510?tab=articles)), which also fixed the frequent EAC-induced disconnects.

**Ban-avoidance mechanism** (stated plainly and consistently across every title's FAQ): (1) the mod **never contacts FromSoftware's matchmaking servers**; (2) it uses a **separate save-file extension** so modded saves can't be loaded by the vanilla game; (3) **EAC is not launched**. Combined, "there's no way to get banned using this mod unless you modify it with the intent of connecting to vanilla players." A Steam Community thread verbatim-confirms the practical risk is user error, not the mod itself: *"I was banned because I accidentally extracted the mod to the Elden Ring folder itself, instead of the Elden Ring/Game folder... At the time I simply wasn't paying attention"* (180-day ban) — [steamcommunity.com, app 1245620](https://steamcommunity.com/app/1245620/discussions/0/4511002214534881824/).

**Anti-cheese / cheating controls without an anti-cheat engine**: Yui runs a **personally curated, cross-title ban list**. The `SeamlessCoopGlobalSyncList` repo explains: *"List of SteamIDs who have been banned from ALL seamless co-op mods for cringe worthy cheats. Seamless co-op will download this list on launch and restrict play for these users"* — split into `GLOBALBLOCKSYNC` (full ban) and `GLOBALRESTRICTSYNC` (restricted from random matchmaking/invasions only); *"All reports are verified by myself personally with video evidence"* ([github.com/yuiamoroll/SeamlessCoopGlobalSyncList](https://github.com/yuiamoroll/SeamlessCoopGlobalSyncList)).

**Version gating**: each release repo contains a flat `VERSION` ledger mapping game-version strings to a compatibility flag, e.g. the Elden Ring repo's file lists `1.41 1`, `1.99 1`, `>2.01 1` against a long run of `0`s ([raw VERSION file](https://raw.githubusercontent.com/yuiamoroll/EldenRingSeamlessCoopRelease/main/VERSION)) — a minimal, low-tech "is my game version known-good" check the launcher presumably reads before allowing a session.

**Anti-virus friction**: the v1.9.2 changelog records *"Removed some post-build virtualisation which was causing antivirus false flags"* — consistent with (unverified, see below) secondhand reports that the shipped DLL is packed/virtualized (e.g., with a commercial protector), which is a known cause of AV heuristic false positives.

**Source availability**: **closed source.** The FAQ is explicit: *"Can I modify or redistribute this mod? No, sorry. Please do not modify, repackage, or redistribute this mod anywhere without my permission."* The GitHub repos are binary-release mirrors with changelog text only — confirmed directly (each repo's file tree contains only `README.md`, `VERSION`, `BLOCKSYNC`, and for Nightreign some game-specific flag files; no source code).

**Credits suggest a small circle of collaborators**, not a solo black box: *"Special thanks to Tremwil for his advice, prolonged assistance and code"* and *"Thanks to Oroboro for help with PvP matchmaking tiers"* ([Nexus description](https://web.archive.org/web/20251221040514/https://www.nexusmods.com/eldenring/mods/510)).

**Independent reverse-engineering attempts exist but are limited**: a search surfaced a repo (`nkmlombardi/seamless-coop-re`) purporting to contain a `REVERSE_ENGINEERING_REPORT.md` describing the DLL as Themida-packed with a custom hooking/signature-scanning framework — **this could not be independently verified**: the repository returned 404 on direct fetch via both the GitHub API and the Wayback Machine, so this detail is reported here only as an unconfirmed secondhand claim from search-engine summaries, not a verified fact. More concretely, Yui's own Patreon post (dated implicitly Oct 2026) confirms third parties now use **AI tools to patch the mod's broken byte-signatures after game patches without her involvement**: *"I did unfortunately get my first taste of people using AI to analyse and attempt to update the mod without my input... although these AI models were able to fix some of the signature issues, they did not update any of the structures inside the mod, and therefore, the mod was still unstable"* ([patreon.com/yuiamoroll](https://www.patreon.com/yuiamoroll/posts/update-general-171717729)). This is a first-hand-confirmed data point that the mod's hook points are **byte-signature-based** (classic pattern-scanning against game memory/binary), which is exactly the kind of fragile-to-patches technique that should inform expectations for an MH Wilds equivalent.

## Update/maintenance model

The mod is effectively **solo-maintained** (supported via [Ko-fi](https://ko-fi.com/lukeyui) and [Patreon](https://www.patreon.com/c/LukeYui)) across now **seven titles simultaneously** (Elden Ring, Dark Souls Remastered, Dark Souls II, Dark Souls III, Sekiro, Armored Core VI, Elden Ring Nightreign). Every FromSoftware patch breaks the mod until Yui updates it; community documentation puts the turnaround at **"1-7 days"** historically ([thegamercodex.com](https://thegamercodex.com/en/elden-ring/tools/seamless-coop)), and Yui's own account of the August 2026 "Elden Ring Tarnished Edition" patch says the turnaround was quick ("over a couple of days") despite signature breaks. The official docs warn users plainly: *"Major game patches can temporarily break mods... wait for a compatible Seamless Co-op build instead of mixing versions"* ([seamlesscoop.net/update](https://seamlesscoop.net/update/)).

Primary-source project status (from Yui's own Oct 2026 Patreon update, [patreon.com/yuiamoroll/posts/update-general-171717729](https://www.patreon.com/yuiamoroll/posts/update-general-171717729)):
- **Dark Souls Remastered** — BETA, stalled ("No further development has taken place since my last post")
- **Dark Souls II** — ALPHA, released 22 Sept 2026, actively being patched; added proximity voice chat ("the PvP and Invasion community seem to really enjoy the addition... allowing communication between players") and working covenant mechanics, both slated to be ported to the other titles
- **Dark Souls III** — ALPHA, currently paused
- **Elden Ring** — BETA, actively maintained, most recently patched for the Aug 28 2026 game update
- **Elden Ring Nightreign** — marked **"Complete"**: once FromSoftware shipped official duo-queue support, "the only real use this mod has over the vanilla game is mod support and increasing player cap," and development effectively stopped ([pcgamer.com](https://www.pcgamer.com/games/rpg/elden-ring-nightreigns-seamless-co-op-mod-now-allows-up-to-6-players-but-wont-add-any-more-as-the-game-just-becomes-comically-easy/))
- **Armored Core VI** — ALPHA, self-described as neglected: *"It is very difficult to get back into, though, as I fundamentally do not enjoy the game"*
- **Sekiro** — unreleased/TBA: *"the mod is semi functional in its current state. I will, however, put this on ice"*; supersedes Yui's own earlier, separate, non-seamless **"Sekiro Online"** mod from 2020, for which she has "ended support"

The same post closes on a telling maintenance-burden note: *"I think that I'm going to take a small hiatus... to help my arm recover from the tendonitis."* This is a real, first-hand-confirmed **bus-factor risk** worth weighing for any similarly-scoped project (see Key takeaways).

## Related LukeYui mods

| Title | Nexus page | Status (Oct 2026) | Notable detail |
|---|---|---|---|
| Elden Ring | [mods/510](https://www.nexusmods.com/eldenring/mods/510) | Beta, active | Flagship; full feature list above |
| Dark Souls Remastered | [darksoulsremastered/mods/899](https://www.nexusmods.com/darksoulsremastered/mods/899) | Beta, stalled | Released ~10 Apr 2025, built in "only a week" after DS3 — but world-streaming (loading/unloading distant map chunks around the host) "took a good amount of reverse engineering" ([Polygon](https://www.polygon.com/news/557559/dark-souls-remastered-seamless-co-op-mod/)) |
| Dark Souls III | [darksouls3/mods/1895](https://www.nexusmods.com/darksouls3/mods/1895) | Alpha, paused | Progress sync, optional invasions on by default, adjustable scaling; confirmed boss-cutscene desync bug (see Community reception) |
| Dark Souls II: SotFS | [darksouls2/mods/1468](https://www.nexusmods.com/darksouls2/mods/1468) | Alpha, active | Released 22 Sept 2026; added proximity voice chat + covenant mechanics |
| Armored Core VI | [armoredcore6firesofrubicon/mods/3](https://www.nexusmods.com/armoredcore6firesofrubicon/mods/3) | Alpha, neglected | Up to 6 players; rogue-AC PvP invasions scale 1:1 with co-op party size (capped at 6 total); all missions except "Ice Worm"; confirmed via archived description + [DSOGaming](https://www.dsogaming.com/mods/armored-core-6-co-op-mod-available-for-download/) |
| Elden Ring Nightreign | [eldenringnightreign/mods/3](https://www.nexusmods.com/eldenringnightreign/mods/3) | "Complete" | Released 30 May 2025 (ships day of patch 1.02 duo-queue); no progress-sync needed (roguelite run structure); notably **calls out to GitHub** to fetch Everdark-boss rotation data it otherwise can't get without touching FromSoft's matchmaking servers — a creative workaround for "server-authoritative-only" data |
| Sekiro | n/a yet | TBA / "on ice" | Supersedes her own 2020 "Sekiro Online" (non-seamless), now unsupported |

A shared cross-title asset, `SeamlessCoopGlobalSyncList`, synchronizes a cheater ban list across all of the above. All titles share the identical UX grammar (item-based lobby open/join/leave ritual, password-gated matchmaking, dedicated launcher, EAC bypass, separate save extension) — strong evidence this is now a deliberate, reusable **product template**, not a one-off.

## Similar open-source projects & patterns

Unlike Seamless Co-op itself, several comparable projects are genuinely open source and show implementable patterns:

- **Skyrim Together Reborn** (`tiltedphoques/TiltedEvolution`, actively forked e.g. at `AHilyard/SkyrimTogetherReborn`) — fully open-source C++, and architecturally instructive precisely because its source is public: a **host-client model** (not pure mesh P2P), custom UDP protocol, and a clean separation into `client/` (game-side plugin), `server/` (authoritative game-state/session server, runnable standalone or dedicated via Docker), `common/` (shared types), and `encoding/` (wire-format/packet message definitions). This is a good template for how to *organize* an equivalent MH Wilds codebase even though it is a different engine/game.
- **ModEngine2** (`soulsmods` community) — open-source generic DLL-injection/asset-override loader for FromSoftware titles; Seamless Co-op explicitly supports launching through it as an alternative to its own launcher. The pattern worth copying: **decouple "get a DLL hooked into the process" from "the multiplayer logic itself,"** so the mod can plug into whichever loader a user's broader mod stack already uses.
- **sekiro-seamless-coop** (`SanguineLoki700/sekiro-seamless-coop`, GitHub, created Oct 2026) — an *independent, in-progress, explicitly 0%-functional* attempt to build a Yui-style seamless co-op for Sekiro from scratch. Its value here is as a **transparent worked example of the problem difficulty**: its own docs state a staged roadmap (native RE research → safe DLL integration with isolated saves → 2-player proof → 4-player → campaign → release) and describe the *intended* architecture before any of it is built: *"the host will confirm enemies, health, posture, executions, rewards, and world events; clients will present their character immediately and receive limited corrections"* — i.e., classic **client-side prediction with host-authoritative reconciliation** ([docs/ROADMAP.md](https://raw.githubusercontent.com/SanguineLoki700/sekiro-seamless-coop/main/docs/ROADMAP.md)). Its research log shows real reverse-engineering mechanics: using Ghidra/RTTI to identify the game's `WorldChrManImp` character-manager class via a read-only live probe, and explicitly cautions that "no gameplay profile is enabled by this finding" even after static+live confirmation ([docs/RESEARCH.md](https://raw.githubusercontent.com/SanguineLoki700/sekiro-seamless-coop/main/docs/RESEARCH.md)). **Takeaway: even a focused, competent team treats "find the player-manager singleton" as just step one of many**, months before any playable build — a realistic calibration point for scoping an MH Wilds effort.
- **des-seamless-coop** (`himingal/des-seamless-coop`) — "seamless co-op for Demon's Souls on RPCS3... built-in party server, summon signs that follow the host, co-op patch and a one-click installer" — shows the "seamless co-op" format has become a recognized genre convention that other teams replicate even on emulated console targets, generally keeping the "summon sign/item follows host" idiom.
- **Nordgaren's Elden Ring Debug Tool** (community, linked throughout ersc-docs) — a companion flag-editor used to manually repair desynced world-state/event flags. Its existence as a *second, separate* community tool is itself a lesson: a mature seamless co-op mod apparently needs an escape-hatch debug tool because full automatic flag-sync correctness isn't fully achievable.
- **RE Engine note**: MH Wilds runs on Capcom's RE Engine, the same family as Resident Evil/DMC5/Monster Hunter Rise. The dominant modding foundation there is **`praydog/REFramework`** — an open-source hooking/scripting/VR platform — but it is explicitly *not* a multiplayer solution, and no existing "seamless co-op"-style overhaul for any RE Engine title was found in this research. This is a meaningful difference from the Souls space, which already had years of community RE and ModEngine2 before Yui started; an MH Wilds project has less engine-specific precedent to stand on.

## Community reception (praise / complaints / requests)

**Praise** (verbatim, with links/dates):
- *"Elden Ring's Seamless Coop mod was something I really wanted from the get-go given the game was open-world, now they actually did it. I'm so hyped. I'm not a pvper in these games, I love working together with friends and randoms to beat bosses, this is exactly right up my alley"* — Steam Community, Dec 12, 2024 ([steamcommunity.com, app 2622380](https://steamcommunity.com/app/2622380/discussions/0/501685433118292839/)).
- *"You do not know how the Seamless mods work, huh lmao. It prevents you from connecting to fromsoft servers, it uses different saves, and it doesn't use EAC. It's safer for modding than playing the base game"* — Steam Community, May 31, 2025 ([steamcommunity.com, app 2622380](https://steamcommunity.com/app/2622380/discussions/0/597402319036893516/)).
- Miyazaki/FromSoftware's acknowledgment (quoted in full above) is arguably the single strongest third-party validation found.

**Complaints / bugs** (verbatim where possible):
- **Cutscene desync during boss fights** (directly relevant to the MH Wilds "watch cutscenes together" goal): *"DS3 SC have its share of bugs. For instance Boss fights with cutscenes either before the fight starts or during the fight (Second phase transitions) for instance Wolnir have a tendency to glitch if playing with friends IE your partner(s) will be sent into a perpetual loop of watching the cutscene, and sometimes Wolnir might just off himself and just give you his soul"* — Steam Community, Jun 7, 2025 ([steamcommunity.com, app 374320](https://steamcommunity.com/app/374320/discussions/0/596276966209913803/)).
- **Quest/NPC-dialogue desync** is pervasive and documented at length in the official FAQ/workarounds docs — quests like Millicent, Sellen/Jerren, Yura, and Varre routinely "lock up" or fail to reward guests; the standing community-sanctioned workaround is simply **"do it solo and back up your save first"** ([ersc-docs.github.io/faq](https://ersc-docs.github.io/faq/), [ersc-docs.github.io/workarounds](https://ersc-docs.github.io/workarounds/)), reinforced by a popular Steam pinned-fix thread ([steamcommunity.com, app 1245620](https://steamcommunity.com/app/1245620/discussions/0/6982351509008261056/)).
- **Accidental bans from misinstallation**, not mod flaws per se: *"I was banned because I accidentally extracted the mod to the Elden Ring folder itself, instead of the Elden Ring/Game folder... I feel that's a very easy mistake to make"* ([steamcommunity.com, app 1245620](https://steamcommunity.com/app/1245620/discussions/0/4511002214534881824/)).
- **Version/password mismatch confusion** is, per every community doc reviewed, the single most common support request — almost always a silent version mismatch misread as "the password must be wrong."
- **Patch-breakage windows**: *"Version-locked to the game patch: when Bandai patches ER, Seamless takes 1-7 days to update. During that window, you can't play"* and *"Basic netcode: lag and desyncs happen especially with 5-6 players. For 2-3 people the experience is stable; for 6 it fluctuates"* ([thegamercodex.com](https://thegamercodex.com/en/elden-ring/tools/seamless-coop)).
- **Branding confusion** specific to Nightreign, where no progress-sync is needed/offered: *"…Why is it called seamless then? That's not what seamless means. Just call it a duo mod."* — Steam Community, May 31, 2025 ([steamcommunity.com, app 2622380](https://steamcommunity.com/app/2622380/discussions/0/597402319036893516/)).
- **Difficulty collapse at high player counts**: the 6-player cap on Nightreign was a deliberate ceiling because, per the creator, "even with a very high scaling curve for enemies, the game just becomes comically easy" beyond that ([pcgamer.com](https://www.pcgamer.com/games/rpg/elden-ring-nightreigns-seamless-co-op-mod-now-allows-up-to-6-players-but-wont-add-any-more-as-the-game-just-becomes-comically-easy/); corroborated by [wardrome.com](https://wardrome.com/elden-ring-nightreigns-seamless-co-op-mod-review/)).

**Feature requests and how they resolved**: more players (delivered experimentally to 127/tested-15 in ER v2.0.0; capped deliberately at 6 in Nightreign); proximity voice chat (delivered in DS2, planned to backport); working covenants (delivered in DS2, planned to backport); random matchmaking/ranked PvP — explicitly declined long-term: *"I have no plans on adding PvP and/or random matchmaking"* (Yui, via PC Gamer).

**Caveat on sourcing**: direct fetches of reddit.com and old.reddit.com were consistently blocked by a Cloudflare interstitial in this research session, so Reddit-specific sentiment here is represented only indirectly (via AI web-search synthesis of Reddit threads, not primary-sourced quotes) — all **verbatim, linked quotes** above come from directly-fetched **Steam Community** discussion threads instead, which were accessible. No dedicated `r/SeamlessCoop` subreddit was found to exist; discussion is spread across `r/EldenRingMods`, `r/Eldenring`, and per-game Steam forums.

## Key takeaways for the MH Wilds Seamless Co-op project

1. **Host-authoritative progression is the proven, if imperfect, model.** Every ERSC title makes the host's world canonical for quest/event flags and gates shop/crafting unlocks on host state. Expect the same trade-off in MH Wilds: guests' solo-save quest flags likely need explicit propagation logic, not just "whoever finishes it first." Budget real engineering time here — this is the #1 complaint category across every title reviewed.
2. **Cutscene synchronization is a known weak point**, confirmed by a direct, verbatim bug report (DS3's Wolnir "perpetual loop of watching the cutscene"). Since the MH Wilds project's explicit goal is "watch cutscenes together," this deserves dedicated design attention: a clear cutscene-start barrier (wait for all party members to be ready), a host-authoritative skip/advance signal, and a timeout/recovery path if a client desyncs mid-cutscene.
3. **Plan for a companion debug/repair tool from day one**, not as an afterthought. Even a 3+ year, actively-maintained project still needs Nordgaren's third-party flag-editor and an "ER Save Manager" to fix desyncs the mod itself can't prevent. A sanctioned, built-in "repair session state" function would reduce support burden versus ERSC's current "redo it solo + keep backups" guidance.
4. **Version lockstep is unavoidable but the error messaging can be better.** ERSC's generic "Failed, no session found" is confirmed (by multiple independent docs) to be the most common point of user confusion, almost always actually a silent version mismatch. A Wilds mod should diagnose and report the *specific* mismatch (game build hash, mod version, active mod list) rather than a generic connection failure.
5. **Budget for a 1–7 day break/fix cycle after every Capcom title update**, mirroring the confirmed FromSoftware-patch cadence. A simple version-ledger file (as crude as ERSC's flat-text `VERSION` list) is a cheap, working way to gate "known-good" launches.
6. **Solo-maintainer bus factor is a real, confirmed risk** — Yui's own words describe tendonitis and multi-project burnout while solo-supporting seven titles. An MH Wilds project should consider a small core team and documented (even if not public) architecture from the start, rather than replicate the single-point-of-failure model.
7. **The ban-avoidance formula is well-proven and portable in principle**: never touch the publisher's online services, use a separate save slot/extension, and skip/avoid the anti-cheat process entirely. Whether and how this maps to MH Wilds depends on Capcom's specific anti-cheat/account-flagging implementation — flagged here as a dependency for a different research thread, not verified for MH Wilds in this report.
8. **A lightweight, developer-curated shared ban list** (`GLOBALBLOCKSYNC`) is a cheap substitute for a real anti-cheat in small, trust-based party sessions, and is worth replicating rather than building full anti-cheat tooling.
9. **Split scaling by encounter type**, exactly as ERSC splits "enemy" vs. "boss" multipliers, expressed as a *percentage of the vanilla per-player curve* rather than a flat bonus — this maps directly onto the user's own framing of MH Wilds' "defeat small monsters" vs. "large monster fight" segments, and the relative-curve approach should generalize better across MH's huge monster-to-monster HP variance than an absolute bonus would.
10. **A death/limbo "spectate" state beats hard session failure.** ERSC's limbo-and-rot system keeps the party together through a death instead of ejecting the player; Monster Hunter's existing "cart" mechanic is a natural analog to extend into the newly-shared pre-SOS segments (e.g., a player knocked out during a shared "defeat small monsters" objective could spectate/wait rather than being dropped from the session).
11. **Scope the ambition honestly and name it accordingly.** The Nightreign mod's backlash over being called "seamless" when it was really "a duo mod" shows that the ERSC brand sets a very specific expectation (full continuity) — the MH Wilds project's narrower, explicitly-scoped goal (pre-SOS walk/talk/cutscene/small-monster segments only, since vanilla already handles the large-monster-hunt join) should be communicated clearly as exactly that scope, both to avoid over-promising and because it is, per the Nightreign precedent, a legitimate and well-received scope-down strategy (build only the bridge the base game is missing).
12. **A mod can "complete" and retire gracefully** — Nightreign Seamless Co-op reached feature-complete status and stopped once FromSoftware shipped official duo support. If Capcom ever extends MH Wilds' own early-quest co-op, the project should be built so it can sunset cleanly rather than fight the base game indefinitely. The Miyazaki quote is a reminder that publishers do sometimes watch and absorb these mods' lessons.
13. **No RE Engine precedent exists yet for this kind of mod** — REFramework is a hooking/scripting platform, not a multiplayer solution, and this research found no existing seamless-co-op-style project for any RE Engine title. This raises technical risk relative to Yui's starting position (which benefited from ModEngine2 and years of prior Souls-engine RE) but also means there's a genuine first-mover opportunity.

## Open questions / couldn't verify

- **Exact wire protocol/packet structure** used by ERSC's Steam-networking rewrite — the source is closed and no verified technical teardown was found.
- The `nkmlombardi/seamless-coop-re` reverse-engineering report (claims re: Themida packing, hooking framework, signature scanning) **could not be independently confirmed** — the repository 404'd on direct access via both GitHub's API and the Wayback Machine; treat any claim sourced to it as unverified.
- A single, authoritative, current unique-download count for the Nexus page — live counters are JS-rendered and not captured in any Wayback snapshot checked; only point-in-time third-party citations (2M–8.6M across different 2024/2025 dates) could be gathered.
- Full scope of **"Tremwil"** and **"Oroboro"**'s code contributions, and whether they remain active collaborators as of 2026 — only the one-time Nexus description credit line was found.
- Direct Reddit-sourced verbatim quotes were not obtainable in this session (Cloudflare-blocked on all attempted reddit.com/old.reddit.com fetch paths, including `.json` suffixes); reception evidence here leans more heavily on Steam Community (directly fetched) than Reddit.
- Precise current (Oct 2026) build/version number and feature state of the **Armored Core VI** co-op mod beyond the creator's own "ALPHA, neglected" self-assessment.
- Whether MH Wilds' own anti-cheat/online-service architecture would allow an analogous "never touch publisher servers + separate save" ban-avoidance strategy — explicitly out of scope for this thread and left for other research.
