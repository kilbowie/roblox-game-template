# CLAUDE.md — working in this repo

This is a Roblox game written in **Luau**, synced into Studio by **Rojo**. Code lives in `src/`.
The map, models and lighting live in the Studio place file, not in this repo.

## Layout

```
src/shared/   -> ReplicatedStorage.Shared   (config + code used by server and client)
src/server/   -> ServerScriptService.Server (Main.server.luau boots Services/ then Game/)
src/client/   -> StarterPlayerScripts.Client (Main.client.luau boots Controllers/)
```

- `*.server.luau` = Script, `*.client.luau` = LocalScript, plain `*.luau` = ModuleScript.
- `src/server/Services/` is the shared core reused by every game. Change it only when the
  change belongs in every game.
- `src/server/Game/` is this game's loop. Most feature work happens here.

## Rules (do not break these)

1. **Server authority.** The client only asks; the server decides. Validate every remote
   argument (type, range, rate). Never trust a client-sent amount, price, product or result.
2. **All remotes are declared in `src/shared/Net.luau`.** Do not create remotes elsewhere.
3. **All tunables live in `GameConfig.luau`; all pass/product IDs live in `Products.luau`.**
   No magic numbers or IDs in services.
4. **Purchases go through `MonetisationService` only.** There is exactly one
   `MarketplaceService.ProcessReceipt`. New product types = `RegisterGrant(kind, handler)`.
   Grant handlers must not yield and must fully succeed or error with no side effects.
   Never return `PurchaseGranted` before the save succeeded.
5. **Save data changes go through `DataService`.** Mutate the table from `DataService.Get`,
   then call `DataService.MarkDirty`. Add new fields to `GameConfig.DataTemplate` (they are
   back-filled into old saves). Never rename or reuse an existing field after launch.
6. **Never change `GameConfig.Data.StoreName` after launch.**
7. **Analytics must never break gameplay.** Use `Telemetry`, which wraps every call in pcall.
8. Keep `stylua --check src` and `selene src` clean before committing.

## Working with Studio through MCP

The Studio MCP server lets you inspect the open place, run Luau, start and stop play mode
(`start_stop_play`), check the mode (`get_studio_mode`), run a script during play
(`run_script_in_play_mode`) and read output (`get_console_output`).

Loop for every change:

1. Edit files in `src/` (Rojo syncs them into Studio while `rojo serve` is running).
2. Start play mode, exercise the change, read the console output for errors and warnings.
3. Stop play mode. Fix and repeat until the output is clean.
4. Run `stylua src` and `selene src`.

Map building (parts, terrain, lighting, UI art made in Studio) is done in Studio via MCP and
saved in the place file. Anything that is code goes in `src/`.

Purchases cannot be fully tested until the place is published and IDs are set in
`Products.luau`. Studio purchase prompts are free test purchases. Ask the user before
changing anything in `Products.luau`, `DataService.luau` or `MonetisationService.luau`.

## Definition of done for a feature

- Works in a Studio playtest with no new errors or warnings in output.
- New tunables are in `GameConfig`, new remotes in `Net`, new products in `Products`.
- Analytics event added if the feature affects onboarding, progression or spending.
- Format and lint clean.
