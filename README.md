# Seamless Co-op — Monster Hunter Wilds

Play Monster Hunter Wilds' **main story together from the first step of every story quest** — ride, talk, investigate,
fight small monsters and watch story cutscenes as one party — instead of soloing to each quest's cutscene and regrouping
through SOS.

> **Status: early development (Phase 2 of 8).** Nothing here is playable yet. The groundwork is done: the in-game
> panel, build checks, save backups at launch, and a private Steam side channel through which modded party members
> recognise each other. The story features come next. Inspired by
> [Elden Ring Seamless Co-op](https://www.nexusmods.com/eldenring/mods/510) and
> [MHW Seamless Co-op](https://www.nexusmods.com/monsterhunterworld/mods/8805).

## Planned scope (v1.0)

- **Seamless story join**: Link Party members at the same story point join the leader's story quest from its start.
- **Together through story segments**: shared travel, dialogue, objectives and NPCs before the hunt.
- **Shared story cutscenes** with vote-to-skip.
- **Auto-follow** the leader into quests and back.
- **Safety net**: build checks, save backups, progress guards, kill switch. The mod never touches quest data or rewards.
- **In-game panel**: party/mod status, settings, diagnostics.

Requirements (planned): PC (Steam), latest game version, [REFramework](https://github.com/praydog/REFramework).
**Everyone in the party needs the mod and must be Steam friends with each other.** No crossplay with consoles in
seamless mode.

## Building from source

Windows, VS 2022 Build Tools (MSVC x64), CMake ≥ 3.25, Ninja. In a *x64 Native Tools* / vcvars64 shell:

```
cmake --preset release
cmake --build --preset release
ctest --preset release
```

The first configure downloads the pinned REFramework plugin header and its Lua 5.4.3 sources, plus Catch2. Layout:
`src/lua/` (the REFramework Lua mod), `src/plugin/` (`seamless_net.dll`), `tests/`. Developers deploy with
`tools/deploy.ps1 -Mod`; see [docs/dev-environment.md](docs/dev-environment.md).

## Documentation

| Document | Purpose |
|---|---|
| [docs/feature-spec.md](docs/feature-spec.md) | What the mod does: features, rules, acceptance criteria, settings, edge cases |
| [docs/implementation-plan.md](docs/implementation-plan.md) | How it will be built: architecture, diagrams, protocol, RE spike, roadmap, risks |
| [docs/dev-environment.md](docs/dev-environment.md) | Toolchain, game-side dev setup (and how to revert it), agent tooling |
| [docs/testing/remote-testing.md](docs/testing/remote-testing.md) | How two-player testing works with a remote tester |
| [docs/research/](docs/research/00-research-summary.md) | Research notes (reference mods, Wilds multiplayer, community sentiment, modding ecosystem, RE tooling, game internals) |

## Risk statement

Any mod that changes online behaviour carries **account risk**. Capcom suspends accounts over modified quest data and
"takes action based on play data and history". This mod is designed to never alter quest data, rewards or saves. It
uses only the game's own functions and works only between consenting modded party members. Even so, the risk cannot be
ruled out.

## Licence

[MIT](LICENSE). Monster Hunter Wilds is © CAPCOM; this project is unofficial and not affiliated with Capcom.
AI assistance (GitHub Copilot) is used in research and development and disclosed here.
