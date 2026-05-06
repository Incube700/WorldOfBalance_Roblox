# World of Balance: Ricochet Tanks - Project Audit

Дата аудита: 2026-05-06.

## Область аудита

Аудит выполнен по файловой системе проекта:

- `docs/GDD.md`
- `docs/TECH_CONTEXT.md`
- `docs/CODEX_TASKS.md`
- `default.project.json`
- все найденные `*.luau`, `*.lua`, `*.server.luau`, `*.client.luau` в `src/`

Сцена `RicochetTanksPrototype.rbxl` не изменялась и не разбиралась как бинарный файл. Если внутри сцены есть вручную созданные Scripts, LocalScripts, ModuleScripts, модели арены, танков или UI, их статус сейчас: **Unknown / requires manual Roblox Studio check**.

## Контекст Rojo

`default.project.json` маппит только три зоны:

- `src/ReplicatedStorage/Shared` -> `ReplicatedStorage.Shared`
- `src/ServerScriptService/Server` -> `ServerScriptService.Server`
- `src/StarterPlayer/StarterPlayerScripts/Client` -> `StarterPlayer.StarterPlayerScripts.Client`

Текущая структура `src/` минимальная:

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

## Найденные скрипты в src

### `src/ServerScriptService/Server/ServerHello.server.luau`

- Тип: Server Script.
- Что делает: выводит в Output сообщение `"[SERVER] Rojo connected. Hello from Rider!"`.
- Какие механики содержит: игровых механик нет. Это smoke-test для проверки, что Rojo синхронизирует серверный скрипт из Rider в Roblox Studio.
- Статус: Review.
- Комментарий: файл полезен как временная проверка Rojo workflow. После появления нормального серверного bootstrap-скрипта его можно рассмотреть как Delete candidate отдельной задачей.

### `src/StarterPlayer/StarterPlayerScripts/Client/ClientHello.client.luau`

- Тип: Client Script.
- Что делает: выводит в Output сообщение `"[CLIENT] Rojo connected. Hello from Rider!"`.
- Какие механики содержит: игровых механик нет. Это smoke-test для проверки, что Rojo синхронизирует клиентский скрипт из Rider в Roblox Studio.
- Статус: Review.
- Комментарий: файл полезен как временная проверка клиентской части Rojo workflow. После появления нормального клиентского bootstrap-скрипта его можно рассмотреть как Delete candidate отдельной задачей.

## Скрипты вне src

В файловой системе проекта не найдено других `*.luau` или `*.lua` скриптов вне `src/`.

Возможные скрипты внутри `RicochetTanksPrototype.rbxl`: **Unknown / requires manual Roblox Studio check**.

## ModuleScript audit

ModuleScript-файлы в `src/` не найдены.

Следующие ожидаемые модули из технического контекста пока отсутствуют:

- `TankConfig`
- `ProjectileConfig`
- `ArenaConfig`
- `TankMovement`
- `TurretAiming`
- `ProjectileService`
- `HealthService`
- `MatchService`
- `InputController`
- `CameraController`
- `HudController`

## Монолитный скрипт

В `src/` монолитного скрипта нет.

Причина: оба найденных файла состоят из одного `print` и не содержат игровой логики.

Потенциальный монолит внутри `RicochetTanksPrototype.rbxl`: **Unknown / requires manual Roblox Studio check**.

Если при ручной проверке Roblox Studio будет найден большой Script, который одновременно создает арену, двигает танк, обрабатывает ввод, стреляет, считает урон и управляет матчем, его нельзя резко переписывать. Безопасный подход:

1. Зафиксировать текущее поведение вручную через Play-тест.
2. Описать ответственности монолита в этом документе.
3. Вынести только конфиги без изменения поведения.
4. Создать новый модуль рядом и направить туда одну ответственность, например расчет движения или параметры снаряда.
5. Оставить старый скрипт как точку запуска, пока новые модули не покроют поведение.
6. После каждого маленького шага проверять Play в Roblox Studio.

## Матрица реализации механик

| Механика | Статус | Основание |
| --- | --- | --- |
| Арена | Unknown | В `src/` нет arena-скриптов. Геометрия может быть вручную размещена внутри `RicochetTanksPrototype.rbxl`, требуется проверка в Studio. |
| Танк игрока | Unknown | В `src/` нет модели или логики танка. Возможная модель внутри `.rbxl` не видна из файловой системы. |
| Движение корпуса | Missing | Нет input-кода, movement-кода или серверной логики движения. |
| Независимая башня | Missing | Нет кода башни, turret aiming или модели башни в `src/`. |
| Прицеливание | Missing | Нет клиентского ввода мыши, камеры или расчета направления. |
| Выстрел | Missing | Нет обработки fire input, cooldown или server-side команды выстрела. |
| Снаряд | Missing | Нет `ProjectileConfig`, `ProjectileService` или кода создания снарядов. |
| Рикошет от стен | Missing | Нет кода столкновения, raycast или отражения направления. |
| Лимит рикошетов | Missing | Нет состояния снаряда и счетчика рикошетов. |
| Самопопадание | Missing | Нет снарядов и нет hit detection. |
| Урон | Missing | Нет кода применения урона. |
| Урон по углу | Missing | По GDD это Future. В `src/` реализации нет. |
| Здоровье | Missing | Нет `HealthService`, health state или конфигов здоровья. |
| Смерть | Missing | Нет проверки здоровья `0` и уничтожения танка. |
| Победа/поражение | Missing | Нет `MatchService` или состояния матча. |
| Рестарт | Missing | Нет restart flow, кнопки или reset-функции. |
| UI здоровья | Missing | Нет клиентского UI-кода. |
| UI результата | Missing | Нет UI статуса матча. |
| Бот/болванка | Unknown | В `src/` нет цели или AI. Возможная болванка внутри `.rbxl` требует проверки в Studio. |
| Client/server разделение | Partially implemented | Rojo-маппинг и smoke-test скрипты есть на клиенте и сервере, но gameplay-разделения пока нет. |
| Конфиги | Missing | В `src/ReplicatedStorage/Shared` нет конфиг-модулей. |

## Риски

- Вся реальная сцена хранится в бинарном `.rbxl`, поэтому часть объектов и встроенных скриптов может быть невидима в обычном файловом аудите.
- Сейчас в `src/` нет gameplay-кода, поэтому нельзя считать MVP реализованным по документации.
- Если внутри Studio уже есть логика, она может конфликтовать с будущими Rojo-скриптами.
- Если начать создавать механику без проверки Explorer в Roblox Studio, можно продублировать арену, танк или UI.
- Smoke-test скрипты полезны для проверки Rojo, но позже станут шумом в Output.

## Что нельзя трогать без отдельной задачи

- `RicochetTanksPrototype.rbxl`
- `default.project.json`
- существующие smoke-test скрипты, если задача не про их удаление
- Rojo-маппинг
- любые вручную созданные объекты в Roblox Studio
- будущую архитектуру client/server без отдельного описания причины

## Рекомендованный следующий шаг

Открыть `RicochetTanksPrototype.rbxl` в Roblox Studio и вручную проверить Explorer: есть ли внутри сцены арена, танк, болванка, UI или встроенные Scripts/LocalScripts/ModuleScripts. После проверки обновить этот аудит коротким разделом `Manual Studio Check`, а затем переходить к Task 00.03 или Task 01.01.
