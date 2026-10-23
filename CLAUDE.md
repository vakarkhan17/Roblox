# SIGNAL '85 (Roblox)

Roblox game in Luau. 1985 small-town mystery + transforming robots; all names and art must stay original (no names/logos from existing shows or toy brands).

- `src/server/Signal85Server.server.lua` — Script for ServerScriptService. Builds the whole map by code, handles transform, blaster, rift shifting, creatures (Hollowers), shards and rounds. Tunables live in the `CONFIG` table at the top.
- `src/client/Signal85Client.client.lua` — LocalScript for StarterPlayerScripts. Lighting presets, HUD, input (F transform, Q blast, E shift), camera shake.
- `default.project.json` — Rojo project file for syncing into Roblox Studio.

Conventions: server is authoritative (validate every RemoteEvent), remotes live in `ReplicatedStorage.Signal85Remotes`, player state is exposed through attributes (`Dimension`, `Carrying`, character `Mode`; `ReplicatedStorage` `Progress`/`Goal`).

## Workflow: plan in Claude chat → build locally → Rojo → GitHub
Design and planning happen in a separate Claude chat, which pushes task files to GitHub. Claude Code runs on the user's computer in this local repo. Rojo (`rojo serve`) syncs this local folder into Roblox Studio live. GitHub is the shared copy and backup.

- `docs/STORY.md` — lore and names. Follow it; don't invent new canon without being asked.
- `docs/tasks/NNN-name.md` — one spec per feature, each with a `Status:` line (`TODO`, `IN PROGRESS`, `DONE`).

When asked to "do the next task" (or a task by number):
1. Run `git pull` first — new task files arrive from the planning chat via GitHub.
2. Pick the lowest-numbered `TODO` task (or the one named). Read the spec fully, plus `docs/STORY.md` if it touches story or text.
3. Set its status to `IN PROGRESS` and implement it, keeping the conventions above. Add any new script to `default.project.json` so Rojo syncs it.
4. Check every requirement and acceptance item. Re-read the code carefully for Luau errors, then tell the user exactly what to test in Studio (Rojo will already have synced the changes).
5. Wait for the user to confirm it works in Studio. Fix anything they report.
6. Once confirmed: set status to `DONE`, add a short `## Notes` section to the spec (what changed, anything left open), commit, and `git push`.

If a spec is unclear or conflicts with the code, make the smallest sensible choice, note it in `## Notes`, and keep going rather than stopping.
Never edit scripts directly in Studio; all changes go through these files so Studio, local and GitHub stay in sync.
