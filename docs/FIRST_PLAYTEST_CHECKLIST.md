# First Playtest Checklist

## Master Polish Setup

- Confirm `default.project.json` still has `$ignoreUnknownInstances = true` under `ReplicatedStorage.Shared.Assets.VFX`.
- Run `docs/patches/MUTE_BURNING_VFX_SOUNDS_COMMAND.lua` outside Play Mode if `TankBurningTemplate` exists.
- Run `docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua` outside Play Mode.
- Run `docs/patches/CREATE_OR_REPAIR_LOBBY_SHOWCASES_COMMAND.lua` outside Play Mode.
- Run `docs/patches/CREATE_OR_REPAIR_LOBBY_GUIDANCE_COMMAND.lua` outside Play Mode.
- Confirm `ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard` exists and `default.project.json` keeps `ReplicatedStorage.Shared.Assets.UI` protected with `$ignoreUnknownInstances = true`.
- Confirm lobby signs are readable: `BATTLE ARENA`, `DUEL`, `TRAINING`, Crystals tip, and coming soon showcases.
- Confirm showcases are visible but do not block ArenaPad, DuelPad, TrainingPad, spawn points, or the main driving route.
- Confirm no Robux/IAP/purchase prompt was added.
- Save the scene with `File -> Save to File`.

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
- Desktop Arena HUD shows `Arena Score`, `Kills`, `Deaths`, `Streak`, and `Upgrades`; tank HP is readable above the active tank.
- Mobile Arena HUD shows compact score/status, a small `Menu`, and tank HP above the active tank without crowding controls.
- Mobile `Menu` opens `Resume` and `Return to Lobby`; `Resume` closes the popup.
- Tank can cross the center area unless it is visibly blocked by cover/ricochet walls.
- Self-hit or forced death switches to `ArenaRespawning`.
- Controls are disabled while destroyed.
- Death overlay shows `Destroyed`, `Respawn in N...`, and `Return to Lobby`.
- Tank respawns after `BattleArenaConfig.RespawnDelay`.
- Return to Lobby returns to lobby spawn and resets arena score/upgrades.
- DuelPad and Training still work after returning.

## Combat Readability Check

- Player tank has one world HP bar.
- DummyTank or enemy tank has one world HP bar.
- Shooting `DummyTank` lowers the world HP bar.
- Successful damage flashes the damaged tank white-yellow.
- Ricochet/no-damage hits do not trigger damage flash.
- Lethal hit sets the bar to zero, flashes, then the bar hides after a short grace delay.
- Round reset creates fresh bars without duplicate old BillboardGui clones.
- BattleArena respawn replaces stale bars/highlights cleanly.
- Mobile Duel/Training can hide large top HP panels while reload/result HUD remains usable.

## Crystals Reward Check

- Start a real Duel with 2 players.
- Win the final match, not only a round.
- Winner sees `+1 Crystal` during MatchEnd/result flow.
- Winner player attributes update: `Crystals`, `PersistentCrystals`, `UnsavedCrystals`, and `LastCrystalsRewardAmount`.
- Output includes `[REWARD] Duel win crystal +1 player=... total=...`.
- Loser receives no Crystal.
- Training victory receives no Crystal.
- BattleArena kill receives no Crystal.
- Leave/rejoin in a published server where DataStore is enabled and confirm Crystals persist.
- In Studio with DataStore unavailable, the game should warn gracefully and session Crystals should still display.

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
- Mobile BattleArena HUD is compact: world HP bar on the tank, score/status top-right, Return to Lobby behind Menu, center mostly free.
- Mobile BattleArena Menu popup Return works and Resume closes the popup.
- Mobile controls hide/disable during ArenaRespawning.
- Wallet HUD shows Bolts and Crystals in lobby/result, and does not crowd BattleArena combat HUD.
- No constant fire/campfire loop after death VFX.
- Shot audio still plays.
- Output has no red errors.
- If the tank gets stuck, set `BattleArenaConfig.DebugCollision = true` and check `[MOVE BLOCKED]` obstacle path.
