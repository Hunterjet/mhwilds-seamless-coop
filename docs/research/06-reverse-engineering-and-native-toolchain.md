<!-- Research note: Reverse-engineering & native-modding toolchain. Compiled 2026-10-20/21 by a research sub-agent (web + GitHub); citations inline. Treat '[inferred]' items as unverified. -->

# RE/Native‑Modding Toolchain for a Monster Hunter Wilds "Seamless Co‑op" Mod

**Scope note:** This report is read‑only research (web + GitHub search/fetch only; nothing executed or downloaded). All star/fork/issue counts and "updated" timestamps were pulled live via the GitHub API on **2026‑10‑21**, the day after the stated "today" of 2026‑10‑20, and are explicitly dated below. Claims are marked **[verified]** when sourced from a primary file/README/official doc I fetched directly, or **[inferred]** when reasoned from adjacent evidence.

---

## 1. RE MCP servers (comparison table + details)

### Comparison table (all figures live as of 2026‑10‑21)

| Server | Backend | Stars★/Forks | Last push | License | Windows setup notes |
|---|---|---|---|---|---|
| **LaurieWired/GhidraMCP** | Ghidra 12.1.4 (ext. + Python bridge) | 11,443 / 1,204 | 2026‑10‑21 | Apache‑2.0 | `uvx` run; headless via PyGhidra |
| **bethington/ghidra-mcp** | Ghidra 12.1.4 + Java 21 | 5,824 / 348 | 2026‑10‑21 | Apache‑2.0 | 200+ tools, Docker-friendly |
| **GhidrAssistMCP** (symgraph) | Ghidra native‑Java extension | 778 / 72 | 2026‑10‑21 | — | In‑Ghidra plugin, no external bridge process |
| **ReVa** (cyberkaida/reverse‑engineering‑assistant) | Ghidra 12.0+ ext. | *unretrievable (see gaps)* | — | — | GUI "assistant mode" (port 8080) or headless `uv tool install` |
| **pyghidra-mcp** (clearbluejar) | Headless PyGhidra | 450 / 66 | 2026‑10‑20 | Apache‑2.0 | Pure Python, `uvx pyghidra-mcp`, optional `--gui` |
| **mrexodia/ida-pro-mcp** | IDA Pro 8.3+ (9 rec.) | 13,062 / 1,600 | 2026‑10‑21 | MIT | **IDA Free explicitly unsupported**; now defers to Hex‑Rays' official server |
| **HexRaysSA/ida-mcp** (official) | IDA 9.4+ with idalib | n/a (new) | 2026‑10‑08‑ish | MIT | `copilot plugin marketplace add HexRaysSA/copilot-marketplace` then `copilot plugin install ida-mcp@HexRaysSA` |
| **fosdickio/binary_ninja_mcp** | Binary Ninja (plugin) | 456 / 88 | 2026‑10‑19 | — | Needs Personal ($199+) license for API/plugins |
| **mrphrazer/binary-ninja-headless-mcp** | Binary Ninja headless | 259 / 24 | 2026‑10‑19 | — | 180 tools, no GUI needed |
| **duty1g/x64dbg-mcp-server** | x64dbg (Zig, zero‑dep) | 2,579 / 287 | 2026‑10‑21 | — | Most‑starred x64dbg bridge |
| **AgentSmithers/x64DbgMCPServer** | x64dbg (C#) | 741 / 106 | 2026‑10‑21 | — | Claude/Windsurf/Cursor configs included |
| **Wasdubya/x64dbgMCP** | x64dbg (C++) | 602 / 74 | 2026‑10‑20 | — | |
| **cheat-engine/AITools** (official CE org) | Cheat Engine 7.5+ Lua extension | 45 / 10 | 2026‑10‑15 | — | Not MCP‑protocol; CE's own built‑in agent/skill loop |
| **miscusi-peek/cheatengine-mcp-bridge** | Cheat Engine (Lua bridge) | 1,679 / 244 | 2026‑10‑21 | — | Most‑starred unofficial CE bridge |
| **dnakov/frida-mcp** | Frida | 459 / 64 | 2026‑10‑21 | — | Node/Python instrumentation, cross‑platform |
| ⚠️ **morluto/rea** ("REA") | Hopper/Ghidra/IDA + built‑ins | **350,431 / 88,086** | 2026‑10‑21 | MIT | See caution below |

All counts above are **[verified]** via direct GitHub API search (`github-mcp-server-search_repositories`), performed in this session.

### Details and reputation

**Ghidra side** is the most crowded and most "free‑tools‑native" niche. **LaurieWired/GhidraMCP** (github.com/LaurieWired/GhidraMCP) is the de‑facto flagship — Apache‑2.0, requires Ghidra 12.1.4 exactly, ships both a GUI‑attached mode (`uvx --from git+... ghidra-mcp --ghidra-server http://127.0.0.1:8080/`) and a fully headless PyGhidra mode that needs no running Ghidra UI at all. Its README gives ready‑to‑paste VS Code/Claude Code JSON snippets that translate directly to a Copilot CLI `mcp-config.json` entry. **bethington/ghidra-mcp** is a legitimate, actively‑maintained rival with a much larger tool surface (200+ tools) and Docker/Ghidra‑Server support — worth trying if GhidraMCP's tool set feels thin. **GhidrAssistMCP** (symgraph) is interesting because the same author previously shipped a non‑MCP LLM sidebar ("GhidrAssist", 766★) and archived MCP ports for Binary Ninja (BinAssistMCP) and IDA (IDAssistMCP) to concentrate on Ghidra — a signal of consolidation around Ghidra as the "free" anchor tool. **ReVa** (cyberkaida/reverse-engineering-assistant) markets itself specifically on reducing LLM "context rot" via small, reinforcing tool calls and ships Claude Code skills (Binary Triage, Deep Analysis, Cryptography Analysis); its README **[verified]** confirms Ghidra 12.0+ requirement and both assistant/headless modes, but I could not retrieve star/fork counts — GitHub's repository‑search endpoint returned zero hits for it twice despite the repo and README being directly fetchable, a specific gap noted at the end. **pyghidra-mcp** (clearbluejar) is the leanest, most automation‑friendly headless option — pure Python, good for CI‑style batch analysis of multiple RE Engine DLLs at once.

**IDA side**: **mrexodia/ida-pro-mcp** is the most‑starred single RE‑MCP project found (13,062★) and historically the reference implementation, but its own README now carries a banner: *"I recommend using the Official Hex-Rays IDA MCP Server instead"* **[verified, mrexodia/ida-pro-mcp:README.md]**. Hex‑Rays' own **HexRaysSA/ida-mcp** (hex-rays.com/blog/hex-rays-ida-mcp-server) is vendor‑built on a shared "IDA Nexus" multi‑client library and — directly relevant here — documents a one‑line **Copilot CLI** install: `copilot plugin marketplace add HexRaysSA/copilot-marketplace` then `copilot plugin install ida-mcp@HexRaysSA` **[verified]**. Both require **IDA Pro**, not IDA Free: mrexodia's README states flatly *"IDA Free is not supported"* and requires 8.3+ (9 recommended); Hex‑Rays' needs IDA 9.4+ with idalib. Cross‑checked against hex-rays.com/ida-free (fetched directly): IDA Free's decompiler is **cloud‑only and UI‑locked** — there is no SDK/API path to extract pseudocode programmatically, so **no IDA‑based MCP server can get decompiled output from IDA Free**, only disassembly. This directly answers the task question: **IDA MCP servers require IDA Home or IDA Pro (with a decompiler add‑on), never IDA Free.**

**Binary Ninja**: fosdickio/binary_ninja_mcp and mrphrazer/binary-ninja-headless-mcp are both solid, but Binary Ninja's Free edition has **no plugin/API access at all** per its own 6.0 pricing page (binary.ninja/2026/07/28/pricing-changes.html, fetched) — you need at least a **Personal license ($199 one‑time, non‑commercial)** to run either MCP server; Commercial is $1,799. This is the only paid-license gate among the Ghidra/Binary Ninja/Frida options.

**x64dbg**: no single canonical project — at least six independent MCP bridges exist with meaningfully different star counts (2,579★ down to a long tail of sub‑50★ forks), reflecting a fragmented, fast‑moving community rather than one converged standard; x64dbg itself is free/GPLv3.

**Cheat Engine**: no official MCP server exists from the `cheat-engine` org itself. **cheat-engine/AITools** **[verified]** is official but is a Lua extension implementing CE's *own* agent/tool‑use loop (drop into CE's Extensions folder), not literally the Model Context Protocol — it won't plug into Copilot CLI's `mcp-config.json`. Unofficial MCP bridges are numerous and unusually high‑variance in naming (several repos imply "official" affiliation, e.g. "CheatEngineNet", that are **not** part of the `cheat-engine` GitHub org); **miscusi-peek/cheatengine-mcp-bridge** (1,679★) is the most‑starred, but community reputation here is thinner/more meme‑flavored (its own topic tags include "vibecheating"/"vibehacking") than the Ghidra/IDA ecosystem.

**Frida**: dnakov/frida-mcp (459★) is the cleanest general‑purpose option; a niche variant, axhlzy/il2cpp-frida-mcp, targets IL2CPP‑style reflective runtimes specifically, which is conceptually (not literally) similar to RE Engine's managed‑type system (see §2).

**⚠️ A caution on "REA" (morluto/rea)**: GitHub's API genuinely reports **350,431 stars and 88,086 forks** for a repository created 2026‑04‑14 (six months old) **[verified via direct API query]**. A third‑party comparison (dev.to/leemie8848, "AI reverse‑engineering tools compared… Oct 2026", fetched) independently flags the same tool as having "attracted fake copies" and cautions that "stars aren't a quality signal." A ~350k‑star RE tool six months old is far outside organic growth patterns for this niche (compare: the 11–13k★ incumbents took 18+ months). I cannot confirm or rule out star‑manipulation from read‑only research, so **I do not recommend REA as a primary pick** despite its claimed breadth (native + .NET + JS/Electron analysis); treat its popularity metric as unreliable pending independent diligence.

### Copilot CLI config snippet pattern

All of the above are standard stdio/HTTP MCP servers and drop into `~/.copilot/mcp-config.json` the same way. Example (GhidraMCP):
```json
{
  "mcpServers": {
    "ghidra": {
      "command": "uvx",
      "args": ["--from", "git+https://github.com/LaurieWired/GhidraMCP", "ghidra-mcp",
                "--ghidra-server", "http://127.0.0.1:8080/"]
    }
  }
}
```
**[verified, LaurieWired/GhidraMCP:README.md]** — swap the `args` block for `ida-pro-mcp`, `binary_ninja_mcp`, `x64dbg-mcp-server`, etc.; each project's README gives the exact equivalent.

### Which is most suitable for a ~500MB x64 binary?

**[Mixed verified/inferred].** NSA's own Ghidra repo has an open discussion (github.com/NationalSecurityAgency/ghidra/discussions/9298, fetched) from a user whose "~250 MB PE x64 dll" auto‑analysis "takes forever" despite ample RAM/cores — a first‑party admission that Ghidra's Java‑based analysis pipeline scales poorly past a few hundred MB. At ~520MB mapped, MonsterHunterWilds.exe is roughly double that reported pain point. Community comparison writeups (flyriver.com/g/binary-ninja-ghidra-ida-pro) consistently describe IDA Pro's native analyzer as tens‑of‑minutes vs. Ghidra's multi‑hour runs at this scale, with Binary Ninja generally regarded as faster than Ghidra but behind IDA. **Practical recommendation**: don't rely on blind full‑binary auto‑analysis at all — use REFramework's own type dump to pre‑seed symbol names (§2) via **kvasszn/ree-pdb**, which is explicitly reported working against Ghidra, IDA, x64dbg and Cheat Engine, collapsing most of the "what is this function" work before Ghidra/IDA's analyzer even has to guess.

---

## 2. RE Engine / Wilds‑specific RE workflow

**REFramework** (praydog/REFramework, README fetched) is the de‑facto open modding/scripting platform for every modern RE Engine title, explicitly listing **Monster Hunter Wilds** among supported games, alongside RE2–RE9, MHRise, DD2, SF6, Pragmata, etc. **[verified]**. As of the newest nightly release notes (github.com/praydog/REFramework-nightly/releases, fetched today), REFramework has moved to a **single monolithic `dinput8.dll`** that detects the running game at runtime and dispatches to the correct type‑database (TDB) layout — a significant architecture change from the old per‑game `MHWILDS.zip`/`REFRAMEWORK_UNIVERSAL` builds. The user's installed nightly (v1.5.9.1, built 2026‑03‑14) **predates this monolithic rework by roughly seven months**; updating is recommended before deep RE work.

### Dump SDK workflow (exact, verified steps)

From Prof9/REF-Plugin-Template's README (fetched): in‑game, open the REFramework overlay (Insert key) → **DeveloperTools → ObjectExplorer → Dump SDK**. This generates two artifacts in the game's install directory: **`Enums_Internal.hpp`** (produced the moment Object Explorer is opened) and **`il2cpp_dump.json`** (produced by the "Dump SDK" click) **[verified]**. "il2cpp" here is colloquial — RE Engine's managed runtime is Capcom's own reflection system, not literally Unity IL2CPP, but community tooling names it that way by convention.

### Importers into Ghidra/IDA/Binary Ninja

The one purpose‑built tool found is **kvasszn/ree-pdb** (README fetched): a Rust CLI that synthesizes a **fake PDB** from `il2cpp_dump.json` + `Enums_Internal.hpp`, giving any PDB‑consuming tool function names, struct layouts, enums, vtables, and global‑singleton symbols. Its own README states it has been tested on **x64dbg, Cheat Engine 7.6, Ghidra 12.0.2 ("might be borked"), and IDA Pro 9.2** **[verified]** — directly answering the task's question about SDK‑dump → disassembler importers. It needs a specific LLVM release (clang+llvm‑22.1.5) rather than a winget/chocolatey LLVM, per its own build notes. A `--ida-safe-enums` flag exists specifically to dodge IDA's enum‑name collision rules, and a `--resolve-native-thunks` flag attempts to name native functions reached only through managed‑method thunks — exactly the "native vs managed function" boundary the task asks about. No equivalent first‑class **Binary Ninja** importer was found in this session (gap).

### RE Engine reflection/type system

REFramework's own SDK headers are the best primary source. `shared/sdk/RETypeDB.cpp`/`.hpp` implement the reflection database; `shared/sdk/TDBVer.hpp` (fetched in full) pins exact **TDB versions per game** — and, critically, gives **Monster Hunter Wilds' exact values**:
```
#elif defined(MHWILDS)
#define TDB_VER 81
...
#if defined(PRAGMATA) || defined(RE9) || defined(MHSTORIES3) || defined(MHWILDS)
#define TYPE_INDEX_BITS 19
#define FIELD_BITS 20
...
#elif defined(MHWILDS)
using RETypeDefinition_ = sdk::RETypeDefVersion74;
```
**[verified, praydog/REFramework:shared/sdk/TDBVer.hpp]** — i.e., Wilds reports TDB 81 but reuses the *RETypeDefVersion74* struct layout, with 19‑bit type indices / 20‑bit field indices. This is the single most Wilds‑specific, independently‑checkable fact in this report.

The `via.*` vs `app.*` namespace split is documented generically (not Wilds‑screenshotted) in REFramework's Lua API book (cursey.github.io/reframework-book/api/sdk.html, fetched): `sdk.game_namespace(name)` converts a bare name to the game's namespace — e.g. DMC5 uses `app.*`, RE3 uses `offline.*`. By convention across RE Engine games, **`via.*`** types are native engine/runtime types (via.Scene, via.SceneManager, via.Position) and **`app.*`**‑prefixed (or game‑specific namespace) types are the managed, game‑logic layer (quest directors, player state, item tables) — this is the practical "managed vs native" boundary modders target.

**How REFramework hooks managed methods** (verified from the same doc): `sdk.hook(method_definition, pre_function, post_function, ignore_jmp)` intercepts calls to a resolved `RETypeDefinition`'s method; pre‑hooks can return `sdk.PreHookResult.SKIP_ORIGINAL` to fully replace a managed call, with raw `void*` args requiring manual casts (`sdk.to_managed_object`, `sdk.get_native_field` for value types). `sdk.deserialize(data)` can even reconstruct live managed objects from a raw RSZ byte blob (the format used in `.scn`/`.user` game files), and `sdk.find_type_definition("via.Scene")`/`sdk.get_native_singleton(...)` give direct handles into running engine systems — this is the main surface a "walk‑and‑talk/cutscene co‑op" mod would use to read/replicate quest and camera/cutscene state. **Native** functions are hooked separately, at the C++ layer, via `safetyhook` (next section).

### Protection‑adjacent engine behavior (directly tied to the user's log line)

REFramework ships a dedicated `src/mods/IntegrityCheckBypass.cpp` module (fetched in full). It explicitly hooks `VirtualProtect` and logs **`"[IntegrityCheckBypass]: Hooked VirtualProtect!"`** — the exact line in the user's environment — to intercept memory‑protection changes the game makes around resource‑pak signature validation, alongside a `sha3_rsa_code_midhook` and a `pak_load_check_function` inline hook that neutralizes RSA/SHA3‑based pak integrity checks **[verified, praydog/REFramework:src/mods/IntegrityCheckBypass.cpp]**. This is strong, primary evidence that Wilds performs file‑integrity/anti‑tamper checks at the resource‑pak layer (consistent with Denuvo‑class anti‑tamper, see §3), and that REFramework already carries a maintained, Wilds‑aware patch for it — a huge head start versus hand‑rolling your own bypass.

---

## 3. Debugger / memory tool feasibility vs game protection

**Denuvo Anti‑Tamper is confirmed present** on Monster Hunter Wilds via its Steam store page and multiple outlets (gamespew.com/2025/03/monster-hunter-wilds-denuvo, sportskeeda.com, insider-gaming.com — all fetched via search, dated March 2025) **[verified]**. Community beta testers reported Enigma Protector strings in a pre‑release build; this is **unconfirmed for the shipped release** (no direct confirmation found) — flagged as inference/rumor only. Separately, Capcom runs a **proprietary anti‑cheat layer with a filed patent** aimed at detecting multiplayer **data‑tampering** (modified quest files used to bypass paywalls / inflate rewards), per monsterhunterhq.com and Capcom's own player‑facing notice (monsterhunter.com/wilds/.../unauthorized-modification-data, fetched) **[verified]**. Importantly, this crackdown is **framed around online quest/save‑data tampering**, not local single‑player visual/QoL mods — REFramework itself remains widely used and the Denuvo/pak‑check bypass above is a routine part of that, but a *seamless co‑op* mod that touches session/quest replication crosses into exactly the territory Capcom's enforcement targets, so this is a real account‑risk consideration for this project, distinct from the pure RE question.

**Cheat Engine / x64dbg attach feasibility — confirmed working in practice.** I could not fetch FearlessRevolution threads directly (403 on `fearlessrevolution.com`, a Cloudflare‑gated forum — noted as a gap), but found and fetched a concrete, dated community artifact: a Monster Hunter Wilds Cheat Engine table by "Leunsel" (mirrored on vgtimes.com, dated 2025‑03‑03) bundling **REFramework as a required companion** and exposing ~40 memory hooks — Quest Director, Quest Data, Save Data Manager, Player Health/Stamina/Transform, Inventory, Otomo, Lucky Ticket, etc. **[verified via mirror]**. This demonstrates two things empirically: (1) **Cheat Engine does attach to the protected process** for ordinary memory read/write in single‑player/offline use, and (2) the community's practical pattern is to pair CE with REFramework rather than fight RE Engine's reflection system cold — CE alone struggles to name RE Engine's managed objects, but REFramework's dumped types make that tractable. `ree-pdb`'s own README independently states it was tested against **Cheat Engine 7.6 and x64dbg** successfully **[verified]**, reinforcing that neither tool is blocked from attaching.

**ScyllaHide** (x64dbg/ScyllaHide) is the standard anti‑anti‑debug plugin for x64dbg and is the generic community recommendation for any Denuvo‑class or custom‑anti‑debug title; I could not source a Wilds‑specific ScyllaHide profile/thread (gap — FearlessRevolution 403), so treat this as **general best‑practice guidance, not a Wilds‑verified report**: install `ScyllaHideX64DBGPlugin.dp64` into x64dbg's plugin folder, attach rather than launch‑from‑debugger, and expect to iterate on which specific hides (NtQueryInformationProcess, CheckRemoteDebuggerPresent, PEB `BeingDebugged`) are needed.

**Detect It Easy (DIE)** is a real, actively maintained signature‑based packer/protector identifier (horsicq/Detect-It-Easy) with Denuvo/VMProtect/Enigma signatures in its database — but I found **no specific, citable DIE scan report run against `MonsterHunterWilds.exe`** in indexed sources (gap). Denuvo's presence is otherwise well‑sourced via press/Steam (above), so a DIE scan would likely just corroborate what's already known rather than reveal something new; running it yourself is still worthwhile to catch any additional packer layered on `steam_api64.dll`/`PartyWin.dll`.

**Network analysis / is traffic encrypted?** **PlayFab Party traffic is encrypted.** Per Microsoft's own PlayFab Party docs (learn.microsoft.com/en-us/xbox/playfab/multiplayer/networking/concepts-invitations-security-model, fetched) **[verified]**, all management, game‑data, and voice/chat traffic through PlayFab Party's Azure relay — and direct peer‑to‑peer traffic — uses **DTLS**, authenticated against PlayFab entity tokens. `PartyWin.dll` is the current (post‑Win7‑deprecation) Windows runtime for this stack. Practically: **Wireshark will show you encrypted UDP/DTLS flows with opaque payloads**, not readable game‑state packets; you cannot "sniff the co‑op protocol" off the wire without key material you don't have. This strongly implies that the tractable path for a co‑op mod is hooking the game's **already‑decrypted in‑process representation** of quest/session state (via REFramework's managed‑object layer, §2) rather than attempting wire‑level protocol reverse‑engineering.

**Process Monitor / API Monitor**: standard, free Sysinternals/third‑party tools, useful here mainly for locating pak/save file I/O call sites and DLL load order (ProcMon) and for tracing which Win32 APIs (`VirtualProtect`, `CryptoAPI`/`bcrypt` calls, `WSASend`/`connect`) the game touches around session start (API Monitor, rohitab.com) — general‑purpose guidance, not Wilds‑specific findings in this session.

---

## 4. Native mod stack options (comparison)

| Option | Managed‑type access | Hooking | ImGui UI | Networking | Hot reload | Patch resilience |
|---|---|---|---|---|---|---|
| **(a) REFramework C++ plugin** | Full, via `reframework::API` | `safetyhook` built‑in | Bundled DX11/DX12/Win32 backends | None built‑in; must add your own | No (DLL reload needs relaunch) — *inferred* | High (reflection‑by‑name) |
| **(b) Standalone proxy DLL + hook lib** | None (must reimplement RTTI walking) | Your choice (MinHook/safetyhook/Detours) | Must vendor yourself | Full control (WinSock2/ASIO) | No | Low unless you build your own reflection |
| **(c) Lua‑only REFramework script** | Full, same `sdk.*` API | `sdk.hook` (managed only) | `imgui.*` Lua bindings | Unconfirmed (see gap) | **Yes** — "Reset Scripts" | Highest (no native build at all) |

**(a) REFramework C++ plugin.** praydog/REFramework ships a working example (`examples/example_plugin/Plugin.cpp`, `Plugin.hpp`, plus DX11/DX12/Win32 ImGui backend files) and a second real‑world example (`examples/weapon_stay_big_plugin/weapon_stay_big.cpp`) showing the `pre_start(argc, argv, arg_tys, ret_addr)` native‑hook entry point pulling a managed object out of `argv[1]` and mutating a field via `get_field<float>("_bodyConstScale")` **[verified, both files fetched/found via code search]**. **Prof9/REF-Plugin-Template** is a ready‑to‑clone "Hello World" using VS Code + CMake Tools, with a Python sanitizer step for the dumped `Enums_Internal.hpp` and automatic copy of the built DLL into `reframework/plugins/` **[verified, readme.md fetched]**. This path inherits REFramework's bundled **Dear ImGui**, **safetyhook**, and the full reflection layer for free — by far the lowest‑effort way to get a working, inspectable C++ mod.

**(b) Standalone proxy DLL.** If you deliberately want to stay outside REFramework (e.g., to avoid a hard runtime dependency), you pick your own hook library. REFramework itself settled on **safetyhook** (cursey/safetyhook) — confirmed directly in its `cmake.toml`: `[fetch-content.safetyhook] git = "https://github.com/cursey/safetyhook"`, and its `shared/utility/FunctionHook.{hpp,cpp}` wraps `safetyhook::InlineHook`/`MidHook` **[verified, both files fetched]** — a strong, already‑field‑tested signal that safetyhook is compatible with Wilds' protections (it's literally what hooks `VirtualProtect` in IntegrityCheckBypass.cpp, §2). **MinHook** (TsudaKageyu/minhook) is the older, simpler, extremely widely used C hooking library in the broader game‑trainer community — smaller API surface, x86/x64, no C++23 requirement. **Microsoft Detours** (microsoft/Detours, 6,413★, MIT‑licensed open source since 2016) **[verified]** is the most "enterprise‑grade"/battle‑tested but is less commonly seen in game‑modding specifically versus MinHook/safetyhook. **Recommendation: safetyhook**, purely because it's already proven against this exact binary's protections inside REFramework.

**(c) Lua‑only scripts.** Fastest iteration loop by far — full `sdk.*` reflection access, `sdk.hook` for managed methods, `imgui.*` for UI, and REFramework's script‑reset hot reload — at the cost of: no arbitrary native‑function hooking beyond what REFramework's API exposes (some native wrapper functions explicitly "cannot be hooked this way" per the sdk.hook docs), interpreter overhead on hot paths, and **unconfirmed networking**: I could not find a `socket`/`net` Lua module in REFramework's bundled API docs or a `luasocket` reference inside its repo (code search for "luasocket" returned zero hits) — treat **Lua‑side networking as unavailable until proven otherwise**; a true network channel almost certainly requires dropping into a C++ plugin.

**Networking capability, concretely:** `steam_api64.dll` exposes Steamworks' `ISteamNetworkingSockets`/`ISteamNetworking` — but a third‑party mod cannot independently authenticate a *new* Steamworks session for someone else's App ID; the realistic pattern is calling into the **game's own already‑initialized Steam interfaces in‑process** (same technique many Steamworks trainers use), which is an RE task in itself (finding/calling the game's existing `SteamAPI_*` accessor). PlayFab Party is Capcom/Microsoft back‑end infrastructure a mod cannot stand up independently and is DTLS‑encrypted end‑to‑end (§3) — not a practical channel to extend directly. Plain WinSock2/ASIO sockets from a C++ plugin are trivial and fully under your control, but building a *seamless* co‑op experience plausibly means **extending/hooking the game's own existing session/quest‑replication messages** (riding its already‑established Party channel) rather than inventing a parallel external protocol — a much harder, longer‑horizon RE goal than the UI/quest‑flow hooking this toolchain phase supports.

**Update resilience**: REFramework's own architecture (TDB version pinning + `RETypeDefinition_` struct‑version aliasing, §2) is built around **reflection‑by‑name** (`sdk.find_type_definition("app.Whatever")`) precisely because Capcom patches shift raw addresses constantly but tend to preserve managed type/method *names* across patches more often than raw offsets — this is the resilience strategy to copy. Hand‑rolled byte‑signature scanning (what a standalone proxy DLL is stuck with for anything not exposed by REFramework) breaks on any code‑gen change and needs re‑derivation per patch; REFramework minimizes this to a handful of native entry points (see `utility::Scan`/`find_function_start` used throughout `IntegrityCheckBypass.cpp`).

**Common libraries** confirmed in active use inside REFramework itself: **Dear ImGui** (ocornut/imgui, MIT, vendored) for all UI; **spdlog** (gabime/spdlog, MIT) for logging — every `IntegrityCheckBypass` log line in §2/§3 is a literal `spdlog::info(...)` call; a JSON‑for‑Modern‑C++‑shaped format is used for `il2cpp_dump.json`, while REFramework's Lua side has its own bundled `json` module (`json.load_file(...)` seen in the sdk docs' RSZ example). **glm** is the standard header‑only math library typically paired with ImGui‑based freecam/overlay mods (not directly confirmed inside REFramework's own repo in this session, but it's the de‑facto community default). **vcpkg** (microsoft/vcpkg) is Microsoft's C++ package manager — useful if you want MinHook/Detours/nlohmann‑json/glm without replicating REFramework's own CMake `FetchContent` setup.

---

## 5. Build tooling (winget IDs)

| Tool | winget ID | Notes |
|---|---|---|
| VS 2022 Build Tools (MSVC) | `Microsoft.VisualStudio.2022.BuildTools` | Add C++ workload: `--override "--add Microsoft.VisualStudio.Workload.VCTools"` **[verified via winstall.app / MS docs]** |
| CMake | `Kitware.CMake` | **[verified]** |
| Ninja | `Ninja-build.Ninja` | **[verified]** |
| vcpkg | *(none)* | No official winget package exists (open request: microsoft/winget-pkgs#44742); `git clone https://github.com/microsoft/vcpkg && .\bootstrap-vcpkg.bat` **[verified]** |
| lua-language-server | `LuaLS.lua-language-server` | For editor/LSP support on Lua REFramework scripts **[verified]** |
| clangd | `LLVM.clangd` | C++ LSP; ships alongside full `LLVM.LLVM` package too | 
| Python 3 | `Python.Python.3.13` | Needed for GhidraMCP's PyGhidra bridge, `ree-pdb`'s sanitizer scripts, REF‑Plugin‑Template's `Enums_Internal.hpp` sanitizer |
| JDK (Ghidra) | `Microsoft.OpenJDK.21` *or* `EclipseAdoptium.Temurin.21.JDK` | **Ghidra 12.1.4 (current public release) requires Java 21 64‑bit JDK** — confirmed directly from `GhidraDocs/GettingStarted.md` pinned at tag `Ghidra_12.1.4_build` **[verified]**. Ghidra's in‑development `GettingStarted.md` (default branch, "effective as of Ghidra 12.2") already requires **Java 25** — plan to re‑check before upgrading past 12.1.x. |
| Wireshark | `WiresharkFoundation.Wireshark` | For the (encrypted/limited‑value) network capture described in §3 |

Already present per the brief: git 2.43, Node 24, .NET SDK, winget — no action needed. Not winget‑packaged: `ree-pdb`'s preferred exact LLVM 22.1.5 toolchain (its own README says winget/chocolatey LLVM builds "don't work" for its PDB‑stream generation needs) — download the `clang+llvm-22.1.5-x86_64-pc-windows-msvc` tarball directly if you want to build `ree-pdb` from source **[verified, kvasszn/ree-pdb:README.md]**.

---

## 6. Recommended toolchain & setup order

1. **Update REFramework first.** The installed v1.5.9.1 (2026‑03‑14) predates the now‑live monolithic cross‑game build **[inferred from release‑notes dating, high confidence]** — pull the latest `REFramework-nightly` release before any other RE work.
2. **Bootstrap the build environment** via winget (§5): VS 2022 Build Tools + VCTools workload, CMake, Ninja, Python 3.13, JDK 21 (Temurin or Microsoft OpenJDK), lua‑language‑server, clangd, Wireshark. Clone vcpkg manually (no winget package).
3. **In‑game: Dump SDK.** DeveloperTools → Object Explorer → Dump SDK, producing `Enums_Internal.hpp` + `il2cpp_dump.json` for the current build.
4. **Set up one MCP server first: `LaurieWired/GhidraMCP`.** It's free (Apache‑2.0), the single most‑starred Ghidra MCP, has a documented headless PyGhidra path, and its README config translates directly into `~/.copilot/mcp-config.json`. Run `ree-pdb --exe MonsterHunterWilds.exe --il2cpp il2cpp_dump.json` first and load the resulting PDB into Ghidra — this sidesteps the multi‑hour blind‑analysis problem documented in NSA's own Ghidra discussion #9298 (§1).
5. **If budget allows, add Binary Ninja Personal ($199)** + `fosdickio/binary_ninja_mcp` as a faster‑analysis second opinion on the 500MB binary; reserve IDA Pro + `HexRaysSA/ida-mcp` (official, native Copilot CLI plugin‑marketplace install) only if a paid IDA Pro/decompiler license is already available — **IDA Free cannot serve any of this**.
6. **Prototype the co‑op quest/cutscene hooks in Lua first** (fastest iteration, hot‑reload, full `sdk.*` reflection) before committing to a C++ plugin.
7. **Graduate to a REFramework C++ plugin** (Prof9/REF-Plugin-Template as scaffold) once you need real hooking/ImGui debug UI/eventual networking beyond Lua's reach — reuse **safetyhook**, already proven against Wilds' `VirtualProtect`/pak‑signature checks inside REFramework's own `IntegrityCheckBypass` module.
8. **Keep Cheat Engine + x64dbg in the loop for live inspection only**, informed by the confirmed‑working community cheat table pattern (REFramework + CE) — add `duty1g/x64dbg-mcp-server` (most‑starred, zero‑dependency) only if you want the agent driving a live debug session; skip the fragmented Cheat‑Engine MCP ecosystem unless you specifically want the agent scripting CE itself.
9. **Deprioritize Frida and Wireshark‑level protocol RE** for this phase: Frida is redundant with REFramework's own instrumentation on a native Windows target, and PlayFab Party's DTLS encryption makes wire‑level co‑op protocol reversing a dead end compared to hooking the game's decrypted in‑process quest/session objects.
10. **Treat multiplayer‑facing testing as higher account‑risk** than pure single‑player visual mods, given Capcom's public, patent‑backed anti‑cheat stance specifically targeting quest/session data tampering (§3) — a policy/process concern layered on top of the pure RE feasibility question this report answers.

---

## 7. Open questions / couldn't verify

- **FearlessRevolution forum content**: direct fetch returned HTTP 403 (Cloudflare gate); I substituted a dated third‑party mirror (vgtimes.com) of an actual MH Wilds Cheat Engine table plus AI‑search synthesis. A logged‑in/manual visit to fearlessrevolution.com's Monster Hunter Wilds subforum would likely yield richer, more current detail (specific ScyllaHide profiles, patch‑by‑patch table updates).
- **No direct Detect‑It‑Easy scan output for `MonsterHunterWilds.exe`** was found in any indexed source — Denuvo presence is well‑sourced via press/Steam instead; running DIE yourself remains the only way to get a first‑party packer fingerprint.
- **Whether REFramework's Lua runtime exposes any socket/networking module** could not be confirmed or denied — a repo‑wide code search for "luasocket" returned zero hits, and the published Lua API docs browsed in this session show no `socket`/`net` namespace. Treat as **unavailable** until someone greps the full `lua`/`sol2` dependency tree directly.
- **ReVa's (cyberkaida/reverse-engineering-assistant) popularity metrics**: repo and README confirmed to exist and load directly, but `search_repositories` returned zero hits for it on two separate query phrasings — no star/fork count obtained this session.
- **The `via.*`/`app.*` namespace convention** is confirmed generically across RE Engine titles via REFramework's own docs, but I did not find a Wilds‑specific screenshot/dump confirming its exact root namespace name (vs. e.g. DMC5's `app.*` or RE3's `offline.*`) — the TDB version/struct mapping *is* Wilds‑specific and verified (§2); the namespace‑prefix convention is treated as **[inferred by analogy]** for Wilds specifically.
- **morluto/rea's 350k‑star count** is real per a live API query but anomalous for a six‑month‑old project; I could not determine whether this reflects genuine adoption or star manipulation, and excluded it from primary recommendations on that basis alone.
- **Exact commit delta** between the user's installed REFramework build (v1.5.9.1, 2026‑03‑14) and today's monolithic nightly was not diffed — the architecture‑change inference is based on release‑note dating, not a line‑by‑line commit comparison.
- **Ghidra's JDK 25 requirement** was confirmed only on the *in‑development* `GettingStarted.md` (default branch, "effective as of Ghidra 12.2"); the exact Ghidra point release that will actually ship requiring JDK 25, and its release date, is unknown as of this research.
