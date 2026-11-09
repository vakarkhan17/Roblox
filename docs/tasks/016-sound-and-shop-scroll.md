# 016 — Sound and music (Phase B), scrolling shop

Status: IN PROGRESS

Requested by the user on 2026-11-09 ("finish what's remaining, then push"). Pushed before a Studio test, at the user's request.

## Sound (Phase B)
- New LocalScript `src/client/Sound.client.lua` (added to `default.project.json`).
- All sounds are in its `SOUNDS` table. They start with sounds that ship with Roblox (`rbxasset://sounds/...`), so no uploads are needed. Replace any line with `rbxassetid://<id>` from the Toolbox for better ones.
- Hooks:
  - your shots (light and heavy guns, the baton)
  - reload and empty
  - hit and kill
  - transform (yours, and other players' in 3D)
  - crossing the rift
  - Scrap, banners, pings, prompts
  - level up, getting hurt
- `MUSIC` table per moment (Town, Undergrid, Boss, Storm, DeepGrid, Morning, Menu). Empty = silence. The user adds music ids they may use (Toolbox audio by Roblox is free).
- Uses the SOUND VOLUME setting (0–10). Music plays at half the effect volume.

## Shop on phones
- The shop rows (ammo refill, weapons, 5 upgrades) are in a scrolling list. The scroll position is kept while buying.

## Left open
- **Game Passes (Robux).** These need the user's decisions (what to sell) and passes created on the Roblox website. The plan is to do them last.
