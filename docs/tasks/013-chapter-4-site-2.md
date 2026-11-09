# 013 — Chapter 4: SITE 2

Status: DONE

Story approved by the user on 2026-11-09 (Chapters 4–6 in `docs/STORY.md`). Chapters 5 and 6 come as separate tasks, one at a time.

## Build
- New ModuleScript `src/server/chapters/Chapter4.lua` → `ServerScriptService.Chapters.Chapter4` (in `default.project.json`). The main server script loads every `ChapterN` module and passes it an `api` table. It also provides generic hooks:
  - creatures can have `targets` / `stopAt` / `attack`
  - objective models with the `Target` attribute are damaged through `def.damageTarget`
  - `def.targets` is used by the Shock Baton
  - `def.clear` is called by `startChapter`

  This keeps the main script under Luau's 200-locals limit.
- Chapter 3's ending now leads into Chapter 4. A save made in "Chapter 3 Complete" continues in Chapter 4.

## Stages
1. **Keycards (4).**
   - Town hotel: room 302 and the roof.
   - Undergrid hotel: room 209 and behind reception.
   - The steel door in the ground-floor men's washroom (the cracked tiles are broken in Chapter 4) says "Locked" until all 4 are found. Undergrid Hollowers roam the hotel.
2. **Echo Pylons (4).** The door takes you to **Site 2**, 120 studs under the hotel: 1950s tunnels, four chambers, a flooded chamber, reel-to-reel computers and flickering lamps. Each pylon (450 HP) calls Echoes when a pilot is close, up to 6 at a time. **Echoes** keep about 24 studs away while they can see you and fire slow purple bolts you can dodge (12 damage). Walls block their shots.
3. **Tape.** The vault opens. "Play the tape" in the deep room: Dr. Helen Marsh's 1962 log.
4. **Complete.** Every radio in Hollow Creek switches on. "To be continued in Chapter 5", or Chapter 5 starts automatically once it exists.

## Client
- Objective texts, help steps, a briefing with 4 new pictures (keycard, door, pylon, Echo), and stage names.
- The compass / TARGET switch knows keycards, the Site 2 door, the pylons and the tape.
- Site 2 counts as indoors (flashlight, close camera, see-through walls). The world label says "SITE 2".
- Auto-aim also targets the pylons.

## Test
- Set `DEBUG_START_CHAPTER = 4`. To jump to the pylons, also set `DEBUG_START_STAGE = "Pylons"` and pick Chapter 4 in CHAPTER SELECT.

## Notes
- Tested and approved in Studio. Chapters 5 and 6 go into `src/server/chapters/` the same way.
