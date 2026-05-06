# Tank Blocking and Projectile Ground Glow Studio Steps

Дата: 2026-05-07.

## Why This Is A Patch

`WOBGameplayServer` and `WOBProjectileVisualEnhancer` are not Rojo-owned in `src/` yet. They are active Studio-owned scripts in the `.rbxl` scene, so this task does not edit `.rbxl` directly and does not pretend those scripts are already migrated.

Prepared patch files:

- `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`
- `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau`

Rojo-owned config change:

- `src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau`

## Manual Studio Apply Steps

1. Start `rojo serve` from the project root and connect the Rojo plugin in Roblox Studio.
2. Confirm `ReplicatedStorage.Shared.Configs.ProjectileVisualConfig` exists in Studio.
3. Open `ServerScriptService/Services/WOBGameplayServer`.
4. Replace the script Source with `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`.
5. Open `ServerScriptService/Services/WOBProjectileVisualEnhancer`.
6. Replace the script Source with `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau`.
7. Press Play and run the checklist below.
8. If Play Mode passes, save the scene manually via `File -> Save to File`.

## What Changed In WOBGameplayServer

- Adds `Workspace.WOB_Generated.Map`, `RicochetWalls`, and `Cover` lookups near the existing root/runtime/test object lookups.
- Adds a small server-side tank movement `Blockcast` helper after `getYawFromDirection`.
- The movement raycast params exclude `PlayerTankPrototype`, `Runtime`, `Projectiles`, and `VFX`.
- Replaces the direct `tankState.Position += ...` write in `updateTank` with a proposed position and blocks that frame if the swept body box hits:
  - `Wall_North`
  - `Wall_South`
  - `Wall_East`
  - `Wall_West`
  - `RicochetWall_*`
  - `Cover_Block_*`

This does not change RemoteEvent contracts, WASD input, turret aim, projectile damage, projectile ricochet count, or projectile raycast behavior.

## What Changed In WOBProjectileVisualEnhancer

- Requires `ReplicatedStorage.Shared.Configs.ProjectileVisualConfig`.
- Keeps trail setup visual-only and reads existing trail values from config.
- Adds `WOBGroundGlow` as a child of each projectile visual.
- Sets the glow to `Anchored = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`.
- Updates the glow on `RunService.Heartbeat` to follow the projectile X/Z while staying just above the arena floor.
- Lets projectile cleanup destroy the glow because the glow is parented under the projectile part.

## Play Mode Checklist

- Tank drives with WASD.
- Turret still aims at the mouse.
- Tank cannot pass through `Wall_North`, `Wall_South`, `Wall_East`, or `Wall_West`.
- Tank cannot pass through `RicochetWall_*`.
- Tank cannot pass through `Cover_Block_*`.
- Projectile flies as before.
- Ricochets work as before.
- Dummy damage works as before.
- Ground glow is visible under the projectile.
- Ground glow does not block raycast.
- Ground glow disappears after projectile hit/destroy cleanup.
- Output has no errors.
