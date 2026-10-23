# 001 — Intro broadcast scene

Status: TODO

## Goal
When a player joins, show a short 80s-TV-style emergency broadcast from **WHCK 85.5 FM / Channel 8** that tells the story (see `docs/STORY.md`) before they start playing.

## Requirements
1. Client-only. Implement in a new LocalScript module or inside `src/client/Signal85Client.client.lua` (prefer a new file `src/client/IntroBroadcast.client.lua` and add it to `default.project.json`).
2. Full-screen dark overlay with:
   - CRT feel: faint horizontal scanlines, slight vignette, subtle flicker.
   - Header: `WHCK CHANNEL 8 — EMERGENCY BROADCAST` in red, blinking `● LIVE` tag.
   - Typewriter text, one line at a time, ~0.03 s per character, pause between lines:
     1. `HOLLOW CREEK, OCTOBER 1985.`
     2. `AT 11:52 PM THE RADIO TOWER RECEIVED A SIGNAL NOBODY SENT.`
     3. `MINUTES LATER, A RIFT OPENED EAST OF MAIN STREET.`
     4. `BEYOND IT LIES THE UNDERGRID — AND THE THINGS THAT LIVE THERE.`
     5. `PROJECT LOWBAND'S MACHINES HAVE WOKEN UP.`
     6. `YOU ARE A SHIFTFRAME.`
     7. `FIND THE SIGNAL SHARDS. SEAL THE RIFT.`
   - Ends with a short "signal lost" static burst, then fades out to the game.
3. A `SKIP ▸` button (bottom right) and pressing Space/Enter/gamepad A skips. Mobile-friendly sizes.
4. Show only once per session (do not replay on respawn). `ScreenGui.ResetOnSpawn = false`, `DisplayOrder` above the HUD.
5. While the intro is showing, hide the main HUD (`Signal85HUD`) and block game input (F/Q/E). Restore after. Suggested approach: the intro sets a local attribute `IntroActive = true` on `Players.LocalPlayer`; `Signal85Client` checks it in `onAction` and in HUD visibility.
6. Use `Enum.Font.Arcade` / `Code` to match the HUD. No external assets required (static can be random-noise frames built from UI, no image IDs). If you add sound, leave a clearly marked `SOUND_ID = 0` constant and skip playback when 0.

## Acceptance
- Join in Studio → broadcast plays, then HUD appears and controls work.
- Skip works instantly at any point.
- Respawning does not replay it.
- No errors in Output.

## Out of scope
Server changes, DataStore "seen intro" saving (later task).
