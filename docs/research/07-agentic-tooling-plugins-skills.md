<!-- Research note: Copilot CLI plugins, skills, MCP & LSP. Compiled 2026-10-20/21 by a research sub-agent (web + GitHub); citations inline. Treat '[inferred]' items as unverified. -->

# Research Report: Copilot CLI Extensibility for Monster Hunter Wilds "Seamless Co-op" Native Modding

*Research conducted 2026-10-20/21 against GitHub Copilot CLI v1.0.101 official docs (docs.github.com) and live GitHub repository data (via GitHub API/MCP tools). All star/fork counts below were pulled directly from the GitHub API on 2026-10-21 — several third-party "best-of" blogs/aggregators quote inflated numbers that did not match the API; where that happened, I flag it explicitly.*

## Copilot CLI extensibility (verified from docs)

**Plugin formats.** Copilot CLI supports two plugin formats ([about-plugins](https://docs.github.com/en/copilot/concepts/agents/about-plugins), [plugins-creating](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating)):
- **Agent Plugins 1.0** — an open, portable standard (`$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` in `plugin.json`). Skills must live under `skills/<name>/SKILL.md`; MCP config must be a root `mcp.json` (its own schema). Copilot-specific pieces (agents, hooks, commands, rules, LSP) go under a `com.github.copilot/` subdirectory, which other clients ignore.
- **Legacy Copilot plugins** — no `$schema`; `plugin.json` can declare custom paths (`"agents"`, `"skills"`, `"hooks"`, `"mcpServers"`) and MCP config can live in `.mcp.json`, `.github/mcp.json`, or inline.

**Yes — Copilot CLI reads Claude Code's marketplace format directly.** The official marketplace-authoring doc states plainly: *"Copilot CLI also looks for the `marketplace.json` file in the `.claude-plugin/` directory"* ([plugins-marketplace](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace)). I verified this empirically: `obra/superpowers`, `obra/superpowers-marketplace`, `trailofbits/skills`, `trailofbits/skills-curated`, and `anthropics/skills`/`anthropics/claude-plugins-official` all ship only a `.claude-plugin/marketplace.json` (no GitHub-native `.github/plugin/` folder), yet the docs' own worked example is `copilot plugin marketplace add anthropics/claude-code` for the "claude-code-plugins" marketplace. Components supported per the manifest: **custom agents** (`*.agent.md`), **skills** (`SKILL.md` folders), **hooks** (`hooks.json`), **MCP server configs**, and **LSP server configs** (`lsp.json`) — confirmed in [about-plugins](https://docs.github.com/en/copilot/concepts/agents/about-plugins).

**Skills.** Project skills live in `.github/skills/`, `.claude/skills/`, or `.agents/skills/`; personal skills in `~/.copilot/skills/` or `~/.agents/skills/` ([add-skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)). `SKILL.md` needs YAML frontmatter (`name`, `description`, optional `license`, optional `allowed-tools`). To add someone else's skill: download the folder (e.g. from `awesome-copilot.github.com/skills/`), move it into a skills directory, then `/skills reload` or `copilot skill add <FILE|URL|DIRECTORY>` non-interactively ([cli-command-reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)). The Agent Skills spec is an **open standard** shared with Claude/other agents ([about-agent-skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)).

**MCP.** User-level config: `~/.copilot/mcp-config.json`. Project-level: `.mcp.json` (walked up from cwd to repo root) or `.github/mcp.json` — project overrides user, and `.mcp.json` overrides `.github/mcp.json` ([add-mcp-servers](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)). The GitHub MCP server is built in already. Add servers via `/mcp add`, `copilot mcp add NAME -- COMMAND ARGS`, or `copilot mcp add --transport http NAME URL`. **GitHub's own worked example is Context7**: `copilot mcp add context7 -- npx -y @upstash/context7-mcp`. Project-level servers are skipped silently in untrusted directories.

**LSP.** User config `~/.copilot/lsp-config.json`; project config `lsp.json` (repo root) or `.github/lsp.json` ([add-lsp-servers](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/add-lsp-servers)). Format: `{"lspServers": {"name": {"command":, "args":, "fileExtensions": {".ext":"languageId"}}}}`. GitHub ships an **`lsp-setup` skill** (from `awesome-copilot`) that automates install+config; its reference table (`github/awesome-copilot:skills/lsp-setup/references/lsp-servers.md`) explicitly lists **clangd** for C/C++ (`clangd --background-index`, installed via LLVM on Windows) and **lua-language-server** for Lua — exactly the two LSPs this project needs. Manage with `/lsp`, `/lsp reload`, or non-interactive `copilot lsp`.

**Hooks & security/trust.** Hooks fire on `sessionStart/End`, `userPromptSubmitted`, `preToolUse` (can *approve or deny* a tool call), `postToolUse`, `agentStop`, `subagentStop`, `errorOccurred` ([hooks](https://docs.github.com/en/copilot/concepts/agents/hooks)); config at `.github/hooks/*.json` or `~/.copilot/hooks/*.json`. On first launch of a directory, Copilot CLI prompts for **trusted-directory** confirmation; the first use of any mutating/executing tool prompts **Yes / Yes-for-session / No** ([copilot-cli concept](https://docs.github.com/en/copilot/concepts/copilot-surfaces/copilot-cli)). Skill frontmatter can pre-approve tools via `allowed-tools`, but the docs explicitly warn: *"Only pre-approve the `shell` or `bash` tools if you have reviewed this skill and any referenced scripts, and you fully trust their source"* ([add-skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)).

**Timeline (secondary sources, not primary docs — inference flagged).** Per GitHub's changelog blog (via web search, not independently fetched): Copilot CLI reached GA 2026-02-25; the LSP/language-intelligence feature shipped ~2026-06-10; **Agent Plugins 1.0** was standardized ~2026-08, with Google joining as a co-maintainer. These dates are consistent with, but not independently re-verified against, `github.blog/changelog`.

## Marketplaces & skill repos surveyed

| Repo | Stars/Forks (API, 2026-10-21) | Notes |
|---|---|---|
| `github/awesome-copilot` (default) | 40,247 / 5,171 | Community-driven; huge `skills/`, `plugins/`, `agents/`, `instructions/` trees; its `skills/` entries (e.g. `lsp-setup`, `security-review`, `microsoft-skill-creator`) are **not** in `marketplace.json`'s `plugins` array — they're standalone downloads, not `plugin install`-able. |
| `github/copilot-plugins` (default) | 375 / 150 | Official but young (created 2026-01); marketplace name is literally `"copilot-plugins"`. Only 2 plugins live in-repo (`build-perf-cpp`, `spark`); the rest are pointers to external Microsoft repos (`microsoft/work-iq`, `microsoft/power-platform-skills`, `microsoft/cpp-language-server`, etc.) via the `"source":{"source":"github","repo":...}` manifest field. |
| `anthropics/claude-plugins-official` | 43,456 / 4,588 | Anthropic's official curated directory; hosts Superpowers' own `claude-plugins-official` listing. |
| `anthropics/skills` | 182,547 / 21,627 | Anthropic's example/reference skills repo (skill-creator, mcp-builder, docx/pdf/pptx/xlsx, frontend-design, webapp-testing). Ships `.claude-plugin/marketplace.json`, installable in Copilot CLI the same way. |
| `obra/superpowers` | 302,689 / 26,989 | "Agentic skills framework & software development methodology." Ships first-class install paths for **11 different coding agents**, including a dedicated **"GitHub Copilot CLI"** section in its own README. |
| `obra/superpowers-marketplace` | 1,303 / 265 | Thin marketplace wrapper Copilot CLI registers against. |
| `obra/superpowers-skills` | — | **Archived** (superseded; development consolidated into the main `obra/superpowers` monorepo, which now carries `.claude-plugin`, `.codex-plugin`, `.cursor-plugin`, `.antigravity-plugin`, etc.). Don't install this old repo. |
| `trailofbits/skills` | 7,667 / 666 | Trail of Bits (security firm) marketplace; `.claude-plugin` format. |
| `trailofbits/skills-curated` | 516 / 35 | A **meta-vetting** marketplace: its README states *"Published skills have been found with backdoors and malicious hooks, and the ecosystem has no built-in quality gate."* It whitelists `obra/superpowers`, `anthropics/claude-plugins-official`, `anthropics/knowledge-work-plugins`, and `openai/skills` as pre-approved — useful independent corroboration. |
| `trailofbits/overtly-malicious-skills` | 44 / 5 | Deliberately malicious skill corpus for testing scanners — not for installation, cited as evidence of real supply-chain risk. |

Community sentiment (web search synthesis, Oct 2026, not independently verifiable the way GitHub stars are): Reddit/HN discussion of Copilot CLI's plugin/skill ecosystem is broadly positive ("agent now has real superpowers via add-ons"), with recurring cautions about (a) vendor lock-in, (b) needing to vet third-party hooks/MCP servers, and (c) a 2026 broader "MCP backlash" around context-window bloat and stale results when users stack many MCP servers simultaneously. Treat the specific numeric claims in that synthesis (e.g., "10–40% of context consumed") as unverified secondary commentary, not confirmed fact.

## Candidates by category

**C/C++ (MSVC/CMake, Windows).**
- **`lsp-setup` skill → clangd** — the canonical, docs-endorsed path to C/C++ code intelligence (`github/awesome-copilot:skills/lsp-setup/references/lsp-servers.md`). clangd itself (LLVM project) is the de facto industry-standard C++ LSP, not a niche choice.
- **`microsoft/cpp-language-server`** (54★/12 forks, created 2026-04) — a first-party Microsoft alternative bundled in the default `copilot-plugins` marketplace ("Navigate and interact with your C++ code using the Microsoft C++ Language Server"). Much smaller community footprint than clangd; I could not read its internals (GitHub blocked anonymous API access behind Microsoft's SAML SSO enforcement), so I can't confirm whether it's MSVC-based or a clangd wrapper.
- **`build-perf-cpp`** (official, `github/copilot-plugins`) — analyzes MSVC build performance via `vcperf.exe`/ETL traces; directly on-topic for a CMake/MSVC DLL project, low risk (first-party, MIT).
- **`trailofbits/skills` → `modern-cpp`, `c-review`, `dwarf-expert`** — modern-cpp covers C++20/23/26 idioms + compiler hardening; c-review is a coverage-verified C/C++ security reviewer; dwarf-expert parses/verifies DWARF debug info (handy for symbol work alongside RE). All from a well-regarded, named-author security firm.

**Lua (REFramework scripting).** No dedicated "REFramework Lua" skill exists anywhere I searched (awesome-copilot, copilot-plugins, trailofbits, superpowers, anthropics). The only concrete asset is **lua-language-server** via the same `lsp-setup` skill — solid (it's the standard Lua LSP, also used by EmmyLua/VS Code Lua extensions) but generic, not game-modding-aware.

**Reverse engineering (reputation only — setup covered elsewhere).**
| Tool | Stars (verified) | Notes |
|---|---|---|
| `mrexodia/ida-pro-mcp` | 13,062 | Most-starred; requires a paid IDA Pro ≥8.3 license. |
| `LaurieWired/GhidraMCP` | 11,443 | Free/open (Ghidra), very mature (since Mar 2025). |
| `cyberkaida/reverse-engineering-assistant` (**ReVa**) | 879 | Native Ghidra extension (not just a decompiler bridge); smaller community but one of the oldest entries (since Aug 2023). |
| `bromoket/x64dbg_mcp` | **133** (verified) | For live-process dynamic debugging. ⚠️ Several SEO-style aggregator sites (dailyaiworld, skillsllm, pulsemcp) quoted "1,913★" or "2.5k★ trending" — these did **not** match the GitHub API and should not be trusted over direct verification. |
| Cheat Engine MCP | — | No actively-maintained, reputable project found with meaningful GitHub traction. |
| `trailofbits/skills-curated` → `ghidra-headless` | (part of 516★ repo) | Headless Ghidra analysis skill from a vetted marketplace. |

**Documentation MCP servers.**
- **Context7** (`upstash/context7`, 63,392★) — GitHub's *own* docs use it as the canonical MCP example (`copilot mcp add context7 -- npx -y @upstash/context7-mcp`; HTTP: `https://mcp.context7.com/mcp`). Best for mainstream library docs (e.g. nlohmann/json, spdlog, DirectX headers) — unlikely to index REFramework itself (niche/undocumented).
- **Microsoft Learn MCP** (`MicrosoftDocs/mcp`, 1,950★) — official, good for Win32/MSVC/CMake/VS documentation grounding.
- **DeepWiki** — official hosted endpoint `https://mcp.deepwiki.com/mcp` (Cognition/Devin), addable as a remote HTTP MCP server with zero local install; the open-source wrapper `regenrek/deepwiki-mcp` (1,385★) is an alternative if you want a local proxy.
- `awesome-copilot` also ships a **`microsoft-docs` skill** (instruction-only, no MCP server) as a lighter-weight alternative.

**GitHub workflow.** The GitHub MCP server is already built into Copilot CLI (no install). `trailofbits/skills → gh-cli` redirects URL-fetch/curl calls to authenticated `gh`. `awesome-copilot`'s own `mcp.json` bundles one server, `github-agentic-workflows` (wraps `gh aw mcp-server`) — niche, optional.

**Planning / brainstorming / TDD / debugging.** Two real options, overlapping heavily with Copilot CLI's own built-in plan mode, `/research`, `/review`, and memory:
- **`obra/superpowers`** — the most complete, most battle-tested option (brainstorming → writing-plans → subagent-driven-development/executing-plans → test-driven-development → requesting/receiving-code-review → finishing-a-development-branch, plus systematic-debugging and verification-before-completion). Its mandatory RED-GREEN-REFACTOR TDD enforcement is a notable **mismatch risk** for reverse-engineering/native-hooking work, where tests against a live game binary aren't always practical — plan to use selectively.
- **`awesome-copilot`'s own planning skills** (`create-implementation-plan`, `breakdown-plan`, `refactor-plan`, `structured-autonomy-plan`, etc.) — lighter-weight, GitHub-native, but likely redundant with Copilot CLI's built-in `/plan` mode; I could not determine how they interact if both are installed simultaneously.

**Skill authoring.** `anthropics/skills → skill-creator` (official, from the 182K★ repo) and `awesome-copilot → microsoft-skill-creator` are both reasonable choices for later authoring a project-specific "REFramework Lua API" or "MHW offset map" skill once your own conventions stabilize.

## Recommended install list (with commands)

Ordered by expected value for *this* project. All commands are drawn verbatim from official docs or the upstream project's own README.

1. **LSP code intelligence for C++ and Lua (highest priority, zero controversy).**
   Download the `lsp-setup` skill from `https://awesome-copilot.github.com/skills/?q=lsp`, unzip, move the folder to `.github/skills/` (project) or `~/.copilot/skills/` (personal), then in a session run `/skills reload` followed by the prompt `setup lsp` (select C/C++ → clangd, then Lua → lua-language-server). Verify with `/lsp`. *(Source: `docs.github.com/.../add-lsp-servers`.)* Prerequisite: clangd requires an LLVM install or a `compile_commands.json`/CMake `CMAKE_EXPORT_COMPILE_COMMANDS=ON` for your DLL target.

2. **Context7 MCP (library docs).**
   ```
   copilot mcp add context7 -- npx -y @upstash/context7-mcp
   ```
   This is GitHub's own documented example command. Prerequisite: Node.js/npx on PATH. Justification: 63K★, official docs endorsement, broadly useful for third-party headers/libs used in native mods (DirectX, MinHook-style hooking libs, JSON/logging libs).

3. **Microsoft Learn MCP (Win32/MSVC/CMake grounding).**
   ```
   copilot mcp add --transport http msdocs https://learn.microsoft.com/api/mcp
   ```
   *(URL form inferred from `MicrosoftDocs/mcp`'s nature as a hosted Streamable-HTTP server; confirm exact endpoint/flags with `copilot mcp add --help` or the repo's own README before relying on this exact string — not independently re-verified against the repo's setup instructions in this pass.)*

4. **Trail of Bits C++ skills (code quality/security for native DLL work).**
   ```
   copilot plugin marketplace add trailofbits/skills
   copilot plugin install modern-cpp@trailofbits
   copilot plugin install c-review@trailofbits
   copilot plugin install dwarf-expert@trailofbits
   ```
   (Marketplace registers under the name `"trailofbits"`, confirmed from its `marketplace.json`.) Justification: reputable named-author security firm, directly on-topic for C++20/23 idioms, security review, and debug-symbol work; low risk given Trail of Bits' own public commitment to code-reviewing every hook/script they publish.

5. **`build-perf-cpp` (official MSVC build-performance plugin).**
   ```
   copilot plugin install build-perf-cpp@copilot-plugins
   ```
   First-party (GitHub/Microsoft authors), MIT-licensed, directly matches your MSVC/CMake toolchain. Low priority but zero-risk and free.

6. **Superpowers — selectively.**
   ```
   copilot plugin marketplace add obra/superpowers-marketplace
   copilot plugin install superpowers@superpowers-marketplace
   ```
   *(Command copied verbatim from `obra/superpowers`'s own README "GitHub Copilot CLI" install section — the single strongest piece of evidence in this whole survey, since the upstream project itself documents first-class Copilot CLI support.)* 302K★, independently whitelisted by `trailofbits/skills-curated`. Use `/skills disable test-driven-development` (or similar) if its enforced RED-GREEN-REFACTOR workflow fights with RE/hook-development tasks that can't be unit-tested conventionally; keep `brainstorming`, `writing-plans`, `systematic-debugging`, `requesting-code-review`, and `using-git-worktrees`, which map cleanly onto "heavy web research + markdown planning docs + git workflow."

7. **Reverse-engineering MCP server — pick one, don't install both GhidraMCP and ida-pro-mcp blindly.** If you have Ghidra (free): `LaurieWired/GhidraMCP` (11.4K★). If you have a licensed IDA Pro ≥8.3: `mrexodia/ida-pro-mcp` (13K★). Detailed setup is out of scope for this thread per your own task split; both are reputable, actively maintained, and explicitly model-agnostic (work fine with current Claude/GPT-5.x-class models per community synthesis — though that synthesis is secondary-source, not a primary benchmark).

## Considered but not recommended

- **`obra/superpowers-skills`** — archived/superseded; install the main `obra/superpowers` repo instead.
- **`spark` plugin** (`github/copilot-plugins`) — React/Tailwind web-app bootstrapping; irrelevant to native C++ game modding.
- **`bromoket/x64dbg_mcp`** — only 133★, 8 months old, and its inflated reputation on aggregator sites doesn't hold up against the GitHub API. Not disqualifying, but treat as experimental/unproven rather than a default install, especially since it attaches a debugger to a live game process.
- **DeepWiki MCP** — moderately useful for OSS-repo Q&A, but redundant with Context7 + the built-in GitHub MCP server for this project's needs, and 2026 commentary flags general MCP context-bloat/staleness concerns if you stack too many doc servers at once. Add only if you specifically want repo-level "ask a question about this dependency's whole codebase" behavior.
- **`anthropics/claude-code` as a marketplace** — GitHub's own doc uses it as the install example, but its main value (Claude-Code-specific defaults) is better obtained via `anthropics/claude-plugins-official` or `anthropics/skills` directly for a Copilot CLI user.
- **`awesome-copilot`'s own planning/security skills** (`create-implementation-plan`, `security-review`, `mcp-security-audit`, etc.) — likely redundant with Copilot CLI's built-in `/plan` mode, `/research`, and `/security-review` agent that you mentioned already exist; I could not verify how skill-selection behaves if both built-ins and these skills are present simultaneously — test in a low-stakes session before relying on either.
- **`microsoft/cpp-language-server`** — only 54★, and I could not inspect its internals due to Microsoft-org SAML enforcement blocking anonymous API reads. Prefer clangd (the LLVM-standard, battle-tested choice) unless you specifically need MSVC-engine-parity behavior this plugin might offer.

## Security notes

- **Plugins can bundle hooks that run arbitrary shell/PowerShell commands** at `preToolUse`/`postToolUse`/session events, and skills can request `allowed-tools: shell`/`bash` pre-approval that *removes your confirmation prompt*. Docs explicitly warn to only do this for fully-reviewed sources ([add-skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)).
- **The skills/plugin ecosystem has had real incidents**: Trail of Bits states plainly that "published skills have been found with backdoors and malicious hooks" and that "the ecosystem has no built-in quality gate" (`trailofbits/skills-curated` README) — this is the strongest first-party evidence of supply-chain risk found in this research, from a credible security vendor, not speculation.
- **Third-party MCP servers can exfiltrate data to external services by design.** Context7, Microsoft Learn MCP, and DeepWiki are all hosted/remote services — queries (and potentially surrounding context) leave your machine. For a project involving reverse-engineering a commercial game's binaries, consider what you paste into prompts that then get sent to these tools' backends, and prefer local/offline MCP servers (e.g., self-hosted GhidraMCP) when working with anything sensitive.
- **Folder/tool trust is heuristic, not a hard sandbox** — GitHub's own docs state "GitHub does not guarantee that all files outside trusted directories will be protected" ([copilot-cli](https://docs.github.com/en/copilot/concepts/copilot-surfaces/copilot-cli)). Use `/sandbox enable` for an extra layer when running unfamiliar plugins/skills for the first time, especially ones that install LSP/debugger binaries or attach to a running game process.
- **Verify popularity claims against the GitHub API directly**, not aggregator/SEO blogs — this research caught at least one clear case (`x64dbg_mcp`) where third-party sites overstated star counts by ~10–20×.
- **Superpowers has optional, documented, disableable telemetry** (a logo ping including its own version number, no project/prompt data) — disable via `SUPERPOWERS_DISABLE_TELEMETRY=1` if undesired.

## Open questions / couldn't verify

- Exact `copilot mcp add` invocation syntax/flags for `MicrosoftDocs/mcp` (endpoint URL, auth headers) — I inferred a plausible command but did not fetch that repo's own setup instructions to confirm it verbatim.
- Internal contents of `microsoft/cpp-language-server` (its underlying LSP engine, whether MSVC- or clangd-based) — blocked by Microsoft-org SAML SSO enforcement on anonymous API reads.
- Whether `awesome-copilot`'s built-in planning/security skills conflict or cleanly coexist with Copilot CLI's native `/plan`, `/research`, and `/security-review` agents — not testable via static repo research alone.
- No REFramework-specific or Monster-Hunter-specific skill/plugin/MCP server exists in any marketplace surveyed (awesome-copilot, copilot-plugins, trailofbits, superpowers, anthropics) — confirmed by direct search of each repo's catalog, not merely absence of a web hit. You'll likely need to author this yourself with `skill-creator`.
- Reddit/HN sentiment was gathered via AI-synthesized web search rather than direct `old.reddit.com` JSON fetches (which redirected to a login wall in this sandbox) — treat community-sentiment claims in this report as a secondary-source synthesis, weighted lower than the GitHub-API-verified facts and primary docs.

---

## What was actually installed (2026-10-21, with the user's approval)
| Item | Scope | Command / location | Why |
|---|---|---|---|
| Context7 MCP | user | `copilot mcp add --transport http context7 https://mcp.context7.com/mcp` | Highly regarded; library docs (ImGui, sol2, CMake, Lua, Steamworks flat API). |
| Microsoft Learn MCP | user | `copilot mcp add --transport http microsoft-learn https://learn.microsoft.com/api/mcp` | Official; Win32/MSVC/CMake/**PlayFab Party** docs. |
| `modern-cpp@trailofbits` | user plugin | `copilot plugin marketplace add trailofbits/skills` → `copilot plugin install modern-cpp@trailofbits` | C++20/23 guidance; skills only (no hooks/MCP). |
| **praydog/re-engine-mcp** | **project** `.mcp.json` → `reframework` | cloned to `C:\src\re-engine-mcp`, server built with .NET 10 SDK, game plugin copied to `<game>\reframework\plugins\source\` | REFramework author's MCP server: the agent can inspect and call into the **live** game. Not found by the plugin survey; surfaced by the ecosystem research (note 05). |
| **GhidraMCP 2.0** + Ghidra 12.1.4 | **project** `.mcp.json` → `ghidra` | `tools/setup/install-ghidra.ps1`; bridge venv `C:\src\_tools\ghidra-mcp-venv` | Native RE when needed (user opted in). |
| clangd 23 + lua-language-server 3.19 | **project** `.github/lsp.json` | winget (machine scope) | Code intelligence for C++ and Lua. |

Not installed: **Superpowers** (popular, but overlaps Copilot CLI's built-in plan mode, `/research`, `/review`,
rubber-duck and fleet; mixed views on its value with current frontier models; user did not select it), Trail of Bits
`c-review`/`dwarf-expert` (DWARF is irrelevant for MSVC/PE), `build-perf-cpp` (not needed yet), DeepWiki (redundant).
Playwright was set up as a small repo-local script (`tools/web-research`) instead of an MCP server.
