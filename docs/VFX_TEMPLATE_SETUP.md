# VFX Template Setup

Этот проект теперь поддерживает два пути VFX:

- старый путь: `TextureId`, procedural parts, `SoundId`;
- новый путь: готовые Toolbox templates из `ReplicatedStorage/Shared/Assets/VFX`.

## Куда класть Toolbox VFX

Для обычных muzzle/impact effects можно сразу положить готовый asset сюда:

```text
ReplicatedStorage
└── Shared
    └── Assets
        └── VFX
	            ├── MuzzleFlashTemplate
	            ├── MuzzleBlastTemplate
	            ├── SmokeTemplate
	            ├── ImpactFlashTemplate
	            ├── ImpactSparksTemplate
	            ├── RicochetTemplate
	            ├── TankExplosionTemplate
	            └── TankBurningTemplate
```

Если папки нет в Studio, сначала синхронизируй Rojo. Если она все равно отсутствует, выполни вне Play Mode:

```text
docs/patches/CREATE_OR_REPAIR_VFX_ASSETS_FOLDER_COMMAND.lua
```

Потом вставь Toolbox asset в `ReplicatedStorage/Shared/Assets/VFX` и сделай `File -> Save to File`.

## Автосбор доноров из Workspace

Если ассеты уже вставлены из Toolbox в `Workspace`, не нужно вручную разбирать каждый объект. Выполни вне Play Mode:

```text
docs/patches/COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua
```

Скрипт ищет доноры в `Workspace` и `Workspace/WOB_EditorOnly_AssetDonors`, создает `ReplicatedStorage/Shared/Assets/VFX`, клонирует найденные эффекты, санитарит их и присваивает понятные имена:

- `Resources explosion`, `Resources Explosion`, `Explosion`, `TankExplosion`, `Tank Explosion` -> `TankExplosionTemplate`;
- `Fire Effect`, `Burning`, `TankBurning` -> `TankBurningTemplate`;
- `ImpactFlash`, `HitFlash`, `DamageHit` -> `ImpactFlashTemplate`;
- `Sparks`, `Shrapnels`, `Impact`, `NoPen`, `No Penetration` -> `ImpactSparksTemplate`;
- `Ricochet` -> `RicochetTemplate`;
- `Smoke` -> `SmokeTemplate`;
- `MuzzleFlash` -> `MuzzleFlashTemplate`;
- `MuzzleBlast`, `Fireball` -> `MuzzleBlastTemplate`.

Оригиналы-доноры не удаляются. Если донор лежал прямо в `Workspace`, скрипт переносит его в `Workspace/WOB_EditorOnly_AssetDonors`, чтобы он не мешал сцене. После успешного запуска сделай `File -> Save to File`.

## Preview templates

Чтобы сравнить эффекты глазами без Play Mode, выполни в Command Bar:

```text
docs/patches/PREVIEW_VFX_TEMPLATES_COMMAND.lua
```

Скрипт создает/обновляет `Workspace/WOB_Generated/VFXPreview`, ставит preview points для muzzle/smoke/impact/ricochet/explosion/burning, клонирует все реальные templates из `ReplicatedStorage/Shared/Assets/VFX`, вызывает `Emit()` у `ParticleEmitter`, опционально играет `Sound` и логирует:

```text
[WOB VFX PREVIEW] Previewed TankExplosionTemplate emitters=X sounds=Y
```

Preview clone также санитарится: `BasePart.CanCollide=false`, `CanTouch=false`, `CanQuery=false`.

## Tank death explosion из Toolbox

Toolbox asset сначала появляется в `Workspace`, потому что Roblox Studio вставляет выбранные модели в текущую сцену. `Workspace` удобен как временное место, но не как склад ассетов: runtime-эффекты создаются и удаляются в `Workspace/WOB_Generated/Runtime/VFX`, а лишние донорские модели могут мешать карте.

Для explosion asset используй командный script, а не ручное перетаскивание:

1. В Studio вставь explosion VFX из Toolbox в `Workspace`.
2. Убедись, что объект называется одним из вариантов:
   `Resources explosion`, `Resources Explosion`, `Explosion`, `TankExplosion`, `Tank Explosion`.
3. В Command Bar вне Play Mode выполни:

```text
docs/patches/INSTALL_TANK_EXPLOSION_VFX_TEMPLATE_COMMAND.lua
```

После выполнения template будет лежать здесь:

```text
ReplicatedStorage/Shared/Assets/VFX/TankExplosionTemplate
```

Script клонирует source asset, заменяет старый `TankExplosionTemplate`, выключает `ParticleEmitter.Enabled`, делает все `BasePart` non-colliding/non-querying и удаляет скрипты из clone. Оригинал в `Workspace` не удаляется.

Подключение происходит через:

```lua
	DeathExplosion = table.freeze({
		Enabled = true,
		TemplateName = "TankExplosionTemplate",
		TemplateLifetime = 4,
		TemplateEmitCount = 28,
		SoundVolume = 0.9,
		UseProceduralFallback = true,
	})
```

Когда танк умирает, сервер клонирует `TankExplosionTemplate`, ставит его в позицию `Body` или `PrimaryPart`, вызывает `Emit()` у всех `ParticleEmitter`, играет все `Sound`, оставляет lights на время жизни clone и удаляет clone через `Debris`.

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

Можно использовать `Model`, `Part`, `Folder`, `Attachment`, `ParticleEmitter`, `Sound`, `PointLight`, `SpotLight`, `SurfaceLight`, `Beam`, `Trail` или template, внутри которого есть эти объекты.

`Script`, `LocalScript` и `ModuleScript` из Toolbox удаляются из installed template clone. Это важно: Toolbox scripts могут запускать чужую логику, спамить Output, менять сцену или конфликтовать с серверным VFX flow. В этом проекте template должен быть только визуальным/звуковым ассетом.

`TemplateName` — это не asset id. Правильно:

```lua
TemplateName = "RicochetTemplate"
TextureId = "rbxassetid://1038411245"
SoundId = "rbxassetid://139771888058836"
```

Неправильно:

```lua
TemplateName = "37194537"
```

Если у тебя есть только id картинки частицы, оставь `TemplateName = ""` и положи id в `TextureId`. Если есть id звука, используй `SoundId`.

## Что делает runtime

Когда указан `TemplateName`:

- сервер ищет template в `ReplicatedStorage/Shared/Assets/VFX`;
- клонирует его в `Workspace/WOB_Generated/Runtime/VFX`;
- ставит clone в точку выстрела или попадания;
- вызывает `Emit()` у всех `ParticleEmitter`;
- вызывает `Play()` у всех `Sound`;
- оставляет `Light` жить на время `TemplateLifetime`;
- удаляет clone через `Debris`.

Если template не найден, игра не падает. Для обязательных/важных templates будет один warn по имени template, затем fallback. Для optional templates с `WarnIfMissingTemplate=false` warning не будет.

Для optional templates вроде `TankBurningTemplate` и `RicochetTemplate` warn отключен, потому что эти ассеты могут появиться позже. Если template отсутствует, игра просто использует fallback или пропускает optional эффект.

## TextureId и SoundId

`TextureId` можно оставить пустым, если template содержит готовые `ParticleEmitter`.

`TextureId` можно оставить заполненным как fallback. Тогда при пустом или плохом `TemplateName` будет работать старый particle/procedural эффект.

`Shot.SoundId` остается отдельным звуком выстрела через `CombatVfxService.playConfiguredSound`. Если твой template уже содержит звук выстрела и получается дубль, очисти `Shot.SoundId = ""`.

## Почему Workspace не склад ассетов

Не храни VFX templates в `Workspace`. Runtime чистит `Workspace/WOB_Generated/Runtime/VFX`, а рабочие эффекты могут быть удалены `Debris`.

Храни исходные templates в `ReplicatedStorage/Shared/Assets/VFX`: это стабильная replicated asset-папка, которую runtime только читает и клонирует.

## Что можно удалить после теста

Можно удалять неудачные template assets из `ReplicatedStorage/Shared/Assets/VFX`, если они не указаны в `VfxConfig.TemplateName`.

Нельзя удалять саму папку `VFX`, `VfxTemplateCatalog` или `.gitkeep`: они держат Rojo path понятным и видимым.

## Burning, Ricochet, Impact, Muzzle

Для burning after death:

```lua
BurningTank = table.freeze({
	Enabled = true,
	TemplateName = "TankBurningTemplate",
	TemplateLifetime = 6,
	TemplateEmitCount = 8,
})
```

Если `TankBurningTemplate` есть, после смерти появится burning aftermath на несколько секунд. Если template отсутствует, warning не будет и death explosion продолжит работать.

Для рикошетов используется:

```lua
Ricochet = table.freeze({
	Enabled = true,
	TemplateName = "RicochetTemplate",
	TemplateLifetime = 0.75,
	TemplateEmitCount = 14,
	UseImpactFallback = true,
})
```

Если `RicochetTemplate` есть, он играет при bounce от стены и armor ricochet. Если его нет, используется impact/sparks fallback.

Для muzzle можно включать templates в `VfxConfig.Shot.MuzzleFlash`, `MuzzleBlast`, `Smoke`.

Для impact slots используется отдельная группа:

```lua
Impact = table.freeze({
	WallImpact = table.freeze({
		TemplateName = "ImpactSparksTemplate",
	}),
	DamageHit = table.freeze({
		TemplateName = "ImpactFlashTemplate",
	}),
	NoPen = table.freeze({
		TemplateName = "ImpactSparksTemplate",
	}),
	SelfHit = table.freeze({
		TemplateName = "ImpactFlashTemplate",
	}),
})
```

`WallImpact` играет при попадании в карту, `DamageHit` после пробития брони, `NoPen` после непробития, `SelfHit` при собственном рикошете. Пока template отсутствует, работают procedural/TextureId fallback effects.

## Как проверить template

В Studio открой:

```text
ReplicatedStorage/Shared/Assets/VFX
```

Проверь, что нужный объект существует, например `TankExplosionTemplate` или `TankBurningTemplate`. Внутри допустимы `ParticleEmitter`, `Sound`, `PointLight`, `SpotLight`, `SurfaceLight`, `Beam`, `Trail`, `Attachment`, `Part`, `Model`, `Folder`. У `ParticleEmitter` должно быть `Enabled = false`; у `BasePart` должны быть `CanCollide = false`, `CanTouch = false`, `CanQuery = false`.

## Как тюнить значения

`TemplateEmitCount` задает базовый `Emit()` count для всех `ParticleEmitter` в template, если у emitter нет своего attribute `EmitCount`.

`TemplateLifetime` задает, сколько clone живет в `Workspace/WOB_Generated/Runtime/VFX` перед cleanup через `Debris`. Ориентиры:

- muzzle: `0.05`-`0.2`;
- smoke: `0.4`-`1.2`;
- impact/no-pen: `0.3`-`0.8`;
- ricochet: `0.4`-`0.9`;
- death explosion: `3`-`4`;
- burning tank: `4`-`6`.

`SoundVolume` задает громкость template sounds и configured `SoundId`. Пустой `SoundId` валиден. Ошибки проигрывания звука throttled и не ломают gameplay.

Для проверки collision/query открой preview clone или template в Studio и проверь каждый `BasePart`: `CanCollide=false`, `CanTouch=false`, `CanQuery=false`. Collector и preview script выставляют эти flags автоматически, но ручная проверка полезна после импорта из Toolbox.
