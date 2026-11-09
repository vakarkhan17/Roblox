# 012 — Camera, compass + target choice, stuck elevators, firepower

Status: DONE

From the user's feedback on 2026-11-09. Points 1–3 were approved and built. Point 4 (firepower) is waiting for approval of the final design.

## 1. Camera (built)
- Inside the Grand Hotel, walls between the camera and the player turn see-through (Invisicam) instead of pushing the camera in, and max zoom is 16 studs. Outside, it goes back to normal.
- A CAMERA touch button (key C) swings the camera behind the character.

## 2. Elevators in Chapters 2 and 3 (built, option A)
- They stay stuck, but the prompt stays visible: "Elevator stuck" (Chapter 2, Hive growth) or "No power" (Chapter 3).
- Using it shows "TAKE THE STAIRS", and the panel turns red and flickers.

## 3. Compass + target choice (built)
- A compass arrow at the top centre turns toward the target. The text says AHEAD / TURN LEFT / TURN RIGHT / BEHIND YOU, plus the distance and the floors up or down.
- The diamond on the target stays when it's on screen. The edge arrow is gone.
- TARGET (touch) / Y / D-pad right cycles the options:
  - the recommended target
  - other shards, nodes, files or relays
  - the console when carrying shards
  - the rift

  The choice resets when the stage changes.

## 4. Firepower (built, approved with the user's "free refill = half" rule)
- Each gun has a magazine, a reload and limited spare ammo:

  | Gun | Magazine | Spare | Reload |
  |---|---|---|---|
  | Pulse | 20 | 120 | 1.6 s |
  | Arc | 40 | 240 | 1.8 s |
  | Scatter | 6 | 36 | 2 s |
  | Lance | 4 | 20 | 2.2 s |

  Reloading is automatic when the magazine is empty. The Shock Baton is unlimited.
- More ammo:
  - **Free ammo is only for the basic Pulse Cannon** (user's rule):
    - creatures drop a Pulse magazine 15% of the time (orange AMMO box)
    - a free refill every 20 min (10 min below level 5) tops the Pulse Cannon up to **half** of full
  - The bought guns (Arc, Scatter, Lance) only refill for Scrap: a full refill of every gun you own costs 40 Scrap at the Garage / SHOP (first row of WEAPONS).
- New upgrades: BIGGER MAGAZINE (+25% per level) and FAST RELOAD (-15% per level).
- Ammo and the refill timer are saved, so rejoining or dying doesn't refill.
- HUD under the screen centre: `PULSE CANNON 18 / 20 SPARE 96`, RELOADING..., OUT OF AMMO, and the refill timer.
- Tunables are in `CONFIG` (`AMMO_*`) and `WEAPONS.*.mag / reserve / reload`.

## Notes
- Tested and approved in Studio. Ammo tunables are `CONFIG.AMMO_*` and the `WEAPONS.*.mag/reserve/reload` lines.
- Left open: tune the numbers after more play.
