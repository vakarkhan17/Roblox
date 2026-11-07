# 008 — The Hollow Creek Grand Hotel

Status: DONE

## Goal
A big abandoned 1920s hotel that every chapter uses for part of its mission, looking a little different each time so it stays interesting. Indoor play (stairs, corridors, rooms, washrooms) instead of only open ground.

## The building
- East side of town, north of the rift field (around x 120–190, z −200 to −130), visible from Main Street.
- **5 floors + roof + basement.** Lobby with front desk and bell, ballroom (floor 1), corridors with numbered rooms (2–4), penthouse (5), roof with the hotel sign and a view, basement with boilers.
- Main stairwell, back fire stairs, and a **working elevator** (call button + floor buttons, works on phone).
- **Washrooms on every floor**: men's, women's and an accessible one, with stalls and doors, sinks, mirrors, hand dryers, tiled floors, a flickering light. Some events happen there (see below).
- Same as the town, it has a **dark mirror in the Undergrid**, where most fights happen.
- HUD shows **FLOOR n**; the yellow marker says **"2 FLOORS UP" / "BASEMENT"**.
- Hollowers come **through floors and ceilings** (3D movement indoors). Pilots/robots get a shoulder **flashlight** in dark rooms.
- Car mode: outside and in the parking garage ramp only (corridors are too narrow).

## How it changes each chapter
| Chapter | Hotel look | What happens there |
|---|---|---|
| 1 Seal the Rift | Lights on, dusty but tidy, luggage carts in the lobby | 2 of the 6 shards are hidden in hotel rooms on the Undergrid side; a washroom mirror on floor 3 shows a Hollower behind you (jump scare) |
| 2 The Source | Hive growth: red tendrils down the stairwells, pulsing walls, the elevator is stuck | One Hive Node grows in the ballroom, one on the roof; the Mind Warden's roar shakes the building |
| 3 LOWBAND | Power out: red emergency lights, flooded basement, flashlights needed | A LOWBAND file is in the penthouse safe; the 3rd relay is in the basement; Static Hounds run the corridors |
| 4 Site 2 (next) | Floors collapsing, a hole through the lobby floor | The way to Site 2 is behind a sealed washroom wall in the basement |

## Questions before building
1. Location east of town (above) is OK?
2. Changing Chapters 1–3 as in the table is OK (they will need a quick retest)?
3. Jump scares: mild (sounds/visuals, nothing gory) — OK for your audience?

## Notes
- Final layout after several rounds of feedback: 112 x 80 studs, 5 floors, an open atrium to a glass roof, and a wide open lobby on floor 1 (reception, lounges, ballroom).
- Floors 2–5: 12 standard guest rooms behind closed doors (E opens; they close after 10 s) and 2 common washrooms (women / men).
- 10-wide grand stairs; an elevator in each wing with a "Use elevator" prompt and a floor list (ElevatorMenu / ElevatorGo remotes, validated on the server).
- Per chapter: Ch1 lights on; Ch2 Hive growth and elevators stuck; Ch3 power out with emergency lights. Shards, nodes and files use hotel spots.
