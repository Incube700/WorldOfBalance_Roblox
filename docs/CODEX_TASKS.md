# World of Balance: Ricochet Tanks — Codex Tasks

## Правила для Codex перед любой задачей

- Не делать сразу весь проект.
- Не переписывать сцену без разрешения.
- Не удалять `RicochetTanksPrototype.rbxl`.
- Не менять Rojo config без необходимости.
- Перед изменениями смотреть текущую структуру проекта.
- Перед изменениями выполнять `git status`.
- Работать маленькими задачами с понятным результатом.
- После каждого небольшого этапа предлагать коммит.
- Если нужно изменить архитектуру, сначала описать причину в `docs/TECH_CONTEXT.md` или отдельной заметке задачи.
- Не добавлять зависимости без необходимости.
- Не создавать случайные тестовые файлы вне Roblox workflow.
- Не смешивать в одном изменении механику, UI, сцену и документацию без причины.

## Текущий статус

- Проект: `World of Balance: Ricochet Tanks`.
- Workflow: Rider + Codex + Rojo + Roblox Studio + GitHub Desktop.
- Rojo установлен и подключается через plugin в Roblox Studio.
- В корне проекта есть `default.project.json`.
- В корне проекта есть локальная сцена `RicochetTanksPrototype.rbxl`.
- Код должен жить в `src/`.
- Документация должна жить в `docs/`.
- MVP пока не реализован как механика. Текущий фокус — документация, структура и затем маленькие проверяемые шаги.

## Milestone 0 — Документация и структура

### Task 00.01 — Создать документацию проекта

- Цель: создать рабочие документы для GDD, технического контекста и плана задач.
- Файлы можно трогать: `docs/GDD.md`, `docs/TECH_CONTEXT.md`, `docs/CODEX_TASKS.md`, `.gitignore` только при необходимости.
- Ожидаемый результат: в проекте есть единый контекст разработки MVP на русском языке.
- Критерий проверки в Roblox Studio: не требуется, задача не меняет механику.
- Какой коммит сделать: `Add project documentation and development context`.

### Task 00.02 — Проверить структуру Rojo

- Цель: убедиться, что `default.project.json` маппит `src/` в правильные сервисы Roblox.
- Файлы можно трогать: `default.project.json` только если найдено реальное несоответствие; `docs/TECH_CONTEXT.md` для фиксации результата.
- Ожидаемый результат: понятен текущий путь синхронизации `Shared`, `Server`, `Client`.
- Критерий проверки в Roblox Studio: Rojo plugin подключается, объекты из `src/` появляются в Studio.
- Какой коммит сделать: `Verify Rojo project structure`.

### Task 00.03 — Подготовить папки src под MVP

- Цель: создать только те подпапки, которые нужны для ближайшей механики.
- Файлы можно трогать: `src/ReplicatedStorage/Shared/Configs/`, `src/ReplicatedStorage/Shared/Utils/`, `src/ServerScriptService/Server/`, `src/StarterPlayer/StarterPlayerScripts/Client/`.
- Ожидаемый результат: структура поддерживает отдельные модули танка, снаряда, арены и UI.
- Критерий проверки в Roblox Studio: Rojo синхронизируется без ошибок.
- Какой коммит сделать: `Prepare source folders for MVP`.

### Task 00.04 — Prepare read-only configs

- Цель: описать будущий вынос hard-coded constants без изменения поведения прототипа.
- Файлы можно трогать: `docs/CONFIG_EXTRACTION_PLAN.md`, `docs/TECH_CONTEXT.md`, `docs/CODEX_TASKS.md`.
- Ожидаемый результат: есть план config extraction по ответственности: `TankConfig`, `WeaponConfig`, `ProjectileCatalog`, `ProjectileVisualConfig`, `DummyRespawnConfig`, `CameraConfig`, `HudConfig`, `PerformanceConfig`.
- Критерий проверки в Roblox Studio: не требуется, задача только документационная.
- Какой коммит сделать: `Add config extraction plan`.

### Task 00.05 — Create config modules without wiring

- Цель: создать read-only ModuleScript configs в `src/ReplicatedStorage/Shared/Configs/` без подключения к Studio gameplay scripts.
- Файлы можно трогать: только новые config modules в `src/ReplicatedStorage/Shared/Configs/` и документацию, если нужно уточнить результат.
- Ожидаемый результат: config modules существуют, но `WOBGameplayServer`, `WOBClientController`, `WOBHudController` и другие Studio scripts еще не используют их.
- Критерий проверки в Roblox Studio: Rojo синхронизируется без ошибок; Play behavior не меняется.
- Какой коммит сделать: `Create read-only config modules`.

### Task 00.06 — Wire first responsibility config in smallest possible slice

- Цель: подключить только одну безопасную группу constants из одного responsibility config.
- Файлы можно трогать: один выбранный config module и минимальный один потребитель, только после отдельного согласования.
- Ожидаемый результат: поведение в Play Mode не меняется; config начинает использоваться в одном узком месте.
- Критерий проверки в Roblox Studio: Play без ошибок, проверка именно той механики/визуала, к которой подключен config.
- Какой коммит сделать: `Wire first config slice`.

Важно: не создавать и не подключать `GameplayConfig` как общий контейнер. Если позже понадобится `GameplayConfig`, он может содержать только global match/round values, которых сейчас в snapshot нет.

## Milestone 1 — Рабочая песочница

### Task 01.01 — Создать простую тестовую арену, если её нет

- Цель: получить компактную арену для проверки движения и рикошетов.
- Файлы можно трогать: `src/ServerScriptService/Server/Arena/`, `src/ReplicatedStorage/Shared/Configs/ArenaConfig.luau`, сцену `.rbxl` только если пользователь явно согласовал ручные изменения в Studio.
- Ожидаемый результат: при запуске есть пол, стены по периметру и, при необходимости, одно центральное препятствие.
- Критерий проверки в Roblox Studio: после `Play` арена видна сверху и не мешает тестировать рикошеты.
- Какой коммит сделать: `Add prototype arena`.

### Task 01.02 — Добавить точки появления игрока и цели

- Цель: задать стабильные стартовые позиции.
- Файлы можно трогать: `src/ServerScriptService/Server/Arena/`, `src/ReplicatedStorage/Shared/Configs/ArenaConfig.luau`.
- Ожидаемый результат: игрок и цель появляются в предсказуемых местах.
- Критерий проверки в Roblox Studio: при каждом `Play` позиции одинаковые и не пересекаются со стенами.
- Какой коммит сделать: `Add prototype spawn points`.

## Milestone 2 — Танк игрока

### Task 02.01 — Добавить конфиг танка

- Цель: вынести параметры танка из логики.
- Файлы можно трогать: `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`.
- Ожидаемый результат: скорость, скорость поворота, здоровье и размеры танка заданы в одном месте.
- Критерий проверки в Roblox Studio: Rojo синхронизирует ModuleScript без ошибок.
- Какой коммит сделать: `Add tank config`.

### Task 02.02 — Добавить базовое движение корпуса

- Цель: сделать управление корпусом танка с клавиатуры.
- Файлы можно трогать: `src/StarterPlayer/StarterPlayerScripts/Client/Input/`, `src/ServerScriptService/Server/Tanks/`, `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`.
- Ожидаемый результат: корпус едет вперед/назад и поворачивается.
- Критерий проверки в Roblox Studio: при `Play` клавиши `W`, `A`, `S`, `D` управляют корпусом.
- Какой коммит сделать: `Add basic tank body movement`.

### Task 02.03 — Ограничить движение границами арены

- Цель: не дать танку проходить сквозь стены или покидать арену.
- Файлы можно трогать: `src/ServerScriptService/Server/Tanks/`, `src/ServerScriptService/Server/Arena/`, `src/ReplicatedStorage/Shared/Configs/`.
- Ожидаемый результат: танк сталкивается со стенами или корректно ограничивается ареной.
- Критерий проверки в Roblox Studio: игрок не может выехать за пределы тестовой карты.
- Какой коммит сделать: `Constrain tank movement to arena`.

## Milestone 3 — Башня и стрельба

### Task 03.01 — Добавить независимый поворот башни

- Цель: отделить направление башни от направления корпуса.
- Файлы можно трогать: `src/StarterPlayer/StarterPlayerScripts/Client/Input/`, `src/StarterPlayer/StarterPlayerScripts/Client/Camera/`, `src/ServerScriptService/Server/Tanks/`, `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`.
- Ожидаемый результат: корпус может ехать в одну сторону, а башня смотреть в другую.
- Критерий проверки в Roblox Studio: мышь меняет направление башни независимо от `WASD`.
- Какой коммит сделать: `Add independent turret aiming`.

### Task 03.02 — Добавить ввод выстрела и задержку

- Цель: обработать команду выстрела и не позволять стрелять каждый кадр.
- Файлы можно трогать: `src/StarterPlayer/StarterPlayerScripts/Client/Input/`, `src/ServerScriptService/Server/Projectiles/`, `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`.
- Ожидаемый результат: левая кнопка мыши отправляет команду выстрела с cooldown.
- Критерий проверки в Roblox Studio: при клике создается не больше одного выстрела за заданный интервал.
- Какой коммит сделать: `Add fire input and cooldown`.

## Milestone 4 — Снаряд и рикошеты

### Task 04.01 — Добавить создание снаряда

- Цель: создать видимый снаряд из дула башни.
- Файлы можно трогать: `src/ServerScriptService/Server/Projectiles/`, `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`.
- Ожидаемый результат: при выстреле появляется объект снаряда в правильной позиции и направлении.
- Критерий проверки в Roblox Studio: после клика снаряд появляется перед башней.
- Какой коммит сделать: `Add projectile spawning`.

### Task 04.02 — Добавить движение снаряда

- Цель: заставить снаряд лететь быстро, но читабельно.
- Файлы можно трогать: `src/ServerScriptService/Server/Projectiles/`, `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`, `src/ReplicatedStorage/Shared/Utils/`.
- Ожидаемый результат: снаряд летит по прямой с конфигурируемой скоростью.
- Критерий проверки в Roblox Studio: траектория снаряда видна, снаряд не зависает после выстрела.
- Какой коммит сделать: `Add projectile movement`.

### Task 04.03 — Добавить рикошет от стен

- Цель: реализовать отражение направления снаряда от стен.
- Файлы можно трогать: `src/ServerScriptService/Server/Projectiles/`, `src/ServerScriptService/Server/Arena/`, `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`, `src/ReplicatedStorage/Shared/Utils/`.
- Ожидаемый результат: снаряд отражается от стен и уничтожается после лимита рикошетов.
- Критерий проверки в Roblox Studio: снаряд делает до 3 рикошетов и затем исчезает.
- Какой коммит сделать: `Add projectile wall ricochets`.

### Task 04.04 — Разрешить попадание по стрелявшему

- Цель: сделать self-hit частью игрового риска.
- Файлы можно трогать: `src/ServerScriptService/Server/Projectiles/`, `src/ServerScriptService/Server/Tanks/`.
- Ожидаемый результат: снаряд после выстрела и рикошета может попасть в исходный танк.
- Критерий проверки в Roblox Studio: игрок может получить урон от собственного снаряда.
- Какой коммит сделать: `Allow projectile self damage`.

## Milestone 5 — Урон и смерть

### Task 05.01 — Добавить здоровье танка

- Цель: хранить и менять здоровье игрока и цели.
- Файлы можно трогать: `src/ServerScriptService/Server/Tanks/`, `src/ServerScriptService/Server/Gameplay/`, `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`.
- Ожидаемый результат: у каждого танка есть здоровье, смерть наступает при `0`.
- Критерий проверки в Roblox Studio: здоровье меняется через тестовый вызов или попадание снаряда.
- Какой коммит сделать: `Add tank health state`.

### Task 05.02 — Добавить урон от снаряда

- Цель: связать попадание снаряда с уменьшением здоровья.
- Файлы можно трогать: `src/ServerScriptService/Server/Projectiles/`, `src/ServerScriptService/Server/Tanks/`, `src/ServerScriptService/Server/Gameplay/`, `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`.
- Ожидаемый результат: попадание снаряда наносит фиксированный урон.
- Критерий проверки в Roblox Studio: после попадания здоровье цели или игрока уменьшается.
- Какой коммит сделать: `Apply projectile damage to tanks`.

### Task 05.03 — Подготовить место под урон по углу

- Цель: не реализовывать сложную броню сразу, но выделить будущую точку расширения.
- Файлы можно трогать: `docs/GDD.md`, `docs/TECH_CONTEXT.md`, при необходимости `src/ServerScriptService/Server/Tanks/`.
- Ожидаемый результат: фиксированный урон остается MVP-логикой, а расчет угла явно описан как Future.
- Критерий проверки в Roblox Studio: поведение MVP не меняется.
- Какой коммит сделать: `Document future angle damage model`.

## Milestone 6 — Победа/поражение/рестарт

### Task 06.01 — Добавить условия победы и поражения

- Цель: завершать матч при уничтожении игрока или противника.
- Файлы можно трогать: `src/ServerScriptService/Server/Match/`, `src/ServerScriptService/Server/Tanks/`, `src/ServerScriptService/Server/Gameplay/`.
- Ожидаемый результат: матч имеет состояния `Playing`, `Victory`, `Defeat`.
- Критерий проверки в Roblox Studio: уничтожение цели показывает победу, уничтожение игрока показывает поражение.
- Какой коммит сделать: `Add match win and loss conditions`.

### Task 06.02 — Добавить базовый рестарт

- Цель: сбрасывать матч без ручного перезапуска всей разработки.
- Файлы можно трогать: `src/ServerScriptService/Server/Match/`, `src/ServerScriptService/Server/Tanks/`, `src/StarterPlayer/StarterPlayerScripts/Client/UI/`, `src/StarterPlayer/StarterPlayerScripts/Client/Input/`.
- Ожидаемый результат: после победы или поражения можно начать заново.
- Критерий проверки в Roblox Studio: после рестарта здоровье, позиции и статус матча сброшены.
- Какой коммит сделать: `Add basic match restart`.

## Milestone 7 — Минимальный UI

### Task 07.01 — Добавить минимальный UI здоровья/результата

- Цель: показать игроку здоровье и результат матча.
- Файлы можно трогать: `src/StarterPlayer/StarterPlayerScripts/Client/UI/`, `src/ReplicatedStorage/Shared/Remotes/`, `src/ServerScriptService/Server/Match/`.
- Ожидаемый результат: UI показывает здоровье игрока, здоровье цели и статус матча.
- Критерий проверки в Roblox Studio: при попадании числа здоровья обновляются, при конце матча появляется результат.
- Какой коммит сделать: `Add minimal match HUD`.

### Task 07.02 — Добавить индикатор перезарядки

- Цель: сделать задержку выстрела понятной.
- Файлы можно трогать: `src/StarterPlayer/StarterPlayerScripts/Client/UI/`, `src/ReplicatedStorage/Shared/Configs/ProjectileConfig.luau`.
- Ожидаемый результат: игрок видит, когда можно стрелять снова.
- Критерий проверки в Roblox Studio: UI или простой индикатор меняется после выстрела и возвращается после cooldown.
- Какой коммит сделать: `Add fire cooldown indicator`.

## Milestone 8 — Полировка MVP

### Task 08.01 — Улучшить читаемость прототипа

- Цель: сделать танки, стены, снаряды и цель визуально различимыми.
- Файлы можно трогать: `src/ServerScriptService/Server/Arena/`, `src/ServerScriptService/Server/Tanks/`, `src/ServerScriptService/Server/Projectiles/`, сцену `.rbxl` только после согласования.
- Ожидаемый результат: игрок легко читает арену, угол башни и полет снаряда.
- Критерий проверки в Roblox Studio: на Play без объяснений понятно, где игрок, цель, стены и снаряд.
- Какой коммит сделать: `Improve MVP readability`.

### Task 08.02 — Проверить MVP по GDD

- Цель: пройти критерии готовности первого прототипа из `docs/GDD.md`.
- Файлы можно трогать: `docs/GDD.md`, `docs/CODEX_TASKS.md`, мелкие исправления в `src/` по найденным дефектам.
- Ожидаемый результат: список критериев либо выполнен, либо имеет явные оставшиеся задачи.
- Критерий проверки в Roblox Studio: ручной проход Play проверяет движение, башню, выстрел, рикошеты, урон, победу/поражение и рестарт.
- Какой коммит сделать: `Validate MVP prototype against GDD`.

### Task 08.03 — Убрать временные тестовые проверки

- Цель: удалить или заменить одноразовые hello/test скрипты, когда полноценные bootstrap-скрипты уже работают.
- Файлы можно трогать: временные файлы в `src/ServerScriptService/Server/` и `src/StarterPlayer/StarterPlayerScripts/Client/`, только если они больше не нужны.
- Ожидаемый результат: в проекте нет случайных тестовых файлов, мешающих чтению структуры.
- Критерий проверки в Roblox Studio: Rojo подключается, Play не показывает лишние тестовые сообщения.
- Какой коммит сделать: `Remove obsolete Rojo smoke test scripts`.
