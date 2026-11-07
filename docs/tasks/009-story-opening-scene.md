# 009 — Story opening scene

Status: DONE

## Goal
Start the game like a story instead of a plain TV overlay: a Hollow Creek family at home listens to WHCK 85.5 FM, the emergency broadcast cuts in, and the player's own pilot (the look they picked) goes out to start the mission.

## Flow
1. Join → title menu (no broadcast overlay any more).
2. NEW GAME → YOUR PILOT (first time) → **story scene** → mission briefing → play.
3. CONTINUE skips the scene; **WATCH THE STORY** on the title / pause menu replays it.

## The scene (~45 s, SKIP any time with the button, Space, Enter or gamepad A)
1. Living room at night: Dad and Mom on the couch, a little brother on the rug, your pilot in the armchair. Lamp light, wood panelling, a big TV and a radio. Radio: *"WHCK 85.5 FM, late night hits..."*, music bars on the TV.
2. Static. The TV turns red: **WHCK CHANNEL 8 — EMERGENCY BROADCAST** and the seven story lines (same text as task 001).
3. Reactions: Dad "What was that?", Mom "Kids, stay away from the window.", little brother "What's that red light?"
4. Your pilot walks to the window: a red glow in the sky, and a Shiftframe outside, visor glowing. *"IT CHOSE YOU."*
5. Fade to black → `CHAPTER 1: SEAL THE RIFT` → briefing.

Built client-side (local parts far above the map), so other players never see it; the pilot is a copy of the player's own character.

## Acceptance
- NEW GAME plays the scene once, then the briefing; CONTINUE does not; WATCH THE STORY replays it.
- Skip works instantly; HUD and controls stay blocked during the scene and come back after.
- Works on phone. No errors in Output.

## Notes
- The IntroBroadcast script is now the story scene: a family in a living room hears the broadcast, then the player's own pilot looks out at a robot, "IT CHOSE YOU.", then the title card. It plays on NEW GAME and from WATCH THE STORY; SKIP is supported.
