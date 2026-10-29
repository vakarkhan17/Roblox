# 002 — Chapters + Chapter 2 "The Source"

Status: TODO

## Goal
Turn the single repeating round into a **chapter system**. Chapter 1 is the existing shard mission. When it is completed, the game moves on to **Chapter 2: The Source**, a new and harder challenge with a boss, instead of just reopening the same rift. Story is in `docs/STORY.md` (Chapters section).

## Part A — Chapter system (server)
1. Add `ReplicatedStorage` attributes: `Chapter` (number, starts at 1), `ChapterTitle` (string), `Stage` (string, e.g. `"Shards"`, `"Nodes"`, `"Boss"`, `"Complete"`), plus keep `Progress` / `Goal` as the generic "x / y" counter for the current stage.
2. Structure the server so each chapter has a `start()` and its own win condition, e.g. a `CHAPTERS` table. Keep all tunables in `CONFIG`.
3. **Chapter 1 "Seal the Rift"** = the existing loop (deliver `SHARDS_TO_WIN` shards). On win: banner `CHAPTER 1 COMPLETE`, short pause (~8 s), then start Chapter 2 — do NOT reopen Chapter 1.
4. Expose a single server function `startChapter(n, stageState)` that resets the world for that chapter (clears creatures, shards, nodes, boss; sends players home to town) and optionally restores mid-chapter progress. Task 003 (save/continue) will call it, so keep it clean and documented.
5. Banner on every chapter start: `CHAPTER n: <TITLE>` (use `NotifyEvent`).

## Part B — Chapter 2 "The Source"
Lore: sealing the rift only cut one line. The signal is now fed by **Hive Nodes** grown in the Undergrid, protected by the **Mind Warden**.

Stage 1 — **Destroy the Hive Nodes** (`Stage = "Nodes"`, `Goal = 3`):
- Spawn 3 Hive Nodes at spread-out open spots in the Undergrid (reuse `randomOpenPoint`). Look: pulsing red/black organic sphere (~8 studs) with tendrils, PointLight, slow pulse, health bar billboard. Mark with attribute `Node = true`.
- Nodes take blaster damage (same raycast as creatures — extend the hit check). Each node ~300 HP.
- While nodes are alive, Hollowers spawn faster and up to `CONFIG.CH2_MAX_CREATURES` (e.g. 12). Each node also spawns a Hollower near itself every ~15 s while a player is within 80 studs.
- Destroying a node: burst effect, banner `HIVE NODE DESTROYED [x/3]`, `Progress` +1.

Stage 2 — **The Mind Warden** (`Stage = "Boss"`, `Goal` = boss HP shown as a boss bar):
- When all 3 nodes are gone, banner `THE MIND WARDEN AWAKENS`, Undergrid gets darker/redder for everyone in it (client lighting tweak keyed on `Stage == "Boss"`).
- Spawn at the Undergrid copy of the radio tower area. Look: giant Hollower (~4x scale), flower head that opens, red neon maw, glowing weak point. Built from parts like existing Hollowers.
- HP ~2000 (scale +50% per extra player, cap at 4 players). Only takes damage while the head is **open**.
- Attack pattern loop (keep it readable and fair, telegraph each attack ~1 s with a glow/shake):
  1. **Shockwave**: slams ground, expanding red ring; damages players on the ground inside the ring (jumping avoids it).
  2. **Summon**: calls 3 Hollowers.
  3. **Head open (vulnerable)** for ~5 s: maw glows, takes blaster damage.
- Players in **vehicle mode** take half damage from the shockwave (reward for transforming).
- On defeat: collapse effect, all creatures die, banner `CHAPTER 2 COMPLETE — THE SIGNAL GOES QUIET`, `Stage = "Complete"`. Then show `TO BE CONTINUED...` and keep the world in a calm free-roam state (no creatures). Leave a clear `-- TODO: Chapter 3` hook.

## Part C — Client
1. HUD shows `CHAPTER n: TITLE` above the objective.
2. Objective box text for the new stages, e.g.:
   - Nodes: `DESTROY THE HIVE NODES IN THE UNDERGRID (x/3). ROBOT MODE + BLAST.`
   - Boss: `DEFEAT THE MIND WARDEN. SHOOT IT WHEN ITS HEAD OPENS. JUMP OVER SHOCKWAVES.`
   - Complete: `THE SIGNAL IS QUIET... FOR NOW.`
3. Boss health bar at top-center while `Stage == "Boss"` (read from a boss attribute, e.g. `ReplicatedStorage` `BossHealth` / `BossMaxHealth`).
4. Update the HOW TO PLAY panel to mention nodes and the boss.
5. Must work on mobile with the existing touch buttons (BLAST lock-on should also target nodes and the boss weak point).

## Acceptance
- Deliver 6 shards → Chapter 1 complete banner → Chapter 2 starts, nodes appear in the Undergrid, objective updates.
- Destroy 3 nodes → boss spawns, boss bar visible.
- Boss can only be hurt while the head is open; shockwave can be jumped; summons work.
- Kill boss → Chapter 2 complete, no more creatures spawn.
- Works on phone (Studio device emulator OK). No errors in Output.
- For quick testing, add `CONFIG.DEBUG_START_CHAPTER` (default 1) so the tester can start straight at Chapter 2.

## Out of scope
Saving (task 003), sound, Chapter 3.
