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

Ограничения аудита:

- `.rbxl` не изменялся.
- Gameplay-код не менялся.
- Скрипты не переносились в `src/`.
- `default.project.json` не менялся.
- Snapshot содержит не все найденные Studio-скрипты.

Не сохранены в snapshot и требуют ручного копирования для полного аудита:

- `ServerScriptService/Services/WOBDummyRespawnServer`
- `ServerScriptService/Services/WOBPerformanceServer`
- `ServerScriptService/Services/WOBProjectileVisualEnhancer`

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
- HUD отправляет reset request через `ResetDummyRequestEvent`, но серверный обработчик этого события не попал в snapshot;
- временные снаряды и VFX создаются сервером в `Workspace.WOB_Generated.Runtime`;
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
- Reset request есть на клиенте, но серверный handler не попал в snapshot.
- Player health UI отсутствует.

### Not snapshotted: `WOBDummyRespawnServer`

- Оригинальный путь: `ServerScriptService/Services/WOBDummyRespawnServer`.
- Тип: likely Server Script.
- Snapshot: отсутствует.
- Статус: Unknown / requires manual copy.
- Вероятная роль: серверная обработка `ResetDummyRequestEvent`, восстановление `DummyTank.Health`, цвета и позиции dummy.

### Not snapshotted: `WOBPerformanceServer`

- Оригинальный путь: `ServerScriptService/Services/WOBPerformanceServer`.
- Тип: likely Server Script.
- Snapshot: отсутствует.
- Статус: Unknown / requires manual copy.
- Вероятная роль: cleanup или контроль runtime/VFX/projectile count.

### Not snapshotted: `WOBProjectileVisualEnhancer`

- Оригинальный путь: `ServerScriptService/Services/WOBProjectileVisualEnhancer`.
- Тип: likely Server Script.
- Snapshot: отсутствует.
- Статус: Unknown / requires manual copy.
- Вероятная роль: дополнительная читаемость снарядов или VFX. Нельзя считать safe extraction, пока не видно, не участвует ли он в gameplay logic.

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

- Статус: Partially implemented / unknown.
- Где: client request есть в `WOBHudController`; server handler likely in missing `WOBDummyRespawnServer`.
- Нужно: сохранить snapshot `WOBDummyRespawnServer`, чтобы подтвердить reset flow.

### Runtime objects

- Статус: Implemented.
- Где: `WOBGameplayServer` создает `Runtime/Projectiles` и `Runtime/VFX`.
- Ограничение: `WOBPerformanceServer` не snapshotted, поэтому cleanup/performance flow неполный.

### Visual enhancer / VFX

- Статус: Partially implemented.
- Где: `WOBGameplayServer` уже создает muzzle flash, impact flash и sparks.
- Unknown: дополнительный `WOBProjectileVisualEnhancer` не snapshotted.

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

### World State -> HUD

- `WOBHudController` читает `DummyTank.Health`.
- `WOBHudController` обновляется через `GetAttributeChangedSignal("Health")`.
- `WOBHudController` показывает feedback на основе изменения здоровья.

### HUD -> Server

- `WOBHudController` отправляет `ResetDummyRequestEvent` по клавише `R`.
- Серверный обработчик не попал в snapshot; вероятно находится в `WOBDummyRespawnServer`.

### Shared constants duplicated

Одни и те же или связанные значения зашиты в разных скриптах:

- `SHOOT_COOLDOWN = 0.45` есть и на сервере, и в HUD.
- `MAX_DUMMY_HEALTH = 100` есть в HUD, а сервер использует default `100` в damage logic.
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
| Рестарт | Partially implemented | HUD отправляет `ResetDummyRequestEvent`; server reset handler не snapshotted. |
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
- `FEEDBACK_TIME = 0.8`

Рекомендуемые будущие модули:

- `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/CameraConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/HudConfig.luau`

### Constants

Безопасные для выноса после config:

- remote names;
- workspace root name `WOB_Generated`;
- folder names `Runtime`, `Projectiles`, `VFX`, `TestObjects`;
- model names `PlayerTankPrototype`, `DummyTank`;
- part names `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`;
- UI names.

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

Можно выносить позже, но осторожно:

- `createFlash`;
- `createMuzzleFlash`;
- `createImpactFlash`;
- spark visual creation;
- projectile color/light visual defaults.

Важно: projectile visuals сейчас находятся внутри `WOBGameplayServer`, а не в snapshotted `WOBProjectileVisualEnhancer`. Перед выносом нужно сохранить и прочитать `WOBProjectileVisualEnhancer`.

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
- reset/respawn flow до snapshot `WOBDummyRespawnServer`;
- performance/runtime cleanup до snapshot `WOBPerformanceServer`;
- projectile visual enhancer до snapshot `WOBProjectileVisualEnhancer`;
- `.rbxl`;
- `default.project.json`;
- существующие `src` smoke-test scripts.

## Risks

- Текущий рабочий прототип держится на hard-coded Studio hierarchy.
- `WOBGameplayServer` является монолитом и точкой наибольшего риска.
- HUD reload может показывать готовность локально, даже если сервер отклонил выстрел по cooldown.
- Self-hit из GDD не реализован, но простое включение playerTank в raycast может резко изменить gameplay и должно быть отдельной задачей.
- Armor hitboxes уже раскладываются, но не используются; их нельзя удалять, потому что они могут быть заделом под angle damage.
- Missing snapshots не позволяют полностью понять reset/performance/extra VFX systems.
- Любой перенос в `src` с подключением к текущим Studio scripts может сломать Rojo workflow или порядок инициализации.

## Recommended Next Safe Step

Сначала завершить snapshot недостающих Studio-скриптов:

- `WOBDummyRespawnServer.server.luau`
- `WOBPerformanceServer.server.luau`
- `WOBProjectileVisualEnhancer.server.luau`

После этого отдельной задачей можно создать read-only config modules в `src/ReplicatedStorage/Shared/Configs/` и перенести туда только дублирующиеся constants, не подключая их к core gameplay loop до Play-проверки.

Рекомендуемый коммит для текущего анализа:

```bash
git add docs/PROJECT_AUDIT.md
git commit -m "Analyze Studio script snapshots"
```
