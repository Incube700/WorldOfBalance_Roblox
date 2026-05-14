# VFX Organizer Report

This file is the target report for `docs/patches/ORGANIZE_ALL_VFX_ASSETS_COMMAND.lua`.

Roblox Studio Command Bar usually cannot write directly into repository files. When direct write access is unavailable, the organizer stores the generated markdown in one or more `StringValue` objects named `VFX_ORGANIZER_REPORT_MD_*` under:

```text
Workspace.WOB_EditorOnly_AssetDonors.VFX_Backups
```

After running the command, copy that generated markdown here if Studio did not overwrite this file automatically. If the report was split into `_Part1`, `_Part2`, and later chunks, paste the chunks in numeric order.

## Found candidates

- Pending Studio run.

## Classified templates

- Pending Studio run.

## Installed templates

- Pending Studio run.

## Quarantined objects

- Pending Studio run.

## Asset IDs found

- Pending Studio run.

## Suspicious scripts removed/disabled

- Pending Studio run.

## Manual save-to-file steps

1. In Studio, open `ReplicatedStorage.Shared.Assets.VFX`.
2. Right click each installed template and choose `Save to File...`.
3. Save each file into `/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox/src/ReplicatedStorage/Shared/Assets/VFX/TemplateName.rbxmx`.
4. Save `MuzzleEffectTemplate.rbxmx`, `MuzzleFlashTemplate.rbxmx`, `MuzzleBlastTemplate.rbxmx` if present, `SmokeTemplate.rbxmx`, `ImpactSparksTemplate.rbxmx`, `RicochetTemplate.rbxmx`, `TankExplosionTemplate.rbxmx`, and `TankBurningTemplate.rbxmx`.
5. Also save `DamageHitTemplate.rbxmx`, `NoPenTemplate.rbxmx`, and `SelfHitTemplate.rbxmx` if the organizer installs them.
6. Run `git add src/ReplicatedStorage/Shared/Assets/VFX/*.rbxmx`.
7. Run `rojo build default.project.json --output /private/tmp/wob-vfx-organizer-check.rbxm`.
