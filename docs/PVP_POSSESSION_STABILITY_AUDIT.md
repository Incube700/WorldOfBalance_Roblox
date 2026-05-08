# PVP Possession Stability Audit

Дата аудита: 2026-05-08

## Phase 0: текущее состояние без правок

Перед аудитом выполнены команды безопасности:

```text
pwd
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox

git status --short
<empty>

git branch --show-current
main

git remote -v
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (fetch)
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (push)
```

## Rojo mapping

`default.project.json` мапит только:

- `ReplicatedStorage/Shared` -> `src/ReplicatedStorage/Shared`
- `ServerScriptService/Server` -> `src/ServerScriptService/Server`
- `StarterPlayer/StarterPlayerScripts/Client` -> `src/StarterPlayer/StarterPlayerScripts/Client`

`StarterGui` и `Workspace` не мапятся через Rojo. Это значит, что танки, карта, spawn points и editable HUD живут в `.rbxl`/Studio command scripts, а не в `src`.

## Server files

`src/ServerScriptService/Server`:

- `ServerHello.server.luau`
- `WOBPvPBootstrap.server.luau`
- `Services/WOBPerformanceServer.server.luau`
- `Gameplay/WOBGameplayServer.server.luau`
- `Gameplay/PlayerTankSpawner.luau`
- `Gameplay/TankParticipantRegistry.luau`
- `Gameplay/Combat/ProjectileCombatService.luau`
- `Gameplay/Movement/TankMovementService.luau`
- `Gameplay/Players/PlayerPossessionService.luau`
- `Gameplay/Projectiles/ProjectileService.luau`
- `Gameplay/Round/RoundMatchService.luau`
- `Gameplay/Stats/MatchStatsService.luau`
- `Gameplay/Stats/PersistentPlayerStatsService.luau`
- `Gameplay/Tanks/TankSpawnResetService.luau`

`WOBPvPBootstrap.server.luau` лежит в `src/ServerScriptService/Server/WOBPvPBootstrap.server.luau`.

Сервисы после рефакторинга лежат в `src/ServerScriptService/Server/Gameplay/*`.

## Client files

`src/StarterPlayer/StarterPlayerScripts/Client`:

- `ClientHello.client.luau`
- `WOBAimLaser.client.luau`
- `WOBCombatFeedbackOverlay.client.luau`
- `WOBImpactFeedbackOverlay.client.luau`
- `WOBPlayableShell.client.luau`
- `WOBProjectileReadabilityOverlay.client.luau`
- `WOBRoundStatusOverlay.client.luau`
- `WOBTankInputController.client.luau`
- `WOBTankLocalTeamVisuals.client.luau`
- `WOBTankPossessionCamera.client.luau`

## Runtime/scene contract

Код ожидает:

- `Workspace/WOB_Generated`
- `Workspace/WOB_Generated/Map`
- `Workspace/WOB_Generated/TestObjects`
- `Workspace/WOB_Generated/TestObjects/PlayerTankPrototype`
- `Workspace/WOB_Generated/TestObjects/Player2TankPrototype`
- `Workspace/WOB_Generated/TestObjects/DummyTank`
- `Workspace/WOB_Generated/Runtime`
- `Workspace/WOB_Generated/Runtime/Projectiles`
- `Workspace/WOB_Generated/Runtime/VFX`
- `Workspace/WOB_Generated/Map/SpawnPoints/PlayerSpawn`
- `Workspace/WOB_Generated/Map/SpawnPoints/DummySpawn`
- `Workspace/WOB_Generated/Map/SpawnPoints/Player2Spawn`

`WOBPvPBootstrap` создаёт только `Runtime/Projectiles` и `Runtime/VFX`, если `WOB_Generated` уже существует.

`TankSpawnResetService` ищет spawn points строго в `Workspace.WOB_Generated.Map.SpawnPoints`.

## Snapshot `.rbxlx`

`RicochetTanksPrototype_snapshot.rbxlx` показывает старую структуру:

- `Workspace/WOB_Generated/Map/Spawns`, а не `Map/SpawnPoints`.
- `Spawns/PlayerSpawnPoint` и `Spawns/EnemySpawnPoint`, а не `PlayerSpawn`/`DummySpawn`/`Player2Spawn`.
- `Workspace/WOB_Generated/Runtime` существует, но в snapshot пустой.
- `Workspace/WOB_Generated/TestObjects/DummyTank` содержит `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes/*Armor`.
- `Workspace/WOB_Generated/TestObjects/PlayerTankPrototype` содержит `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes/*Armor`.
- `Player2TankPrototype` в snapshot отсутствует.
- `StarterGui/HUD` есть, но это legacy `HUD/MainPanel` + `WOBHudController`; `HUD/Root` отсутствует.
- Есть legacy `StarterPlayer/StarterPlayerScripts/WOBClientController`.
- Есть legacy `ServerScriptService/Services/WOBDummyRespawnServer`.

Текущий live log отличается от snapshot: клиент видит `Workspace.WOB_Generated.TestObjects.PlayerTankPrototype` как модель, у которой первым и единственным потомком является `Hitboxes`. Это означает, что текущий `.rbxl` уже разошёлся со snapshot или содержит wrapper/metadata model вместо полной физической модели.

## Tank creation/registration points

- `WOBGameplayServer.server.luau`
  - Берёт `testObjects:WaitForChild("PlayerTankPrototype")` и `DummyTank`.
  - Создаёт/получает `Player2TankPrototype` через `PlayerTankSpawner.getOrCreateRuntimePlayerTank`.
  - Регистрирует участников через локальный `registerTankParticipant`.

- `PlayerTankSpawner.luau`
  - Сейчас либо возвращает existing `Player2TankPrototype`, либо клонирует `PlayerTankPrototype`.
  - Слепо ждёт `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`.
  - Если source model является пустым wrapper, clone наследует пустой wrapper.

- `TankParticipantRegistry.luau`
  - Хранит `participant.Model`.
  - Ставит `TankId`, `OwnerUserId`, `OwnerName`, `TeamId`, `IsPlayerTank`, `ControllerType` на `participant.Model`.
  - Сейчас не проверяет, что `participant.Model` содержит `BasePart`.
  - Сейчас не различает wrapper model и physical model.

- `TankSpawnResetService.luau`
  - `layoutTank` ищет `Body/Turret/Barrel/ShootPoint` только как прямых детей.
  - Если чего-то нет, тихо `return`.
  - PrimaryPart ставится только после успешного нахождения прямых детей.

- `PlayerPossessionService.luau`
  - Назначает игрока на первый свободный `IsPlayerTank` participant.
  - Не создаёт физику, только ставит ownership attributes через registry.

## Client owned tank lookup

- `WOBTankPossessionCamera.client.luau`
  - Ищет owned tank среди прямых детей `TestObjects` по `OwnerUserId == LocalPlayer.UserId`.
  - Уже пробует `PrimaryPart`, deep `Body/Hull/Root`, любой `BasePart`.
  - Если owned model является wrapper без BasePart, камера не может следовать.

- `WOBTankInputController.client.luau`
  - Ищет owned player tank среди прямых детей `TestObjects` по `IsPlayerTank` и `OwnerUserId`.
  - Не fallback-ится на `PlayerTankPrototype`, что правильно.

- `WOBAimLaser.client.luau`
  - Ищет local tank среди прямых детей `TestObjects`.
  - `ShootPoint`/`Barrel` ищутся внутри найденной модели.
  - Если найден wrapper без muzzle parts, лазер выключен.

- `WOBTankLocalTeamVisuals.client.luau`
  - Обходит прямых детей `TestObjects`.
  - Красит `Body/Turret/Barrel`, armor hitboxes не трогает.
  - Если physical model вложена глубже или attributes стоят на wrapper, цвета не применятся к физике.

- `WOBRoundStatusOverlay.client.luau`
  - Жёстко привязан к `PlayerTankPrototype` и `DummyTank`.
  - Для PvP это не per-client perspective: второй клиент должен видеть свой `Player2TankPrototype` как Player HP, а врага как Enemy HP.

## Legacy conflicts

В snapshot есть legacy объекты, которые не принадлежат Rojo mapping:

- `StarterPlayer/StarterPlayerScripts/WOBClientController`
- `StarterGui/HUD/WOBHudController`
- `ServerScriptService/Services/WOBDummyRespawnServer`
- возможно old Studio-owned `WOBGameplayServer`, `WOBPerformanceServer`, `WOBProjectileVisualEnhancer`

`WOBPvPBootstrap` и `WOBTankInputController` отключают legacy `WOBClientController`, но server-side legacy scripts нужно отключать Studio command script-ом, потому что Rojo не владеет `ServerScriptService/Services`.

## HUD warning

Лог:

```text
[WOB] Modular HUD not found (PlayerGui/HUD was not found). Using emergency runtime UI.
```

Причина по source contract:

- Rojo не мапит `StarterGui`.
- `WOBRoundStatusOverlay` ожидает `PlayerGui/HUD/Root`.
- Snapshot содержит только legacy `StarterGui/HUD/MainPanel`, без `Root`.
- `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua` уже создаёт правильный путь `StarterGui/HUD/Root`, но этот command script должен быть выполнен в Studio и сохранён через `File -> Save to File`.

## Player2 spawn warning

Лог:

```text
[SPAWN] Player2 using fallback pos=(42.0, 0.0, 42.0) yaw=45.0
```

Причина:

- `TankSpawnResetService` ожидает `Workspace.WOB_Generated.Map.SpawnPoints.Player2Spawn`.
- Текущий `docs/patches/CREATE_PLAYER2_SPAWN_COMMAND.lua` ошибочно ищет `Workspace.Map`.
- Snapshot содержит legacy `Workspace.WOB_Generated.Map.Spawns`, а не `SpawnPoints`.

## Critical blockers

1. `TankParticipantRegistry` может зарегистрировать wrapper model без `BasePart`.
2. `TankSpawnResetService.layoutTank` тихо ничего не делает, если physical parts не являются прямыми детьми модели.
3. Клиентские camera/laser/visuals ищут owned tank model, но не умеют надёжно перейти от wrapper к physical model.
4. Player2Spawn command создаёт объект в неверном месте.
5. `StarterGui/HUD/Root` не гарантирован в `.rbxl`, потому что Rojo не мапит `StarterGui`.
6. Legacy Studio scripts могут продолжать работать параллельно с Rojo-managed системами.

## Likely root causes

- Главная root cause possession: ownership attributes поставлены на модель `PlayerTankPrototype`, которая в текущем runtime является wrapper/metadata object с `Hitboxes`, но без `Body/Hull/BasePart`.
- `PlayerTankSpawner` и registry не валидируют physical model contract.
- Сцена и source разошлись: snapshot показывает старые полные танки и legacy HUD, а текущий runtime log показывает пустой/обрезанный tank wrapper.
- Spawn/HUD command scripts не были выполнены или сохранены после перехода на новые имена и структуру.

## Минимальный порядок фиксов

1. Сервер: добавить безопасный physical tank contract resolver/self-heal.
2. Сервер: registry должен логировать и ставить attributes на physical model, PrimaryPart назначать через `Body`, `Hull`, затем первый `BasePart`.
3. Сервер: `layoutTank` должен искать части глубоко и предупреждать, если модель всё ещё не физическая.
4. Клиент: camera/input/laser/team visuals должны искать owned physical model по `OwnerUserId`, `TankId`, `PhysicalModelPath` и наличию `BasePart`.
5. HUD: `WOBRoundStatusOverlay` должен использовать local owned tank и enemy tank, а не жёстко `PlayerTankPrototype` для всех клиентов.
6. Studio command scripts: исправить `CREATE_PLAYER2_SPAWN_COMMAND.lua`; добавить command для восстановления tank model contract; обновить инструкции.

## Файлы, которые нужно менять

- `src/ServerScriptService/Server/Gameplay/PlayerTankSpawner.luau`
- `src/ServerScriptService/Server/Gameplay/TankParticipantRegistry.luau`
- `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`
- `src/ServerScriptService/Server/Gameplay/Tanks/TankSpawnResetService.luau`
- `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankPossessionCamera.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankInputController.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankLocalTeamVisuals.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBRoundStatusOverlay.client.luau`
- `docs/patches/CREATE_PLAYER2_SPAWN_COMMAND.lua`
- `docs/patches/CREATE_TANK_MODEL_CONTRACT_COMMAND.lua`
- `docs/CODEX_TASKS.md`

## Файлы, которые нельзя трогать без отдельной причины

- `RicochetTanksPrototype.rbxl`
- `default.project.json`
- projectile formulas / ricochet math / armor penetration formulas
- DataStore behavior
- Bot/lobby/matchmaking/game mode code

