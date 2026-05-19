# VFX Template Source Audit

Date: 2026-05-20

## Findings

| Source | Risk | Action |
| --- | --- | --- |
| `src/ReplicatedStorage/Shared/Assets/VFX/TankBurningTemplate.rbxm` | Contained unsafe scripts under `FIRE` and could restore fire/campfire behavior from source. | Archived and replaced with safe `.rbxmx` source. |
| `src/ReplicatedStorage/Shared/Assets/VFX/ImpactSparksDonor.rbxm` | Donor asset contained script descendants and was not the configured `ImpactSparksTemplate`. | Archived. |
| `src/ReplicatedStorage/Shared/Assets/VFX/ImpactSparksTemplate.rbxm` | Configured template. | Left in place. |
| `src/ReplicatedStorage/Shared/Assets/VFX/TankExplosionTemplate.rbxm` | Configured death explosion template. | Left in place. |
| `src/ReplicatedStorage/Shared/Assets/VFX/MuzzleEffectTemplate.rbxm` | Configured shot muzzle template. | Left in place. |
| `src/ReplicatedStorage/Shared/Assets/VFX/MuzzleFlashTemplate.rbxm` | Configured shot muzzle template. | Left in place. |
| `src/ReplicatedStorage/Shared/Assets/VFX/RicochetTemplate.rbxm` | Configured ricochet template. | Left in place. |
| `src/ReplicatedStorage/Shared/Assets/VFX/SmokeTemplate.rbxm` | Configured smoke template. | Left in place. |

## Canonical Burning Source

Current source:

```text
src/ReplicatedStorage/Shared/Assets/VFX/TankBurningTemplate.rbxmx
```

Expected Studio path:

```text
ReplicatedStorage.Shared.Assets.VFX.TankBurningTemplate
```

The replacement contains visual `Fire`, `Smoke`, and `PointLight` instances only. It intentionally contains no `Sound`, `Script`, `LocalScript`, or `ClickDetector`.

`VfxConfig.BurningTank` also keeps:

```lua
PlayTemplateSounds = false
SoundVolume = 0
AllowLoopedSounds = false
```

## Archive

Archived unsafe sources:

```text
docs/archive/vfx-unsafe-templates/2026-05-20/TankBurningTemplate.with-scripts.rbxm
docs/archive/vfx-unsafe-templates/2026-05-20/ImpactSparksDonor.with-scripts.rbxm
```

These were not destroyed. Restore manually only after sanitizing them in Studio.
