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

Manual apply:

1. Open Roblox Studio.
2. Open `ServerScriptService/Services/WOBGameplayServer`.
3. Save a temporary copy of the old Source somewhere safe if you want an easy rollback.
4. Replace the full Source with `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`.
5. Press Play.

Patch Play Mode checks:

- WASD still works.
- Tank cannot pass through `Wall_North`, `Wall_South`, `Wall_East`, `Wall_West`.
- Tank cannot pass through `RicochetWall_*`.
- Tank cannot pass through `Cover_Block_*`.
- Turret still aims with the mouse.
- Projectile still flies and ricochets.
- Dummy still receives damage.
- Output has no errors.

Rollback if tank stops moving:

1. Stop Play Mode.
2. Open `ServerScriptService/Services/WOBGameplayServer`.
3. Replace Source with the old saved Source, or with `docs/studio_scripts_snapshot/WOBGameplayServer.server.luau`.
4. Press Play and confirm WASD works again.

## Commit Split

Recommended Rojo-visible commit:

```bash
git add src/StarterPlayer/StarterPlayerScripts/Client src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau docs/START_HERE_RU.md
git commit -m "Add visible tank direction and projectile readability overlays"
```

Recommended patch-prep commit:

```bash
git add docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau docs/patches/README_VISIBLE_SPRINT.md
git commit -m "Prepare tank wall blocking patch"
```
