# Visible Gameplay Sprint

Дата: 2026-05-07.

## What Is Visible Through Rojo Immediately

These scripts are in the existing Rojo-managed mapping:

```text
src/StarterPlayer/StarterPlayerScripts/Client
  WOBTankDirectionIndicator.client.luau
  WOBProjectileReadabilityOverlay.client.luau
  WOBImpactFeedbackOverlay.client.luau
```

Current `default.project.json` maps this folder to:

```text
StarterPlayer/StarterPlayerScripts/Client
```

No new Rojo mapping is required.

## Rojo-Visible Play Mode Checks

After `rojo serve` and Rojo plugin `Connect`:

- A bright direction marker appears in front of `PlayerTankPrototype.Body`.
- The marker follows the tank and rotates with the body.
- Turret aim still follows the mouse independently.
- A small ground glow appears under each projectile.
- Projectile glow disappears when the projectile disappears.
- Impact/bounce VFX get a brief extra local pulse.
- WASD, shoot, ricochet, dummy damage and HUD still work.
- Output has no new errors from the three `WOB...Overlay` scripts.

## Manual Studio Patch: Tank Wall Blocking

`WOBGameplayServer` is still Studio-owned inside `.rbxl`, so the wall blocking change is a patch file:

```text
docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau
```

This is a full-source patch for:

```text
ServerScriptService/Services/WOBGameplayServer
```

Manual apply:

1. Open Roblox Studio.
2. Open `ServerScriptService/Services/WOBGameplayServer`.
3. Save a temporary copy of the old Source somewhere safe if you want an easy rollback.
4. Replace the full Source with the full contents of `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`.
5. Press Play.

Patch Play Mode checks:

- WASD still works.
- Tank rotates normally.
- Tank cannot pass through `Wall_North`, `Wall_South`, `Wall_East`, `Wall_West`.
- Tank cannot pass through `RicochetWall_*`.
- Tank cannot pass through `Cover_Block_*`.
- Turret still aims with the mouse.
- Projectile still flies and ricochets.
- Dummy still receives damage.
- HUD still works.
- Output has no red errors.
- When pushing into a wall, Output may show throttled messages like `[WALL] blocked by Wall_North`.

Rollback if tank stops moving:

1. Stop Play Mode.
2. Open `ServerScriptService/Services/WOBGameplayServer`.
3. Replace Source with the old saved Source, or with `docs/studio_scripts_snapshot/WOBGameplayServer.server.luau`.
4. Press Play and confirm WASD works again.

If the tank starts stuck immediately:

- Confirm `PlayerTankPrototype` starts at approximately `Vector3.new(-42, 0, -42)`.
- Confirm the tank is not already overlapping a `Wall_*`, `RicochetWall_*`, or `Cover_Block_*` part.
- Temporarily reduce `TANK_MOVEMENT_CAST_PADDING` from `0.45` to `0.25` in the pasted script and test again.
- If it still cannot move, rollback to the snapshot and re-paste the patch from a clean copy.

If the tank still passes through walls:

- Confirm the active script you edited is exactly `ServerScriptService/Services/WOBGameplayServer`, not a Rojo copy elsewhere.
- Confirm the full patch was pasted, not only the helper functions.
- Confirm wall and cover parts have `CanQuery = true`.
- Confirm obstacles are under `Workspace/WOB_Generated/Map`, or are named `Wall_North`, `Wall_South`, `Wall_East`, `Wall_West`, `RicochetWall_*`, or `Cover_Block_*`.
- Push the tank into a wall and look for `[WALL] blocked by <part name>` in Output. If no message appears, the obstacle is probably outside the expected map folder, renamed, or has `CanQuery = false`.

## Commit Split

Recommended Rojo-visible commit:

```bash
git add src/StarterPlayer/StarterPlayerScripts/Client src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau docs/START_HERE_RU.md
git commit -m "Add visible tank direction and projectile readability overlays"
```

Recommended patch-prep commit:

```bash
git add docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau docs/patches/README_VISIBLE_SPRINT.md
git commit -m "Finalize tank wall blocking patch"
```
