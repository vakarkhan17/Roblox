# 011 — Easy to learn, fun with friends (Phase D)

Status: DONE

Approved by the user on 2026-11-08 (plan given in the Claude Code chat).

## Requirements
1. **"First Night" tutorial** for new players, after START MISSION. Six steps that each wait for the player:
   1. walk to a light
   2. suit up
   3. shoot 3 practice targets (auto-aim explained)
   4. car through a ring
   5. Shock Baton up close
   6. follow the yellow marker to the rift

   Device-specific instructions, with an arrow at the touch button to press. SKIP is always on screen. Finishing gives +100 Scrap and the FIRST NIGHT achievement, once. It shows once (saved), and can be replayed from Settings. The targets are only on that player's screen.
2. **Revive.** With another player in the game, a killing hit puts you DOWN for 15 s instead: red glow, can't move or act, and creatures ignore you. A teammate holds E / taps for 3 s to revive you at half health (+15 Scrap, NO ONE LEFT BEHIND achievement). If nobody comes in time, you die as usual. Alone, nothing changes.
3. **Ping.** T, or the PING touch button, marks where you look for everyone for 8 s. It snaps to an enemy (red) or an item (yellow) close by. Limited to once every 2 s.
4. **Invite + friend bonus.** INVITE FRIENDS (in REWARDS) opens Roblox's invite window. While a Roblox friend is in the same server: +10% gameplay Scrap.
5. **Settings.**
   - HUD size: small / normal / large
   - damage numbers: on / off
   - sound volume: saved for Phase B
   - replay tutorial
   - the Settings screen now scrolls

## Rules
- Server-authoritative: damage goes through `hurtPlayer`, ping positions are validated and rate-limited, and the tutorial reward is paid once.
- Saves from before this task count as "tutorial done", so existing players don't get it.

## Notes
- New LocalScript `src/client/Tutorial.client.lua`. Damage to players goes through `hurtPlayer` (DOWN state). Pings use the `Ping` remote. Friend bonus via `IsFriendsWith`.
- The Chapter 3 code went into a do-block to stay under Luau's 200-locals limit (constant locals don't count, so test headroom with non-constant values).
- Invites only work in a published game.
