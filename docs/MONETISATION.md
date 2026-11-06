# Monetisation setup

The kit ships with three game passes and four developer products, all with `id = 0`.
Nothing is sold until you create each item on Roblox and paste its ID into
`src/shared/Config/Products.luau`.

## Default catalogue

| Key | Type | What it does | Suggested starting price |
| --- | --- | --- | --- |
| `DoubleGains` | Pass | 2x all gains, forever | 99–199 R$ |
| `AutoTrain` | Pass | Trains every second while toggled on | 149–249 R$ |
| `VIP` | Pass | +25% gains | 249–399 R$ |
| `Boost2x15m` | Product | 2x gains for 15 min, stacks | 25–49 R$ |
| `PowerPackSmall` | Product | 250 × current stage Power | 25–49 R$ |
| `PowerPackLarge` | Product | 2,000 × current stage Power | 149–249 R$ |
| `AdBoost` | Product | 2x for 5 min, **granted by rewarded ads only** | Any price; never shown in the shop |

Prices are starting points to test, not benchmarks. Change one price at a time and watch
Robux per visit.

## 1. Create the items

1. Publish the place once (File > Publish to Roblox).
2. Creator Hub > Creations > your game > **Monetization > Passes**: create each pass, set a price, put it on sale.
3. **Monetization > Developer Products**: create each product and set a price.
4. Copy each ID into the matching `id` in `Products.luau`.
5. Play in Studio: the Output warning listing unconfigured items should be gone.

## 2. Test purchases

- Purchases prompted in Studio are free test purchases.
- Check after each test: the grant appears, it survives leaving and rejoining, and buying
  again grants again (products) or shows OWNED (passes).
- To test retry safety (published place, real DataStores): temporarily add `task.wait(20)`
  just before `DataService.SaveNow` in `processReceipt`, buy, then stop the playtest within
  20 seconds. On the next play the purchase should be granted exactly once. Remove the wait.

## 3. How grants are kept safe

`MonetisationService` handles every developer product receipt like this:

1. Waits for the player's save data. If it is not ready, Roblox retries later.
2. If the receipt's `PurchaseId` is already in the save, it only confirms (after a save).
3. Runs the grant handler, records the `PurchaseId` in the same save data, saves immediately.
4. Returns `PurchaseGranted` only after that save succeeds.

So a purchase can never be granted twice, and a crash mid-purchase never loses it.

## 4. Rewarded video ads

- `RewardedAdService` shows an ad on request (5-minute cooldown per player by default) and
  the reward arrives through `ProcessReceipt` as the `AdBoost` product.
- The button only appears when Roblox reports an ad is available, and is hidden from anyone
  who has spent Robux (`GameConfig.Ads.HideForSpenders`).
- Eligibility per Roblox's docs at the time of writing: creator 13+, ID-verified account,
  public game with at least 2,000 unique visitors a month. Check current requirements before launch.

## 5. Adding a new kind of product

```lua
-- In your game service's Start():
MonetisationService.RegisterGrant("coins", function(player, data, def)
	data.coins += def.amount
end)
```

Then add products with `grant = "coins"` and an `amount` in `Products.luau`.
