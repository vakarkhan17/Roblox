# 004 — Scrap, shop, weapons and upgrades

Status: DONE

## Goal
Give players something to earn and spend: a saved in-game currency (**Scrap**), a shop with new weapons and permanent upgrades. Everything is earned by playing (no Robux; Game Passes come last, as a separate task).

## Scrap (server, saved)
| Action | Scrap | Who gets it |
|---|---|---|
| Deliver a shard | +10 per shard | the player who delivered |
| Kill a Hollower | +2 | the player whose shot killed it |
| Destroy a Hive Node | +25 | the player whose shot destroyed it |
| Defeat the Mind Warden | +200 | everyone on the server |
| Finish a chapter | +100 | everyone on the server |

- Shown in `leaderstats` (`Scrap`) and as a small `+10 SCRAP` popup.
- Saved with the game (new optional save fields: `scrap`, `owned`, `weapon`, `upgrades`; old saves still load).

## Weapons (equip one; robot mode only)
| Id | Name | Behaviour | Price |
|---|---|---|---|
| `pulse` | Pulse Cannon | 45 dmg, 0.25 s, small splash (current weapon) | free |
| `arc` | Arc Repeater | 20 dmg, 0.1 s, no splash | 400 |
| `scatter` | Static Scattergun | 5 pellets x 18 dmg, spread, 70 range, 0.6 s, splash | 700 |
| `lance` | Lowband Lance | 140 dmg, 1.2 s, pierces up to 4 enemies, x1.5 vs the Mind Warden | 1500 |

## Upgrades (permanent, 3 levels each)
| Id | Name | Per level | Prices |
|---|---|---|---|
| `armor` | Armor Plating | +25 max health | 150 / 300 / 500 |
| `turbo` | Turbo | +10% car speed | 150 / 300 / 500 |
| `shield` | Shield Capacitor | +2 s rift shield | 100 / 200 / 350 |

## Shop
- Open from **MENU → SHOP** or at the **Garage** next to the town spawn (ProximityPrompt, works on phone).
- Tabs WEAPONS / UPGRADES; each item shows what it does, price and BUY / EQUIP / EQUIPPED / MAX.
- Server validates everything (`Shop` RemoteFunction: `list`, `buy`, `equip`); the client never sends prices.

## Acceptance
- Killing Hollowers, delivering shards etc. gives Scrap with a popup; Scrap survives Stop/Play when saving is on.
- Buying deducts Scrap, can't go negative, owned items stay owned after rejoining.
- Each weapon fires as described (hold-to-fire rate follows the weapon); upgrades apply after respawn too.
- Works on phone.

## Notes
- Scrap from creatures, shards, nodes and chapter clears; shop at the garage (prompt) and from the menu.
- Weapons: Pulse (free), Shock Baton (free melee, added on request), Arc, Scatter, Lance. R / SWAP cycles owned weapons.
- Upgrades: armor, turbo, shield. Optional auto-aim (Settings) for playing without a mouse.
- Left open: Game Passes / Robux items, to be done last.
