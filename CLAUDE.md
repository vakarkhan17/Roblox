# SIGNAL '85 (Roblox)

Roblox game in Luau. 1985 small-town mystery + transforming robots; all names and art must stay original (no names/logos from existing shows or toy brands).

- `src/server/Signal85Server.server.lua` — Script for ServerScriptService. Builds the whole map by code, handles transform, blaster, rift shifting, creatures (Hollowers), shards and rounds. Tunables live in the `CONFIG` table at the top.
- `src/client/Signal85Client.client.lua` — LocalScript for StarterPlayerScripts. Lighting presets, HUD, input (F transform, Q blast, E shift), camera shake.
- `default.project.json` — Rojo project file for syncing into Roblox Studio.

Conventions: server is authoritative (validate every RemoteEvent), remotes live in `ReplicatedStorage.Signal85Remotes`, player state is exposed through attributes (`Dimension`, `Carrying`, character `Mode`; `ReplicatedStorage` `Progress`/`Goal`).
