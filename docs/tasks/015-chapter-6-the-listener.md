# 015 — Chapter 6: THE LISTENER (Season 1 finale)

Status: IN PROGRESS

Story approved by the user on 2026-11-09 (`docs/STORY.md`, chapter 6).

## Build
- New ModuleScript `src/server/chapters/Chapter6.lua`.
- `api.shared` lets modules share things. Chapter 4 provides:
  - `openSite2(on)`: washroom door + vault open in later chapters
  - `spawnEcho(at, targetsFn)`
- Saves:
  - "Chapter 5 Complete" continues in Chapter 6.
  - The Listener fight (all 3 phases) restarts from phase 1.
- Chapter 5's ending starts Chapter 6 automatically.

## The Deep Grid
- A floating area far from both worlds, centred at (0, 600, 3200):
  - the landing
  - a walkway with floating pieces of Hollow Creek
  - the centre platform with Ricky's cage
  - the Listener behind it
  - the radio tower platform 330 studs west
  - cables and broken towers in the dark
- The way in: Site 2's round door in the deep room → "Descend".
- Falling off → back to the checkpoint, 20 damage. Dying → you respawn back in the Deep Grid once you've been there.
- The HUD uses the "DeepGrid" lighting preset and shows "THE DEEP GRID".

## Stages
1. **Locks (3).** Break the static locks around Ricky's cage (500 HP each). Hollowers, Static Hounds and Echoes attack, up to 10 at once.
2. **Listener.** Shoot off its 4 antennas (450 HP each; boss bar "THE LISTENER"). Static beams: a red circle under a pilot, then 25 damage 1.4 s later.
3. **Collapse.** Drive the floating road west to the tower platform within 45 s. The road falls from the centre end, one segment every 0.9 s. When everyone is on the tower platform, or time is up, the next stage starts. Anyone left behind is pulled to the towers.
4. **Broadcast.** Stand in the 3 blue rings. Each occupied ring adds 1 per second, and 90 are needed (solo about 90 s, three pilots 30 s). Beams and enemies keep coming.
5. **Complete.**
   - The Listener disappears with a white flash.
   - Everyone is sent home to a **morning** in Hollow Creek (Morning preset).
   - Radio epilogue, "SEASON 1 COMPLETE", and +300 Scrap.
   - Last line: one Shiftframe's eyes flicker on again.

## Test
- `DEBUG_START_CHAPTER = 6`. To jump to the boss, also set `DEBUG_START_STAGE = "Listener"` and pick Chapter 6 in CHAPTER SELECT.
- Then: hotel washroom door → Site 2 → round door (deep room) → Descend.
