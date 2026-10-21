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
- GitHub: use `tools/dev/gh.ps1` (portable gh, config in `C:\src\.cache\gh`, token approved by the user for this repo).
- Two-player testing uses a **remote tester** (PC-B, no access). Anything they must do goes into plain-language tester
  docs and session scripts (`docs/testing/`). Never put personal details about the tester in the repo.
- Start Copilot CLI inside this repo so `.mcp.json` (reframework, ghidra) and `.github/lsp.json` load.
- Deploy with `tools/deploy.ps1`. Lua hot-reloads via REFramework "Reset Scripts"; the DLL needs a game restart.
- Commits: include the `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer.
