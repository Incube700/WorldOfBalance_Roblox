# FX Asset Guide

This guide defines the source-controlled FX folder layout for Ricochet Tanks. It prepares gameplay FX and future cosmetic shop FX without wiring any gameplay, purchasing, DataStore, or equip UI behavior.

## Runtime Folders

The canonical active runtime path is:

- `ReplicatedStorage/Assets/FX/Gameplay`

The canonical Rojo source path is:

- `src/ReplicatedStorage/Assets/FX/Gameplay`

The future shop/equip source path is:

- `src/ReplicatedStorage/Assets/FX/Cosmetics`

`Gameplay` is for baseline effects that support normal readability and combat feedback:

- `MuzzleFlashFX`
- `ProjectileTrailFX`
- `ProjectileVisualFX`
- `ProjectileImpactFX`
- `RicochetImpactFX`
- `TankExplosionFX`
- `RepairFX`
- `ReflectShieldFX`
- `UpgradeSelectFX`
- `LevelUpFX`

`Cosmetics` is for unlockable/equippable variants by shop category:

- `TankExplosion`
- `ProjectileTrail`
- `MuzzleFlash`
- `ProjectileImpact`
- `RicochetImpact`
- `Repair`
- `ReflectShield`
- `UpgradeSelect`
- `LevelUp`

## Manual Staging Folders

`ReplicatedStorage/Assets/FX/Candidates` is a manual inbox for cleaned or partly cleaned FX that are not ready for code. Match the category folder names used under `Cosmetics`.

`ReplicatedStorage/Assets/FX/Rejected` is for reference-only rejected imports. Nothing in `Candidates` or `Rejected` should be wired into gameplay.

## Template Naming

Use stable names that match the catalog id where possible:

- `TankExplosion_Default`
- `TankExplosion_Fire`
- `TankExplosion_Electric`
- `ProjectileTrail_Default`
- `ProjectileTrail_Laser`
- `ReflectShield_Default`
- `ReflectShield_Electric`

Save the final template as `.rbxmx` when you want a reviewable XML file, or `.rbxm` when the asset is too noisy for XML diffs. Prefer `.rbxmx` for small clean template folders.

## Import Cleanup Rules

Before moving an imported FX template into `Gameplay` or `Cosmetics`:

- remove all third-party `Script`, `LocalScript`, and `ModuleScript` descendants;
- remove unsafe runtime dependencies and random marketplace loader code;
- remove unrelated meshes/sounds/textures that are not part of the visible effect;
- rename the root object to the final template name;
- keep the effect self-contained under one root `Folder`, `Model`, `Attachment`, or `BasePart`;
- test in Studio before adding it to the catalog as an active option.

Do not use `InsertService` at runtime for these effects. Imported Toolbox/Creator Store assets should be cleaned in Studio and saved into the Rojo source tree.

## Saving Manual FX Files

Use these source paths:

- Candidate tank explosion: `src/ReplicatedStorage/Assets/FX/Candidates/TankExplosion/<TemplateName>.rbxmx`
- Approved cosmetic tank explosion: `src/ReplicatedStorage/Assets/FX/Cosmetics/TankExplosion/<TemplateName>.rbxmx`
- Approved default gameplay explosion: `src/ReplicatedStorage/Assets/FX/Gameplay/TankExplosionFX/<TemplateName>.rbxmx`

Repeat the same pattern for each category. After saving files, run:

```bash
rojo build default.project.json --output /tmp/wob-fx-check.rbxm
```

## Cosmetic Catalog

The foundation catalog lives at:

`src/ReplicatedStorage/Shared/Cosmetics/CosmeticFXCatalog.luau`

Each item uses:

- `Id`
- `Category`
- `DisplayName`
- `Description`
- `TemplatePath`
- `Rarity`
- `PriceBolts`
- `IsDefault`
- `SortOrder`

The catalog is data only. It does not purchase, equip, save, spawn, or replicate FX yet.

## Legacy VFX Folder

Existing live VFX currently remain under:

`ReplicatedStorage/Shared/Assets/VFX`

Do not move those templates in this pass. Migrate only after a dedicated gameplay FX wiring task, with a small compatibility plan.

## Visual FX Runtime v1

The active visual runtime reads default gameplay templates only from:

`ReplicatedStorage/Assets/FX/Gameplay`

Active keys:

- `MuzzleFlash`
- `ProjectileTrail`
- `ProjectileVisual`
- `ProjectileImpact`
- `RicochetImpact`
- `TankExplosion`
- `Repair`
- `ReflectShield`
- `UpgradeSelect`
- `LevelUp`

`ProjectileTrail` currently uses the reliable code-created projectile trail. Imported `ProjectileTrailFX` assets remain in source for later testing, but are not required for the release default trail.

`ProjectileVisual` is optional and attaches visual-only children to the projectile when `ProjectileVisual_Default` exists. It must not replace the projectile hitbox.

Runtime code intentionally does not read from `Cosmetics`, `Candidates`, or `Rejected` yet. Those folders are staging/future-shop data only.

Audio is intentionally disabled in this pass. If a visual template contains `Sound` objects, the runtime clone is muted/stopped and the sound is not played.

Temporary clones are parented under:

`Workspace/WOB_TemporaryFX`

Clones are cleaned up with `Debris`. This folder should not accumulate old FX after several seconds of gameplay.

Template resolution is deterministic:

1. If `GameplayFXCatalog` has a playable exact `TemplateName`, runtime uses that child.
2. Otherwise, if the folder contains exactly one playable child with `Default` in the name, runtime uses that child.
3. Otherwise, if the folder contains exactly one playable child, runtime uses that child.
4. Otherwise, runtime skips the effect. In debug mode it prints why.

If multiple children contain `Default`, runtime treats that as ambiguous unless `TemplateName` names one exact child.

Playable template roots are:

- `Model`
- `Folder` with visual descendants
- `BasePart` / `MeshPart`
- `Attachment`
- `ParticleEmitter`
- `Beam`
- `Trail`

`Beam` templates must have valid `Attachment0` and `Attachment1` inside the cloned template or be safe to bind to projectile attachments. `Trail` templates also require attachments and movement; do not rely on Trail-only one-shot world FX.

For projectile-attached `ProjectileVisual` templates, runtime may bind `Beam`/`Trail` attachments to the projectile's own `TrailFront` and `TrailBack` attachments. Any visual `BasePart` descendants are made non-colliding, massless, and welded to the projectile part.

To enable Studio debug logs temporarily, set `GameplayFXCatalog.Debug = true` in:

`src/ReplicatedStorage/Shared/FX/GameplayFXCatalog.luau`

Keep it `false` before committing normal gameplay work.

When adding a default gameplay template:

1. Put the cleaned template under the matching `Gameplay` category folder, for example `ReplicatedStorage/Assets/FX/Gameplay/TankExplosionFX/TankExplosion_Default`.
2. Prefer the exact template name configured in `GameplayFXCatalog`, for example `ProjectileImpact_Default`.
3. Remove third-party `Script`, `LocalScript`, and `ModuleScript` descendants before committing. Runtime also strips those descendants from cloned FX as a safety net.
4. Keep the root as a `Model`, `Folder`, `BasePart`, `Attachment`, or `ParticleEmitter`.
5. Keep one-shot particles configured with an `EmitCount` attribute when the default burst count is not enough.

Do not save the whole gameplay collection as one `Gameplay.rbxm`. Save playable templates separately inside their category folders:

- good: `src/ReplicatedStorage/Assets/FX/Gameplay/ProjectileImpactFX/ProjectileImpact_Default.rbxm`
- bad: `src/ReplicatedStorage/Assets/FX/Gameplay.rbxm`

## Replacing ProjectileImpact

The active projectile impact template should live at:

`src/ReplicatedStorage/Assets/FX/Gameplay/ProjectileImpactFX/ProjectileImpact_Default.rbxm`

If a better old impact effect exists under legacy `src/ReplicatedStorage/Shared/Assets/VFX`, copy or re-save that cleaned template into the canonical `ProjectileImpactFX` folder and rename the root to `ProjectileImpact_Default`.

After replacing it:

1. Keep `GameplayFXCatalog.Effects.ProjectileImpact.TemplateName = "ProjectileImpact_Default"`.
2. Tune `EmitCount`, `Lifetime`, `YOffset`, and `ScaleMultiplier` in `GameplayFXCatalog`.
3. Run `rojo build default.project.json --output /tmp/wob-fx-check.rbxm`.

Bad or experimental impact effects should move to:

`src/ReplicatedStorage/Assets/FX/Candidates/ProjectileImpact`

Rejected effects can be archived under:

`src/ReplicatedStorage/Assets/FX/Rejected`

## Tuning Values

Runtime tuning lives in:

`src/ReplicatedStorage/Shared/FX/GameplayFXCatalog.luau`

Supported fields:

- `TemplateName`: exact playable child to use when present.
- `Lifetime`: cleanup delay for the cloned FX.
- `EmitCount`: default particle burst count.
- `YOffset`: vertical placement offset.
- `ScaleMultiplier`: safe clone-only scaling for models, base parts, attachments, particle sizes, beam widths, and trail widths.
- `DebugName`: human-readable label for audits/debugging.

Scale only affects runtime clones. It does not modify original templates.

## Release Default Checklist

Expected default template names:

- `MuzzleFlashFX/MuzzleFlash_Default`
- `ProjectileTrailFX/ProjectileTrail_Default` is present, but the release trail is code-created for reliability.
- `ProjectileVisualFX/ProjectileVisual_Default`
- `ProjectileImpactFX/ProjectileImpact_Default`
- `RicochetImpactFX/RicochetImpact_Default`
- `TankExplosionFX/TankExplosion_Default`
- `ReflectShieldFX/ReflectShield_Default`
- `RepairFX/Repair_Default`
- `UpgradeSelectFX/UpgradeSelect_Default`
- `LevelUpFX/LevelUp_Default`

Current release defaults present in source:

- `MuzzleFlashFX/MuzzleFlash_Default`
- `ProjectileTrailFX/ProjectileTrail_Default`
- `ProjectileImpactFX/ProjectileImpact_Default`
- `RicochetImpactFX/RicochetImpact_Default`
- `TankExplosionFX/TankExplosion_Default`
- `ReflectShieldFX/ReflectShield_Default`
- `LevelUpFX/LevelUp_Default`

Still missing:

- `ProjectileVisualFX/ProjectileVisual_Default`
- `RepairFX/Repair_Default`
- `UpgradeSelectFX/UpgradeSelect_Default`

`ProjectileTrail_Deafult.rbxm` was migrated from legacy into the canonical folder with the corrected filename `ProjectileTrail_Default.rbxm`.

Legacy `ReplicatedStorage/Shared/Assets/VFX` remains as the existing fallback path for current projectile/death visuals. The new `Gameplay` templates take priority only when a matching cleaned template exists. Do not add new active runtime assets to the legacy folder.

## Legacy To Canonical Migration Status

Initial migrated defaults:

- `MuzzleEffectTemplate.rbxm` -> `src/ReplicatedStorage/Assets/FX/Gameplay/MuzzleFlashFX/MuzzleFlash_Default.rbxm`
- `ImpactSparksTemplate.rbxm` -> `src/ReplicatedStorage/Assets/FX/Gameplay/ProjectileImpactFX/ProjectileImpact_Default.rbxm`
- `RicochetTemplate.rbxm` -> `src/ReplicatedStorage/Assets/FX/Gameplay/RicochetImpactFX/RicochetImpact_Default.rbxm`
- `TankExplosionTemplate.rbxm` -> `src/ReplicatedStorage/Assets/FX/Gameplay/TankExplosionFX/TankExplosion_Default.rbxm`

Projectile impact alternatives:

- Current canonical default uses the old active fallback `ImpactSparksTemplate.rbxm`.
- `ProjectileImpactVFX.rbxm` was copied as a candidate at `src/ReplicatedStorage/Assets/FX/Candidates/ProjectileImpact/ProjectileImpactVFX_Candidate.rbxm`.
- To switch to the candidate later, inspect it in Studio, clean it if needed, then replace `ProjectileImpact_Default.rbxm` with that chosen template.

Not migrated yet:

- `ReflectShieldFX`: no clear safe legacy `ShieldReflectTemplate` file exists in source. The old shield reflect path still falls back procedurally.
- `RepairFX`, `UpgradeSelectFX`, `LevelUpFX`: no safe legacy defaults exist yet.
- `ProjectileTrailFX`: canonical default exists, but runtime uses the code-created projectile trail for the release default.

Do not use `TankBurningTemplate.rbxmx` as an active default while it contains a `Script` descendant. It can be revisited only after a dedicated cleanup pass.
