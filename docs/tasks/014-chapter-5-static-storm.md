# 014 — Chapter 5: STATIC STORM

Status: DONE

Story approved by the user on 2026-11-09 (`docs/STORY.md`, chapter 5).

## Build
- New ModuleScript `src/server/chapters/Chapter5.lua` (loaded like Chapter 4).
- Main script changes:
  - `spawnCreature` and `spawnHound` return their model, and `spawnHoundPack` returns the pack, so modules can give creatures their own targets.
  - `api` also has `console` and `randomOpenPoint`.
  - Saves: "Chapter 4 Complete" continues in Chapter 5. The van defence and the tape race restart from their beginning.
- Chapter 4's ending starts Chapter 5 automatically.

## Stages
1. **Rifts (5).** The town turns red (workspace attribute `Storm`, client preset "Storm"), and tendrils grow on the ground. Five mini-rifts open in town:
   - one in front of the hotel
   - one by the radio tower
   - three random open spots

   Stand in a red circle for 10 s (faster with more pilots) to close it. Open rifts let Hollowers and Static Hounds out **in town**. These creatures hunt pilots in Hollow Creek.
2. **Van.** Defend the WHCK 85.5 van on Main Street for 120 s (1200 HP, blue boss bar, timer). Waves come from around it. If the van is destroyed, the defence restarts.
3. **TapeRace.** Grab the signal tapes by the radio tower console. You then have 50 s to reach the Grand Hotel entrance (blue ring). The road cracks behind the carrier, and hounds chase the tapes. If the carrier dies or time runs out, the tapes go back to the tower.
4. **Complete.** The storm calms. A huge rift opens under Ricky, who is taken ("...guys? I can see it. It's so big..."). Then "To be continued in Chapter 6", or Chapter 6 starts when it exists.

## Client
- Storm lighting, boss bar and timer for the van, timer for the tapes.
- Objective texts, help steps, a briefing with 3 new pictures (mini-rift, van, tapes), stage names.
- The compass / TARGET switch knows the mini-rifts, the van, the tapes and the hotel goal.

## Test
- `DEBUG_START_CHAPTER = 5`. To jump ahead, also set `DEBUG_START_STAGE = "Van"` or `"TapeRace"` and pick Chapter 5 in CHAPTER SELECT.

## Notes
- Tested and approved in Studio. Town creatures use the generic creature hooks (`targets` / `stopAt` / `attack`), so the main script only needed small changes.
