# 017 — Robux: Game Passes and Scrap packs

Status: IN PROGRESS

The user asked on 2026-11-09 to complete everything (Game Passes were planned last) and will test it all together. Claude chose the items; they're easy to change in `CONFIG` and the Robux section of the server script.

## Items
| Item | Type | Effect |
|---|---|---|
| VIP PILOT | Game Pass | +25% gameplay Scrap & XP, double daily reward, "VIP" tag on the HUD |
| NEON SUIT PACK | Game Pass | 3 exclusive suit paints: SYNTHWAVE, CHROME, STATIC |
| AMMO BELT | Game Pass | +50% spare ammo, free Pulse Cannon refill every 10 min (instead of 20) |
| 500 SCRAP / 1500 SCRAP | Developer Products | Scrap, saved right away |

Design rule: nothing that can't also be earned by playing. Passes speed things up or are cosmetic.

## How it works
- Ids are in `CONFIG.GAME_PASSES` and `CONFIG.PRODUCTS`. `0` = not set up: the shop shows "SOON" and explains.
- Passes are checked with `UserOwnsGamePassAsync` on every join, and with `PromptGamePassPurchaseFinished` during play. They are not saved, because Roblox is the source of truth.
- Scrap packs use `ProcessReceipt`:
  - It waits until the profile is loaded and the player has left the start menu.
  - It never grants a `PurchaseId` twice (handled receipts are kept in the save).
  - It writes the save right away and returns `NotProcessedYet` if that fails, so Roblox retries.
- Shop: a third tab, **ROBUX**, opens Roblox's own purchase window. Prices come from `GetProductInfo`, and the shop refreshes after a purchase.

## Setup (the user, on the Roblox website)
1. Publish the game.
2. Creator Dashboard → the game → **Monetization → Passes**: create VIP PILOT, NEON SUIT PACK and AMMO BELT, then set a price and put each on sale.
3. **Monetization → Developer Products**: create 500 SCRAP and 1500 SCRAP, with prices.
4. Copy each id into `CONFIG.GAME_PASSES` / `CONFIG.PRODUCTS` in the server script.
5. Test in Studio: purchases there are free test purchases.
