# 018 — Weaker Shock Baton, refill anywhere, more sound

Status: DONE

Approved by the user on 2026-11-14 (baton damage 25; refill 60 in the field / 40 at the Garage; sound Option A).

## Shock Baton
- Damage 55 → **25**: a Hollower (100 HP) takes 4 hits, a Static Hound 2, an Echo 5. Speed and reach unchanged.

## Ammo refill anywhere
- A full refill costs **40 Scrap at the Scrap Garage** (within `CONFIG.GARAGE_RANGE` = 45 studs of the counter, in town) and **60 anywhere else** (`CONFIG.AMMO_REFILL_PRICE` / `AMMO_REFILL_PRICE_FIELD`). The server decides the price.
- HUD: a **REFILL** button above the ammo line when the gun in your hands is low (two magazines or less in total). Key **B** or tap. It uses the existing `Shop` remote ("ammo").
- The shop row shows the price for where you stand.

## Sound (Option A: every hook built, stand-in sounds)
`src/client/Sound.client.lua` now also plays:
- hotel doors opening / closing (at the door), elevator ding and "stuck" buzz
- robot footsteps, a car engine loop that rises with speed
- creatures nearby (Hollower growl, hound crackle, Echo hum), Echo shots
- boss sounds: Mind Warden head opening and slam, the Listener's beam warning and beam
- pickups (shards, files, keycards, ammo, tapes), fanfare (achievement, quest, level, chapter, daily reward), alerts
- menu button clicks
- ambience loops (Undergrid, storm with thunder, Site 2 with drips, Deep Grid)
- music slots per place (still empty), now including Site 2

Every line in `SOUNDS`, `MUSIC` and `AMBIENCE` has Toolbox search words in a comment.

## Left open
- The stand-ins are Roblox's built-in `rbxasset://sounds/...` files. The new ones (door, growl, thunder, engine, fanfare, click...) were not checked in Studio; a file that doesn't exist just stays silent with a warning in Output.
- The user picks the real sounds and music in Toolbox → Audio and pastes the ids.

## Notes
- Confirmed by the user in Studio on 2026-11-14.
- The user picked all 46 sounds and music tracks in `docs/SOUND_IDS.xlsx`; they are applied in `Sound.client.lua` (pitch reset to 1 for every replaced sound). `docs/SOUND_IDS.md` is the text version of the same list.
- Volumes are still first guesses; tune them in the `SOUNDS` / `AMBIENCE` tables.
