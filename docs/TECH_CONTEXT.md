# World of Balance: Ricochet Tanks — Technical Context

## Текущий стек

- Движок: Roblox Studio.
- Язык: Luau.
- Редактор кода: Rider.
- Синхронизация кода: Rojo.
- Сцена: локальный `.rbxl` файл.
- Контроль версий: Git и GitHub Desktop.

Важно: это Roblox-проект. Здесь не используется C# и не используется Unity.

## Как запускать проект

1. Открыть проект в Rider.
2. Открыть терминал в корне проекта:

   ```bash
   /Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox
   ```

3. Запустить Rojo:

   ```bash
   rojo serve
   ```

4. Открыть `RicochetTanksPrototype.rbxl` в Roblox Studio.
5. В Roblox Studio открыть Rojo plugin.
6. Нажать `Connect`.
7. Дождаться синхронизации дерева из `src/`.
8. Нажать `Play`.
9. Смотреть ошибки и тестовые сообщения в `Output`.

## Как работает Rojo

Rojo читает `default.project.json` в корне проекта и синхронизирует папки из `src/` в Roblox Studio.

Текущие ключевые маппинги:

- `src/ReplicatedStorage/Shared` -> `ReplicatedStorage.Shared`;
- `src/ServerScriptService/Server` -> `ServerScriptService.Server`;
- `src/StarterPlayer/StarterPlayerScripts/Client` -> `StarterPlayer.StarterPlayerScripts.Client`.

Rojo синхронизирует код и объекты из файловой системы, но не заменяет сохранение сцены. Изменения, сделанные вручную в Roblox Studio, нужно сохранять в `.rbxl` файл через `File -> Save to File`.

## Структура проекта

Текущая обязательная структура:

```text
WorldOfBalanceRoblox/
  default.project.json
  RicochetTanksPrototype.rbxl
  src/
    ReplicatedStorage/
      Shared/
    ServerScriptService/
      Server/
    StarterPlayer/
      StarterPlayerScripts/
        Client/
  docs/
```

Предпочтительная структура `src/` для MVP:

```text
src/
  ReplicatedStorage/
    Shared/
      Configs/
      Utils/
      Remotes/
  ServerScriptService/
    Server/
      Bootstrap/
      Gameplay/
      Tanks/
      Projectiles/
      Arena/
      Match/
  StarterPlayer/
    StarterPlayerScripts/
      Client/
        Bootstrap/
        Input/
        Camera/
        UI/
```

Папки можно создавать постепенно по мере задач. Не нужно заранее плодить пустую структуру без кода или понятной причины.

## Где лежит сцена

Сцена лежит в корне проекта:

```text
RicochetTanksPrototype.rbxl
```

Правила:

- не удалять `.rbxl`;
- не переименовывать `.rbxl` без отдельной задачи;
- не заменять сцену новой пустой сценой;
- после изменений в Roblox Studio сохранять сцену через `File -> Save to File`.

## Где писать код

Весь Luau-код для Rojo workflow должен лежать внутри `src/`.

Основные зоны:

- серверный код: `src/ServerScriptService/Server/`;
- клиентский код: `src/StarterPlayer/StarterPlayerScripts/Client/`;
- общий код и конфиги: `src/ReplicatedStorage/Shared/`.

Не нужно добавлять случайные `.cs`, `.js` или другие файлы, не относящиеся к Roblox-прототипу.

## Client/Server/Shared разделение

### Server

Сервер отвечает за авторитетную игровую логику:

- состояние матча;
- создание и уничтожение снарядов;
- урон;
- здоровье;
- смерть танков;
- победу и поражение;
- серверную валидацию действий игрока.

### Client

Клиент отвечает за локальные действия игрока:

- ввод с клавиатуры и мыши;
- камеру;
- локальные визуальные реакции;
- UI;
- отправку намерений игрока на сервер, если используется client/server схема.

### Shared

Общий слой содержит:

- конфиги танков;
- конфиги снарядов;
- конфиги арены;
- общие утилиты;
- определения Remotes, если они нужны.

Shared не должен превращаться в папку для всего подряд.

## Dependency separation

Конфиги должны группироваться по будущей ответственности системы, а не по тому, где значения сейчас лежат в монолитном Studio-скрипте.

Правила:

- `TankConfig` отвечает за параметры танка и заметки о модели танка.
- `WeaponConfig` отвечает за правила выстрела и выбор типа снаряда.
- `ProjectileCatalog` отвечает за механику снарядов: скорость, урон, lifetime, лимит рикошетов и behavior type.
- `ProjectileVisualConfig` отвечает только за визуальную читаемость снарядов и VFX.
- `DummyRespawnConfig` отвечает за reset/respawn dummy и связанные reset colors.
- `HudConfig` отвечает за отображение и форматирование UI.
- `PerformanceConfig` отвечает за lighting/performance profile.
- Projectile mechanics должны быть отделены от weapon firing и projectile visuals.
- Server gameplay logic не должен зависеть от UI или visual configs.
- Visual configs могут ссылаться на projectile type ids, но не должны владеть правилами damage, speed, lifetime или ricochet behavior.
- `GameplayConfig` не используется как свалка. Если он понадобится позже, он должен содержать только global match/round values, например round duration, round start delay, round end delay и score to win.

## Правила сохранения сцены

- Код из `src/` Git видит сразу.
- Изменения в Roblox Studio Git увидит только после сохранения `.rbxl` на диск.
- После ручных изменений сцены нужно выполнить `File -> Save to File`.
- Перед коммитом нужно проверить, что изменился именно ожидаемый `.rbxl`, а не временный `.lock`.
- Rojo serve должен быть остановлен только если он больше не нужен для теста.

## Git workflow

Перед любой задачей:

```bash
git status
```

После изменений:

1. Проверить список измененных файлов.
2. Если менялась сцена в Roblox Studio, выполнить `File -> Save to File`.
3. Не коммитить временные файлы.
4. Коммитить маленькими логическими шагами.
5. Писать понятные сообщения коммитов.

Не коммитить:

- `.rbxl.lock`;
- `.DS_Store`;
- `.idea/`;
- любые временные `.lock` файлы.

## .gitignore правила

Минимальный `.gitignore` для проекта:

```gitignore
.DS_Store
.idea/
*.lock
```

Эти правила защищают репозиторий от macOS-мусора, Rider-настроек и временных lock-файлов Roblox/Rojo.

Если позже появятся новые инструменты, `.gitignore` можно расширять отдельной маленькой задачей. Нельзя добавлять широкие правила, которые случайно исключат `src/`, `docs/`, `default.project.json` или `.rbxl` сцену.

## Архитектурные правила

- Не складывать всю игровую логику в один Script.
- Разделять input, movement, turret aiming, shooting, projectile behavior, health и match state.
- Не создавать большие god-object файлы.
- Использовать простую архитектуру с понятными ответственностями.
- Не добавлять DI-контейнеры на старте MVP.
- Конфиги держать отдельно от логики.
- Магические числа выносить в конфиг.
- Сервер должен быть источником истины для урона, смерти и матча.
- Временные упрощения допустимы, но должны быть явно отмечены.
- Каждый модуль должен иметь понятную ответственность и короткое имя.

## Правила именования файлов

Предпочтительные имена:

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

Правила:

- ModuleScript использовать там, где код переиспользуется или имеет отдельную ответственность.
- Script использовать для точек запуска и bootstrap-логики.
- LocalScript использовать для клиентского ввода, камеры и UI.
- Название файла должно объяснять ответственность без чтения содержимого.
- Не использовать названия вроде `Script1`, `Test`, `NewScript`, если это не временная одноразовая проверка.

## Временные технические упрощения MVP

Допустимо на первом этапе:

- один локальный игрок вместо полноценного PvP;
- простая болванка вместо AI;
- простая Part-арена вместо финального уровня;
- фиксированный урон вместо расчета угла брони;
- простые визуальные объекты без финального арта;
- минимальный UI;
- базовый рестарт без полноценного flow матча.

Недопустимо оставлять временное решение без пометки, если оно влияет на архитектуру будущего PvP или урон.

## Ограничения Roblox, которые важно помнить

- LocalScript работает только в клиентских контейнерах, например `StarterPlayerScripts`.
- Script в `ServerScriptService` не виден клиенту и подходит для серверной логики.
- Быстрые физические снаряды могут пролетать через тонкие объекты, если полагаться только на столкновения; для надежности лучше использовать raycast или шаговую проверку.
- Клиентские данные нельзя считать надежными для урона и победы.
- Репликация объектов имеет задержки, поэтому визуальные эффекты и авторитетная логика должны быть разделены.
- Network ownership может влиять на физику движущихся объектов.
- Roblox Studio не сохраняет `.rbxl` автоматически в Git после каждого изменения сцены.
- Пустые папки обычно не имеют смысла для Rojo без объектов или файлов.

## Что нельзя делать без отдельной задачи

- Удалять или заменять `RicochetTanksPrototype.rbxl`.
- Менять `default.project.json`, если текущий Rojo workflow работает.
- Переписывать весь проект целиком.
- Добавлять сетевой PvP.
- Добавлять магазин, валюты или монетизацию.
- Добавлять новые зависимости.
- Делать крупный рефакторинг структуры `src/`.
- Переносить проект на другой движок или язык.
- Коммитить `.lock`, `.DS_Store`, `.idea/`.
- Создавать механику, если текущая задача только про документацию.
