# Agent instructions — Seamless Co-op (Monster Hunter Wilds)

These rules add to `C:\src\AGENTS.md` (machine-wide rules: personal files, credentials, workspace).

## Project facts
- REFramework-based mod: **Lua** (`src/lua`, deployed to `<game>\reframework\autorun\`) for logic/UI, plus a small
  **C++20 REFramework plugin** (`src/plugin`, `seamless_net.dll`) for the Steam P2P side channel and file I/O outside the
  Lua sandbox. Specs: `docs/feature-spec.md`; design: `docs/implementation-plan.md`.
- `<game>` = `C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds`.

## Hard rules
- **Game folder:** write only inside `<game>\reframework\` (and REFramework's `<game>\dinput8.dll` after a backup).
  Never touch other game files, PAKs or the exe. **Never touch save files** (the plugin may only *copy* them for backups).
- **Fair play:** never modify quest definitions, rewards, timers, drops, monster parameters or story flags outside the
  game's own routines. Joins must use the game's own request functions.
- Every game type/method/field name goes through `src/lua/seamless_coop/compat/registry.lua`. Features must fail
  closed when an entry does not resolve.
- Hooks do minimal work (capture → emit event). Logic runs from the scheduler under `pcall`.
- Use **read-only** re-engine-mcp tools by default. Mutating tools (`invoke_method`, `write_field`, `set_*`, chat)
  only with explicit intent, offline or in a private session.
- Never commit game-derived dumps (`il2cpp_dump.json`, `Enums_Internal.hpp`, generated `types/`) or raw research captures (`.research-cache/`).
- Do not copy code from unlicensed repositories (e.g. BetterSoS). Study it; write our own.
- Logs must not contain OS user names or full Steam IDs.

## Workflow
- GitHub: use `tools/dev/gh.ps1` (system gh with project-scoped config in `C:\src\.cache\gh`; token approved by the user for this repo).
- Two-player testing uses a **remote tester** (PC-B, no access). Anything they must do goes into plain-language tester
  docs and session scripts (`docs/testing/`, `tools/tester-kit/`). Never put personal details about the tester in the repo.
- Tester kit: build with `powershell -File tools/tester-kit/build-kit.ps1` (→ `C:\src\.cache\dist\`), publish as a
  GitHub pre-release. Kit scripts must run on **Windows PowerShell 5.1**: ASCII only (no BOM → `—` breaks parsing),
  no `Get-FileHash`/`Compress-Archive` (use the .NET helpers in `kit-common.ps1`), `.cmd`/`.ps1` stay CRLF
  (`.gitattributes`). Test against a fake Steam layout with `-SteamDir`/`-GameDir`/`-OutDir`/`-NoPause`, never the real game folder.
- Start Copilot CLI inside this repo so `.mcp.json` (reframework, ghidra) and `.github/lsp.json` load.
- RE: map types with `tools/dev/re-typemap.ps1` (output stays in `.research-cache/`); record verified facts in `docs/re/game-model.md`.
- Deploy with `tools/deploy.ps1` (`-Mod`, `-Mod -LuaOnly`, `-Probe`). Lua hot-reloads via REFramework "Reset Scripts";
  the DLL needs a game restart. Close the game with `Process.CloseMainWindow()` (never kill it), relaunch with
  `steam://rungameid/2246340`. Unattended in-game check: `"dev_selftest": true` in the game's
  `reframework\data\seamless_coop\config.json` → one `selftest:` line in `logs\session-N.log` (turn it off afterwards).
- Build/test (vcvars64 shell): `cmake --preset release`, `cmake --build --preset release`, `ctest --preset release`.
  Lua-only: `build\release\tests\lua_runner.exe tests\lua\run.lua .` Lint: LuaLS `--check src\lua --configpath .luarc.json`.
  CI (`.github/workflows/ci.yml`) runs the same build + ctest on every push/PR; keep it green
  (`tools\dev\gh.ps1 run list --workflow ci.yml`).
- seamless_net.dll must be compiled against REFramework's own Lua sources at the pinned commit (RefDeps.cmake); when
  REFramework is updated, bump `REF_COMMIT` and rebuild. Lua bindings must never raise Lua errors (return nil, err).
- Docs with Mermaid: run `node tools/web-research/check-mermaid.mjs <file.md>` before committing. Never use `;` in
  sequence/state diagram text (Mermaid treats it as a line break).
- Commits: include the `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer.
