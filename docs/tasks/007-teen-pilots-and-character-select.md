# 007 — Teen pilots and character select (Avatars, option A)

Status: DONE

## Goal
Players are no longer a generic armored avatar. Each player is a stylish Hollow Creek teen who **pilots** a Shiftframe: walk around town as yourself, suit up into the robot, fold into the car.

## Story (approved; canon in `docs/STORY.md`)
When the rift opened, the LOWBAND machines woke up — and each one **chose a pilot** from the kids of Hollow Creek. Pilot and machine are synced: the armor folds around the pilot.

## Modes
| Mode | How | What you can do |
|---|---|---|
| PILOT | spawn mode; **G** / touch **SUIT** from robot or car (in town only) | walk (16), use the shop and doors; can't shoot |
| ROBOT | **F** or **G** from pilot; crossing the rift suits you up automatically | shoot, armored |
| CAR | **F** from robot | fast, no weapon |
F: pilot → robot → car → robot. G: pilot ⇄ robot (and car → pilot in town).

## Character select (title menu, pause menu, and once for new players)
- OUTFIT: VARSITY, DENIM, WINDBREAKER, SKATER, ARCADE, AEROBICS (original 80s styles, built from colours + parts — no catalog ids needed).
- HAIR: SHORT, SPIKY, LONG, PONYTAIL, CURLY, MOHAWK, BUZZ. HAIR COLOUR and SKIN TONE: 6 each.
- Any combination for anyone — nothing is locked to boy or girl.
- **USE MY ROBLOX AVATAR** keeps the player's own avatar.
- Camera turns to face your character while you choose. Saved with the game.
- Optional later: real Marketplace clothing/hair ids can be added per outfit (`shirtId`, `pantsId`, `hairId` slots, 0 = not used).

## Acceptance
- New players pick a look once; it is applied on every spawn and comes back after Stop/Play.
- Pilot ⇄ robot ⇄ car works on laptop (F/G) and phone (TO CAR / SUIT buttons); only robot mode can shoot.
- Crossing the rift as a pilot suits you up first.
- No errors in Output.

## Notes
- YOUR PILOT screen: skin tone, outfit, hair style and hair colour; the look is saved and hidden under the suit.
- Hair: free Roblox catalog hair (Pal Hair, Brown Hair, Short Fringe, Top Knot, Long Red Hair) plus 3 block styles marked (ANY COLOR). A hair that fails to load falls back to block hair with a "[Look]" warning in Output.
