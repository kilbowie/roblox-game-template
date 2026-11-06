# Roblox Game Template

Kilbowie's starter for shipping small Roblox games fast: Luau + Rojo, a shared monetisation
kit that is safe with real Robux, session-locked save data, analytics wired for kill / scale
decisions, and a playable "+1" incremental loop (G1) on top.

## What's in the box

| Layer | Files | Reuse across games? |
| --- | --- | --- |
| Config | `src/shared/Config/GameConfig.luau`, `Products.luau` | Edit per game |
| Save data | `src/server/Services/DataService.luau` | Yes, unchanged |
| Monetisation | `MonetisationService.luau`, `RewardedAdService.luau` | Yes, unchanged |
| Analytics | `Telemetry.luau` | Yes, unchanged |
| Networking | `src/shared/Net.luau`, `Signal.luau` | Yes, add remotes as needed |
| Game loop (G1) | `src/server/Game/TrainingService.luau` | Replace per game |
| Placeholder UI | `src/client/Controllers/*` | Restyle per game |

## Quick start (about one evening)

1. **Tools.** Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
   Install the Rojo plugin in Studio (`rojo plugin install`).
2. **Studio place.** Create a new Baseplate place in Roblox Studio and publish it once
   (File > Publish to Roblox), under your Roblox Group.
3. **Enable saves in Studio.** Game Settings > Security > *Enable Studio Access to API Services*.
   Without it, DataService runs in memory-only mode and warns you.
4. **Sync code.** Run `rojo serve` here, then click **Connect** in the Rojo plugin.
   Code now lives in `src/`; the map and models live in the place file.
5. **Connect Claude Code.** In Studio: Assistant > ⋯ > Manage MCP Servers > *Enable Studio as
   MCP server*, then register it in Claude Code. `CLAUDE.md` tells Claude how to work here.
6. **Play.** Press Play. You should see Power, the Train button (or press E), and the Shop.
   The Output window lists which pass/product IDs are still unconfigured.

## Day-to-day

```bash
rojo serve              # live-sync src/ into Studio
stylua src              # format
selene src              # lint
rojo build -o game.rbxlx  # build a place file (CI does this on every push)
```

CI (`.github/workflows/ci.yml`) runs format check, lint and a Rojo build on every push to `main`.

## Starting a new game from this template

1. Copy the repo (GitHub: *Use this template*) and rename it.
2. Edit `GameConfig.luau`: game name, a fresh `Data.StoreName`, stages, multipliers.
3. Edit `Products.luau`: the passes and products this game sells.
4. Replace `src/server/Game/` with the new game's loop. Register any new product kinds with
   `MonetisationService.RegisterGrant(kind, handler)`.
5. Keep `src/server/Services/` unchanged unless the change belongs in every game, in which
   case make it here in the template too.

## Further docs

- [`docs/MONETISATION.md`](docs/MONETISATION.md): creating passes and products, testing purchases, rewarded ads
- [`docs/LAUNCH-CHECKLIST.md`](docs/LAUNCH-CHECKLIST.md): before every launch
- [`CLAUDE.md`](CLAUDE.md): rules and workflow for Claude Code
