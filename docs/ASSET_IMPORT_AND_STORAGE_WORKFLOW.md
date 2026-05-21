# Asset Import And Storage Workflow

This workflow keeps Rojo, Studio, VFX templates, UI templates, and future cosmetic catalog data aligned.

## Storage Contract

Final VFX assets belong here:

```text
ReplicatedStorage
`-- Shared
    `-- Assets
        `-- VFX
```

Source files belong here:

```text
src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxm
src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx
```

Do not save an entire VFX/UI folder as one `.rbxmx` source file inside `src`.

Each template should be its own file.

## Naming Contract

The Studio instance name must be the template name:

```text
ReplicatedStorage.Shared.Assets.VFX.RicochetTemplate
```

It must not be:

```text
ReplicatedStorage.Shared.Assets.VFX.RicochetTemplate.rbxmx
```

`.rbxm` and `.rbxmx` are file extensions on disk, not instance names in the DataModel.

## Store Asset Cleanup

Before a Creator Store asset becomes a template:

- remove `Script`;
- remove `LocalScript`;
- remove `ClickDetector`;
- review every `Sound`;
- mute fire/burning sounds unless explicitly approved;
- ensure no looping fire/campfire sound plays by default;
- ensure template contents are visual-safe and do not mutate gameplay.

`TankBurningTemplate` must remain visual-only unless a future audio pass explicitly moves burning audio into `AudioCatalog`.

## Registration Steps

When adding a new VFX template:

1. Insert or build it in Studio.
2. Sanitize scripts/click detectors/sounds.
3. Put it under `ReplicatedStorage.Shared.Assets.VFX`.
4. Save that single object to `src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxm/.rbxmx`.
5. Confirm the Studio object name is exactly `<TemplateName>`.
6. Let `VfxTemplateCatalog` discover it as a real child.
7. Add it to `VfxConfig` only if gameplay uses it.
8. Add it to `CosmeticCatalog` if it can be unlocked/equipped later.

## Rojo Safety

- Never accept Rojo UI/VFX add/delete prompts blindly.
- Confirm whether a template is meant to be source-backed or Studio-only before accepting changes.
- Keep `ReplicatedStorage.Shared.Assets.VFX` and `ReplicatedStorage.Shared.Assets.UI` protected with `$ignoreUnknownInstances`.
- Back up a template before replacing it.
- Do not use repair/organize/clean/move scripts unless the task explicitly calls for them and the script is reviewed first.

## Cosmetic Catalog Safety

`CosmeticCatalog` may reference:

- real VFX templates through `TemplateName`;
- skin entries through `SkinId`;
- config-driven visuals through `ConfigPath`.

If a referenced template is not present in source yet, set:

```lua
MissingTemplate = true
```

This prevents future audits from treating a planned cosmetic as an installed runtime template.
