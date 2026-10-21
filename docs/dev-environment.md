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

Everything is listed in `reframework\backups\CHANGES-seamless-coop-dev.txt`.
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
