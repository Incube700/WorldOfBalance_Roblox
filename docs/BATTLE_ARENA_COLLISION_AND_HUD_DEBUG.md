# Battle Arena Collision And HUD Debug

Дата: 2026-05-14.

## Why Stuck Happens After Manual Moves

`TankMovementService` builds its obstacle list from `Workspace.WOB_Generated`. A part can block tank movement if it has `WOBMovementObstacle = true`, if it is inside folders such as `Boundaries`, `Cover`, or `RicochetWalls`, or if its name matches known wall/cover patterns.

When BattleArena visual parts are moved manually, stale obstacles can remain near the old center. They may be invisible or almost invisible but still have `CanQuery = true`, `CanCollide = true`, or `WOBMovementObstacle = true`, so movement casts treat them as real blockers.

Another hard failure mode is XZ overlap with the lobby. If `Lobby.Floor` overlaps `BattleArena.Floor`, lobby railings or lobby floor query/collision can sit in the arena driving space. If the tank gets stuck near the arena center, check scene-space overlap before tuning movement code.

Run outside Play Mode:

```text
docs/patches/AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua
```

Expected output after repair:

```text
[SPACE AUDIT] Lobby/BattleArena overlap XZ = false
```

Warnings such as `Lobby.Floor overlaps BattleArena.Floor` or `Lobby obstacle near/inside BattleArena bounds` mean the arena must be moved as a whole.

## Audit

Run outside Play Mode:

```text
docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua
```

It prints BattleArena path, pivot if available, estimated center, floor, spawn positions, every `BasePart`, invisible blockers, spawn points inside obstacles, and stale obstacles near the arena.

Warnings use `[ARENA WARNING]`.

## Repair

If the issue is Lobby/BattleArena overlap, run outside Play Mode:

```text
docs/patches/MOVE_BATTLE_ARENA_TO_SAFE_ZONE_COMMAND.lua
```

This moves all `BasePart` descendants inside `Workspace.WOB_Generated.BattleArena` by one shared delta. It does not move Lobby, ArenaPad, DuelPad, or TrainingPad. The default safe center comes from `BattleArenaConfig.SafeArenaCenter`.

After moving, run outside Play Mode:

```text
docs/patches/REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua
```

The repair script preserves the current BattleArena position by reading the existing `BattleArena/Floor` center and size. It does not reset the arena to the original default coordinates.

Then run the audit again and save the scene:

```text
File -> Save to File
```

Recommended order after manual arena movement:

1. `AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua`
2. `MOVE_BATTLE_ARENA_TO_SAFE_ZONE_COMMAND.lua` if overlap is true
3. `REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua`
4. `AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua`
5. `AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua`
6. `File -> Save to File`

## Movement Obstacles

Allowed BattleArena movement obstacles:

- `BattleArena.Boundaries`
- `BattleArena.Cover`
- `BattleArena.RicochetWalls`

These parts should be `Anchored = true`, `CanCollide = true`, `CanQuery = true`, and `WOBMovementObstacle = true`. Ricochet walls also use `WOBRicochetSurface = true`.

## Not Movement Obstacles

These should not have `WOBMovementObstacle = true`:

- `BattleArena.Floor`
- `SpawnPoints/ArenaSpawn1..8`
- pads
- triggers
- labels
- VFX preview/runtime objects

The floor remains collidable for tanks but is not included in movement obstacle casts.

## Movement Debug

Normal mode has no collision spam. To debug a stuck case, set either:

- `BattleArenaConfig.DebugCollision = true`
- `TankConfig.Movement.DebugCollision = true`

Then Play and reproduce. Blocked movement logs look like:

```text
[MOVE BLOCKED] tank=... obstacle=... reason=blockcast ...
```

The log includes obstacle path, position, size, `WOBMovementObstacle`, `CanCollide`, `CanQuery`, and transparency.

## BattleArena HUD

`WOBBattleArenaOverlay.client.luau` is the arena HUD. It is visible only when `PlayerMode = InBattleArena` or `PlayerMode = ArenaRespawning`.

It reads:

- `Player.ArenaScore`
- `Player.ArenaKills`
- `Player.ArenaDeaths`
- `Player.ArenaStreak`
- `Player.ArenaUpgradeIds`
- owned tank `CurrentHealth` / `Health` / `HP`
- owned tank `MaxHealth`
- `Player.ArenaRespawnAt`

`WOBRoundStatusOverlay.client.luau` remains duel/training-only and is visible only during `InMatch`.

## VFX Template Cleaning

Creator Store VFX donors can contain scripts, click detectors, and interactive helpers. Those must not run when templates are cloned into `Workspace.WOB_Generated.Runtime.VFX`.

Run outside Play Mode:

```text
docs/patches/CLEAN_VFX_TEMPLATES_COMMAND.lua
```

It sanitizes `ReplicatedStorage.Shared.Assets.VFX` templates and any existing `Workspace.WOB_Generated.Runtime.VFX` instances:

- removes `Script`, `LocalScript`, nested `ModuleScript`;
- removes `ClickDetector`;
- sets template `BasePart` collision/touch/query off;
- disables `ParticleEmitter.Enabled`;
- keeps `Sound` objects.
