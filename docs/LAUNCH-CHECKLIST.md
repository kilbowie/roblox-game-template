# Launch checklist

Run through this before every launch. Launch on a Friday to catch weekend traffic.

## Code and data

- [ ] `GameConfig.Data.StoreName` is final (it can never change after launch)
- [ ] All pass and product IDs set in `Products.luau`; no "unconfigured" warning in Output
- [ ] Test purchases done for every item: granted, persists after rejoin, no double grant
- [ ] CI green on `main` (format, lint, build)
- [ ] Two-player playtest (Test > Clients and Servers) with no errors in server or client output

## First 60 seconds

- [ ] A new player knows what to do within 10 seconds, without reading
- [ ] First stage unlock reachable in under 3 minutes
- [ ] Shop is one tap away and readable on a phone screen
- [ ] Runs well on a low-end phone (Studio device emulator)

## Store page

- [ ] Original name, icon and thumbnails (no other game's names, characters or art)
- [ ] Maturity questionnaire completed honestly
- [ ] Avatar type set to R15 (required for the higher US 18+ DevEx rate)
- [ ] Description states the core loop in one line

## After launch

- [ ] Day 1: check errors in Creator Hub > Analytics, fix anything above noise
- [ ] Day 7: gate review: D1 retention, like ratio, Robux per visit (see build plan)
- [ ] Weekly update while the game stays at "Iterate" or "Scale"
