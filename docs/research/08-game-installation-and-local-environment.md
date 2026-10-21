# 08 — Game installation, technical facts & local environment

> Research note for **Seamless Co-op (Monster Hunter Wilds)**. Gathered 2026-10-20.
> Sources: PCGamingWiki (wikitext via API), Steam store page, Game8 patch notes, and read-only
> inspection of the local Steam install on the developer PC.

## 1. Game identity & technical facts

| Item | Value | Source |
|---|---|---|
| Title / developer | Monster Hunter Wilds — Capcom | PCGamingWiki |
| Engine | **RE Engine** (same family as MH Rise, RE2/3/4/7/8, DD2, SF6) | PCGamingWiki |
| Release (PC) | 2025-02-28 | PCGamingWiki |
| Steam App ID | **2246340** (main depot 2246341; DLC depot 3308900 ≈ 32 GB installed locally — very likely the free *High Resolution Texture Pack*, unverified) | PCGamingWiki, local `appmanifest_2246340.acf` |
| Executable | `MonsterHunterWilds.exe`, x64 only, D3D12 only, AVX2 required | PCGamingWiki, local folder |
| Mapped module size | `0x2079C000` (~520 MB) at base `0x140000000` | local REFramework log |
| DRM | **Steam + Denuvo** ("All versions require Steam DRM and Denuvo") | PCGamingWiki |
| Integrity checks | Present — REFramework logs `[IntegrityCheckBypass]: Hooked VirtualProtect!` | local REFramework log |
| Multiplayer middleware | **Microsoft Azure PlayFab** (`PartyWin.dll` in the game folder = PlayFab Party native library) | PCGamingWiki "Middleware", local folder |
| Online play | 4 players per quest; **crossplay with PS5 and Xbox Series** | PCGamingWiki "Network" |
| Other middleware | Wwise (audio), DirectStorage 1.2.3, DLSS 4 / FSR 4 / XeSS, Streamline (`sl.*.dll`), NVIDIA Aftermath | PCGamingWiki, local folder |
| Steam API | `steam_api64.dll` shipped (Steam friends/invites/overlay; game networking itself is PlayFab) | local folder |
| Anti-cheat | None listed by PCGamingWiki (unverified — see 05-wilds-modding-ecosystem.md) | PCGamingWiki |

### Versions & content roadmap
- Latest **major** update found: **Ver.1.042.00.00 — 2026-08-04** (prologue demo, offline event quests,
  bug fixes) — [Game8](https://game8.co/games/Monster-Hunter-Wilds/archives/613320).
  Earlier reference points: Ver.1.020.00.00 (2025-06-27, DLSS MFG), Ver.1.041.00.00 (2026-02-18).
- Local Steam **buildid 24705561**, `LastUpdated` ≈ 2026-08-31 (likely a hotfix after 1.042).
- **Online multiplayer requires the latest game version** (stated in update notes) → the mod must
  track the current version; there is no value in supporting old builds.
- **Expansion "Monster Hunter Wilds: Ascendance" is announced for 2027** (PCGamingWiki) — new story
  content will arrive later; design should not hard-code an assumption that the story set is final.
- A **Prologue Demo** exists (Steam) — online features are not available in it (irrelevant for us,
  but note that demo saves can transfer to the full game).

## 2. File locations (Steam, this PC)

| What | Path |
|---|---|
| Game folder | `C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds` (default Steam library on C:) |
| Config | `<game>\config.ini` |
| Saves | `<Steam>\userdata\<steam-user-id>\2246340\remote\win64_save` — **Steam Cloud enabled** |
| Game data | `re_chunk_000.pak` + `.patch_001…015.pak`, `re_chunk_000.pak.sub_000.pak` + patches, `dlc\` |
| REFramework | `<game>\dinput8.dll` (loader), `<game>\reframework\{autorun,data,fonts,plugins}` |
| REFramework logs/config | `<game>\re2_framework_log.txt`, `<game>\re2_fw_config.txt` |
| Steam manifest | `C:\Program Files (x86)\Steam\steamapps\appmanifest_2246340.acf` |

## 3. Mods / tools already installed on this PC (observed, read-only)

- **REFramework nightly** — tag `v1.5.9.1` + 438 commits, commit `28e7be74df76d04b00622c27766a8a2dbfd2e217`,
  built 2026-03-14, branch master, game name `mhwilds`. At startup it **copies the game's DLLs into a
  `_storage_` folder** and loads them from there (observed in log; purpose presumably related to Wilds'
  integrity checks/loader — to confirm), and hooks `VirtualProtect` / `NtProtectVirtualMemory`
  (integrity-check bypass).
  - `reframework\autorun` is **empty**; `reframework\plugins` holds only `DirectStorageOption.log`.
  - Loose-file loading artefacts present: `reframework_accessed_files.txt`, `reframework_loose_files.txt`,
    `reframework_faulty_files.txt`.
  - `Enums_Internal.hpp` in the game root — an enum dump produced by REFramework (useful for RE).
- **Fluffy Mod Manager** (`ModdedByFluffyModManager.txt`, `CrashReport_FMMBACKUP.exe`).
- **ReShade** (`dxgi.dll`, `ReShade.ini`, `reshade-shaders\`) + **RenoDX** HDR addon (`renodx-mhwilds.addon64`).
- `mhws-tex-decompressor.exe` (texture tool shipped with some texture mods).

**Implication:** the user already runs REFramework successfully on the current build, so REFramework is
a proven injection/scripting host on this machine. Any new mod must coexist with ReShade (dxgi proxy),
RenoDX and Fluffy-managed PAK/loose-file mods.

## 4. Developer machine

| Tool | Status |
|---|---|
| OS | Windows 11 (build 26200) |
| git | 2.43.0 ✅ |
| Node.js / npm | 24.20.0 ✅ |
| .NET SDK | present ✅ |
| winget | present ✅ |
| Visual Studio / MSVC Build Tools | ❌ not installed |
| CMake / Ninja | ❌ |
| Python 3 | ❌ (only the Microsoft Store alias) |
| Java / JDK (for Ghidra) | ❌ |
| Lua / lua-language-server | ❌ |
| GitHub CLI (`gh`) | ❌ |

## 5. Workspace-policy implications (from `C:\src\AGENTS.md`)

- Code lives under `C:\src`; everything outside it is treated as personal by default.
- The **game folder is outside `C:\src`** → deploying mod builds into `<game>\reframework\…` needs an
  explicit, scoped permission from the user (or a user-created directory junction pointing from the game's
  `reframework\autorun\<mod>` to the repo), and **save files must never be touched by the agent**.
- Nexus Mods blocks automated fetches (HTTP 403, Cloudflare). The Wayback Machine works for mod
  description pages. The user allowed Playwright with their Nexus account if necessary; policy requires a
  fresh browser profile and the user signing in themselves (no browser-saved credentials/cookies).

---

## Changes made on 2026-10-21 (user-approved, inside `<game>\reframework\` + REFramework loader only)
- REFramework updated to **nightly-01433** (`d4611aef1d63effd3a736bdf9404ea702428017d`, monolithic `dinput8.dll`).
  Previous loader backed up to `reframework\backups\dinput8.dll.v1.5.9.1+438-28e7be7.bak`.
- REFramework **C# API** (`csharp-api.zip`) extracted into `reframework\plugins\`.
- **re-engine-mcp** dev plugin source copied to `reframework\plugins\source\` (serves `http://localhost:8899` only).
- Revert manifest: `reframework\backups\CHANGES-seamless-coop-dev.txt`.
- Dev machine now has: VS 2022 Build Tools (MSVC 14.44), CMake 4.4.4, Ninja 1.13.2, Python 3.13.15, .NET SDK 10.0.402,
  lua-language-server 3.19.1, clangd 23.1.0, OpenJDK 21.0.12, Ghidra 12.1.4 (+GhidraMCP 2.0) in `C:\src\_tools`.
- **First launch verified (2026-10-21 00:13).** One-time C# reference-assembly generation took ~2.5 min (black screen):
  `_System.Private.CoreLib` (324 types), `viacore` (6,919), `application` (94,473) → `reframework\plugins\managed\generated\`.
  re-engine-mcp compiled and listened on `localhost:8899`; live TDB: 322,054 types, 1,970,957 methods, 711,740 fields.
  Live singletons confirmed: `app.MissionManager`, `app.NetworkManager`, `app.CutSceneGalleryManager`, `app.DialogueManager`.
  The generated `REFramework.NET.application.dll` is itself a typed SDK of the game (usable offline for type discovery).
