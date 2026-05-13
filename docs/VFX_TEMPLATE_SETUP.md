# VFX Template Setup

Этот проект теперь поддерживает два пути VFX:

- старый путь: `TextureId`, procedural parts, `SoundId`;
- новый путь: готовые Toolbox templates из `ReplicatedStorage/Shared/Assets/VFX`.

## Куда класть Toolbox VFX

В Roblox Studio положи готовый asset сюда:

```text
ReplicatedStorage
└── Shared
    └── Assets
        └── VFX
            ├── MuzzleFlashTemplate
            ├── MuzzleBlastTemplate
            ├── SmokeTemplate
            ├── ImpactFlashTemplate
            └── ImpactSparksTemplate
```

Если папки нет в Studio, сначала синхронизируй Rojo. Если она все равно отсутствует, выполни вне Play Mode:

```text
docs/patches/CREATE_OR_REPAIR_VFX_ASSETS_FOLDER_COMMAND.lua
```

Потом вставь Toolbox asset в `ReplicatedStorage/Shared/Assets/VFX` и сделай `File -> Save to File`.

## Как назвать template

Имя объекта в Studio должно точно совпадать со строкой в `VfxConfig`.

Пример:

```lua
MuzzleFlash = table.freeze({
	Enabled = true,
	TemplateName = "MuzzleFlashTemplate",
	TemplateLifetime = 0.35,
	TemplateEmitCount = 10,
	TextureId = "",
	UseProceduralFallback = true,
})
```

Можно использовать `Model`, `Part`, `Folder`, `Attachment`, `ParticleEmitter`, `Sound` или template, внутри которого есть эти объекты.

## Что делает runtime

Когда указан `TemplateName`:

- сервер ищет template в `ReplicatedStorage/Shared/Assets/VFX`;
- клонирует его в `Workspace/WOB_Generated/Runtime/VFX`;
- ставит clone в точку выстрела или попадания;
- вызывает `Emit()` у всех `ParticleEmitter`;
- вызывает `Play()` у всех `Sound`;
- оставляет `Light` жить на время `TemplateLifetime`;
- удаляет clone через `Debris`.

Если template не найден, игра не падает. Будет один warn по имени template, затем старый fallback.

## TextureId и SoundId

`TextureId` можно оставить пустым, если template содержит готовые `ParticleEmitter`.

`TextureId` можно оставить заполненным как fallback. Тогда при пустом или плохом `TemplateName` будет работать старый particle/procedural эффект.

`Shot.SoundId` остается отдельным звуком выстрела через `SFX_CannonShotEmitter`. Если твой template уже содержит звук выстрела и получается дубль, очисти `Shot.SoundId = ""`.

## Почему Workspace не склад ассетов

Не храни VFX templates в `Workspace`. Runtime чистит `Workspace/WOB_Generated/Runtime/VFX`, а рабочие эффекты могут быть удалены `Debris`.

Храни исходные templates в `ReplicatedStorage/Shared/Assets/VFX`: это стабильная replicated asset-папка, которую runtime только читает и клонирует.

## Что можно удалить после теста

Можно удалять неудачные template assets из `ReplicatedStorage/Shared/Assets/VFX`, если они не указаны в `VfxConfig.TemplateName`.

Нельзя удалять саму папку `VFX`, `VfxTemplateCatalog` или `.gitkeep`: они держат Rojo path понятным и видимым.
