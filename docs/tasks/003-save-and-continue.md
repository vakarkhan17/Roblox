# 003 — Save game and continue

Status: TODO
Depends on: 002 (uses `startChapter(n, stageState)`)

## Goal
Players can save their progress and later come back and **continue from where they saved**, or start a new game.

## What is saved (per player, DataStoreService)
DataStore name `Signal85Save_v1`, key `"player_" .. UserId`. Value is a table:
```
{
  version = 1,
  chapter = 2,            -- chapter at the time of saving
  stage = "Nodes",        -- stage inside that chapter
  progress = 1,           -- Progress counter at save time (shards delivered / nodes destroyed)
  bestChapter = 2,        -- highest chapter ever reached (never goes down)
  lifetimeShards = 14,    -- the leaderstats Shards total
  brightness = 2,         -- client LIGHT setting
  savedAt = os.time(),
}
```
Do **not** save boss HP mid-fight: if saved during `Boss`, restore to the start of the boss stage. Do not save carried shards.

## When it saves
1. **Manual SAVE** button on the HUD (and key `K`). Server-side: validate, rate-limit to once per 15 s per player, then write. Show banner `GAME SAVED` (or `SAVE FAILED — TRY AGAIN` on error).
2. **Auto-save checkpoints**: on every chapter start, every stage change, and on `PlayerRemoving`. Also `game:BindToClose` saves everyone.
3. Use `UpdateAsync`, wrap every DataStore call in `pcall` with up to 3 retries and backoff. Never let a DataStore error break the game.

## Start menu (client, new `src/client/StartMenu.client.lua`, add to `default.project.json`)
Shown right **after** the intro broadcast (wait until `IntroActive` is false) and before the HOW TO PLAY panel. Retro style matching the HUD/intro.
- Title `SIGNAL '85`.
- **CONTINUE** — only if a save exists. Shows `CHAPTER n: TITLE — <stage>` and how long ago it was saved.
- **NEW GAME** — starts Chapter 1. If a save exists, confirm first: `START OVER? YOUR SAVE WILL BE REPLACED WHEN YOU NEXT SAVE.`
- Big touch-friendly buttons, works with mouse, keyboard (arrows + Enter) and gamepad.
- While the menu is open, keep HUD hidden and game input blocked (reuse the `IntroActive` pattern, e.g. a `MenuActive` attribute).
- Server sends the save summary to the client via a new RemoteFunction or RemoteEvent in `Signal85Remotes` (e.g. `GetSave` / `ChooseStart`). Client never sends the save data itself — it only sends a choice (`"continue"` or `"new"`); the server loads the data and decides.

## Multiplayer rule (server is shared)
The chapter state is shared by everyone on the server, so:
- If the world is still **fresh** (Chapter 1, Progress 0, no one has chosen yet), the first player to choose CONTINUE sets the server to their saved chapter/stage/progress via `startChapter`.
- If a chapter is already in progress, CONTINUE just joins the current game (show `JOINING YOUR CREW IN CHAPTER n`), but the player's `bestChapter` is kept and they still get checkpoint saves.
- NEW GAME on a fresh server = Chapter 1. NEW GAME when a game is running = just join.

## Restore on continue
- Server calls `startChapter(chapter, { stage = stage, progress = progress })`.
- Chapter 1: set `Progress` to saved shards delivered.
- Chapter 2 Nodes: spawn only `3 - progress` nodes.
- Chapter 2 Boss: start the boss stage fresh.
- Chapter 2 Complete: free-roam state.
- Restore `lifetimeShards` into leaderstats and `brightness` into the client LIGHT setting (send it to the client; client applies it).

## Also
- Save also stores `IntroSeen = true`; on later visits the intro can be skipped with one tap (keep it playing by default, just show `SKIP` immediately).
- README: add a "Saving" section: game must be **published** and **Game Settings → Security → Enable Studio Access to API Services** must be ON for saving to work in Studio. If DataStores are unavailable, the game still runs and the menu shows `SAVING UNAVAILABLE` with only NEW GAME.

## Acceptance
- Play to Chapter 2, press SAVE → `GAME SAVED`.
- Stop, Play again → intro → menu shows CONTINUE `CHAPTER 2: THE SOURCE — Nodes` → continue puts you in Chapter 2 with the right number of nodes left.
- NEW GAME starts Chapter 1.
- Leaving the game auto-saves.
- With API access OFF: no errors that stop the game; menu shows saving unavailable.
- Works on phone.

## Out of scope
Multiple save slots, cloud sync of settings beyond brightness.
