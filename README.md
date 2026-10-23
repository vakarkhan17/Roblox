# SIGNAL '85 — Roblox game starter

**Pitch:** 1985, the small town of Hollow Creek. A rift has torn open to **the Undergrid**, a dark, spore-filled mirror of the town where shadow creatures called **Hollowers** drift through walls. Every player is a **Shiftframe** — a robot that transforms into a car. Cross the rift, grab Signal Shards, race them back to the radio tower and seal the rift before the Undergrid swallows the town.

## Setup (5 minutes)
1. Open Roblox Studio → New → **Baseplate**. Delete the Baseplate part (the script builds its own map).
2. In **ServerScriptService**, insert a **Script**, name it `Signal85Server`, paste `Signal85Server.server.lua`.
3. In **StarterPlayer → StarterPlayerScripts**, insert a **LocalScript**, name it `Signal85Client`, paste `Signal85Client.client.lua`.
4. Press **Play**.

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

## Syncing with Rojo (optional)
Install [Rojo](https://rojo.space), run `rojo serve` in this folder, and connect from the Rojo plugin in Studio. Scripts then update live as you edit them in Claude Code.
