# Source Of Truth Cleanup

This repo uses Rojo for code and selected asset templates, but the tuned playable scene still lives in the `.rbxl` place file.

## Code Source Of Truth

Code source of truth is the `src` tree mapped by `default.project.json`:

- `src/ReplicatedStorage/Shared`
- `src/ServerScriptService/Server`
- `src/StarterPlayer/StarterPlayerScripts/Client`

Rojo should be used to sync code and reviewed template assets only. Do not accept broad Rojo changes that add/delete UI or VFX templates without inspecting the source file that caused the diff.

## Scene Source Of Truth

The manually tuned playable scene is source-of-truth in Studio / `.rbxl`.

Do not run old `CREATE_OR_REPAIR_*`, `ORGANIZE_*`, `RECOVER_*`, `MOVE_*`, or `CLEAN_*` scripts after manual scene tuning unless a fresh audit and backup were made first. These scripts can recreate pads, showcases, guidance arrows, VFX, and UI.

## Asset Template Contract

Final shared templates belong only here:

```text
ReplicatedStorage
└── Shared
    └── Assets
        ├── UI
        └── VFX
```

Disk sources:

- `src/ReplicatedStorage/Shared/Assets/UI`
- `src/ReplicatedStorage/Shared/Assets/VFX`

`ReplicatedStorage.Shared.Assets.UI` and `ReplicatedStorage.Shared.Assets.VFX` must keep `$ignoreUnknownInstances: true` in `default.project.json`.

Do not create these as final asset stores:

- `ReplicatedStorage.Assets`
- `ReplicatedStorage.UI`
- `ReplicatedStorage.VFX`
- `ReplicatedStorage.UX`
- `Workspace.Assets`
- `Workspace.UI`
- `Workspace.VFX`
- `Workspace.UX`

## Runtime Contract

Runtime objects belong under:

```text
Workspace.WOB_Runtime
├── VFX
└── Client
    ├── HealthBarAnchors
    └── Visuals
```

Editor backups belong under:

```text
Workspace.WOB_EditorOnly_AssetDonors
├── VFX_Backups
├── VFX_Quarantine
├── UI_Backups
└── OrphanBackups
```

## `.rbxmx` Naming Rule

`.rbxmx` is a file format on disk, not an Instance name in Explorer.

Correct:

```text
src/ReplicatedStorage/Shared/Assets/UI/TankHealthBillboard.rbxm
Studio Instance.Name = TankHealthBillboard
```

Wrong:

```text
Studio Instance.Name = TankHealthBillboard.rbxmx
```

That wrong name can happen when a file is accidentally named like `TankHealthBillboard.rbxmx.rbxm`; Rojo strips only the final extension and treats the source stem as `TankHealthBillboard.rbxmx`.

## Rojo Review Rule

If Rojo proposes adding/deleting UI or VFX templates, stop and review:

1. `default.project.json`
2. `src/ReplicatedStorage/Shared/Assets/UI`
3. `src/ReplicatedStorage/Shared/Assets/VFX`
4. `docs/archive`
5. `docs/patches` for old mutation scripts

Do not blindly accept Rojo UI/VFX changes. The person running Studio owns the final sync decision.
