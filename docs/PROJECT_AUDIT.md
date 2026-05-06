# World of Balance: Ricochet Tanks - Project Audit

Дата аудита: 2026-05-06.

## Scope and Source of Truth

Аудит обновлен после ручной проверки Roblox Studio Explorer. Ранее аудит `src/` был неполным: большая часть текущей gameplay logic находится внутри `RicochetTanksPrototype.rbxl`, а не в Rojo-папке `src/`.

Прочитанные документы:

- `docs/GDD.md`
- `docs/TECH_CONTEXT.md`
- `docs/CODEX_TASKS.md`
- `docs/PROJECT_AUDIT.md`

Ограничения аудита:

- `.rbxl` не изменялся.
- Gameplay не рефакторился.
- Скрипты не переносились в `src/`.
- `default.project.json` не менялся.
- Содержимое Studio-скриптов недоступно из файловой системы, поэтому точный line-level анализ требует ручного открытия Script Editor в Roblox Studio.
- Выводы по `.rbxl` ниже основаны на найденных объектах Studio и их именах. Где поведение не подтверждено исходником или Play-тестом, это отмечено как inferred / requires Studio source check.

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

Rojo workflow работает как внешний слой, но текущая игровая логика прототипа живет в сцене. Это важно: перенос в `src/` должен быть отдельной задачей и делаться постепенно.

## Current Prototype Architecture

Фактическая архитектура прототипа сейчас гибридная:

- `src/` содержит только smoke-test скрипты для проверки Rojo.
- `RicochetTanksPrototype.rbxl` содержит рабочую сцену, runtime-объекты, UI и основные Studio-скрипты.
- `Workspace` содержит карту, runtime-контейнеры и тестовые танки.
- `ServerScriptService/Services` содержит серверные системы прототипа.
- `StarterPlayer/StarterPlayerScripts` содержит клиентский контроллер и папку контроллеров.
- `StarterGui/HUD` содержит HUD и клиентскую UI-логику.

Найденная структура внутри Roblox Studio:

```text
ServerScriptService/
  Services/
    WOBDummyRespawnServer
    WOBGameplayServer
    WOBPerformanceServer
    WOBProjectileVisualEnhancer

StarterGui/
  HUD/
    WOBHudController
    MainPanel
    DummyHp UI
    Reload UI
    FeedbackLabel
    HintLabel

StarterPlayer/
  StarterPlayerScripts/
    WOBClientController
    Controllers/

Workspace/
  Map
  Runtime
  TestObjects
  DummyTank
  PlayerTankPrototype
```

Архитектурный вывод: MVP-прототип уже имеет несколько систем, но они не представлены как Rojo-managed Luau files. Любая работа через Rider/Codex должна учитывать, что `src/` не является полной картиной проекта.

## Filesystem Scripts in src

### `src/ServerScriptService/Server/ServerHello.server.luau`

- Тип: Server Script.
- Что делает: выводит в Output сообщение `"[SERVER] Rojo connected. Hello from Rider!"`.
- Какие механики содержит: игровых механик нет.
- Статус: Review.
- Комментарий: временный smoke-test Rojo. Не удалять без отдельной задачи, пока нет нормального серверного bootstrap в `src/`.

### `src/StarterPlayer/StarterPlayerScripts/Client/ClientHello.client.luau`

- Тип: Client Script.
- Что делает: выводит в Output сообщение `"[CLIENT] Rojo connected. Hello from Rider!"`.
- Какие механики содержит: игровых механик нет.
- Статус: Review.
- Комментарий: временный smoke-test Rojo. Не удалять без отдельной задачи, пока нет нормального клиентского bootstrap в `src/`.

## Studio Script Inventory

### `ServerScriptService/Services/WOBGameplayServer`

- Тип: Unknown from filesystem; likely Server Script.
- Что делает: вероятно центральная серверная gameplay-система прототипа.
- Какие механики содержит: likely tank/projectile loop, damage handling, runtime object orchestration, match feedback. Exact responsibilities require Studio source check.
- Статус: Refactor later.
- Комментарий: главный кандидат на сильную связанность. Не трогать первым и не переносить целиком.

### `ServerScriptService/Services/WOBDummyRespawnServer`

- Тип: Unknown from filesystem; likely Server Script.
- Что делает: вероятно управляет восстановлением `DummyTank` после уничтожения или тестового сброса.
- Какие механики содержит: likely dummy health/death/respawn reset.
- Статус: Keep / Review.
- Комментарий: полезная отдельная система, но ее зависимости от `WOBGameplayServer`, `DummyTank`, `Runtime` и UI нужно проверить в Studio.

### `ServerScriptService/Services/WOBPerformanceServer`

- Тип: Unknown from filesystem; likely Server Script.
- Что делает: вероятно следит за runtime-объектами, cleanup, ограничением количества визуальных объектов или производительностью прототипа.
- Какие механики содержит: likely cleanup/performance guard, not core gameplay.
- Статус: Review.
- Комментарий: безопаснее анализировать после понимания `Workspace/Runtime`, потому что он может удалять снаряды, эффекты или временные объекты.

### `ServerScriptService/Services/WOBProjectileVisualEnhancer`

- Тип: Unknown from filesystem; likely Server Script or ModuleScript.
- Что делает: вероятно усиливает визуальную читаемость снарядов: подсветка, следы, эффекты рикошета/попадания.
- Какие механики содержит: likely projectile VFX/readability; should not own damage or ricochet decisions.
- Статус: Safe extraction candidate after source check.
- Комментарий: хороший кандидат для первого выноса только если подтвердится, что скрипт не принимает gameplay-решения.

### `StarterGui/HUD/WOBHudController`

- Тип: Unknown from filesystem; likely Client Script / LocalScript.
- Что делает: вероятно обновляет HUD: здоровье болванки, перезарядку, feedback и hint labels.
- Какие механики содержит: UI update flow, status feedback, reload display.
- Статус: Safe extraction candidate after source check.
- Комментарий: UI formatting можно выносить раньше core gameplay, но нельзя ломать связи с текущими ValueObjects, Attributes или Remotes, если они используются.

### `StarterPlayer/StarterPlayerScripts/WOBClientController`

- Тип: Unknown from filesystem; likely Client Script / LocalScript.
- Что делает: вероятно обрабатывает input, camera, tank control, turret aiming и fire intent.
- Какие механики содержит: likely tank control, aiming, shooting input, client-side camera.
- Статус: Refactor later.
- Комментарий: опасная зона для раннего переноса, потому что изменение input/camera/tank control сразу ломает ощущение прототипа.

### `StarterPlayer/StarterPlayerScripts/Controllers/`

- Тип: Folder.
- Что делает: вероятный контейнер клиентских контроллеров.
- Какие механики содержит: Unknown / requires Studio source check.
- Статус: Review.
- Комментарий: нужно вручную раскрыть папку в Studio и зафиксировать все вложенные Script/ModuleScript.

## Runtime Object Inventory

### `Workspace/Map`

- Тип: Workspace object / model or folder.
- Роль: карта и геометрия арены.
- Статус: Keep.
- Риск: стены карты могут быть напрямую найдены скриптами по имени или иерархии.

### `Workspace/Runtime`

- Тип: Workspace folder/model.
- Роль: вероятный контейнер временных объектов: снаряды, эффекты, runtime state.
- Статус: Keep / Review.
- Риск: `WOBGameplayServer`, `WOBPerformanceServer` и `WOBProjectileVisualEnhancer` могут зависеть от точного имени и структуры.

### `Workspace/TestObjects`

- Тип: Workspace folder/model.
- Роль: тестовые объекты прототипа.
- Статус: Review.
- Риск: может содержать debug geometry, цели или временные helpers, которые нужны для текущего Play-теста.

### `Workspace/DummyTank`

- Тип: Workspace model.
- Роль: цель/болванка для MVP.
- Статус: Keep.
- Риск: вероятно связан с `WOBDummyRespawnServer`, HUD `DummyHp UI` и damage logic.

### `Workspace/PlayerTankPrototype`

- Тип: Workspace model.
- Роль: текущий танк игрока.
- Статус: Keep.
- Риск: вероятно связан с `WOBClientController` и `WOBGameplayServer`; нельзя переименовывать или менять структуру без отдельной задачи.

## Systems already implemented

### Gameplay loop

- Система: `WOBGameplayServer`.
- Статус: Partially implemented / inferred.
- Вероятная роль: центральный цикл прототипа, который связывает танк игрока, болванку, снаряды, урон, runtime-объекты и feedback.
- Риск: может быть монолитом. Не выносить первым.

### Tank control

- Система: `WOBClientController`, `PlayerTankPrototype`, возможно `Controllers/`.
- Статус: Partially implemented / inferred.
- Вероятная роль: ввод игрока, движение корпуса, наведение башни, камера и команда выстрела.
- Риск: client-side control может быть тесно связан с конкретной моделью `PlayerTankPrototype`.

### Projectile handling

- Система: `WOBGameplayServer`, `WOBProjectileVisualEnhancer`, `Workspace/Runtime`.
- Статус: Partially implemented / inferred.
- Вероятная роль: создание снарядов, движение, столкновения, рикошеты, визуальное усиление, cleanup.
- Риск: visual enhancer может быть смешан с gameplay-состоянием. Нужно проверить, кто считает попадание и лимит рикошетов.

### UI update flow

- Система: `StarterGui/HUD/WOBHudController`, `MainPanel`, `DummyHp UI`, `Reload UI`, `FeedbackLabel`, `HintLabel`.
- Статус: Partially implemented / inferred.
- Вероятная роль: отображение здоровья dummy, перезарядки, подсказок и feedback.
- Риск: UI может читать состояние напрямую из Workspace вместо стабильного Remote/Attribute контракта.

### Respawn

- Система: `WOBDummyRespawnServer`, `DummyTank`.
- Статус: Partially implemented / inferred.
- Вероятная роль: восстановление dummy после смерти или тестового события.
- Риск: respawn может напрямую сбрасывать health, позицию, UI и runtime state.

### Runtime objects

- Система: `Workspace/Runtime`, `WOBPerformanceServer`, `WOBGameplayServer`, `WOBProjectileVisualEnhancer`.
- Статус: Partially implemented / inferred.
- Вероятная роль: хранение снарядов, эффектов, временных объектов, debug state.
- Риск: удаление или переименование runtime-детей может сломать несколько систем сразу.

### Visual enhancer

- Система: `WOBProjectileVisualEnhancer`.
- Статус: Partially implemented / inferred.
- Вероятная роль: читаемость снаряда, glow/trail/impact/ricochet visual feedback.
- Риск: если скрипт только визуальный, это хороший кандидат на ранний вынос; если он управляет gameplay collision/damage, переносить нельзя до декомпозиции.

## Likely monolith zones

### `ServerScriptService/Services/WOBGameplayServer`

Вероятно смешанные ответственности:

- создание или поиск runtime-объектов;
- spawn/init tank references;
- обработка выстрела;
- создание снаряда;
- движение или обновление снаряда;
- collision/raycast;
- рикошет;
- урон;
- смерть dummy/player;
- feedback для UI;
- cleanup.

Что опасно менять:

- имена объектов `Map`, `Runtime`, `DummyTank`, `PlayerTankPrototype`;
- порядок инициализации;
- math для projectile direction и ricochet;
- правила damage/self-hit;
- связи с HUD и respawn.

Безопасный strangler refactor позже:

1. Сначала открыть script source в Studio и выписать реальные блоки ответственности.
2. Не менять поведение, только вынести константы в отдельный config.
3. Вынести чистые helper-функции без side effects, например vector reflection.
4. Вынести visual-only код, если он не влияет на попадания.
5. После каждого шага запускать Play и сверять поведение с текущим прототипом.

### `StarterPlayer/StarterPlayerScripts/WOBClientController`

Вероятно смешанные ответственности:

- input keyboard/mouse;
- camera;
- tank movement intent;
- turret aiming;
- fire input;
- local visual feedback;
- связь с HUD или server state.

Что опасно менять:

- схему управления;
- расчет mouse world position;
- CFrame башни и корпуса;
- связь с конкретными частями `PlayerTankPrototype`;
- частоту отправки событий на сервер, если есть RemoteEvents.

Безопасный strangler refactor позже:

1. Вынести числовые параметры управления.
2. Вынести форматирование input state.
3. Вынести camera helper только после Play-теста.
4. Core movement/turret behavior оставить в старом скрипте до появления тестируемого replacement.

### `StarterGui/HUD/WOBHudController`

Вероятно смешанные ответственности:

- чтение health/reload state;
- форматирование текста;
- показ feedback;
- показ hint;
- возможная обработка restart/reload hints.

Что опасно менять:

- имена UI элементов;
- источник health/reload state;
- timing feedback labels.

Безопасный strangler refactor позже:

1. Вынести только UI formatting.
2. Вынести constants для цветов/текстов/durations.
3. Не менять контракт получения данных до отдельной задачи.

## Safe extraction candidates

Эти части безопаснее всего выносить первыми, но только после просмотра исходника соответствующих Studio-скриптов:

- configs: health, projectile speed, projectile damage, reload time, max ricochets, tank speed, turret speed, respawn delay, spawn positions;
- constants: имена объектов `Map`, `Runtime`, `DummyTank`, `PlayerTankPrototype`, имена UI-элементов, collision tags, colors;
- helper utils: vector reflection, CFrame helpers, clamp/lerp helpers, safe instance lookup, cleanup helpers;
- projectile visuals: trail/glow/impact/ricochet effects, если они не считают damage и collision;
- UI formatting: health text, reload text, result/feedback labels, colors, short display helpers.

Не выносить первым:

- core gameplay loop;
- projectile collision and damage authority;
- tank movement feel;
- turret aiming behavior;
- respawn flow;
- match state, если он уже смешан с damage/respawn/UI.

## Updated Mechanics Matrix

| Механика | Статус | Основание |
| --- | --- | --- |
| Арена | Implemented | В Studio найден `Workspace/Map`. Качество стен и пригодность для рикошетов требуют Play-проверки. |
| Танк игрока | Implemented | В Studio найден `Workspace/PlayerTankPrototype`. Внутренняя структура модели требует Studio check. |
| Движение корпуса | Partially implemented | Есть `WOBClientController` и `PlayerTankPrototype`; точный код движения не виден из файловой системы. |
| Независимая башня | Partially implemented | Вероятно находится в `WOBClientController`/модели танка, но нужно подтвердить исходником и Play-тестом. |
| Прицеливание | Partially implemented | Вероятно client-side в `WOBClientController`; расчет mouse/camera требует Studio source check. |
| Выстрел | Partially implemented | Есть `Reload UI`, `WOBGameplayServer` и projectile visual system; точный fire flow требует source check. |
| Снаряд | Partially implemented | Есть `WOBProjectileVisualEnhancer` и `Workspace/Runtime`; создание/движение снарядов нужно подтвердить в `WOBGameplayServer`. |
| Рикошет от стен | Partially implemented | Центральная механика прототипа вероятно в `WOBGameplayServer`; точный алгоритм отражения требует source check. |
| Лимит рикошетов | Unknown | Наличие лимита 3 не подтверждено объектной структурой. Нужно смотреть `WOBGameplayServer`. |
| Самопопадание | Unknown | Нельзя подтвердить без просмотра hit detection и filtering logic. |
| Урон | Partially implemented | `DummyHp UI`, `DummyTank` и `WOBGameplayServer` указывают на damage flow, но правила не подтверждены исходником. |
| Урон по углу | Missing | По GDD это Future. Нет признаков отдельной angle damage системы. |
| Здоровье | Partially implemented | Есть `DummyHp UI`; здоровье игрока и dummy нужно подтвердить source check. |
| Смерть | Partially implemented | `WOBDummyRespawnServer` указывает на death/respawn flow для dummy. |
| Победа/поражение | Unknown | `FeedbackLabel` может показывать результат, но match state не подтвержден. |
| Рестарт | Partially implemented | Есть dummy respawn, но полноценный restart матча не подтвержден. |
| UI здоровья | Partially implemented | Есть `StarterGui/HUD/DummyHp UI` и `WOBHudController`; player health UI не подтвержден. |
| UI результата | Partially implemented | Есть `FeedbackLabel`, но формат victory/defeat не подтвержден. |
| Бот/болванка | Implemented | В Studio найден `Workspace/DummyTank` и `WOBDummyRespawnServer`. |
| Client/server разделение | Partially implemented | Есть server services, client controller и HUD controller, но они живут в `.rbxl`, а контракты между ними неизвестны. |
| Конфиги | Missing | Отдельных Rojo config modules нет. Константы могут быть зашиты внутри Studio-скриптов. |

## Suspected Dependencies

- `WOBGameplayServer` likely depends on `Workspace/Map`, `Workspace/Runtime`, `Workspace/DummyTank`, `Workspace/PlayerTankPrototype`, maybe HUD state objects or RemoteEvents.
- `WOBClientController` likely depends on `Workspace/PlayerTankPrototype`, camera, input services, mouse position, maybe `Controllers/`.
- `WOBHudController` likely depends on `StarterGui/HUD/MainPanel`, `DummyHp UI`, `Reload UI`, `FeedbackLabel`, `HintLabel`, and some replicated state.
- `WOBDummyRespawnServer` likely depends on `Workspace/DummyTank`, spawn position, health state, and maybe `WOBGameplayServer`.
- `WOBPerformanceServer` likely depends on `Workspace/Runtime` and temporary projectile/VFX objects.
- `WOBProjectileVisualEnhancer` likely depends on projectile instances created by gameplay logic and may write visual children into `Workspace/Runtime`.

Unknown dependencies to verify in Studio:

- RemoteEvents / BindableEvents;
- Attributes / ValueObjects used as state;
- CollectionService tags;
- exact Part names inside `DummyTank` and `PlayerTankPrototype`;
- exact child names inside `Map`, `Runtime`, `TestObjects`;
- whether UI reads server state through remotes or directly through replicated objects.

## Risks

- The main prototype behavior is embedded in `.rbxl`, so Rider/Codex cannot safely edit or inspect it as normal files.
- Future Rojo code can duplicate existing Studio logic if implementation starts before script source audit.
- Object names in Workspace and HUD are likely used as hard-coded dependencies.
- `WOBGameplayServer` may own too many responsibilities and should be treated as fragile.
- Projectile visuals may be mixed with gameplay collision or damage unless proven otherwise.
- UI may be tightly coupled to exact label/frame names.
- Respawn may reset more than dummy state, including UI, runtime objects or gameplay flags.
- Smoke-test files in `src/` are harmless now, but they do not represent the real prototype architecture.

## What Not To Touch First

- `RicochetTanksPrototype.rbxl`
- `default.project.json`
- `ServerScriptService/Services/WOBGameplayServer`
- `StarterPlayer/StarterPlayerScripts/WOBClientController`
- `Workspace/PlayerTankPrototype`
- `Workspace/DummyTank`
- `Workspace/Runtime`
- `StarterGui/HUD` element names
- projectile collision/damage logic
- respawn flow
- object names used by existing Studio scripts

## Recommended Next Step

Manual script source snapshot:

1. Открыть `RicochetTanksPrototype.rbxl` в Roblox Studio.
2. Открыть исходники `WOBGameplayServer`, `WOBClientController`, `WOBHudController`, `WOBDummyRespawnServer`, `WOBPerformanceServer` и `WOBProjectileVisualEnhancer`.
3. Вручную скопировать их код в `docs/studio_scripts_snapshot/` по инструкции из `docs/studio_scripts_snapshot/README.md`.
4. Не менять оригинальные Studio-скрипты и не переносить их в `src/`.
5. После snapshot обновить этот аудит разделом `Script Source Notes`.

Первый технический шаг после анализа snapshot: вынести только configs/constants в `src/ReplicatedStorage/Shared/Configs` через strangler refactor, не трогая core gameplay loop.
