# SIGNAL '85 — Roblox game starter

**Pitch:** 1985, the small town of Hollow Creek. A rift has torn open to **the Undergrid**, a dark, spore-filled mirror of the town where shadow creatures called **Hollowers** drift through walls. Every player is a **Shiftframe** — a robot that transforms into a car. Cross the rift, grab Signal Shards, race them back to the radio tower and seal the rift before the Undergrid swallows the town.

## Project layout (Rojo)
| File | Becomes in Studio |
|---|---|
| `src/server/Signal85Server.server.lua` | Script `ServerScriptService.Signal85Server` |
| `src/client/Signal85Client.client.lua` | LocalScript `StarterPlayer.StarterPlayerScripts.Signal85Client` |

`default.project.json` maps the files; `rokit.toml` pins the Rojo version (7.7.1).

## Setup with live sync
1. Open Roblox Studio → New → **Baseplate**. Delete the Baseplate part (the script builds its own map).
2. In a terminal in this folder, run `rojo serve` and leave it running.
3. In Studio: **Plugins** tab → **Rojo** → **Connect** (default `localhost:34872`).
4. Press **Play**. Edits to the files in `src/` sync into Studio while connected.

Save the place in Studio as usual (File → Save to Roblox); Rojo only manages the two scripts.

To build a place file without Studio: `rojo build -o Signal85.rbxlx`.

### First-time install on a new computer
1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Run `rojo plugin install` to add the Rojo plugin to Studio (restart Studio afterwards).

## Controls
| Key | Action |
|---|---|
| F | Transform: robot ⇄ vehicle |
| Q | Arm blaster (robot mode only) — aim with the mouse |
| E | Shift through the rift (stand next to the red ring) |

Mobile and gamepad buttons are created automatically.

## How it plays
- **Robot mode:** armored, speed 18, can shoot Hollowers.
- **Vehicle mode:** speed 75, no weapon — use it to escape and to run shards home.
- The rift sits in the field east of Main Street. Shards spawn only in the Undergrid.
- Deliver shards at the green console under the radio tower (north end of the road). Die and you drop what you carry.
- Deliver 6 shards as a team → rift sealed → 12 seconds later it reopens and a new round starts.

## Tuning
Everything is in the `CONFIG` table at the top of the server script: speeds, damage, creature count, shards needed, etc.

## Ideas for the next version
- **Sound:** add a synth-wave music loop and transform / blaster sounds (Toolbox → Audio, then put `Sound` objects in the scripts).
- **Real models:** replace the part-built car and robot with meshes you model in Blender, keeping the same weld approach.
- **Boss:** a giant Hollower "Mind Warden" that appears when the seal reaches 50%.
- **Classes:** scout (fast car), tank (truck, more health), jet (flies in vehicle mode).
- **Data saving:** save total shards with DataStoreService and unlock new Shiftframe paint jobs.
- **Story:** walkie-talkie messages from kids in town giving hints, comic-style intro cutscene.

Keep names, characters and art original — don't use names or logos from existing shows or toy brands, or Roblox may take the game down.
