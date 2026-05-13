# Stable Fun Duel VFX And Movement Pass

Дата прохода: 2026-05-13.

## Preflight

```text
pwd
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox

git status --short
 M RicochetTanksPrototype.rbxl
 M docs/CODEX_TASKS.md
 M docs/VFX_TEMPLATE_SETUP.md
 M src/ReplicatedStorage/Shared/Assets/VFX/VfxTemplateCatalog.luau
 M src/ReplicatedStorage/Shared/Configs/MatchConfig.luau
 M src/ReplicatedStorage/Shared/Configs/VfxConfig.luau
 M src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau
 M src/ServerScriptService/Server/Gameplay/Round/RoundMatchService.luau
 M src/ServerScriptService/Server/Gameplay/VFX/CombatVfxService.luau
 M src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau
?? docs/patches/INSTALL_TANK_EXPLOSION_VFX_TEMPLATE_COMMAND.lua

git branch --show-current
main

git remote -v
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (fetch)
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (push)

git log --oneline -8
8ab52a3 Add conflicting SoundId variants in VfxConfig
ef40f19 Add conflicting SoundId variants in VfxConfig
31e12c9 Update VFX assets and add new rbxl scene
bf8e2fc Add shared VFX assets folder
5854013 Add VFX template storage folder
7beaa09 Support particle texture bursts for shot VFX
68c3bdd Add configurable shot particle asset slots
fdfa22b Keep shot sound alive independently from muzzle flash

conflict marker grep over src/docs/default.project.json
no conflict markers found
```

`RicochetTanksPrototype.rbxl` was already dirty at preflight. This pass does not edit `.rbxl` directly.

## VFX Templates Found

Filesystem/Rojo view:

- `src/ReplicatedStorage/Shared/Assets/VFX/VfxTemplateCatalog.luau`
- `src/ReplicatedStorage/Shared/Assets/VFX/.gitkeep`

No concrete template asset files are visible in the repository path. That means existing Studio-created templates or Toolbox donors are currently inside the saved `.rbxl` DataModel or `Workspace`, not represented as Rojo source files.

Configured template names checked in source:

- `DeathExplosion.TemplateName = "TankExplosionTemplate"`: good if installed in `ReplicatedStorage/Shared/Assets/VFX`.
- `BurningTank.TemplateName = "TankBurningTemplate"`: good optional name if a burning/fire donor is installed.
- No raw numeric asset ids were found in `src/**/TemplateName`. A value like `TemplateName = "37194537"` would be bad because it is an asset id, not an object name under `ReplicatedStorage/Shared/Assets/VFX`.

## Template Suitability

- `TankExplosionTemplate`: suitable for `DeathExplosion` after running `INSTALL_TANK_EXPLOSION_VFX_TEMPLATE_COMMAND.lua` or the new collector command.
- `TankBurningTemplate`: suitable for `BurningTank` only if a burning/fire donor exists and is installed. Runtime should skip quietly if absent.
- `MuzzleFlashTemplate`: suitable for `Shot.MuzzleFlash` if installed.
- `MuzzleBlastTemplate`: suitable for `Shot.MuzzleBlast` if installed; raw id strings do not belong in `TemplateName`.
- `SmokeTemplate`: suitable for `Shot.Smoke` if installed.
- `ImpactFlashTemplate`: suitable for `Shot.ImpactFlash` if installed.
- `ImpactSparksTemplate`: suitable for `Shot.ImpactSparks` if installed.
- `RicochetTemplate`: suitable for ricochet wall/tank bounces if installed.

Potentially bad templates:

- Any template containing `Script`, `LocalScript`, or `ModuleScript`: sanitize before use.
- Any template with collidable/queryable parts: can interfere with tank collision/projectile raycasts.
- Any raw asset id in `TemplateName`: should be moved to `TextureId` or `SoundId`, or replaced with a real template object name.

## Gameplay Bugs Still Active

- Corner clipping before this pass: movement validated translation, but the server changed `BodyYaw` before final overlap validation. Rotation-only contact could gradually push the oriented collision box into a wall/corner.
- Final candidate pose validation before this pass was incomplete: `resolveTankMovement` returned position only and did not decide whether the new yaw was safe.
- If a tank begins a frame already intersecting an obstacle, the new resolver refuses to apply any still-overlapping pose. Recovery may require backing out only if a non-overlapping candidate is available, or a reset if the scene spawns a tank inside geometry.

## Plan

1. Add movement collision config fields to `TankConfig.Movement`.
2. Add final oriented-box pose validation to `TankMovementService`.
3. Add a new `resolveTankPose` API that evaluates full move+rotation, movement-only, rotation-only, X/Z slide with final pose checks, then falls back to the last valid pose.
4. Update `WOBGameplayServer` to stop applying body yaw before movement validation.
5. Keep `VfxConfig.TemplateName` values clean so asset ids are not used as template names.
6. Make `VfxTemplateCatalog` discover real children under `ReplicatedStorage/Shared/Assets/VFX` at runtime.
7. Add `COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua` for Workspace/AssetDonor collection and sanitization.
8. Add optional burning and ricochet template playback through the existing `CombatVfxService`.
9. Update docs and run `git diff --check`, conflict grep, and Rojo build.

## Changes Made

- `TankConfig.Movement` now has `CollisionBoxSize`, `CollisionBoxYOffset`, `CollisionSkinWidth`, and `DebugCollision`.
- `TankMovementService.resolveTankPose` validates the full final pose with an oriented overlap box after translation and rotation.
- `WOBGameplayServer` now computes desired yaw first, asks `TankMovementService` for a valid position/yaw pair, then applies only the resolved pose.
- Rotation into walls is blocked if the resulting tank box overlaps a movement obstacle.
- Sliding remains allowed only when the final pose is valid.
- `VfxConfig` was checked for raw numeric asset ids in `TemplateName`; none remain in source.
- `VfxConfig.BurningTank` is enabled as an optional template effect with missing-template warnings suppressed.
- `VfxConfig.Ricochet` was added for wall bounces and armor ricochets.
- `CombatVfxService` can play configured non-template sounds and can suppress missing-template warnings for optional effects.
- `ProjectileService` now exposes `createRicochetVfx` and `createBurningTank`.
- Tank death now plays death explosion plus optional burning aftermath.
- Wall bounce and armor ricochet now try `RicochetTemplate` before falling back to impact sparks.
- `VfxTemplateCatalog` now discovers real children under `ReplicatedStorage/Shared/Assets/VFX` instead of listing templates that may not exist.
- `docs/patches/COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua` collects and sanitizes known Workspace donors into the VFX template folder.

## Root Cause For Corner Clipping

The server movement loop applied the desired body yaw independently from the collision result. A forward/slide cast could be blocked correctly, but repeated yaw changes near a wall were still allowed. Because the tank collision box is longer than it is wide, turning while sliding could rotate a corner through the obstacle and start the next frame partially inside the wall.

The fix is to treat position and yaw as one candidate pose. `resolveTankPose` tests the full candidate, movement-only, rotation-only, and axis slide fallbacks, and every accepted fallback must pass the final oriented `Workspace:GetPartBoundsInBox` overlap check.

## VFX Template Catalog

No concrete template asset files are visible in Rojo source at this moment. The catalog will discover templates that exist in Studio under:

```text
ReplicatedStorage/Shared/Assets/VFX
```

Supported known names:

- `TankExplosionTemplate` -> `TankDeathExplosion`
- `TankBurningTemplate` -> `BurningTank`
- `MuzzleFlashTemplate` -> `MuzzleFlash`
- `MuzzleBlastTemplate` -> `MuzzleBlast`
- `SmokeTemplate` -> `Smoke`
- `ImpactFlashTemplate` -> `ImpactFlash`
- `ImpactSparksTemplate` -> `ImpactSparks`
- `RicochetTemplate` -> `Ricochet`

If a template is absent, it is not reported as available by `VfxTemplateCatalog`.

## Studio Command Scripts

- `docs/patches/COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua`: preferred broad collector for Workspace donors such as explosion, burning/fire, smoke, sparks, ricochet, muzzle.
- `docs/patches/INSTALL_TANK_EXPLOSION_VFX_TEMPLATE_COMMAND.lua`: focused installer for only the tank death explosion donor.
- `docs/patches/CREATE_OR_REPAIR_ARENA_CONTAINMENT_COMMAND.lua`: scene containment/collision repair for lobby railings, walls, cover, and arena boundaries.

All command scripts must be run outside Play Mode, then `File -> Save to File`.

## Manual Acceptance Focus

- Lobby railing blocks direct movement and slide+turn penetration.
- Duel/training wall blocks direct movement and slide+turn penetration.
- Cover corners block the tank without letting rotation screw into geometry.
- `TankExplosionTemplate` plays on DummyTank and player tank death if installed.
- `TankBurningTemplate` plays after death if installed; missing template is quiet.
- `RicochetTemplate` plays on ricochet if installed; otherwise impact fallback remains.
- Lobby no-damage shooting does not produce death explosion.

## Verification

Run on 2026-05-13:

- `git diff --check`: passed.
- conflict marker grep over `src`, `docs`, and `default.project.json`: no matches.
- `rojo build default.project.json --output /private/tmp/wob-vfx-movement-next-pass-check.rbxm`: passed.
- `luau`, `luau-lsp`, `selene`, `stylua`, and `darklua`: not available in PATH, so no local Luau/static formatting checks were run.
