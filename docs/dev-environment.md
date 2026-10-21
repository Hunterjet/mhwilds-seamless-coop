# Development environment

How this machine was set up (2026-10-21) and how to reproduce it on the second test PC.

## 1. Toolchain

Run once per PC (one UAC prompt; safe to re-run):

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup\install-toolchain.ps1   # VS 2022 Build Tools (C++), CMake, Ninja,
                                                                              # Python 3.13, .NET 10 SDK, LuaLS, clangd, OpenJDK 21
powershell -ExecutionPolicy Bypass -File tools\setup\install-ghidra.ps1      # Ghidra 12.1.4 + GhidraMCP 2.0 → C:\src\_tools
```

Logs: `C:\src\.cache\logs\toolchain-install.log`. Downloads and package caches stay under `C:\src\.cache\`.

## 2. Game-side setup (inside `<game>\reframework\` only)

`<game>` = `C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds`.

| Change | Details |
|---|---|
| REFramework → **nightly-01433** (`d4611ae`) | Only `dinput8.dll` from `REFramework.zip` (per release notes). Old DLL backed up to `reframework\backups\dinput8.dll.v1.5.9.1+438-28e7be7.bak`. |
| REFramework **C# API** | `csharp-api.zip` → `reframework\plugins\` (REFramework.NET runtime; needs .NET 10). |
| **re-engine-mcp** game plugin (dev only) | `reframework\plugins\source\TestWebAPI.cs` + `WebAPI\` — compiled by REFramework at launch; serves `http://localhost:8899` only. |
| **Seamless Co-op dev build** | `reframework\autorun\seamless_coop.lua` + `seamless_coop\`, `reframework\plugins\seamless_net.dll` (+ `.pdb`), data in `reframework\data\seamless_coop\`. Installed/removed with `tools\deploy.ps1 -Mod [-Remove]` (§9). |

Everything is listed in `reframework\backups\CHANGES-seamless-coop-dev.txt`.
**First launch after installing the C# API shows a long black screen.** REFramework.NET generates .NET reference
assemblies for the entire game type database into `reframework\plugins\managed\generated\`. This happens
synchronously at startup and can take several minutes. It is cached (keyed by the game exe's SHA256 and the
REFramework.NET hash) and **regenerates after every game or REFramework update**. Don't close the game during it; follow
progress with `tools\dev\watch-reframework-log.ps1`.
**Revert:** close the game, copy the `.bak` back to `<game>\dinput8.dll`, delete the files listed in the manifest.
**Before normal online play:** remove `reframework\plugins\source\TestWebAPI.cs` and `WebAPI\`. The dev plugin can call
any game method, including sending chat.

## 3. Agent tooling (GitHub Copilot CLI)

- **Start Copilot CLI inside `C:\src\mhwilds-seamless-coop`** and trust the folder, so the project config loads:
  - `.mcp.json` → `reframework` (re-engine-mcp; works while the game runs) and `ghidra` (GhidraMCP; works while Ghidra runs).
  - `.github/lsp.json` → clangd (C/C++) and lua-language-server (Lua). Check with `/lsp`.
- User-level MCP servers: `context7` (library docs) and `microsoft-learn` (Win32/MSVC/CMake/PlayFab docs).
- Plugin: `modern-cpp@trailofbits` (C++ guidance). Marketplace `trailofbits` registered.

### Live game inspection (re-engine-mcp)
1. Launch the game via Steam. REFramework compiles the C# plugin on first launch; check the REFramework log for
   `[WebAPI] Listening on http://localhost:8899/`. Optional dashboard: open http://localhost:8899.
2. In Copilot CLI (inside the repo), call the `help` tool of the `reframework` server first, then use
   `get_singleton`, `search_types`, `inspect_object`, `chain`, and so on. Prefer read-only tools. Only call mutating
   tools (`invoke_method`, `write_field`) offline or in a private session.

### Native RE (only when needed)
1. Run `C:\src\_tools\ghidra_12.1.4_PUBLIC\ghidraRun.bat` (JDK 21).
2. In CodeBrowser: *File → Configure → Developer* → enable **GhidraMCPPlugin** (HTTP server on `127.0.0.1:8080`).
3. Prefer analysing a memory dump plus `ree-pdb` symbols over the Denuvo-protected exe on disk (see research note 06).

## 4. Type information for Lua

1. In game: REFramework menu → *DeveloperTools → Object Explorer → **Dump SDK*** → `il2cpp_dump.json` (large).
2. Keep dumps out of git (`.research-cache/`).
3. Generate LuaLS stubs into `types/` with `kagenocookie/REFDumpFormatter`, and point `.luarc.json` → `workspace.library`
   at `types/`.

## 5. Research helper

`tools/web-research/fetch-pages.mjs` renders pages with system Edge through Playwright, using a **fresh, isolated profile**
(`.pw-profile`, gitignored). It never uses your browser's saved logins. Run it with `HEADLESS=0` (Nexus/Reddit block
headless browsers):

```powershell
cd tools\web-research; $env:HEADLESS='0'; node fetch-pages.mjs ..\..\.research-cache\web <url> [url...]
```

Keep it low-volume. Nexus Mods and Reddit pages render without login; old.reddit.com requires an account.

## 6. GitHub

- Repository: https://github.com/Hunterjet/mhwilds-seamless-coop (public).
- GitHub CLI is installed system-wide (`C:\Program Files\GitHub CLI\gh.exe`). For this project call it through **`tools\dev\gh.ps1`**, which keeps its config
  in `C:\src\.cache\gh` instead of the user profile. The login token lives in Windows Credential Manager (gh's keyring
  entry). It was approved for this repository's work only. Sign out with `tools\dev\gh.ps1 auth logout`.
- This repo's local git config resets inherited credential helpers and uses only the gh login, so pushes never touch
  credentials stored elsewhere on the PC. Commits use the GitHub **noreply** email (repo-local `user.email`).

## 7. Troubleshooting

- **`/lsp` says clangd / lua-language-server "not found":** the terminal was opened before the toolchain install, so it
  has an old `PATH`. Close **all** Windows Terminal windows, reopen, start `copilot` in the repo, then `/resume`.
- **Black screen for minutes on first launch after a game or REFramework update:** expected; see §2.
- **`reframework` MCP tools fail with "pipe not connected" or a connection error:** the game isn't running, or the
  re-engine-mcp plugin isn't installed. It only answers while the game runs.
- **GitHub shows "Unable to render rich display" for a diagram:** run
  `cd tools\web-research; node check-mermaid.mjs ..\..\docs\<file>.md` to see the parse error locally (headless Edge +
  Mermaid 11). Common cause: a `;` inside sequence-diagram text.

## 8. Research probe (read-only)

- `re/probes/seamless_probe.lua` logs calls to selected game methods plus changes in key state to
  `<game>\reframework\data\seamless_coop\traces\trace-<UTC>.jsonl`. It never changes the game.
- Install/update: `tools\deploy.ps1 -Probe`; remove: `tools\deploy.ps1 -Probe -Remove`. After deploying, use
  REFramework menu → ScriptRunner → **Reset scripts**.
- While playing: **F8** adds a mark (a short "Probe: mark #N saved" toast confirms it). Optional label text and a
  pause switch are in the REFramework menu under "Seamless Co-op probe".

## 9. Building, testing and deploying the mod

| Step | Command (repo root, vcvars64 shell for CMake) |
|---|---|
| Configure (once) | `cmake --preset release` → `build\release\` (downloads REFramework's `API.h` + Lua 5.4.3 sources at `d4611ae`, upstream `lua.c`, Catch2 v3.8.1) |
| Build | `cmake --build --preset release` → `src\plugin\seamless_net.dll`, `tests\lua_runner.exe`, `tests\plugin_tests.exe` |
| Test | `ctest --preset release` (Lua + C++), or `build\release\tests\lua_runner.exe tests\lua\run.lua . [test_name]` |
| Lint | `lua-language-server --check src\lua --checklevel=Warning --configpath .luarc.json` |
| Deploy | `tools\deploy.ps1 -Mod` (game closed: DLL + Lua) · `-Mod -LuaOnly` (game running; then Reset scripts) · `-Mod -Remove` |

In the game folder the mod is `reframework\autorun\seamless_coop.lua` + `reframework\autorun\seamless_coop\` +
`reframework\plugins\seamless_net.dll` (+ `.pdb` for dev builds). Its data lives in
`reframework\data\seamless_coop\`: `config.json`, `logs\session-1..5.log` (rotating), `save_backups\<UTC stamp>\`
(the last 10 launches) and `diagnostics.json` (written by the panel's button or the selftest).

**In-game panel:** REFramework menu (Insert) → Script Generated UI → **Seamless Co-op**. It shows the kill switch
(Ctrl+F12), game build and verification, versions, side channel and save backup status, Link Party members with
their mod status and RTT, and diagnostics. With `"dev_tools": true` in `config.json` it also shows loopback test
peers (buttons for compatible, mismatched and silent peers on a simulated 150 ms link).

**Unattended check:** `"dev_selftest": true` makes the mod log one `selftest:` line 8 s after start. Verified result on
PC-A (2026-10-21): every loopback case as expected, plus `steam_self=compatible rtt≈420ms` (a real Steam round trip
to itself). Turn it off again for normal play.
