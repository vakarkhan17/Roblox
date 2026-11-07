# 006 — Graphics and game feel (Phase A)

Status: DONE

## Goal
Make the first 10 seconds look and feel like a finished game, on laptop and phone. Part of the approved upgrade plan: A graphics + feel, then C retention, D friends + tutorial, B sound.

## Graphics
- Lighting: Future lighting (set by script when allowed, otherwise Studio: Lighting > Technology = Future), soft shadows, sun rays, 80s dusk sky, stronger neon glow.
- Terrain: real grass terrain under the town and hills around the edge; dark rocky terrain in the Undergrid. The old Ground part stays (invisible) for raycasts.
- Town details: sidewalks + curbs, power poles with wires, mailboxes, parked 80s cars, lit shop signs (DINER, ARCADE, VIDEO, RECORDS, PIZZA — original names), awnings, puddles reflecting neon.
- Undergrid mood: red lightning flashes (client), glowing cracks around the Undergrid rifts, shop signs turn red.

## Effects
- Muzzle flash and hit sparks for every weapon; Hollowers/Hounds dissolve into smoke; car exhaust; spark burst on transform.

## Feedback
- Floating damage numbers and a hit marker for your own hits (server tells the shooter via a `Hit` remote).
- HEALTH bar in the HUD panel; red pulsing screen edge under 35% health.

## Settings
- MENU > SETTINGS (also on the title menu): GRAPHICS LOW / MEDIUM / HIGH (phones default to MEDIUM) and CAMERA SHAKE ON / OFF. Saved with the game.

## Acceptance
- Town and Undergrid clearly look better; no big FPS drop on HIGH on a laptop; LOW is smooth on a phone.
- Damage numbers, hit marker, health bar and low-health warning work on laptop and phone.
- Settings change instantly and come back after Stop/Play with saving on.
- No errors in Output.

## Notes
- Future lighting (with fallback), sky and sun rays, graphics quality and camera shake settings, hit numbers and markers, low-health vignette, target marker with "N FLOORS UP".
- Remaining phases from the approved order: C (retention), D (tutorial, friends), B (sound, needs the user's asset IDs).
