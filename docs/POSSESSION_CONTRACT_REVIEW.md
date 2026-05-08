# Possession Contract Review

Дата аудита: 2026-05-09

## Preflight

Перед любыми изменениями выполнены команды:

```text
pwd
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox

git status --short
 M RicochetTanksPrototype.rbxl

git branch --show-current
main

git remote -v
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (fetch)
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (push)
```

Важно: `RicochetTanksPrototype.rbxl` уже был изменен до аудита. Его нельзя перезаписывать из кода и нельзя откатывать.

## 1. Rojo Mapping

`default.project.json` мапит только:

- `src/ReplicatedStorage/Shared` -> `ReplicatedStorage/Shared`
- `src/ServerScriptService/Server` -> `ServerScriptService/Server`
- `src/StarterPlayer/StarterPlayerScripts/Client` -> `StarterPlayer/StarterPlayerScripts/Client`

Rojo не управляет:

- `Workspace`
- `StarterGui`
- `ServerScriptService/Services`
- legacy `StarterPlayer/StarterPlayerScripts` вне папки `Client`

Следствие: карта, танки, spawn points, HUD и legacy Studio scripts живут в `.rbxl` и чинятся command scripts из `docs/patches`. Это основной источник расхождения между `src` и live-сценой.

## 2. Expected Workspace Hierarchy

Целевой контракт:

```text
Workspace
  WOB_Generated
    SpawnPoints
      PlayerSpawn
      Player2Spawn
      DummySpawn
    Map
    TestObjects
      PlayerTankPrototype
      Player2TankPrototype
      DummyTank
    Runtime
      Projectiles
      VFX
```

Примечание: серверный код на момент аудита искал `Workspace.WOB_Generated.Map.SpawnPoints`. Safe-fix должен сделать root-level `SpawnPoints` предпочтительным путем и оставить `Map/SpawnPoints` только как fallback для старых сцен.

`WOBPvPBootstrap.server.luau` создает только `Runtime/Projectiles` и `Runtime/VFX`, если `WOB_Generated` уже есть. `TestObjects`, `Map` и `SpawnPoints` он не создает.

## 3. Scene And Tank Facts

Файловая система не дает надежно прочитать текущий бинарный `RicochetTanksPrototype.rbxl` без Studio. Поэтому фактическая live-структура ниже основана на предоставленных runtime логах, а snapshot `RicochetTanksPrototype_snapshot.rbxlx` используется только как исторический снимок.

### Snapshot `.rbxlx`

В `RicochetTanksPrototype_snapshot.rbxlx`:

- `Workspace.WOB_Generated.TestObjects.PlayerTankPrototype` является `Model`, содержит `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`, имеет `PrimaryPart`.
- `Workspace.WOB_Generated.TestObjects.DummyTank` является `Model`, содержит `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`, имеет `PrimaryPart`.
- `Player2TankPrototype` отсутствует.
- `Workspace.WOB_Generated.Map.Spawns` содержит legacy `PlayerSpawnPoint`/enemy spawn naming, а не `Map.SpawnPoints.PlayerSpawn/DummySpawn/Player2Spawn`.
- `Workspace.StreamingEnabled = true`, `StreamingMinRadius = 64`, `StreamingTargetRadius = 1024`.
- tank `ModelStreamingMode = Default`.
- `StarterGui/HUD` есть как legacy `HUD/MainPanel` + `WOBHudController`; `HUD/Root` отсутствует.
- legacy `StarterPlayer/StarterPlayerScripts/WOBClientController` присутствует.

### Current Runtime From Logs

Сервер:

```text
[TANK] registered PlayerTankPrototype model=Workspace.WOB_Generated.TestObjects.PlayerTankPrototype primaryPart=Body baseParts=8
```

Клиент:

```text
[PVP] camera owned tank found: PlayerTankPrototype
[PVP] camera cannot follow: no BasePart for PlayerTankPrototype
First 20 descendants:
  [1] Hitboxes (Folder)
```

Это означает, что client-visible `PlayerTankPrototype` имеет attributes ownership, но не имеет client-visible `Body`, `Hull`, `Turret`, `Barrel`, `ShootPoint` или любого `BasePart`; виден только `Hitboxes`.

Ожидаемый контракт для каждого танка:

- `ClassName = Model`
- `Body` или `Hull` или хотя бы один `BasePart`
- `PrimaryPart` назначен на `Body`, затем `Hull`, затем первый `BasePart`
- `Turret`
- `Barrel`
- `ShootPoint`
- `Hitboxes`
- attributes на той же physical model: `TankId`, `OwnerUserId`, `OwnerName`, `TeamId`, `ControllerType`, `IsPlayerTank`

Текущий факт по логам:

| Tank | Сервер | Клиент | Вывод |
| --- | --- | --- | --- |
| `PlayerTankPrototype` | видит `Body`, `PrimaryPart=Body`, `baseParts=8` | видит только `Hitboxes` | scene/runtime replication contract сломан |
| `Player2TankPrototype` | создается/получается из `PlayerTankPrototype` через `PlayerTankSpawner` | риск унаследовать неправильную структуру или быть server-created only | нужен scene command script |
| `DummyTank` | должен быть physical model | клиентские HUD/laser/combat ждут physical hitboxes | нужен такой же контракт, как у player tanks |

## 4. Who Creates, Repairs, Clones Tanks

`WOBGameplayServer.server.luau`:

- берет `TestObjects.PlayerTankPrototype` и `TestObjects.DummyTank`;
- вызывает `PlayerTankSpawner.ensurePhysicalTankModel`;
- создает/получает `Player2TankPrototype` через `PlayerTankSpawner.getOrCreateRuntimePlayerTank`;
- регистрирует participants.

`PlayerTankSpawner.luau`:

- runtime repair создает `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes/*Armor`, если их нет;
- назначает `PrimaryPart`;
- для `Player2TankPrototype` возвращает existing model или clone от `PlayerTankPrototype`.

`TankParticipantRegistry.luau`:

- сейчас нормализует `participant.Model = participant.PhysicalModel`;
- ставит attributes на `participant.Model` и `participant.PhysicalModel`;
- логирует `[TANK] registered ... primaryPart=... baseParts=...`;
- предупреждение без BasePart сейчас не critical по тексту.

`TankSpawnResetService.luau`:

- работает с `participant.Model`;
- ищет части глубоко;
- раскладывает `Body/Turret/Barrel/ShootPoint/Hitboxes`;
- использует spawn points из `map.SpawnPoints`.

`PlayerPossessionService.luau`:

- назначает владельца через registry;
- сам физику не создает.

`docs/patches/CREATE_TANK_MODEL_CONTRACT_COMMAND.lua`:

- уже существует и восстанавливает три модели, но лог и часть поведения не совпадают с требуемым контрактом;
- должен стать главным scene-level repair, а runtime repair остаться страховкой.

## 5. Client Tank Lookup

`TankModelResolver.luau`:

- ищет physical model по `PrimaryPart`, `Body`, `Hull`, `Root`, затем первому `BasePart`;
- умеет переходить по `PhysicalModelPath`;
- ищет owned tank по `OwnerUserId`.

`WOBTankPossessionCamera.client.luau`:

- ищет owned tank по `OwnerUserId`;
- следует только при `GameState == Playing`;
- уже логирует `[PVP] camera follow started: TankId part=...`;
- проблема не в camera fallback, а в том, что найденная модель не физическая на клиенте.

`WOBTankInputController.client.luau`:

- ищет owned tank по `OwnerUserId`;
- input-flow живой: клиент отправляет input, сервер принимает и применяет.

`WOBAimLaser.client.luau`:

- берет `ShootPoint`/`Barrel` из owned physical tank.

`WOBTankLocalTeamVisuals.client.luau`:

- красит resolved physical model, но `isVisualTankModel` зависит от attributes на physical model или `Name == DummyTank`.

`WOBRoundStatusOverlay.client.luau`:

- ищет HUD `PlayerGui/HUD/Root`;
- уже использует `TankModelResolver.findOwnedTank` и `findEnemyTank` для HP.

## 6. Legacy Scripts

Known legacy scripts from snapshot:

- `StarterPlayer/StarterPlayerScripts/WOBClientController`
- `StarterGui/HUD/WOBHudController`
- `ServerScriptService/Services/WOBGameplayServer`
- `ServerScriptService/Services/WOBDummyRespawnServer`
- `ServerScriptService/Services/WOBPerformanceServer`
- `ServerScriptService/Services/WOBProjectileVisualEnhancer`

Disabling:

- `WOBPvPBootstrap.server.luau` and `WOBTankInputController.client.luau` disable only legacy `WOBClientController`.
- `DISABLE_LEGACY_STUDIO_SCRIPTS_COMMAND.lua` disables old server/client/HUD scripts, but only if run in Studio and saved.
- Rojo cannot disable scripts in `ServerScriptService/Services` or legacy `StarterGui/HUD` because those paths are not mapped.

## 7. Streaming And Replication Risk

Snapshot has `Workspace.StreamingEnabled = true`. However, the client log is not a normal streaming symptom:

- client receives the model and attributes;
- client sees `Hitboxes` folder;
- client sees no `BasePart` descendants at all;
- server reports `baseParts=8` after runtime repair.

Most likely root cause is scene hierarchy mismatch plus runtime repair:

- `.rbxl` currently contains a wrapper/partial `PlayerTankPrototype` visible to client;
- server-side startup repair creates/assigns physical parts during Play Mode;
- client scripts can bind to the wrapper before the full physical model contract is available, or server-created repair does not represent the saved scene contract;
- attributes are placed on the model name that client treats as tank, but physical parts are not guaranteed as part of the client-visible model at lookup time.

`ModelStreamingMode = Default` and `StreamingEnabled = true` can make this worse, but the immediate issue is not camera timing. The physical model contract must exist in the saved scene and on the exact model that carries ownership attributes.

## 8. HUD

Warning:

```text
[WOB] Modular HUD not found (PlayerGui/HUD was not found)
```

Reason:

- `StarterGui` is not Rojo-managed;
- `WOBRoundStatusOverlay` expects `PlayerGui/HUD/Root`;
- snapshot has legacy `StarterGui/HUD/MainPanel`, no `Root`;
- `CREATE_MODULAR_HUD_COMMAND.lua` creates the correct structure, but must be run in Studio outside Play Mode and saved.

Required path:

```text
StarterGui
  HUD
    Root
      EnemyStatusPanel
      WeaponStatusPanel
      PlayerStatusPanel
      RoundStatusPanel
      MatchSeriesPanel
```

## 9. Player2 Spawn

`TankSpawnResetService` on audit start expected the historical path:

```text
Workspace.WOB_Generated.Map.SpawnPoints.PlayerSpawn
Workspace.WOB_Generated.Map.SpawnPoints.Player2Spawn
Workspace.WOB_Generated.Map.SpawnPoints.DummySpawn
```

Target path for the safe-fix is:

```text
Workspace.WOB_Generated.SpawnPoints.PlayerSpawn
Workspace.WOB_Generated.SpawnPoints.Player2Spawn
Workspace.WOB_Generated.SpawnPoints.DummySpawn
```

Current `CREATE_SPAWN_POINTS_COMMAND.lua` creates only `PlayerSpawn` and `DummySpawn`.

Current `CREATE_PLAYER2_SPAWN_COMMAND.lua` uses the historical `WOB_Generated/Map/SpawnPoints` path, but when created it may copy `DummySpawn.CFrame`. That can overlap `Player2Spawn` with `DummySpawn`, which is bad for Training/PvP switching and explains fallback/overlap risk.

## Root Cause

Real root cause: `PlayerTankPrototype` is treated as the combat participant and ownership target, but the saved/client-visible scene contract for that model is not guaranteed to be a physical tank model. Server runtime repair can create enough parts for server logs, while the client still resolves a wrapper/partial model with only `Hitboxes`. This leaves attributes on a model that the client can find, but without a `BasePart` for camera, laser, visuals and stable replication.

Secondary causes:

- Workspace and StarterGui are outside Rojo.
- Tank physical model creation is relying too much on Play Mode runtime repair.
- Player2 tank/spawn are not fully scene-owned.
- Legacy Studio scripts remain possible unless command cleanup is run and saved.

## Files To Change

Minimal safe set:

- `docs/patches/CREATE_TANK_MODEL_CONTRACT_COMMAND.lua`
- `docs/patches/CREATE_SPAWN_POINTS_COMMAND.lua`
- `docs/patches/CREATE_PLAYER2_SPAWN_COMMAND.lua`
- `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua`
- `src/ServerScriptService/Server/Gameplay/PlayerTankSpawner.luau`
- `src/ServerScriptService/Server/Gameplay/TankParticipantRegistry.luau`
- `src/ServerScriptService/Server/Gameplay/Tanks/TankSpawnResetService.luau`
- `src/ServerScriptService/Server/Gameplay/Players/PlayerPossessionService.luau`
- `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankPossessionCamera.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankInputController.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankLocalTeamVisuals.client.luau`
- `src/ReplicatedStorage/Shared/Utils/TankModelResolver.luau`

## Files Not To Touch

- `RicochetTanksPrototype.rbxl` from filesystem automation.
- `default.project.json`, unless a later task explicitly decides to Rojo-manage Workspace/StarterGui.
- `src/ReplicatedStorage/Shared/Utils/RicochetMath.luau`.
- damage, armor, ricochet and DataStore behavior.
- BotBrain/lobby/matchmaking.
- full architecture rewrite.

## Minimal Safe-Fix Plan

1. Make `CREATE_TANK_MODEL_CONTRACT_COMMAND.lua` the source of truth for saved scene contract: create/repair `PlayerTankPrototype`, `Player2TankPrototype`, `DummyTank`; keep existing geometry; ensure `Body/Turret/Barrel/ShootPoint/Hitboxes`; set attributes on physical model; assign `PrimaryPart`; print `[TANK CONTRACT] ...`.
2. Keep server runtime repair as a safety net, but make registry/possession/spawn always operate on physical model and emit a critical warning when `baseParts == 0`.
3. Make client resolver stricter and clearer: owned tank lookup should return physical model when available; if it sees wrapper, resolve by `TankId`/`PhysicalModelPath`; diagnostics should include base part count.
4. Ensure aim laser and team visuals only act on resolved physical model.
5. Ensure HUD command script creates the exact `StarterGui/HUD/Root/*Panel` contract and documents Studio save.
6. Ensure spawn command scripts create all three named spawn points under `WOB_Generated/SpawnPoints`, with `Player2Spawn` separated from `DummySpawn`; keep `Map/SpawnPoints` as legacy fallback only.
7. Run `git diff --check`.
8. Run `rojo build default.project.json --output /private/tmp/wob-possession-contract-hard-reset-check.rbxm`.
