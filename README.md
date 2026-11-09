# SIGNAL '85 — Roblox game starter

**Pitch:** 1985, the small town of Hollow Creek. A rift has torn open to **the Undergrid**, a dark, spore-filled mirror of the town where shadow creatures called **Hollowers** drift through walls. Every player is a **Shiftframe** — a robot that transforms into a car. Cross the rift, grab Signal Shards, race them back to the radio tower and seal the rift before the Undergrid swallows the town.

## Project layout (Rojo)
| File | Becomes in Studio |
|---|---|
| `src/server/Signal85Server.server.lua` | Script `ServerScriptService.Signal85Server` |
| `src/client/Signal85Client.client.lua` | LocalScript `StarterPlayer.StarterPlayerScripts.Signal85Client` (HUD, controls, target marker) |
| `src/client/IntroBroadcast.client.lua` | LocalScript `StarterPlayer.StarterPlayerScripts.IntroBroadcast` |
| `src/client/Tutorial.client.lua` | LocalScript `StarterPlayer.StarterPlayerScripts.Tutorial` ("First Night" tutorial) |
| `src/client/StartMenu.client.lua` | LocalScript `StarterPlayer.StarterPlayerScripts.StartMenu` (title / pause menu, mission briefing) |

`default.project.json` maps the files; `rokit.toml` pins the Rojo version (7.7.1).

## Setup with live sync
1. Open Roblox Studio → New → **Baseplate**. Delete the Baseplate part (the script builds its own map).
2. In a terminal in this folder, run `rojo serve` and leave it running.
3. In Studio: **Plugins** tab → **Rojo** → **Connect** (default `localhost:34872`).
4. Press **Play**. Edits to the files in `src/` sync into Studio while connected.

Save the place in Studio as usual (File → Save to Roblox); Rojo only manages the scripts.

To build a place file without Studio: `rojo build -o Signal85.rbxlx`.

### First-time install on a new computer
1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Run `rojo plugin install` to add the Rojo plugin to Studio (restart Studio afterwards).

## Controls
| Laptop | Phone | Action |
|---|---|---|
| G | SUIT UP / SUIT OFF | Put the robot suit on or take it off (pilot on foot) |
| F | TO CAR / TO ROBOT | Transform: robot ⇄ vehicle |
| Hold Q or left mouse | Hold BLAST | Fire the current weapon (robot mode only); auto-aim can be turned on in Settings |
| R | SWAP | Swap to the next weapon you own |
| E | RIFT / tap prompt | Shift through the rift, open hotel doors, use the elevator |
| M / K | MENU / SAVE | Pause menu / save the game |
| REWARDS button | REWARDS | Daily reward, daily quests, achievements, top pilots, codes, invite friends |
| T | PING | Mark a spot (or an enemy / item) for everyone |
| Y | TARGET | Switch the compass to another target (another shard, node, the rift...) |
| C | CAMERA | Swing the camera behind you |
| Hold E | Hold the prompt | Revive a downed teammate |
| H | ? | How to play |
| - / + | - / + | Darker / brighter |

A yellow marker always points to your next target.

## How it plays
- After the intro: **CONTINUE**, **NEW GAME** or **CHAPTER SELECT** (replay any chapter you reached), then a mission briefing with pictures of what to do.
- **Chapter 1, Seal the Rift:** enter the rift east of Main Street, collect Signal Shards in the Undergrid, deliver 6 to the green console under the radio tower.
- **Chapter 2, The Source:** destroy 3 Hive Nodes in the Undergrid, then defeat the Mind Warden by the Undergrid radio tower (shoot it while its head is open, jump over shockwaves).
- **Chapter 3, LOWBAND:** recover the lab files, power the relays, escort the Carrier and win the race.
- **The Grand Hotel** is used in every chapter: 5 floors, guest rooms (press E at a door), washrooms, grand stairs and elevators. It changes a little each chapter.
- **Scrap** from creatures and missions buys weapons and upgrades at the garage or from the menu.
- **Pilot level:** gameplay Scrap also gives XP. Levels unlock suit paints (5, 10), the ponytail hair (15) and the VETERAN title (20).
- **Come back daily:** a 7-day reward streak, 3 daily quests, 16 achievements, the TOP PILOTS board by the garage, codes, and 2x Scrap + XP on weekends (Fri–Sun UTC).
  For testing, `CONFIG.DEBUG_DAY_OFFSET` (pretend it's N days later) and `CONFIG.DEBUG_FORCE_WEEKEND` are at the top of the server script.
- **Robot mode:** armored, can shoot. **Vehicle mode:** fast, no weapon, half shockwave damage.

## Saving
Saving uses DataStores, so in Studio it only works when:
1. the place is **published** (File → Publish to Roblox), and
2. **Game Settings → Security → Enable Studio Access to API Services** is ON.

Otherwise the game still runs and the menu shows `SAVING UNAVAILABLE` with only NEW GAME.
The game auto-saves on every chapter start and stage change and when you leave; SAVE / K saves at any time (once every 15 s).

## Tuning
Everything is in the `CONFIG` table at the top of the server script: speeds, damage, creature count, shards needed, etc.

## Ideas for the next version
- **Sound:** add a synth-wave music loop and transform / blaster sounds (Toolbox → Audio, then put `Sound` objects in the scripts).
- **Real models:** replace the part-built car and robot with meshes you model in Blender, keeping the same weld approach.
- **Classes:** scout (fast car), tank (truck, more health), jet (flies in vehicle mode).
- **Unlocks:** new Shiftframe paint jobs for lifetime shards.
- **Story:** walkie-talkie messages from kids in town giving hints, comic-style intro cutscene.

Keep names, characters and art original — don't use names or logos from existing shows or toy brands, or Roblox may take the game down.
