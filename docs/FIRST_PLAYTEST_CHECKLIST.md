# First Playtest Checklist

## Battle Arena v0.1 Setup

- If `Workspace.WOB_Generated.BattleArena` is missing, run `docs/patches/CREATE_OR_REPAIR_BATTLE_ARENA_COMMAND.lua` outside Play Mode. If the arena was manually moved already, start with the audit/repair steps below instead.
- Run `docs/patches/AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua` outside Play Mode and confirm `Lobby/BattleArena overlap XZ = false`.
- If overlap is true, run `docs/patches/MOVE_BATTLE_ARENA_TO_SAFE_ZONE_COMMAND.lua`.
- Run `docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua` outside Play Mode.
- If there are collision warnings, run `docs/patches/REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua`, then audit again.
- Run `docs/patches/CLEAN_VFX_TEMPLATES_COMMAND.lua` outside Play Mode if any template/runtime VFX script errors appear.
- Run `docs/patches/REPAIR_ALL_LOBBY_PADS_COMMAND.lua` outside Play Mode.
- Run `docs/patches/AUDIT_LOBBY_PADS_COMMAND.lua` and confirm ArenaPad/DuelPad/TrainingPad warnings are resolved.
- Save the scene with `File -> Save to File`.
- Confirm `Workspace.WOB_Generated.Lobby.ArenaPad` exists and has `WOBPadType = "BattleArena"`, `RequiredPlayers = 1`.
- Confirm `ArenaPad.Trigger` is aligned with the visible pad, `CanTouch = true`, `CanQuery = true`, and `WOBPadTrigger = true`.
- Confirm `ArenaPad.Label` shows `BATTLE ARENA` and `Drive here`.
- Confirm `Workspace.WOB_Generated.BattleArena.SpawnPoints` has `ArenaSpawn1` through `ArenaSpawn8`.
- Confirm BattleArena boundaries, cover, and ricochet walls have `WOBMovementObstacle = true`; ricochet walls also have `WOBRicochetSurface = true`.

## 1-Player

- Spawn in lobby.
- DuelPad is still visible.
- ArenaPad is visible and visually distinct.
- Drive onto ArenaPad.
- Player mode becomes `InBattleArena`.
- Tank spawns at one of 8 arena spawns.
- Tank can drive and shoot in BattleArena.
- Desktop Arena HUD shows `HP`, `Arena Score`, `Kills`, `Deaths`, `Streak`, and `Upgrades`.
- Mobile Arena HUD shows compact `HP`, `Score`, `K/D`, `Streak`, `Upg`, and a small `Menu`.
- Mobile `Menu` opens `Resume` and `Return to Lobby`; `Resume` closes the popup.
- Tank can cross the center area unless it is visibly blocked by cover/ricochet walls.
- Self-hit or forced death switches to `ArenaRespawning`.
- Controls are disabled while destroyed.
- Death overlay shows `Destroyed`, `Respawn in N...`, and `Return to Lobby`.
- Tank respawns after `BattleArenaConfig.RespawnDelay`.
- Return to Lobby returns to lobby spawn and resets arena score/upgrades.
- DuelPad and Training still work after returning.

## 2-Player

- Both players can enter BattleArena independently.
- Both players can drive and shoot in the arena.
- A player kill gives killer `ArenaScore +1`, `ArenaKills +1`.
- Victim gets `ArenaDeaths +1` and respawns after delay.
- Self-hit death gives no kill score.
- Score thresholds unlock temporary upgrades:
  - 2: `DamageUp`
  - 4: `FireRateUp`
  - 6: `DoubleShot`
  - 8: `MoveSpeedUp`
  - 10: `TripleSpread`
- DoubleShot/TripleSpread projectiles still damage the correct victim.
- Leaving arena resets upgrades.
- Duel mode remains separate: DuelPad queue/countdown, round end, match result, rematch, and return still work.

## Regression Checks

- Lobby shooting remains no-damage.
- Arena death never shows Match Result.
- Arena death never calls `RoundMatchService.endRound`.
- Duel death still ends only the duel round.
- Mobile `MOVE`, `AIM`, and `FIRE` controls appear in Lobby, QueuedForDuel, InMatch, and InBattleArena.
- Mobile right `AIM` stick rotates the turret/aim laser, and `FIRE` shoots in that direction.
- Mobile left `MOVE` and right `AIM` can be used simultaneously.
- Mobile BattleArena HUD is compact: HP top-left, score top-right, Return to Lobby behind Menu, center mostly free.
- Mobile BattleArena Menu popup Return works and Resume closes the popup.
- Mobile controls hide/disable during ArenaRespawning.
- Output has no red errors.
- If the tank gets stuck, set `BattleArenaConfig.DebugCollision = true` and check `[MOVE BLOCKED]` obstacle path.
