# World of Balance: Ricochet Tanks - Project Audit

Дата аудита: 2026-05-06.

## Scope and Source of Truth

Аудит обновлен после анализа snapshot-файлов из `docs/studio_scripts_snapshot/`.

Прочитанные документы и файлы:

- `docs/GDD.md`
- `docs/TECH_CONTEXT.md`
- `docs/CODEX_TASKS.md`
- `docs/PROJECT_AUDIT.md`
- `docs/studio_scripts_snapshot/README.md`
- `docs/studio_scripts_snapshot/WOBGameplayServer.server.luau`
- `docs/studio_scripts_snapshot/WOBClientController.client.luau`
- `docs/studio_scripts_snapshot/WOBHudController.client.luau`
- `docs/studio_scripts_snapshot/WOBDummyRespawnServer.luau`
- `docs/studio_scripts_snapshot/WOBPerformanceServer.luau`
- `docs/studio_scripts_snapshot/WOBProjectileVisualEnhancer.luau`

Ограничения аудита:

- `.rbxl` не изменялся.
- Gameplay-код не менялся.
- Скрипты не переносились в `src/`.
- `default.project.json` не менялся.
- Snapshot содержит все шесть ключевых Studio-скриптов, перечисленных в `docs/studio_scripts_snapshot/README.md`.
- Три новых snapshot-файла сохранены с именами без `.server.luau` суффикса: `WOBDummyRespawnServer.luau`, `WOBPerformanceServer.luau`, `WOBProjectileVisualEnhancer.luau`. По содержимому это серверные скрипты из `ServerScriptService/Services`.

## Rojo Context

`default.project.json` маппит только три зоны:

- `src/ReplicatedStorage/Shared` -> `ReplicatedStorage.Shared`
- `src/ServerScriptService/Server` -> `ServerScriptService.Server`
- `src/StarterPlayer/StarterPlayerScripts/Client` -> `StarterPlayer.StarterPlayerScripts.Client`

Текущая Rojo-часть все еще минимальная:

```text
src/
  ReplicatedStorage/
    Shared/
  ServerScriptService/
    Server/
      ServerHello.server.luau
  StarterPlayer/
    StarterPlayerScripts/
      Client/
        ClientHello.client.luau
```

Основная gameplay logic сейчас находится в Studio-сцене и представлена в `docs/studio_scripts_snapshot/` только как read-only копия для анализа.

## Current Prototype Architecture

Фактическая архитектура прототипа:

- серверная авторитетная логика движения танка и снарядов находится в `WOBGameplayServer`;
- клиент отправляет input и aim через RemoteEvents из `WOBClientController`;
- HUD читает здоровье dummy через replicated Attribute `DummyTank.Health`;
- HUD отправляет reset request через `ResetDummyRequestEvent`, серверный обработчик находится в `WOBDummyRespawnServer`;
- временные снаряды и VFX создаются сервером в `Workspace.WOB_Generated.Runtime`;
- projectile trail добавляется отдельным серверным enhancer-скриптом;
- lighting/shadow performance profile применяется отдельным серверным performance-скриптом;
- модели танков ожидаются в `Workspace.WOB_Generated.TestObjects`;
- конфиги не вынесены: числа и имена объектов зашиты прямо в Studio-скрипты.

Ключевая структура, которую используют snapshot-скрипты:

```text
ReplicatedStorage/
  Remotes/
    TankInputEvent
    ShootRequestEvent
    ResetDummyRequestEvent

Workspace/
  WOB_Generated/
    Runtime/
      Projectiles
      VFX
    TestObjects/
      PlayerTankPrototype/
        Body
        Turret
        Barrel
        ShootPoint
        Hitboxes/
          FrontArmor
          RearArmor
          LeftArmor
          RightArmor
      DummyTank/
        Body
        Hitboxes

StarterGui/
  HUD/
    WOBHudController
    MainPanel/
      DummyHpLabel
      DummyHpBack/
        DummyHpFill
      ReloadLabel
      ReloadBack/
        ReloadFill
    FeedbackLabel
```

## Studio Service Roles

| Studio script | Роль | Уровень риска |
| --- | --- | --- |
| `WOBGameplayServer` | Core gameplay: tank state, shooting, projectiles, damage, VFX flashes | High |
| `WOBDummyRespawnServer` | Dummy health reset, delayed respawn, color restore | Medium |
| `WOBPerformanceServer` | Lighting profile, disabled shadows for generated parts and characters | Low/Medium |
| `WOBProjectileVisualEnhancer` | Adds Trail objects to projectile parts | Low, если остается purely visual |
| `WOBClientController` | Input, camera, aim projection, fire request | Medium/High |
| `WOBHudController` | Dummy HP UI, reload UI, feedback, reset request | Medium |

## Filesystem Scripts in src

### `src/ServerScriptService/Server/ServerHello.server.luau`

- Тип: Server Script.
- Что делает: выводит `"[SERVER] Rojo connected. Hello from Rider!"`.
- Механики: нет.
- Статус: Review.
- Комментарий: временный smoke-test Rojo. Не удалять без отдельной задачи.

### `src/StarterPlayer/StarterPlayerScripts/Client/ClientHello.client.luau`

- Тип: Client Script.
- Что делает: выводит `"[CLIENT] Rojo connected. Hello from Rider!"`.
- Механики: нет.
- Статус: Review.
- Комментарий: временный smoke-test Rojo. Не удалять без отдельной задачи.

## Studio Script Snapshot Inventory

### `WOBGameplayServer.server.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBGameplayServer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBGameplayServer.server.luau`.
- Размер: 451 строка.
- Статус: Refactor later.

Что делает:

- выбирает первого подключенного игрока как `controllingPlayer`;
- скрывает стандартного Roblox-персонажа игрока;
- принимает `TankInputEvent` и `ShootRequestEvent`;
- хранит серверное состояние танка игрока: позиция, yaw корпуса, yaw башни;
- двигает корпус танка на сервере;
- наводит башню на aim position от клиента;
- вручную раскладывает `Body`, `Turret`, `Barrel`, `ShootPoint` и armor hitboxes;
- создает runtime-папки `Projectiles` и `VFX`;
- создает видимые снаряды;
- двигает снаряды через server Heartbeat;
- использует raycast для столкновений;
- отражает направление снаряда от нормали поверхности;
- ограничивает рикошеты через `PROJECTILE_MAX_BOUNCES = 3`;
- уменьшает damage после каждого рикошета через `PROJECTILE_DAMAGE_MULTIPLIER = 0.75`;
- наносит урон только `DummyTank`;
- хранит здоровье dummy в Attribute `Health`;
- при смерти dummy красит все BasePart в темный цвет;
- создает muzzle flash, impact flash и sparks.

Механики внутри:

- player assignment;
- server-authoritative tank movement;
- independent turret aiming;
- shooting cooldown;
- projectile spawning;
- projectile movement;
- projectile raycast collision;
- wall/object ricochet;
- max bounce limit;
- damage falloff after bounce;
- dummy damage;
- dummy death visual state;
- projectile and impact VFX;
- runtime cleanup через `Debris` и ручное удаление projectile parts.

Важные замечания:

- Self-hit сейчас не реализован: raycast исключает `playerTank`, поэтому снаряд не может попасть в стрелявшего.
- Урон по углу не реализован: armor hitboxes раскладываются, но не используются для angle damage.
- Player health не реализован в этом snapshot.
- Victory/defeat не реализованы как match state.
- Серверный код сильно зависит от конкретных имен объектов.

### `WOBClientController.client.luau`

- Оригинальный путь: `StarterPlayer/StarterPlayerScripts/WOBClientController`.
- Тип: Client Script / LocalScript.
- Snapshot: `docs/studio_scripts_snapshot/WOBClientController.client.luau`.
- Размер: 134 строки.
- Статус: Keep / Refactor later.

Что делает:

- читает `W`, `A`, `S`, `D`;
- считает throttle и steer;
- считает позицию мыши на плоскости `Y = 0`;
- держит камеру строго сверху над `PlayerTankPrototype.Body`;
- выставляет `CameraType = Scriptable`;
- отправляет `TankInputEvent` на сервер каждые `0.05` секунды;
- отправляет `ShootRequestEvent` при клике мыши.

Механики внутри:

- keyboard input;
- mouse aim;
- top-down camera;
- client-to-server input stream;
- client-to-server fire request.

Важные замечания:

- Клиент не двигает танк напрямую, только отправляет намерение на сервер.
- Камера жестко привязана к `PlayerTankPrototype.Body`.
- Расчет aim зависит от плоскости `Y = 0`, что важно не ломать при изменении высот арены.
- Constants камеры и input interval зашиты в скрипт.

### `WOBHudController.client.luau`

- Оригинальный путь: `StarterGui/HUD/WOBHudController`.
- Тип: Client Script / LocalScript.
- Snapshot: `docs/studio_scripts_snapshot/WOBHudController.client.luau`.
- Размер: 102 строки.
- Статус: Keep / Safe extraction candidate for formatting only.

Что делает:

- находит `DummyTank`;
- читает `DummyTank:GetAttribute("Health")`;
- подписывается на `DummyTank:GetAttributeChangedSignal("Health")`;
- обновляет label и fill здоровья dummy;
- показывает feedback при попадании, уничтожении и reset;
- локально показывает reload progress после клика мыши;
- по клавише `R` отправляет `ResetDummyRequestEvent`;
- плавно скрывает `FeedbackLabel`.

Механики внутри:

- dummy health UI;
- reload UI;
- hit feedback;
- target destroyed feedback;
- target reset feedback;
- reset request input.

Важные замечания:

- Reload UI не подтверждает серверный cooldown, а считает прогресс локально от момента клика.
- HUD напрямую зависит от точных имен UI-элементов.
- Reset request есть на клиенте, server handler подтвержден в `WOBDummyRespawnServer`.
- Player health UI отсутствует.

### `WOBDummyRespawnServer.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBDummyRespawnServer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBDummyRespawnServer.luau`.
- Размер: 71 строка.
- Статус: Keep / Refactor later.

Что делает:

- находит `ReplicatedStorage.Remotes.ResetDummyRequestEvent`;
- находит `Workspace.WOB_Generated.TestObjects.DummyTank`;
- хранит `MAX_HEALTH = 100` и `RESPAWN_DELAY = 2.25`;
- восстанавливает `DummyTank.Health` до `100`;
- восстанавливает цвета частей dummy по именам `Body`, `Turret`, `Barrel`, `ShootPoint`, `FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor`;
- подписывается на изменение Attribute `Health`;
- если здоровье dummy `<= 0`, запускает отложенный respawn;
- принимает reset request от клиента и сразу вызывает reset.

Зависимости:

- `ReplicatedStorage.Remotes.ResetDummyRequestEvent`;
- `Workspace.WOB_Generated.TestObjects.DummyTank`;
- Attribute `DummyTank.Health`;
- точные имена деталей dummy и armor hitboxes.

Риск конфликта с `WOBGameplayServer`:

- оба скрипта пишут/читают `DummyTank.Health`;
- `WOBGameplayServer` при смерти красит все BasePart dummy в темный цвет, а `WOBDummyRespawnServer` восстанавливает цвета;
- если изменить max health в одном месте и не изменить в другом, HUD/damage/respawn начнут расходиться;
- reset может сработать во время активного projectile update, но текущий код не удаляет снаряды и не сбрасывает combat state.

Безопасно выносить позже:

- `MAX_HEALTH`;
- `RESPAWN_DELAY`;
- таблицу цветов dummy parts;
- helper `setPartColor`.

### `WOBPerformanceServer.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBPerformanceServer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBPerformanceServer.luau`.
- Размер: 57 строк.
- Статус: Keep / Safe extraction candidate for constants.

Что делает:

- применяет lighting profile: `GlobalShadows = false`, `Brightness = 2`, `ClockTime = 14`, `FogEnd = 100000`;
- пытается выставить `Lighting.Technology = Enum.Technology.Compatibility` через `pcall`;
- отключает `CastShadow` у всех BasePart внутри `Workspace.WOB_Generated`;
- отключает `CastShadow` у новых descendants внутри `Workspace.WOB_Generated`;
- отключает `CastShadow` у character parts существующих и новых игроков.

Зависимости:

- `Workspace.WOB_Generated`;
- `Lighting`;
- `Players`;
- `BasePart.CastShadow`.

Риск конфликта с `WOBGameplayServer`:

- низкий для gameplay: скрипт не меняет урон, движение, снаряды или remotes;
- средний для визуала: любые новые parts, созданные gameplay/VFX, автоматически получают `CastShadow = false`;
- может перезаписать художественные настройки Lighting, если позже появится отдельный визуальный pipeline.

Безопасно выносить позже:

- lighting constants;
- helper `optimizePart`;
- список performance defaults.

### `WOBProjectileVisualEnhancer.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBProjectileVisualEnhancer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBProjectileVisualEnhancer.luau`.
- Размер: 45 строк.
- Статус: Keep / Safe extraction candidate for visual config.

Что делает:

- находит `Workspace.WOB_Generated.Runtime.Projectiles`;
- добавляет к каждому projectile BasePart два Attachment;
- создает `Trail` с именем `WOBTrail`;
- задает trail lifetime, min length, light emission, color и transparency;
- обрабатывает уже существующие projectile children;
- подписывается на `projectileFolder.ChildAdded` и добавляет trail новым projectile parts.

Зависимости:

- `Workspace.WOB_Generated.Runtime.Projectiles`;
- projectile должен быть `BasePart`;
- child name `WOBTrail`;
- attachment names `TrailAttachment0`, `TrailAttachment1`.

Риск конфликта с `WOBGameplayServer`:

- низкий для gameplay: скрипт не меняет projectile position, damage, direction, raycast или lifetime;
- возможный конфликт по lifecycle: `WOBGameplayServer` уничтожает projectile Part, а enhancer добавляет children к этому Part;
- если `WOBGameplayServer` изменит тип projectile object не на BasePart, enhancer перестанет работать;
- если visual children начнут попадать в raycast, это может быть риск, но сейчас raycast исключает `projectileFolder`, так что trail attachments внутри projectileFolder не должны мешать collision.

Безопасно выносить позже:

- trail visual constants;
- helper `addTrail`;
- attachment offsets;
- color/transparency sequences.

## Systems Already Implemented

### Gameplay loop

- Статус: Partially implemented.
- Где: `WOBGameplayServer`.
- Реально есть: server Heartbeat вызывает `updateTank` и `updateProjectiles`.
- Нет: полноценного match state, victory/defeat, player death, round restart.

### Tank control

- Статус: Implemented for one local/controller player.
- Где: `WOBClientController` + `WOBGameplayServer`.
- Реально есть: `WASD` на клиенте, серверный throttle/steer, clamp позиции в пределах `-58..58`.
- Ограничение: только один `controllingPlayer`; нет PvP.

### Turret aiming

- Статус: Implemented.
- Где: client отправляет `AimPosition`, server считает `TurretYaw` и раскладывает turret/barrel/shootpoint.
- Ограничение: нет ограниченной скорости поворота башни; башня мгновенно смотрит на aim direction.

### Projectile handling

- Статус: Implemented for MVP dummy target.
- Где: `WOBGameplayServer`.
- Реально есть: spawn, movement, raycast, lifetime, destroy, ricochet, max bounces, damage falloff.
- Ограничение: нет self-hit, нет player damage, нет angle damage.

### UI update flow

- Статус: Partially implemented.
- Где: `WOBHudController`.
- Реально есть: dummy HP, reload display, hit/destroyed/reset feedback.
- Ограничение: UI читает `DummyTank.Health` напрямую через replicated Attribute; нет player HP и полноценного result UI.

### Respawn / reset

- Статус: Partially implemented.
- Где: `WOBHudController` отправляет `ResetDummyRequestEvent`, `WOBDummyRespawnServer` обрабатывает reset и delayed respawn.
- Реально есть: reset dummy health, restore part colors, auto-respawn через `task.delay(2.25)` после `Health <= 0`.
- Ограничение: это reset dummy, а не полноценный restart матча; player state, projectiles и runtime state не сбрасываются.

### Runtime objects

- Статус: Implemented.
- Где: `WOBGameplayServer` создает `Runtime/Projectiles` и `Runtime/VFX`; `WOBProjectileVisualEnhancer` подписывается на `Runtime/Projectiles`; `WOBPerformanceServer` оптимизирует generated descendants.
- Ограничение: cleanup runtime-снарядов есть в `WOBGameplayServer`, но полного reset runtime state нет.

### Visual enhancer / VFX

- Статус: Implemented for prototype readability.
- Где: `WOBGameplayServer` создает muzzle flash, impact flash и sparks; `WOBProjectileVisualEnhancer` добавляет projectile trails.
- Ограничение: визуальные параметры зашиты в серверные скрипты, отдельного visual config нет.

### Performance profile

- Статус: Implemented.
- Где: `WOBPerformanceServer`.
- Реально есть: disabled shadows, simple lighting profile, optimization for generated parts and characters.
- Ограничение: это глобально меняет Lighting и может конфликтовать с будущей визуальной задачей.

## Likely Monolith Zones

### Main monolith: `WOBGameplayServer`

Это главный монолит текущего прототипа.

Смешанные ответственности:

- поиск сервисов и объектов сцены;
- создание runtime folders;
- выбор controlling player;
- скрытие стандартного character;
- хранение состояния танка;
- движение танка;
- наведение башни;
- ручная раскладка модели танка;
- управление hitboxes;
- обработка remotes;
- shooting cooldown;
- создание снаряда;
- движение снаряда;
- raycast collision;
- ricochet math;
- damage model;
- dummy death;
- projectile VFX;
- cleanup.

Что опасно менять:

- object paths: `Workspace.WOB_Generated`, `Runtime`, `TestObjects`, `PlayerTankPrototype`, `DummyTank`;
- part names: `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`;
- remote names: `TankInputEvent`, `ShootRequestEvent`;
- physics assumptions: anchored parts, `Y = 0`, clamp bounds `-58..58`;
- raycast filter, особенно исключение `playerTank`;
- bounce order and damage multiplier;
- Attribute `DummyTank.Health`;
- `PROJECTILE_MAX_BOUNCES = 3` behavior.

### Secondary coupling: `WOBClientController`

Это не большой монолит по размеру, но сильная точка связанности input/camera/model/remotes.

Смешанные ответственности:

- input;
- aim projection;
- top-down camera;
- network send interval;
- fire request.

Что опасно менять:

- camera math;
- mouse projection to ground plane;
- path to `PlayerTankPrototype.Body`;
- input send interval;
- fire request timing.

### UI coupling: `WOBHudController`

Компактный, но связан с точными UI names и state source.

Смешанные ответственности:

- чтение replicated gameplay state;
- formatting;
- progress bar layout;
- feedback timing;
- reset input.

Что опасно менять:

- имена `DummyHpLabel`, `DummyHpBack`, `DummyHpFill`, `ReloadLabel`, `ReloadBack`, `ReloadFill`, `FeedbackLabel`;
- `DummyTank.Health` contract;
- `ResetDummyRequestEvent`;
- локальную reload логику, пока server cooldown не реплицируется явно.

## Client/Server/HUD Dependencies

### Client -> Server

- `WOBClientController` отправляет `TankInputEvent` каждые `0.05` секунды.
- Payload: `Throttle`, `Steer`, `AimPosition`.
- `WOBClientController` отправляет `ShootRequestEvent` при MouseButton1.
- Payload: `AimPosition`.

### Server -> World State

- `WOBGameplayServer` пишет CFrame частей `PlayerTankPrototype`.
- `WOBGameplayServer` создает projectile parts в `Runtime/Projectiles`.
- `WOBGameplayServer` создает VFX parts в `Runtime/VFX`.
- `WOBGameplayServer` пишет `DummyTank.Health` Attribute.
- `WOBGameplayServer` красит BaseParts dummy при `Health <= 0`.
- `WOBDummyRespawnServer` пишет `DummyTank.Health` и восстанавливает цвета dummy parts.
- `WOBPerformanceServer` меняет Lighting и отключает shadows у generated parts.
- `WOBProjectileVisualEnhancer` добавляет trail children к projectile parts.

### World State -> HUD

- `WOBHudController` читает `DummyTank.Health`.
- `WOBHudController` обновляется через `GetAttributeChangedSignal("Health")`.
- `WOBHudController` показывает feedback на основе изменения здоровья.

### HUD -> Server

- `WOBHudController` отправляет `ResetDummyRequestEvent` по клавише `R`.
- `WOBDummyRespawnServer` принимает `ResetDummyRequestEvent` и вызывает reset dummy.

### Shared constants duplicated

Одни и те же или связанные значения зашиты в разных скриптах:

- `SHOOT_COOLDOWN = 0.45` есть и на сервере, и в HUD.
- `MAX_DUMMY_HEALTH = 100`, `MAX_HEALTH = 100` и default `100` для damage logic дублируют одно значение в разных скриптах.
- `RESPAWN_DELAY = 2.25` зашит в respawn server.
- lighting и trail constants зашиты в отдельных server scripts.
- object names и UI names зашиты строками в скриптах.

## Updated Mechanics Matrix

| Механика | Статус | Основание |
| --- | --- | --- |
| Арена | Implemented | Скрипты работают с `Workspace.WOB_Generated`; столкновения идут через raycast по world geometry. Качество карты требует Play-проверки. |
| Танк игрока | Implemented | `PlayerTankPrototype` используется сервером и клиентом; сервер вручную раскладывает `Body`, `Turret`, `Barrel`, `ShootPoint`. |
| Движение корпуса | Implemented | `WOBClientController` отправляет throttle/steer; `WOBGameplayServer` двигает позицию и yaw корпуса. |
| Независимая башня | Implemented | `TurretYaw` считается отдельно от `BodyYaw`, turret/barrel/shootpoint раскладываются независимо. |
| Прицеливание | Implemented | Клиент проецирует мышь на `Y = 0` и отправляет `AimPosition`; сервер считает yaw. |
| Выстрел | Implemented | `ShootRequestEvent`, server cooldown `0.45`, spawn из `ShootPoint`. |
| Снаряд | Implemented | Снаряд как neon Ball Part, state table и update loop на сервере. |
| Рикошет от стен | Implemented | Raycast collision и `reflect(direction, normal)`. |
| Лимит рикошетов | Implemented | `PROJECTILE_MAX_BOUNCES = 3`, уничтожение после превышения. |
| Самопопадание | Missing | Raycast filter исключает `playerTank`, поэтому self-hit невозможен. |
| Урон | Partially implemented | Урон наносится только `DummyTank`; player damage отсутствует. |
| Урон по углу | Missing | Armor hitboxes раскладываются, но angle damage не используется. |
| Здоровье | Partially implemented | `DummyTank.Health` Attribute есть; player health не найден. |
| Смерть | Partially implemented | Dummy death затемняет части; полноценная смерть игрока отсутствует. |
| Победа/поражение | Missing | Match state victory/defeat в snapshot не найден. |
| Рестарт | Partially implemented | `ResetDummyRequestEvent` подтвержден: HUD отправляет, `WOBDummyRespawnServer` сбрасывает dummy. Полный restart матча, player state и runtime cleanup отсутствуют. |
| UI здоровья | Partially implemented | Есть Dummy HP UI; player HP UI нет. |
| UI результата | Partially implemented | Есть feedback `TARGET DESTROYED`, но нет полноценного victory/defeat UI. |
| Бот/болванка | Implemented | `DummyTank` получает урон и имеет health feedback. AI нет, но MVP-болванка есть. |
| Client/server разделение | Partially implemented | Input и HUD на клиенте, движение/снаряды/урон на сервере; контракты пока через hard-coded remotes и Attributes. |
| Конфиги | Missing | Константы зашиты в Studio-скрипты, Rojo config modules отсутствуют. |

## Safe Extraction Candidates

Можно выносить первыми в `src` через Rojo только как маленькие read-only модули, без подключения к gameplay до отдельной задачи и Play-проверки.

### Configs

Самый безопасный кандидат:

- `MOVE_SPEED = 34`
- `TURN_SPEED = math.rad(115)`
- `SHOOT_COOLDOWN = 0.45`
- `PROJECTILE_SPEED = 160`
- `PROJECTILE_DAMAGE = 35`
- `PROJECTILE_MAX_BOUNCES = 3`
- `PROJECTILE_DAMAGE_MULTIPLIER = 0.75`
- `PROJECTILE_LIFETIME = 4`
- `CAMERA_HEIGHT = 95`
- `CAMERA_FIELD_OF_VIEW = 42`
- `INPUT_SEND_INTERVAL = 0.05`
- `MAX_DUMMY_HEALTH = 100`
- `MAX_HEALTH = 100`
- `RESPAWN_DELAY = 2.25`
- `FEEDBACK_TIME = 0.8`
- Lighting defaults: shadows, brightness, clock time, fog end, technology;
- Trail defaults: attachment offsets, lifetime, min length, light emission, color, transparency.

Рекомендуемые будущие модули:

- `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/CameraConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/HudConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/RespawnConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/VisualConfig.luau`

### Constants

Безопасные для выноса после config:

- remote names;
- workspace root name `WOB_Generated`;
- folder names `Runtime`, `Projectiles`, `VFX`, `TestObjects`;
- model names `PlayerTankPrototype`, `DummyTank`;
- part names `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`;
- UI names.
- trail child names `WOBTrail`, `TrailAttachment0`, `TrailAttachment1`.

### Helper utils

Относительно безопасные pure helpers:

- `reflect(direction, normal)`;
- `clamp01(value)`;
- `getYawFromDirection(direction)`;
- safe instance lookup helpers.

### UI formatting

Безопасно выносить после HUD constants:

- формат `"Dummy HP: x / max"`;
- формат `"Reload: READY"`;
- формат `"Reload: N%"`;
- feedback text constants.

### Projectile visuals

Можно выносить после configs/constants:

- `createFlash`;
- `createMuzzleFlash`;
- `createImpactFlash`;
- spark visual creation;
- projectile color/light visual defaults.
- `WOBProjectileVisualEnhancer.addTrail`;
- trail visual constants.

Важно: projectile visuals разделены между `WOBGameplayServer` и `WOBProjectileVisualEnhancer`. Safe extraction должен начинаться с visual constants и helper functions, без изменения projectile lifecycle.

### Performance helpers

Низкорисковые кандидаты:

- `applyLightingProfile` constants;
- `optimizePart`;
- `optimizeModel`;
- `optimizeCharacter`.

## Dangerous Areas

Не трогать первым:

- `WOBGameplayServer` как целый файл;
- `updateTank`;
- `updateProjectiles`;
- raycast filter;
- projectile bounce order;
- damage application;
- `DummyTank.Health` contract;
- `WOBClientController` camera and aim math;
- `WOBHudController` direct UI paths;
- reset/respawn flow, если задача не про dummy reset;
- performance lighting profile, если задача не про визуальный профиль;
- projectile visual enhancer lifecycle, если задача не про visual-only changes;
- `.rbxl`;
- `default.project.json`;
- существующие `src` smoke-test scripts.

## Risks

- Текущий рабочий прототип держится на hard-coded Studio hierarchy.
- `WOBGameplayServer` является монолитом и точкой наибольшего риска.
- HUD reload может показывать готовность локально, даже если сервер отклонил выстрел по cooldown.
- Self-hit из GDD не реализован, но простое включение playerTank в raycast может резко изменить gameplay и должно быть отдельной задачей.
- Armor hitboxes уже раскладываются, но не используются; их нельзя удалять, потому что они могут быть заделом под angle damage.
- Reset/performance/extra VFX теперь понятны на уровне snapshot, но все еще завязаны на hard-coded Studio hierarchy.
- Любой перенос в `src` с подключением к текущим Studio scripts может сломать Rojo workflow или порядок инициализации.

## Recommended Next Safe Step

Следующий безопасный шаг: создать read-only config plan в документации для `TankConfig`, `ProjectileConfig`, `HudConfig`, `RespawnConfig` и `VisualConfig`, не создавая и не подключая gameplay modules. После этого отдельной задачей можно аккуратно добавить config modules в `src/ReplicatedStorage/Shared/Configs/`, но не подключать их к core gameplay loop без Play-проверки.

Рекомендуемый коммит для текущего анализа:

```bash
git add docs/PROJECT_AUDIT.md docs/studio_scripts_snapshot/WOBDummyRespawnServer.luau docs/studio_scripts_snapshot/WOBPerformanceServer.luau docs/studio_scripts_snapshot/WOBProjectileVisualEnhancer.luau
git commit -m "Analyze remaining Studio script snapshots"
```
