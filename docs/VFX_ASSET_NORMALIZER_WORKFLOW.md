# VFX Asset Normalizer Workflow

Use this workflow for Stable Fun Duel v0.1 when VFX assets were inserted through Studio, Toolbox, Creator Store, or copied from another place.

## 1. DataModel vs Rojo

Studio objects disappear after Rojo reconnect or rebuild if they were never saved into the source tree. The final VFX templates must live in:

```text
ReplicatedStorage.Shared.Assets.VFX
```

For Rojo persistence, each installed template must be saved as a `.rbxmx` file under:

```text
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox/src/ReplicatedStorage/Shared/Assets/VFX
```

## 2. Run the organizer

In Roblox Studio, stop Play Mode. Run this command script from the Command Bar:

```text
docs/patches/ORGANIZE_ALL_VFX_ASSETS_COMMAND.lua
```

The organizer scans:

- `Workspace`
- `Workspace.WOB_EditorOnly_AssetDonors`
- `ReplicatedStorage`
- `ReplicatedStorage.Shared.Assets.VFX`
- `ServerStorage`
- `ServerStorage.WOB_EditorOnly_AssetDonors`
- `Lighting`

`MaterialService` is report-only for `MaterialVariant` objects. It is not treated as a standalone VFX template source.

## 3. What the organizer installs

The organizer classifies VFX candidates into these target template object names:

- `MuzzleEffectTemplate`
- `MuzzleFlashTemplate`
- `MuzzleBlastTemplate`
- `SmokeTemplate`
- `ImpactSparksTemplate`
- `RicochetTemplate`
- `DamageHitTemplate`
- `NoPenTemplate`
- `SelfHitTemplate`
- `TankExplosionTemplate`
- `TankBurningTemplate`

`TemplateName` in `VfxConfig` is the object name in `ReplicatedStorage.Shared.Assets.VFX`, not an asset id.

`TextureId` and `SoundId` are asset ids inside `ParticleEmitter`, `Beam`, `Trail`, `Texture`, `Decal`, and `Sound` instances. One effect may have many texture ids; the organizer prints and reports all unique ids it finds.

## 4. Shot and ricochet rule

If an old/current `MuzzleEffectTemplate` looks like a spark/impact effect and a clearer muzzle candidate exists, the organizer uses the old shot effect as `RicochetTemplate` and installs the clearer candidate as `MuzzleEffectTemplate`.

The script does not change `Shot.SoundId`, projectile size, or projectile trail values. Procedural fallback stays enabled.

## 5. Quarantine behavior

The organizer does not permanently delete VFX objects. It moves replaced or risky objects into:

```text
Workspace.WOB_EditorOnly_AssetDonors.VFX_Backups
Workspace.WOB_EditorOnly_AssetDonors.VFX_Quarantine
Workspace.WOB_EditorOnly_AssetDonors.VFX_Unclassified
```

Toolbox/Creator Store scripts inside installed template clones are removed from the clone. Suspicious scripts found in safe donor/template sources are disabled and moved to quarantine when possible.

## 6. Save installed templates to files

After the organizer finishes, right click each installed template under `ReplicatedStorage.Shared.Assets.VFX` and choose `Save to File...`.

Save these when present:

- `MuzzleEffectTemplate.rbxmx`
- `MuzzleFlashTemplate.rbxmx`
- `MuzzleBlastTemplate.rbxmx`
- `SmokeTemplate.rbxmx`
- `ImpactSparksTemplate.rbxmx`
- `RicochetTemplate.rbxmx`
- `TankExplosionTemplate.rbxmx`
- `TankBurningTemplate.rbxmx`

Also save these when the organizer installed specialized impact variants:

- `DamageHitTemplate.rbxmx`
- `NoPenTemplate.rbxmx`
- `SelfHitTemplate.rbxmx`

Target folder:

```text
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox/src/ReplicatedStorage/Shared/Assets/VFX/TemplateName.rbxmx
```

## 7. Add and verify

After saving from Studio:

```bash
git add src/ReplicatedStorage/Shared/Assets/VFX/*.rbxmx
rojo build default.project.json --output /private/tmp/wob-vfx-organizer-check.rbxm
```

Then preview in Studio:

```text
docs/patches/PREVIEW_VFX_TEMPLATES_COMMAND.lua
```

The preview command emits all particles, optionally plays sounds, and logs template counts plus texture/sound ids.

## 8. Commit

Commit the source changes and the saved `.rbxmx` files together. Recommended message:

```text
Add full VFX organizer and template workflow
```
