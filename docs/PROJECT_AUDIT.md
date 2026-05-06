# World of Balance: Ricochet Tanks - Project Audit

Дата аудита: 2026-05-06.

## Scope and Source of Truth

Аудит обновлен после анализа snapshot-файлов из `docs/studio_scripts_snapshot/`.

Прочитанные документы:

- `docs/GDD.md`
- `docs/TECH_CONTEXT.md`
- `docs/CODEX_TASKS.md`
- `docs/PROJECT_AUDIT.md`

Проанализированные snapshot-файлы:

- `docs/studio_scripts_snapshot/WOBGameplayServer.server.luau`
- `docs/studio_scripts_snapshot/WOBClientController.client.luau`
- `docs/studio_scripts_snapshot/WOBHudController.client.luau`
- `docs/studio_scripts_snapshot/WOBDummyRespawnServer.server.luau`
- `docs/studio_scripts_snapshot/WOBPerformanceServer.server.luau`
- `docs/studio_scripts_snapshot/WOBProjectileVisualEnhancer.server.luau`

Ограничения аудита:

- `.rbxl` не изменялся.
- Gameplay-код не менялся.
- Скрипты не переносились в `src/`.
- `default.project.json` не менялся.
- Snapshot-файлы рассматриваются как read-only копии Studio-скриптов для анализа.

`WOBDummyRespawnServer.server.luau` перепроверен и теперь содержит dummy respawn/reset logic. Он больше не совпадает с `WOBPerformanceServer.server.luau`.

## Rojo Context

`default.project.json` маппит только три зоны:

- `src/ReplicatedStorage/Shared` -> `ReplicatedStorage.Shared`
- `src/ServerScriptService/Server` -> `ServerScriptService.Server`
- `src/StarterPlayer/StarterPlayerScripts/Client` -> `StarterPlayer.StarterPlayerScripts.Client`

Текущая Rojo-часть минимальная:

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

Основная gameplay logic текущего прототипа все еще живет внутри Studio-сцены, а не в `src/`.

## Current Prototype Architecture

Фактическая архитектура прототипа:

- `WOBGameplayServer` держит core gameplay: tank state, движение, башню, стрельбу, снаряды, рикошеты, урон по dummy и часть VFX.
- `WOBClientController` читает input, считает aim point, ведет камеру и отправляет намерения на сервер.
- `WOBHudController` читает `DummyTank.Health`, обновляет HUD и отправляет `ResetDummyRequestEvent`.
- `WOBProjectileVisualEnhancer` добавляет trail к projectile parts.
- `WOBPerformanceServer` применяет Lighting/performance profile.
- `WOBDummyRespawnServer` обрабатывает reset dummy и delayed respawn после `Health <= 0`.

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

| Studio script | Role | Risk |
| --- | --- | --- |
| `WOBGameplayServer` | Core gameplay: tank state, shooting, projectiles, ricochet, dummy damage, VFX flashes | High |
| `WOBClientController` | Input, camera, aim projection, fire request | Medium/High |
| `WOBHudController` | Dummy HP UI, reload UI, feedback, reset request | Medium |
| `WOBDummyRespawnServer` | Dummy health reset, delayed respawn, color restore | Medium |
| `WOBPerformanceServer` | Lighting profile and shadow disabling | Low/Medium |
| `WOBProjectileVisualEnhancer` | Projectile trail visuals | Low if it stays visual-only |

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

Зависимости:

- `Players`, `Workspace`, `RunService`, `ReplicatedStorage`, `Debris`;
- `ReplicatedStorage.Remotes.TankInputEvent`;
- `ReplicatedStorage.Remotes.ShootRequestEvent`;
- `Workspace.WOB_Generated.Runtime`;
- `Workspace.WOB_Generated.TestObjects.PlayerTankPrototype`;
- `Workspace.WOB_Generated.TestObjects.DummyTank`;
- точные имена частей танка: `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`;
- Attribute `DummyTank.Health`.

Механики внутри:

- server-authoritative movement;
- independent turret aiming;
- shooting cooldown;
- projectile spawn/movement/lifetime;
- raycast collision;
- wall/object ricochet;
- max bounce limit;
- damage falloff after bounce;
- dummy damage/death visual state;
- VFX flashes/sparks.

Важные замечания:

- Self-hit не реализован: raycast filter исключает `playerTank`.
- Player damage не реализован.
- Урон по углу не реализован: armor hitboxes раскладываются, но не участвуют в damage.
- Victory/defeat отсутствуют как match state.
- Это главный монолит текущего прототипа. Не переписывать и не переносить первым.

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

Зависимости:

- `Players`, `Workspace`, `RunService`, `UserInputService`, `ReplicatedStorage`;
- `ReplicatedStorage.Remotes.TankInputEvent`;
- `ReplicatedStorage.Remotes.ShootRequestEvent`;
- `Workspace.WOB_Generated.TestObjects.PlayerTankPrototype.Body`;
- текущая камера Roblox.

Риск:

- камера, aim projection и input-send interval напрямую влияют на ощущение управления;
- изменение плоскости `Y = 0` или пути к `Body` может сразу сломать прицеливание.

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

Зависимости:

- `Workspace.WOB_Generated.TestObjects.DummyTank`;
- Attribute `DummyTank.Health`;
- `ReplicatedStorage.Remotes.ResetDummyRequestEvent`;
- `script.Parent.MainPanel`;
- `DummyHpLabel`, `DummyHpBack.DummyHpFill`, `ReloadLabel`, `ReloadBack.ReloadFill`, `FeedbackLabel`.

Риск:

- HUD напрямую зависит от exact UI names;
- reload UI локальный и может расходиться с server cooldown;
- server handler для `ResetDummyRequestEvent` подтвержден в `WOBDummyRespawnServer`.

### `WOBDummyRespawnServer.server.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBDummyRespawnServer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBDummyRespawnServer.server.luau`.
- Размер: 71 строка.
- Статус: Keep / Refactor later.

Что делает:

- находит `ReplicatedStorage.Remotes.ResetDummyRequestEvent`;
- находит `Workspace.WOB_Generated.TestObjects.DummyTank`;
- хранит `MAX_HEALTH = 100` и `RESPAWN_DELAY = 2.25`;
- восстанавливает `DummyTank.Health` до `100`;
- восстанавливает цвета частей dummy по именам `Body`, `Turret`, `Barrel`, `ShootPoint`, `FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor`;
- подписывается на `DummyTank:GetAttributeChangedSignal("Health")`;
- если здоровье dummy `<= 0`, запускает отложенный respawn через `task.delay(RESPAWN_DELAY, ...)`;
- принимает `ResetDummyRequestEvent.OnServerEvent` и сразу вызывает reset.

Зависимости:

- `Workspace.WOB_Generated.TestObjects.DummyTank`;
- `ReplicatedStorage.Remotes.ResetDummyRequestEvent`;
- Attribute `DummyTank.Health`;
- точные имена частей dummy и armor hitboxes.

RemoteEvent:

- `ResetDummyRequestEvent`.

Attributes:

- читает `DummyTank.Health`;
- пишет `DummyTank.Health`.

Зависимость от `WOBGameplayServer`:

- прямой зависимости нет;
- есть shared state dependency через `DummyTank.Health` и визуальное состояние parts dummy.

Риск конфликта с `WOBGameplayServer`:

- `WOBGameplayServer` уменьшает `DummyTank.Health` и затемняет dummy parts при смерти;
- `WOBDummyRespawnServer` слушает `DummyTank.Health <= 0`, восстанавливает здоровье и цвета;
- если изменить max health только в одном скрипте, HUD/damage/respawn начнут расходиться;
- reset может сработать во время активных projectile updates, но текущий reset не чистит снаряды и runtime state.

Безопасно выносить позже:

- `MAX_HEALTH`;
- `RESPAWN_DELAY`;
- таблицу цветов dummy parts;
- helper `setPartColor`.

### `WOBPerformanceServer.server.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBPerformanceServer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBPerformanceServer.server.luau`.
- Размер: 57 строк.
- Статус: Keep / Safe extraction candidate for constants.

Что делает:

- применяет Lighting profile: `GlobalShadows = false`, `Brightness = 2`, `ClockTime = 14`, `FogEnd = 100000`;
- пытается выставить `Lighting.Technology = Enum.Technology.Compatibility`;
- отключает `CastShadow` у всех BasePart внутри `Workspace.WOB_Generated`;
- отключает `CastShadow` у новых descendants внутри `Workspace.WOB_Generated`;
- отключает `CastShadow` у character parts существующих и новых игроков.

Зависимости:

- `Workspace.WOB_Generated`;
- `Lighting`;
- `Players`;
- `BasePart.CastShadow`.

RemoteEvent:

- не использует.

Attributes:

- не читает и не пишет.

Зависимость от `WOBGameplayServer`:

- прямой зависимости нет;
- косвенная зависимость есть через generated parts, которые создает gameplay/VFX.

Риск конфликта с `WOBGameplayServer`:

- низкий для gameplay behavior;
- средний для визуала, потому что все новые generated parts получают `CastShadow = false`;
- не дублируется с `WOBDummyRespawnServer.server.luau` после исправления snapshot.

Безопасно выносить позже:

- lighting constants;
- `optimizePart`;
- `optimizeModel`;
- `optimizeCharacter`;
- performance defaults.

### `WOBProjectileVisualEnhancer.server.luau`

- Оригинальный путь: `ServerScriptService/Services/WOBProjectileVisualEnhancer`.
- Тип: Server Script.
- Snapshot: `docs/studio_scripts_snapshot/WOBProjectileVisualEnhancer.server.luau`.
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

RemoteEvent:

- не использует.

Attributes:

- не читает и не пишет.

Зависимость от `WOBGameplayServer`:

- косвенная: `WOBGameplayServer` создает `Runtime.Projectiles` и сами projectile BasePart;
- enhancer не управляет movement, damage, direction, raycast или lifetime.

Риск конфликта с `WOBGameplayServer`:

- низкий для gameplay;
- возможен lifecycle-конфликт, если projectile уничтожается сразу после добавления attachments/trail;
- если projectile перестанет быть BasePart, enhancer перестанет работать;
- raycast сейчас исключает `projectileFolder`, поэтому trail/attachments не должны мешать collision.

Безопасно выносить позже:

- trail visual constants;
- attachment offsets;
- `addTrail` helper;
- color/transparency sequences.

## Systems Already Implemented

### Gameplay Loop

- Статус: Partially implemented.
- Где: `WOBGameplayServer`.
- Есть: server Heartbeat вызывает `updateTank` и `updateProjectiles`.
- Нет: полноценного match state, victory/defeat, player death, round restart.

### Tank Control

- Статус: Implemented for one controlling player.
- Где: `WOBClientController` + `WOBGameplayServer`.
- Есть: `WASD`, server throttle/steer, clamp позиции в пределах `-58..58`.
- Ограничение: только один `controllingPlayer`; нет PvP.

### Tank Wall Blocking

- Статус: Patch prepared, not active until manually pasted into Studio-owned `WOBGameplayServer`.
- Где патч: `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`.
- Что меняет: перед применением новой позиции танка server-side `Blockcast` проверяет swept body box по направлению движения.
- Какие obstacles блокируются: `Workspace/WOB_Generated/Map/RicochetWalls`, `Workspace/WOB_Generated/Map/Cover`, `Wall_North`, `Wall_South`, `Wall_East`, `Wall_West`, `RicochetWall_*`, `Cover_Block_*`.
- Что исключается из cast: `PlayerTankPrototype`, `Runtime`, `Projectiles`, `VFX`.
- Что не меняется: RemoteEvent contracts, WASD input, turret aim, projectile damage, projectile ricochet logic, dummy damage.
- MVP-ограничение: при blocked movement позиция не применяется для этого кадра; sliding вдоль стены не реализован.

### Turret Aiming

- Статус: Implemented.
- Где: client отправляет `AimPosition`, server считает `TurretYaw`.
- Ограничение: башня мгновенно смотрит на aim direction, без ограниченной скорости поворота.

### Projectile Handling

- Статус: Implemented for MVP dummy target.
- Где: `WOBGameplayServer`.
- Есть: spawn, movement, raycast, lifetime, destroy, ricochet, max bounces, damage falloff.
- Ограничение: нет self-hit, player damage и angle damage.

### Dummy Respawn / Reset

- Статус: Partially implemented.
- Где: `WOBHudController` отправляет `ResetDummyRequestEvent`; `WOBDummyRespawnServer` обрабатывает reset и delayed respawn.
- Есть: reset dummy health, restore part colors, auto-respawn через `task.delay(2.25)` после `Health <= 0`.
- Ограничение: это reset dummy, а не полноценный restart матча; player state, projectiles и runtime state не сбрасываются.

### UI Update Flow

- Статус: Partially implemented.
- Где: `WOBHudController`.
- Есть: dummy HP, reload display, hit/destroyed/reset feedback.
- Ограничение: нет player HP и полноценного result UI.

### Runtime Object Handling

- Статус: Implemented.
- Где: `WOBGameplayServer` создает `Runtime/Projectiles` и `Runtime/VFX`; `WOBProjectileVisualEnhancer` слушает `Runtime/Projectiles`.
- Ограничение: reset runtime state отсутствует.

### Projectile Visuals / VFX / Readability

- Статус: Implemented for prototype readability.
- Где: `WOBGameplayServer` создает muzzle/impact flashes and sparks; `WOBProjectileVisualEnhancer` добавляет projectile trails.
- Ограничение: visual constants зашиты в Studio-скрипты.

### Projectile Ground Glow / Readability

- Статус: Config updated + patch prepared; active Studio-owned `WOBProjectileVisualEnhancer` must be manually replaced to enable glow.
- Где config: `src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau`.
- Где патч: `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau`.
- Новые visual-only поля: `GroundGlowEnabled`, `GroundGlowSize`, `GroundGlowTransparency`, `GroundGlowHeightOffset`, `GroundGlowColor`.
- Что меняет: visual enhancer создает `WOBGroundGlow` под projectile, обновляет его на `RunService.Heartbeat`, и glow уничтожается вместе с projectile part.
- Collision/raycast safety: glow uses `Anchored = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`; `WOBGameplayServer` projectile raycast already excludes `Runtime/Projectiles`.
- Что не меняется: projectile speed, damage, lifetime, max ricochets, damage multiplier and ricochet raycast behavior.

### Performance / Cleanup

- Статус: Partially implemented.
- Где: `WOBPerformanceServer`.
- Есть: Lighting profile и отключение теней у generated/character parts.
- Нет: отдельного cleanup service для старых runtime objects; projectile cleanup остается в `WOBGameplayServer`.
- Риск: performance profile глобально меняет Lighting и может конфликтовать с будущей визуальной задачей.

## Likely Monolith Zones

### Main monolith: `WOBGameplayServer`

Смешанные ответственности:

- поиск сервисов и объектов сцены;
- создание runtime folders;
- выбор controlling player;
- скрытие standard character;
- хранение состояния танка;
- движение танка;
- наведение башни;
- ручная раскладка модели танка;
- обработка remotes;
- shooting cooldown;
- создание, движение и удаление снарядов;
- raycast collision;
- ricochet math;
- damage model;
- dummy death visual;
- VFX flashes/sparks.

Что опасно менять:

- `Workspace.WOB_Generated`, `Runtime`, `TestObjects`, `PlayerTankPrototype`, `DummyTank`;
- `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`;
- `TankInputEvent`, `ShootRequestEvent`;
- assumptions `Anchored`, `Y = 0`, clamp bounds `-58..58`;
- raycast filter, особенно исключение `playerTank`;
- bounce order, damage multiplier and max bounce behavior;
- `DummyTank.Health`.

### Secondary coupling: `WOBClientController`

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
- `INPUT_SEND_INTERVAL`;
- fire request timing.

### UI coupling: `WOBHudController`

Смешанные ответственности:

- чтение replicated gameplay state;
- UI formatting;
- progress bar layout;
- feedback timing;
- reset input.

Что опасно менять:

- exact UI names;
- `DummyTank.Health`;
- `ResetDummyRequestEvent`;
- локальную reload логику, пока server cooldown не реплицируется явно.

## Client/Server/HUD Dependencies

### Client -> Server

- `WOBClientController` отправляет `TankInputEvent` каждые `0.05` секунды.
- Payload: `Throttle`, `Steer`, `AimPosition`.
- `WOBClientController` отправляет `ShootRequestEvent` при MouseButton1.
- Payload: `AimPosition`.

### HUD -> Server

- `WOBHudController` отправляет `ResetDummyRequestEvent` по клавише `R`.
- `WOBDummyRespawnServer` принимает `ResetDummyRequestEvent` и вызывает reset dummy.

### Server -> World State

- `WOBGameplayServer` пишет CFrame частей `PlayerTankPrototype`.
- `WOBGameplayServer` создает projectile parts в `Runtime/Projectiles`.
- `WOBGameplayServer` создает VFX parts в `Runtime/VFX`.
- `WOBGameplayServer` пишет `DummyTank.Health`.
- `WOBGameplayServer` красит BaseParts dummy при `Health <= 0`.
- `WOBPerformanceServer` меняет Lighting и отключает shadows у generated parts.
- `WOBProjectileVisualEnhancer` добавляет trail children к projectile parts.
- `WOBDummyRespawnServer` пишет `DummyTank.Health` и восстанавливает цвета dummy parts.

### World State -> HUD

- `WOBHudController` читает `DummyTank.Health`.
- `WOBHudController` обновляется через `GetAttributeChangedSignal("Health")`.
- `WOBHudController` показывает feedback на основе изменения здоровья.

### Duplicated Constants

- `SHOOT_COOLDOWN = 0.45` есть в `WOBGameplayServer` и `WOBHudController`.
- `MAX_DUMMY_HEALTH = 100` в HUD дублирует server default `100` в damage logic.
- `MAX_DUMMY_HEALTH = 100`, `MAX_HEALTH = 100` и server default `100` дублируют одно значение здоровья dummy.
- Trail constants зашиты в `WOBProjectileVisualEnhancer`.
- Object names, remote names and UI names зашиты строками.

## Updated Mechanics Matrix

| Механика | Статус | Основание |
| --- | --- | --- |
| Арена | Implemented | Скрипты работают с `Workspace.WOB_Generated`; projectile collision идет через world raycast. |
| Танк игрока | Implemented | `PlayerTankPrototype` используется сервером и клиентом. |
| Движение корпуса | Implemented | Client отправляет throttle/steer, server двигает `tankState.Position` и `BodyYaw`. |
| Tank wall blocking | Patch prepared | `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau` добавляет server-side `Blockcast`; нужно вручную вставить в Studio-owned `WOBGameplayServer`. |
| Независимая башня | Implemented | `TurretYaw` считается отдельно от `BodyYaw`. |
| Прицеливание | Implemented | Client проецирует мышь на `Y = 0`, server считает yaw. |
| Выстрел | Implemented | `ShootRequestEvent`, server cooldown, spawn из `ShootPoint`. |
| Снаряд | Implemented | Neon Ball Part, server state table and Heartbeat update. |
| Рикошет от стен | Implemented | Raycast collision и `reflect(direction, normal)`. |
| Лимит рикошетов | Implemented | `PROJECTILE_MAX_BOUNCES = 3`. |
| Самопопадание | Missing | Raycast filter исключает `playerTank`. |
| Урон | Partially implemented | Урон наносится только `DummyTank`; player damage отсутствует. |
| Урон по углу | Missing | Armor hitboxes раскладываются, но angle damage не используется. |
| Здоровье | Partially implemented | Есть `DummyTank.Health`; player health не найден. |
| Смерть | Partially implemented | Dummy death затемняет части; player death отсутствует. |
| Победа/поражение | Missing | Match state victory/defeat не найден. |
| Dummy respawn/reset | Partially implemented | HUD отправляет `ResetDummyRequestEvent`; `WOBDummyRespawnServer` сбрасывает `DummyTank.Health`, восстанавливает цвета и делает delayed respawn после `Health <= 0`. |
| Рестарт | Partially implemented | Есть reset dummy, но полный restart матча, player state и runtime cleanup отсутствуют. |
| UI здоровья | Partially implemented | Dummy HP UI есть; player HP UI нет. |
| UI результата | Partially implemented | Feedback `TARGET DESTROYED` есть, полноценного result UI нет. |
| Projectile visuals | Implemented + glow patch prepared | `WOBProjectileVisualEnhancer` добавляет trail; `WOBGameplayServer` создает flashes/sparks; `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau` добавляет visual-only ground glow. |
| Performance/cleanup | Partially implemented | Lighting/shadow optimization есть; runtime cleanup как отдельная система не найден. |
| Runtime object handling | Implemented | `Projectiles` и `VFX` создаются/используются; reset runtime state отсутствует. |
| Бот/болванка | Implemented | `DummyTank` получает урон и имеет HUD feedback. |
| Client/server разделение | Partially implemented | Input/HUD на клиенте, movement/projectiles/damage на сервере; contracts hard-coded. |
| Конфиги | Missing | Константы зашиты в Studio-скрипты. |

## Safe Extraction Candidates

Можно выносить первыми в `src` через Rojo только маленькими read-only модулями и без подключения к core gameplay loop до отдельной Play-проверки.

### Configs / Constants

Безопасные кандидаты:

- tank: `MOVE_SPEED`, `TURN_SPEED`;
- projectile: `SHOOT_COOLDOWN`, `PROJECTILE_SPEED`, `PROJECTILE_DAMAGE`, `PROJECTILE_MAX_BOUNCES`, `PROJECTILE_DAMAGE_MULTIPLIER`, `PROJECTILE_LIFETIME`;
- camera: `CAMERA_HEIGHT`, `CAMERA_FIELD_OF_VIEW`, `INPUT_SEND_INTERVAL`;
- HUD: `MAX_DUMMY_HEALTH`, `FEEDBACK_TIME`, feedback text;
- respawn: `MAX_HEALTH`, `RESPAWN_DELAY`, dummy part colors;
- visual: projectile colors, flash sizes/lifetimes, trail lifetime, trail color, trail transparency;
- performance: `GlobalShadows`, `Brightness`, `ClockTime`, `FogEnd`, `Lighting.Technology`;
- names: remote names, workspace root/folder names, model names, part names, UI names, trail child names.

`RespawnConfig` теперь допустим как future safe extraction candidate, но подключать его к gameplay нельзя без отдельной задачи и Play-проверки.

### Helper Utils

Относительно безопасные pure helpers:

- `reflect(direction, normal)`;
- `clamp01(value)`;
- `getYawFromDirection(direction)`;
- safe instance lookup helpers;
- visual-only `addTrail`, если остается без gameplay effects.

### UI Formatting

Безопасно выносить после constants:

- формат `Dummy HP: x / max`;
- формат `Reload: READY`;
- формат `Reload: N%`;
- feedback text/color constants.

### Visual / Projectile Enhancer

Хороший ранний кандидат:

- trail constants;
- attachment offsets;
- `addTrail` helper;
- visual-only projectile readability defaults.

Не трогать при этом:

- projectile spawn;
- projectile movement;
- raycast;
- bounce count;
- damage.

### Cleanup / Performance Constants

Низкий риск:

- lighting defaults;
- shadow toggle;
- `optimizePart`;
- `optimizeModel`;
- `optimizeCharacter`.

Риск: не подключать к gameplay loop и не менять художественный профиль без отдельной задачи.

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

- Текущий прототип держится на hard-coded Studio hierarchy.
- `WOBGameplayServer` является главным монолитом и точкой наибольшего риска.
- `WOBDummyRespawnServer` и `WOBGameplayServer` оба завязаны на `DummyTank.Health`; изменение одного без другого может сломать reset/damage/HUD consistency.
- Dummy reset не очищает активные снаряды и runtime state, поэтому это не полноценный restart матча.
- HUD reload может показывать готовность локально, даже если сервер отклонил выстрел по cooldown.
- Self-hit из GDD не реализован, но простое включение playerTank в raycast резко изменит gameplay и должно быть отдельной задачей.
- Armor hitboxes уже раскладываются, но не используются; их нельзя удалять, потому что это задел под angle damage.
- Performance и VFX завязаны на hard-coded `Workspace.WOB_Generated`.
- Любой перенос в `src` с подключением к текущим Studio scripts может сломать Rojo workflow или порядок инициализации.
- Tank blocking patch uses `Workspace:Blockcast`; проверить в Play Mode, что cast не блокируется floor/spawns and does block `RicochetWalls`/`Cover`.
- Projectile ground glow patch requires `ReplicatedStorage.Shared.Configs.ProjectileVisualConfig` to exist via Rojo before Play.
- Ground glow is visual-only, but проверить, что `CanQuery = false` and projectile raycast still ignores projectile visuals.

## Manual Studio Patch Files

Так как `WOBGameplayServer` и `WOBProjectileVisualEnhancer` остаются Studio-owned, активные скрипты в `.rbxl` не изменены автоматически.

Manual apply instructions:

- `docs/patches/TANK_BLOCKING_AND_PROJECTILE_GLOW_STUDIO_STEPS.md`

Patch sources to paste into Roblox Studio:

- `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau` -> `ServerScriptService/Services/WOBGameplayServer`
- `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau` -> `ServerScriptService/Services/WOBProjectileVisualEnhancer`

Rojo-owned config that should sync before Play:

- `src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau`

## Recommended Next Safe Step

Следующий безопасный шаг: вручную вставить prepared patches в Studio-owned scripts, подключить Rojo, пройти Play Mode checklist, затем сохранить `.rbxl` через `File -> Save to File`, если проверка прошла.

Рекомендуемый коммит для текущей подготовки patch-файлов:

```bash
git add docs/PROJECT_AUDIT.md docs/CODEX_TASKS.md docs/patches src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau
git commit -m "Prepare tank blocking and projectile glow patches"
```
