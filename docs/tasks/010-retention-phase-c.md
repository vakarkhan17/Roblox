# 010 — Reasons to come back (Phase C)

Status: DONE

Approved by the user on 2026-11-08 (plan given in the Claude Code chat).

## Goal
Give players reasons to come back every day, without changing the chapters themselves.

## Requirements
1. **Daily reward, 7-day streak.** Claim once per UTC day: 50 / 75 / 100 / 150 / 200 / 300 / 600 Scrap. Day 7 also unlocks the GOLD suit paint. Missing a day restarts the streak at Day 1. A popup appears after the player starts playing, and DAILY REWARD sits in the menu with a "next reward in" timer.
2. **Daily quests.** 3 quests a day, the same for everyone, changing at midnight UTC. Each has a progress bar in a QUESTS page, and finishing one gives Scrap and XP with a toast.
3. **Pilot level (XP).** Gameplay Scrap also gives the same amount of XP. Every level gives Scrap. Unlocks:
   - level 5: CRIMSON suit paint
   - level 10: NEON TRIM paint
   - level 15: PONYTAIL hair
   - level 20: VETERAN title
   Level shows on an XP bar in the HUD and as "Level" in the player list.
4. **Achievements.** About 15 badges kept inside the game, each with a one-time Scrap reward. An ACHIEVEMENTS page shows locked ones in grey with a hint.
5. **Leaderboard.** A "TOP PILOTS" board in town and a page in the menu with 2 tabs: Highest Level and Most Creatures Defeated. It covers all servers through OrderedDataStores and refreshes every 2 minutes. When those are unavailable (unpublished place), it falls back to this server's players.
6. **Codes.** A code box in the REWARDS screen (moved there from Settings, which is already full on phones); each code works once per player. Codes live in `CONFIG.CODES` (SIGNAL85 +250, HOLLOWCREEK +150).
7. **Weekend 2×.** Friday to Sunday UTC, gameplay Scrap and XP are doubled, with a "2× WEEKEND" banner.

## Rules
- Everything is server-authoritative: the server checks claim times, quest progress and codes.
- All new data goes into the existing save as optional fields, so old saves keep working.
- For testing: `CONFIG.DEBUG_DAY_OFFSET` pretends it's N days later, and `CONFIG.DEBUG_FORCE_WEEKEND` turns 2× on.
- All panels must work on phones.

## Acceptance
- Claim the daily reward, then rejoin: it can't be claimed twice the same day. With `DEBUG_DAY_OFFSET = 1` it moves to Day 2.
- Quest progress goes up while playing, and a finished quest pays once.
- XP bar fills and levels up. The level-5 paint is locked before level 5 and selectable after.
- An achievement pops once and stays unlocked after rejoining.
- The leaderboard shows something in Studio (this server's players) and all servers in a published game.
- A code works once, and the second try says "ALREADY USED".

## Notes
- Server: task 010 section (`MetaFunction` "Meta" remote), XP from gameplay Scrap (`awardScrap` plain flag for non-gameplay rewards), `track(player, kind, n)` hooks in kills, objectives, rift, transform, doors, elevator, chapter clears and purchases. Save gets optional fields: xp, streak, lastClaimDay, gold, quests, counts, achievements, codes.
- Leaderboard: OrderedDataStores `Signal85Top_Level_v1` / `Signal85Top_Kills_v1`; falls back to this server's players.
- Client: REWARDS hub (title menu + corner button while playing), daily popup after START MISSION, LV + XP bar in the HUD, 2x banner, SUIT PAINT row in YOUR PILOT.
- Codes went in the REWARDS screen, not Settings (Settings and the pause menu are already full on phones).
- Also fixed: the server script was over Luau's 200 top-level locals (it would not run); the hotel runtime, pilot-look helpers, boss fight and this section are now in do-blocks.
- Left open: real Roblox Badges (with Game Passes, later).
