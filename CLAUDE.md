# SIGNAL '85 (Roblox)

Roblox game in Luau. 1985 small-town mystery + transforming robots; all names and art must stay original (no names/logos from existing shows or toy brands).

- `src/server/Signal85Server.server.lua` — Script for ServerScriptService. Builds the whole map by code, handles transform, blaster, rift shifting, creatures (Hollowers), shards and rounds. Tunables live in the `CONFIG` table at the top.
- `src/client/Signal85Client.client.lua` — LocalScript for StarterPlayerScripts. Lighting presets, HUD, input (F transform, Q blast, E shift), camera shake.
- `default.project.json` — Rojo project file for syncing into Roblox Studio.

Conventions: server is authoritative (validate every RemoteEvent), remotes live in `ReplicatedStorage.Signal85Remotes`, player state is exposed through attributes (`Dimension`, `Carrying`, character `Mode`; `ReplicatedStorage` `Progress`/`Goal`).

## Workflow: planning in Claude chat, building in Claude Code
Design and planning happen in a separate Claude chat. Decisions reach this repo as files:

- `docs/STORY.md` — lore and names. Follow it; don't invent new canon without being asked.
- `docs/tasks/NNN-name.md` — one spec per feature, each with a `Status:` line (`TODO`, `IN PROGRESS`, `DONE`).

When asked to "do the next task" (or a task by number):
1. Read the spec fully, plus `docs/STORY.md` if the task touches story or text.
2. Set its status to `IN PROGRESS`, implement it, keeping the conventions above.
3. Add any new script to `default.project.json`.
4. Check every requirement and acceptance item in the spec. You can't run Roblox here, so re-read the code carefully for Luau errors and say what the user should test in Studio.
5. Set status to `DONE`, add a short `## Notes` section to the spec (what changed, anything left open), commit, and push.

If a spec is unclear or conflicts with the code, make the smallest sensible choice, note it in `## Notes`, and keep going rather than stopping.
