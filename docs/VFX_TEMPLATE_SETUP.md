# VFX Template Setup

Этот проект теперь поддерживает два пути VFX:

- старый путь: `TextureId`, procedural parts, `SoundId`;
- новый путь: готовые Toolbox templates из `ReplicatedStorage/Shared/Assets/VFX`.

## Stable Fun Duel v0.1 full organizer

Для полноценного VFX organization pass используй не ручной donor flow, а Studio command script:

```text
docs/patches/ORGANIZE_ALL_VFX_ASSETS_COMMAND.lua
```

Его нужно запускать в Roblox Studio Command Bar вне Play Mode. Он проходит по `Workspace`, `Workspace.WOB_EditorOnly_AssetDonors`, `ReplicatedStorage`, `ReplicatedStorage.Shared.Assets.VFX`, `ServerStorage`, `ServerStorage.WOB_EditorOnly_AssetDonors` и `Lighting`. `MaterialService` проверяется только для отчета по `MaterialVariant`, не как самостоятельный VFX template.

Organizer ищет все `Model`/`Part`/`Folder`/`Attachment` VFX-кандидаты, внутри которых есть `ParticleEmitter`, `Sound`, `Beam`, `Trail`, lights, `Decal`, `Texture`, `MeshPart` или `SpecialMesh`. Он печатает audit по counts, texture ids, sound ids, mesh ids, `ThumbnailCamera` и подозрительным scripts (`Kick`, `HttpService`, `require(number)`, `loadstring`, `getfenv`, `setfenv`).

Установленные templates кладутся только сюда:

```text
ReplicatedStorage.Shared.Assets.VFX
```

Рабочие quarantine/backup folders создаются тут:

```text
Workspace.WOB_EditorOnly_AssetDonors.VFX_Backups
Workspace.WOB_EditorOnly_AssetDonors.VFX_Quarantine
Workspace.WOB_EditorOnly_AssetDonors.VFX_Unclassified
```

Workspace не должен оставаться финальным складом ассетов. Если organizer распознает прямой Workspace object как VFX donor, после установки он переносит исходник в `Workspace.WOB_EditorOnly_AssetDonors`. Неоднозначные gameplay-scene объекты он оставляет на месте и только логирует.

Special rule для выстрела: если старый `MuzzleEffectTemplate` выглядит как spark/impact effect и найден более чистый muzzle candidate, старый shot effect клонируется в `RicochetTemplate`, а новый muzzle ставится в `MuzzleEffectTemplate`. Старый template не удаляется: заменяемые объекты уходят в `VFX_Backups`.

Codex и `rojo build` видят только файлы в source tree. Если VFX donor вставлен в Roblox Studio и command script создал объект только в текущем DataModel, этого объекта не видно как файла в `src/ReplicatedStorage/Shared/Assets/VFX`. Поэтому после organizer обязательно сохрани установленные templates как `.rbxmx`. Optional slots могут быть подключены по имени только когда у них есть procedural/template fallback и `WarnIfMissingTemplate=false`, как в текущем v0.1 config.

## Recovery after Rojo removed Studio-only templates

Если после Rojo sync в Output появляется предупреждение вроде:

```text
[VFX] Template 'TankExplosionTemplate' for DeathExplosion was not found under ReplicatedStorage/Shared/Assets/VFX; using fallback.
```

значит template был только Studio-only объектом и не был сохранён в source tree как `.rbxmx`. `VfxTemplateCatalog.luau` не является самим эффектом; он только перечисляет реальные child objects, которые уже существуют в `ReplicatedStorage.Shared.Assets.VFX`.

Recovery workflow:

1. Stop Play Mode.
2. Run:

```text
docs/patches/RECOVER_VFX_TEMPLATES_FROM_SCENE_COMMAND.lua
```

3. Run:

```text
docs/patches/AUDIT_VFX_TEMPLATES_COMMAND.lua
```

4. Для каждого восстановленного объекта в `ReplicatedStorage.Shared.Assets.VFX` выполни `Right click -> Save to File...`.
5. Сохрани в:

```text
src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx
```

6. Добавь файлы в Git:

```bash
git add src/ReplicatedStorage/Shared/Assets/VFX/*.rbxmx
```

Command scripts не могут надёжно записать `.rbxmx` в repo сами. Ручной `Save to File...` обязателен, иначе следующий Rojo sync снова удалит Studio-only templates из managed folder.

Перед `Save to File...`, Publish или Rojo reconnect запускай audit:

```text
docs/patches/AUDIT_VFX_TEMPLATES_COMMAND.lua
```

## Rojo Connect protection

`default.project.json` configures the Studio node:

```text
ReplicatedStorage.Shared.Assets.VFX
```

with:

```json
"$ignoreUnknownInstances": true
```

This is an emergency guard for playtest/publish: Rojo will continue syncing file-backed children like `VfxTemplateCatalog.luau` and future `.rbxmx` templates from `src/ReplicatedStorage/Shared/Assets/VFX`, but it should not delete unknown Studio-installed VFX templates that already exist under `ReplicatedStorage.Shared.Assets.VFX` during Connect.

Long-term persistence is still required. Every real Studio template should be saved with `Right click -> Save to File...` into:

```text
src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx
```

Then commit those `.rbxmx` files. The ignore guard prevents accidental deletion during the current workflow; it is not a replacement for saving templates into the repo.

Текущее Studio-подключение использует уже существующие объекты в `ReplicatedStorage.Shared.Assets.VFX`. Эти строки должны совпадать с именами объектов один в один:

- `Shot.MuzzleFlash.TemplateName = "MuzzleEffectTemplate"`;
- `Shot.MuzzleBlast.TemplateName = "MuzzleFlashTemplate"`;
- `Shot.Smoke.TemplateName = "SmokeTemplate"`;
- `Impact.WallImpact.TemplateName = "ImpactSparksTemplate"`;
- `Impact.DamageHit.TemplateName = "DamageHitTemplate"` with fallback to `ImpactSparksTemplate`;
- `Impact.NoPen.TemplateName = "NoPenTemplate"` with fallback to `ImpactSparksTemplate`;
- `Impact.SelfHit.TemplateName = "SelfHitTemplate"` with fallback to `ImpactSparksTemplate`;
- `Ricochet.TemplateName = "RicochetTemplate"`;
- `DeathExplosion.TemplateName = "TankExplosionTemplate"`;
- `BurningTank.TemplateName = "TankBurningTemplate"`.

Если один из этих объектов отсутствует в `ReplicatedStorage.Shared.Assets.VFX`, runtime не должен падать: `WarnIfMissingTemplate=false` отключает Output spam для optional slots, а `UseProceduralFallback=true` оставляет базовый эффект там, где fallback предусмотрен.

## Burning template audio safety

`TankBurningTemplate` должен быть visual-only для текущего playtest. Combat audio owned by `AudioCatalog/WOBAudioController`; template sounds are muted by config:

```lua
BurningTank = table.freeze({
	PlayTemplateSounds = false,
	SoundVolume = 0,
	AllowLoopedSounds = false,
})
```

Если в Studio уже есть `ReplicatedStorage.Shared.Assets.VFX.TankBurningTemplate`, перед Publish запусти вне Play Mode:

```text
docs/patches/MUTE_BURNING_VFX_SOUNDS_COMMAND.lua
```

Скрипт не удаляет VFX template. Он ставит `Sound.Volume = 0`, `Sound.Looped = false`, `Sound.Playing = false` и удаляет donor `Script`/`LocalScript`/`ClickDetector` descendants внутри burning template.

## Stable Fun Duel v0.1 VFX Rule

Для v0.1 gameplay readability не зависит от Creator Store templates. Базовая игра должна выглядеть нормально, даже если `ReplicatedStorage/Shared/Assets/VFX` пустой и там есть только `.gitkeep`/`VfxTemplateCatalog`.

Обязательные fallback paths:

- shot sound and bright projectile trail;
- muzzle flash/blast/smoke from config values;
- wall impact, ricochet, damage, no-pen, and self-hit procedural flashes/sparks;
- procedural death explosion if `TankExplosionTemplate` is absent.

Store templates можно подключать позже как усиление, но не как обязательный gameplay dependency.

## Куда класть Toolbox VFX

Для обычных muzzle/impact effects можно сразу положить готовый asset сюда:

```text
ReplicatedStorage
└── Shared
    └── Assets
        └── VFX
            ├── MuzzleFlashTemplate
            ├── MuzzleEffectTemplate
            ├── SmokeTemplate
            ├── ImpactSparksTemplate
            ├── RicochetTemplate
            ├── TankExplosionTemplate
            └── TankBurningTemplate
```

Если папки нет в Studio, сначала синхронизируй Rojo. Если она все равно отсутствует, выполни вне Play Mode:

```text
docs/patches/CREATE_OR_REPAIR_VFX_ASSETS_FOLDER_COMMAND.lua
```

Можно вставить Toolbox asset напрямую в `ReplicatedStorage/Shared/Assets/VFX`, но для donor workflow обычно проще вставить asset в `Workspace`, затем запустить collector ниже. После Studio-side установки проверь, что объект реально появился под `ReplicatedStorage/Shared/Assets/VFX`.

## Автосбор доноров из Workspace (legacy narrow collector)

Для Stable Fun Duel v0.1 full pass используй `ORGANIZE_ALL_VFX_ASSETS_COMMAND.lua`. Старый collector ниже оставлен как узкая helper-команда для известных donor names. Если ассеты уже вставлены из Toolbox в `Workspace`, можно выполнить вне Play Mode:

```text
docs/patches/COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua
```

Скрипт ищет реальные доноры в `Workspace` и `Workspace/WOB_EditorOnly_AssetDonors`, создает `ReplicatedStorage/Shared/Assets/VFX`, клонирует только найденные эффекты, санитарит их и присваивает понятные имена:

- `Resources explosion`, `Resources Explosion`, `Explosion` -> `TankExplosionTemplate`;
- `Burning`, `Fire`, `TankBurning`, `Tank Burning`, `Fire Effect` -> `TankBurningTemplate`;
- `Impact`, `Sparks` -> `ImpactSparksTemplate`;
- `Ricochet` -> `RicochetTemplate`;
- `Smoke` -> `SmokeTemplate`;
- `MuzzleFlash`, `Muzzle Flash` -> `MuzzleFlashTemplate`;
- `MuzzleBlast`, `Muzzle Blast` -> `MuzzleBlastTemplate`.

Collector не создает пустые fake templates и не редактирует `VfxConfig`. Он логирует existing templates, found donors, skipped missing donors, installed templates и final templates list. Оригиналы-доноры не удаляются; если donor находится в gameplay `Workspace`, скрипт переносит его в `Workspace/WOB_EditorOnly_AssetDonors`, чтобы он не мешал сцене.

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
		TemplateLifetime = 1,
		TemplateEmitCount = 28,
		PlayTemplateSounds = false,
		SoundVolume = 0,
		UseProceduralFallback = true,
	})
```

Когда танк умирает, сервер клонирует `TankExplosionTemplate`, ставит его в позицию `Body` или `PrimaryPart`, вызывает `Emit()` у всех `ParticleEmitter`, гасит template sounds unless `PlayTemplateSounds=true`, оставляет lights на время жизни clone и удаляет clone через `Debris`.

## Как назвать template

Имя объекта в Studio должно точно совпадать со строкой в `VfxConfig`. Если такого объекта нет, оставь `TemplateName = ""` и используй `TextureId`/procedural fallback.

Пример:

```lua
MuzzleFlash = table.freeze({
	Enabled = true,
	TemplateName = "",
	TemplateLifetime = 0.35,
	TemplateEmitCount = 10,
	TextureId = "rbxassetid://243660364",
	UseProceduralFallback = true,
})
```

После того как collector реально установил `ReplicatedStorage/Shared/Assets/VFX/MuzzleFlashTemplate`, можно включить template:

```lua
TemplateName = "MuzzleFlashTemplate"
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
- удаляет donor `Script`/`LocalScript`/`ClickDetector` из runtime clone;
- ставит clone в точку выстрела или попадания;
- вызывает `Emit()` у всех `ParticleEmitter`;
- вызывает `Play()` у template `Sound` только если config explicitly has `PlayTemplateSounds=true`;
- оставляет `Light` жить на время `TemplateLifetime`;
- удаляет clone через `Debris`.

Если template не найден, игра не падает. Для обязательных/важных templates будет один warn по имени template, затем fallback. Для optional templates с `WarnIfMissingTemplate=false` warning не будет.

Для optional templates вроде `TankBurningTemplate` и `RicochetTemplate` warn отключен, потому что эти ассеты могут появиться позже. Если template отсутствует, игра просто использует fallback или пропускает optional эффект.

## TextureId и SoundId

`TextureId` можно оставить пустым, если template содержит готовые `ParticleEmitter`.

`TextureId` можно оставить заполненным как fallback. Тогда при пустом или плохом `TemplateName` будет работать старый particle/procedural эффект.

Звук выстрела сейчас живет в `AudioCatalog/WOBAudioController`, а не в VFX template. Рабочий default:

```lua
DefaultCannonShot.SoundId = "rbxassetid://139771888058836"
```

Если звук выстрела пропал, сначала проверь `src/ReplicatedStorage/Shared/Configs/AudioCatalog.luau` и `WOBAudioController.client.luau`. VFX templates should remain visual-only unless a future audio pass explicitly opts in.

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
	WallImpact = table.freeze({ TemplateName = "ImpactSparksTemplate" }),
	DamageHit = table.freeze({ TemplateName = "ImpactSparksTemplate" }),
	NoPen = table.freeze({ TemplateName = "ImpactSparksTemplate" }),
	SelfHit = table.freeze({ TemplateName = "ImpactSparksTemplate" }),
})
```

`WallImpact` играет при попадании в карту, `DamageHit` после пробития брони, `NoPen` после непробития, `SelfHit` при собственном рикошете. Эти slots могут использовать один общий `ImpactSparksTemplate`, если он реально существует в `ReplicatedStorage.Shared.Assets.VFX`. Если template отсутствует, должны работать procedural/TextureId fallback effects.

Если projectile стал слишком маленьким сверху, проверь `VfxConfig.Shot.Projectile`: `Size` должен быть примерно `1.1`-`1.35`, `LightBrightness` около `2.4`, `TrailLifetime` около `0.18`, `TrailWidthStart` около `1.1`-`1.6`.

Для v0.1 current baseline:

```lua
Shot = {
	SoundId = "rbxassetid://139771888058836",
	Projectile = {
		Size = 1.2,
		LightBrightness = 2.4,
		LightRange = 10,
		TrailLifetime = 0.18,
		TrailWidthStart = 1.35,
		TrailWidthMid = 0.7,
	},
}
```

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
- death explosion: `1`-`1.5` for playtest readability without lingering runtime load;
- burning tank: `4`-`6`.

`SoundVolume` применяется только если template sounds explicitly enabled. Current playtest default is visual-only VFX: `PlayTemplateSounds=false`, so looped/fire sounds must stay muted.

Для проверки collision/query открой preview clone или template в Studio и проверь каждый `BasePart`: `CanCollide=false`, `CanTouch=false`, `CanQuery=false`. Collector и preview script выставляют эти flags автоматически, но ручная проверка полезна после импорта из Toolbox.
