# Safe Patch Workflow

Use this workflow before running any Studio Command Bar patch that mutates the scene, UI, VFX, or assets.

## Rules

1. Run audit scripts first.
2. Save a Studio backup before mutation. Use `File -> Save to File As...` with a clear safe name.
3. Mutation scripts are disabled by default with `ENABLE_MUTATION=false`.
4. Only set `ENABLE_MUTATION=true` after reading the script and confirming the target paths.
5. Never run old `CREATE_OR_REPAIR_*` scripts after manual scene tuning unless you intend to rebuild those objects.
6. Never blindly accept Rojo UI/VFX add/delete suggestions.
7. Commit `.rbxl` changes separately from code changes.
8. Remember that `.rbxmx` is a disk file format, not a Studio `Instance.Name`.

## Safe Scripts

Audit-only scripts may be run when they only print/read:

- `docs/patches/AUDIT_CURRENT_FOLDER_STRUCTURE_COMMAND.lua`
- `docs/patches/AUDIT_FIRE_SOUNDS_COMMAND.lua`
- `docs/patches/AUDIT_LEGACY_HUD_COMMAND.lua`
- `docs/patches/AUDIT_VFX_TEMPLATES_COMMAND.lua`
- `docs/patches/AUDIT_WOB_FOLDER_HYGIENE_COMMAND.lua`

## Disabled Mutation Scripts

Scripts that create, repair, move, clean, install, recover, preview, show, hide, mute, or disable scene/UI/VFX objects now require manual opt-in:

```lua
local ENABLE_MUTATION = false
```

Change this only after audit and backup.

## Do Not Use Casually

Avoid these after manual scene tuning:

- `CREATE_OR_REPAIR_BATTLE_ARENA_COMMAND.lua`
- `CREATE_OR_REPAIR_LOBBY_GUIDANCE_COMMAND.lua`
- `CREATE_OR_REPAIR_LOBBY_SHOWCASES_COMMAND.lua`
- `ORGANIZE_ALL_VFX_ASSETS_COMMAND.lua`
- `RECOVER_VFX_TEMPLATES_FROM_SCENE_COMMAND.lua`
- `COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua`
- `CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua`

They remain in the repo for reference and emergency recovery, but should not be the default workflow.
