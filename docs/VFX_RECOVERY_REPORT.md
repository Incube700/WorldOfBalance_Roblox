# VFX Recovery Report

## Current Folder State

Current source folder:

```text
src/ReplicatedStorage/Shared/Assets/VFX
```

contains only:

- `.gitkeep`
- `VfxTemplateCatalog.luau`

Missing persisted template files:

- `TankExplosionTemplate.rbxmx`
- `TankBurningTemplate.rbxmx`
- `RicochetTemplate.rbxmx`
- `ImpactSparksTemplate.rbxmx`
- `MuzzleEffectTemplate.rbxmx`
- `MuzzleFlashTemplate.rbxmx`
- `SmokeTemplate.rbxmx`

Additional configured optional names also have no persisted `.rbxmx` file:

- `MuzzleBlastTemplate.rbxmx`
- `DamageHitTemplate.rbxmx`
- `NoPenTemplate.rbxmx`
- `SelfHitTemplate.rbxmx`

`VfxTemplateCatalog.luau` is only a runtime catalog module. It does not contain the actual particle, sound, mesh, beam, trail, or light objects.

## Git History Findings

Command run:

```bash
git log --all --name-status -- src/ReplicatedStorage/Shared/Assets/VFX
git log --all --name-status -- "*.rbxmx" "*.rbxm"
```

Findings:

- No `.rbxmx` or `.rbxm` VFX template files were found in Git history.
- The VFX folder history only shows `.gitkeep` and `VfxTemplateCatalog.luau`.
- There is no deleted template commit that can be restored with `git checkout <commit> -- <path>`.

Relevant commits touched the folder:

- `5854013 Add VFX template storage folder` added `VfxTemplateCatalog.luau`.
- `bf8e2fc Add shared VFX assets folder` added `.gitkeep`.
- later VFX commits updated `VfxTemplateCatalog.luau`, but did not add `.rbxmx` assets.

## Disk Search Findings

Commands run:

```bash
find . \( -iname "*.rbxmx" -o -iname "*.rbxm" \) -print
find "/Users/sergoburnheart/RobloxProjects" \( -iname "*.rbxmx" -o -iname "*.rbxm" \) -print | grep -iE "VFX|Template|Explosion|Ricochet|Muzzle|Impact|Burning|Smoke"
```

Findings:

- No `.rbxmx` or `.rbxm` files were found in the repository.
- No matching template files were found under `/Users/sergoburnheart/RobloxProjects`.
- No automatic filesystem copy recovery is currently available.

## Likely Cause

The visual templates were Studio-only DataModel objects. They were not saved as `.rbxmx` files under:

```text
src/ReplicatedStorage/Shared/Assets/VFX
```

When Rojo synced the source tree, it rebuilt `ReplicatedStorage.Shared.Assets.VFX` from files in `src`, so Studio-only children were removed. This is expected Rojo behavior for managed folders.

## Recovery Path

Use Studio recovery, then persist the result into Git:

1. Stop Play Mode in Roblox Studio.
2. Run:

```text
docs/patches/RECOVER_VFX_TEMPLATES_FROM_SCENE_COMMAND.lua
```

3. Run:

```text
docs/patches/AUDIT_VFX_TEMPLATES_COMMAND.lua
```

4. For each recovered template under `ReplicatedStorage.Shared.Assets.VFX`, right click the object and choose `Save to File...`.
5. Save each object to:

```text
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox/src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx
```

6. Add and commit the saved source files:

```bash
git add src/ReplicatedStorage/Shared/Assets/VFX/*.rbxmx
git add docs/VFX_RECOVERY_REPORT.md docs/VFX_TEMPLATE_SETUP.md docs/VFX_ASSET_NORMALIZER_WORKFLOW.md docs/CODEX_TASKS.md docs/patches/RECOVER_VFX_TEMPLATES_FROM_SCENE_COMMAND.lua docs/patches/AUDIT_VFX_TEMPLATES_COMMAND.lua
git commit -m "Add VFX recovery and persistence workflow"
```

## Manual Save List

Save these if recovery finds them:

- `TankExplosionTemplate.rbxmx`
- `TankBurningTemplate.rbxmx`
- `RicochetTemplate.rbxmx`
- `ImpactSparksTemplate.rbxmx`
- `MuzzleEffectTemplate.rbxmx`
- `MuzzleFlashTemplate.rbxmx`
- `MuzzleBlastTemplate.rbxmx`
- `SmokeTemplate.rbxmx`
- `DamageHitTemplate.rbxmx`
- `NoPenTemplate.rbxmx`
- `SelfHitTemplate.rbxmx`

Minimum expected templates for the current config:

- `TankExplosionTemplate`
- `TankBurningTemplate`
- `RicochetTemplate`
- `ImpactSparksTemplate`
- `MuzzleEffectTemplate`
- `SmokeTemplate`

## Safety Notes

- Do not edit `.rbxl` directly.
- Do not rely on Studio-only VFX objects inside Rojo-managed folders.
- `TemplateName` is the object name in `ReplicatedStorage.Shared.Assets.VFX`, not an asset id.
- `TextureId` and `SoundId` fields are where raw asset ids belong.
- Runtime fallback must continue to work when templates are missing.
- `Shot.SoundId = "rbxassetid://139771888058836"` should remain unchanged unless there is a deliberate audio pass.
- Projectile size and trail readability values should remain unchanged during recovery.
