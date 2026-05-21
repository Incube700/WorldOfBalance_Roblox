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

## Project folder quarantine note

- `New project 2` is quarantine; real project is `/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox`.
- Do not apply old TankParticipant refactor wholesale.
- Use old refactor only as reference.

## Что сейчас является Stable Fun Duel v0.1

- Lobby free drive, no-damage shooting, Training, DuelPad 2-player queue/countdown, RoundEnd/MatchEnd series, Result/Stats/Rematch/Return to Lobby.
- Server-authoritative movement, shooting, damage, death, round state, dead tank control, and collision validation.
- Procedural VFX fallback is the baseline. Creator Store templates are optional upgrades, not required for gameplay readability.
- Do not add shop, monetization, inventory, deathmatch, or new modes before this loop is stable in manual Studio checks.

## Текущий статус

- Проект: `World of Balance: Ricochet Tanks`.
- Workflow: Rider + Codex + Rojo + Roblox Studio + GitHub Desktop.
- Rojo установлен и подключается через plugin в Roblox Studio.
- В корне проекта есть `default.project.json`.
- В корне проекта есть локальная сцена `RicochetTanksPrototype.rbxl`.
- Код должен жить в `src/`.
- Документация должна жить в `docs/`.
- MVP пока не реализован как механика. Текущий фокус — документация, структура и затем маленькие проверяемые шаги.

## Current Sprint — Playtest Polish, Rewards, and Lobby UX

- Статус: mobile/playtest polish pass поверх Stable Fun Duel + BattleArena, без переписывания loop.
- Master doc: `docs/PLAYTEST_POLISH_MASTER_PASS.md`.
- Mobile performance notes: `docs/MOBILE_PERFORMANCE_PASS.md`.
- UX/readability rules: `docs/ROBLOX_UX_READABILITY_GUIDE.md`.
- Crystals: внутриигровая валюта, не Robux/IAP. Хранится в `PlayerWalletService` рядом с Bolts и публикуется через attributes `Crystals`, `PersistentCrystals`, `SessionCrystalsEarned`, `UnsavedCrystals`.
- Reward config: `src/ReplicatedStorage/Shared/Configs/RewardConfig.luau`.
- Duel reward owner: `MatchRewardService.luau`; только финальная победа в real PvP Duel дает `RewardConfig.DuelWinCrystals` (`+1` сейчас). Training и BattleArena не дают Crystals.
- Fire loop hotfix: `VfxConfig.BurningTank` mutes template sounds by default; `CombatVfxService` sanitizes runtime VFX clone sounds/scripts; run `docs/patches/MUTE_BURNING_VFX_SOUNDS_COMMAND.lua` outside Play Mode for existing Studio template cleanup.
- Performance profile: `PerformanceConfig.ActiveProfile = "MobileLow"` disables expensive shadows for playtest. `Balanced` remains available in config for later visual polish.
- Lobby scene scripts:
  - `docs/patches/CREATE_OR_REPAIR_LOBBY_SHOWCASES_COMMAND.lua`
  - `docs/patches/CREATE_OR_REPAIR_LOBBY_GUIDANCE_COMMAND.lua`
- Publish checklist additions: confirm Rojo VFX guard, no infinite fire sound, Duel +1 Crystal, readable lobby signs/showcases, mobile controls/HUD, BattleArena/Training/Duel regressions.
- Recommended commit message: `Polish playtest UX rewards and lobby showcases`.

## Current Add-on — Editable BaseTankTemplate Workflow

- Статус: editable template workflow добавлен поверх существующего TankFactory; gameplay loop не изменён.
- Docs: `docs/BASE_TANK_TEMPLATE_WORKFLOW.md`.
- `TankFactoryConfig.BaseTankTemplateName = "BaseTankTemplate"` добавлен как единственный source-of-truth имени шаблона.
- `TankTemplateProvider:GetTemplateForRole` теперь проверяет `BaseTankTemplate` в `TestObjectsRoot` как приоритет 1 для всех ролей; при отсутствии — role-specific legacy fallback chain без изменений.
- `TankTemplateProvider:GetBaseTankTemplate()` — вспомогательный метод для явного lookup.
- `TankArmorPartsService.Configure` теперь ищет `ArmorZones` (новый контракт) или `Hitboxes` (legacy) — оба поддерживаются.
- `TankSkinApplier.luau` создан: применяет `Default` скин к `Visuals` folder, устанавливает `CanQuery=false/CanCollide=false/Massless=true` на visual parts.
- `TankFactory:SpawnTank` вызывает `TankSkinApplier.Apply(model, loadout)` после `TankArmorPartsService.Configure`.
- `docs/patches/CREATE_BASE_TANK_TEMPLATE_PREVIEW_COMMAND.lua` — отключённый по умолчанию Studio command script для создания BaseTankTemplate из PlayerTankPrototype.
- Правила: `BaseTankTemplate` не создаётся кодом — только пользователем в Studio. Legacy prototypes не удаляются. Bot v0.1 / Duel / BattleArena / Training не затронуты.
- Manual Studio workflow: описан в `docs/BASE_TANK_TEMPLATE_WORKFLOW.md`.
- Recommended commit message: `Add editable base tank template workflow`.

## Current Feature Add-on — BattleArena Bot v0.1

- Статус: simple BattleArena-only bot filler through `TankFactory`.
- Docs: `docs/BOT_V01.md`, `docs/BATTLE_ARENA_BOTS.md`.
- Config: `src/ReplicatedStorage/Shared/Configs/BotConfig.luau`.
- Runtime owner: `BotService.luau`; one `BotController` per bot.
- Spawn path: `TankFactory:SpawnTank` with `Role = ArenaBot`, `StatsProfileId = BotDefault`, and `TeamId = "Bots"`.
- BattleArena integration: bots register as arena participants through `ArenaCombatService.RegisterBotParticipant`.
- Movement/shooting: server-side, using `TankMovementService.resolveTankPose`, `TankSpawnResetService.layoutTank`, and `ProjectileService.tryShoot`.
- Scope guard: no bots in Duel, Lobby free drive, or Training quick flow; no pathfinding, no new weapons, no shop/upgrades/camera changes.
- Manual checks: solo BattleArena spawns bot, bot moves/aims/shoots, player and bot can damage each other, bot death/respawn works, returning to Lobby hides bots, DuelPad remains normal 1v1.
- Recommended commit message: `Add BattleArena bot v0.1 through TankFactory`.

## Current Feature Add-on — BattleArena V2 Foundation

- Статус: run-based Arena V2 foundation implemented without scene/template changes.
- `ArenaCombatService` now tracks `ArenaXP`, `ArenaLevel`, pending upgrade offers, and run-scoped temporary upgrades separately from persistent session score/kills/deaths.
- Kills grant `BattleArenaConfig.XPPerKill`; survival ticks and Supply Crates also have small XP config hooks; level thresholds live in `BattleArenaConfig.LevelThresholds`.
- Level-up and Supply Crates use `UpgradeChoiceEvent` with server-authoritative validation.
- Death resets current-run XP/level/upgrades/modifiers/streak and keeps `ArenaScore`, kills/deaths, and already granted currencies.
- Optional scene hooks are supported if Studio adds them later: `BattleArena.ControlZone`, `BattleArena.Medkits`, and `BattleArena.SupplyCrates`.
- `WOBBattleArenaOverlay` displays Arena Level/XP and a compact 3-choice upgrade panel.
- Survival XP is intentionally small by default so it supports the run loop without replacing kills and Control Zone risk.
- Recommended commit message: `Implement BattleArena V2 run progression`.

## Current Add-on Sprint — Tank World HP/Reload Bars and Hit Flash

- Статус: combat readability pass поверх существующего damage/combat logic.
- Docs: `docs/TANK_WORLD_HEALTH_BARS.md`, `docs/COMBAT_HIT_FLASH.md`, `docs/ROBLOX_UX_READABILITY_GUIDE.md`.
- Server attributes: tank models expose `CurrentHealth`, `MaxHealth`, `HP`, `IsDead`, `IsAlive`, `OwnerName`, `TankId`, and `TankParticipantId`.
- Damage metadata: `LastDamageSerial`, `LastDamageAmount`, `LastDamageAt`, `LastDamageAtServerTime`, and `LastDamageWasLethal` update only after successful damage.
- Reload metadata: accepted server shots publish `LastShotAtServerTime`, `ReloadDuration`, `ReloadProgress`, and `ReloadReady` as presentation-only attributes. Client UI must not use these as shooting authority.
- World HP/reload bars: `WOBTankWorldHealthBars.client.luau` clones `ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard` into `PlayerGui/WOBTankWorldHealthBars`, updates green HP from health attributes, updates blue reload fill from reload attributes, and cleans up on model removal/deactivation.
- Template command: run `docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua` outside Play Mode. `default.project.json` protects `ReplicatedStorage.Shared.Assets.UI` with `$ignoreUnknownInstances = true`.
- Hit flash: `WOBTankDamageFlash.client.luau` listens to `LastDamageSerial` and uses local `Highlight` feedback only on real damage.
- HUD cleanup: `HudConfig.WorldHealthBars` and `HudConfig.CombatHud` hide duplicate top HP panels and large top Reload panels in BattleArena/mobile while preserving result/score UI. `WOBHudBootstrap` keeps the base modular HUD disabled outside `InMatch` to avoid stale HP/reload panels behind lobby/BattleArena UI.
- Manual checks: Training dummy HP bar decreases, successful damage flashes, blue reload fill resets/fills after shooting, lethal bar goes zero/hides, round reset/respawn creates no duplicate bars/highlights, mobile combat screen is less crowded.
- Recommended commit message: `Clean up HUD after adding world HP bars`.

## Current Sprint — Stable Fun Duel v0.1

- Статус: code-first stabilization sprint after audit in `docs/STABLE_FUN_DUEL_V01_AUDIT.md`; current gameplay advancement notes: `docs/STABLE_FUN_DUEL_GAMEPLAY_ADVANCEMENT.md`.
- Главный фикс: `TankMovementService` теперь собирает movement obstacles из `Workspace/WOB_Generated`, включая `Lobby/Railings`, `Map/RicochetWalls`, `Map/Cover`, boundary folders, named `Wall_*` parts and `WOBMovementObstacle` parts. Movement casts use include-filtered obstacle parts, not broad world hits with post-filtering only.
- Scene repair: run `docs/patches/REPAIR_LOBBY_VERTICAL_CONTAINMENT_COMMAND.lua` outside Play Mode for elevated lobby railings/walls, and `docs/patches/CREATE_OR_REPAIR_ARENA_CONTAINMENT_COMMAND.lua` for lower arena walls/cover/boundaries. Both tag movement obstacles and keep lobby Y separate from arena Y. Then `File -> Save to File`.
- VFX templates: `CombatVfxService` clones templates from `ReplicatedStorage/Shared/Assets/VFX`; `VfxConfig` is grouped as `Shot`, `Impact`, `Ricochet`, `DeathExplosion`, and `BurningTank`. Optional slots keep `TemplateName = ""` until a real template object exists; fallback must stay readable. Ricochet now has a dedicated bright procedural fallback. Setup notes: `docs/VFX_TEMPLATE_SETUP.md`; tuning audit: `docs/VFX_TUNING_PASS.md`.
- Tank death VFX: `docs/patches/INSTALL_TANK_EXPLOSION_VFX_TEMPLATE_COMMAND.lua` installs the Workspace Toolbox explosion donor as `ReplicatedStorage/Shared/Assets/VFX/TankExplosionTemplate`; `VfxConfig.DeathExplosion` plays it on any tank death, with procedural fallback and `MatchConfig.RoundResetDelay` keeping the explosion readable.
- Round/match flow: `RoundEnd` now stays in gameplay with a small score/countdown overlay and auto-starts the next round after `MatchConfig.RoundResetDelay`; final `MatchEnd` waits `MatchConfig.MatchResultDelay` before full Result/Rematch/Return to Lobby. Details: `docs/ROUND_MATCH_FLOW.md`.
- Movement corner clipping: current code path uses `TankMovementService.resolveTankPose`, which validates translation and body yaw together with a final oriented overlap check. Sliding remains possible only when the accepted final pose does not overlap movement obstacles.
- Reverse steering uses arcade car-style path control: when reversing, A/D steer the reverse path, not the tank nose.
- Turret config is exposed as `TankConfig.Turret.TurnSpeedDegreesPerSecond`; server shooting uses current turret facing when enabled.
- VFX template collection: run `docs/patches/COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua` outside Play Mode to collect real Workspace donors into `ReplicatedStorage/Shared/Assets/VFX`, sanitize scripts/collision/query, move donors into `Workspace/WOB_EditorOnly_AssetDonors`, and log existing/found/skipped/final templates. Run `docs/patches/PREVIEW_VFX_TEMPLATES_COMMAND.lua` outside Play Mode to preview installed templates at `Workspace/WOB_Generated/VFXPreview`.
- VFX catalog cleanup: `VfxTemplateCatalog` discovers only real templates under `ReplicatedStorage/Shared/Assets/VFX`; `TemplateName` values must be object names, not raw asset ids. Asset ids belong in `TextureId` or `SoundId`.
- VFX recovery guard: if Rojo sync removes Studio-only templates, run `docs/patches/RECOVER_VFX_TEMPLATES_FROM_SCENE_COMMAND.lua`, then `docs/patches/AUDIT_VFX_TEMPLATES_COMMAND.lua`, then manually `Save to File...` each recovered template as `src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx`. Recovery notes live in `docs/VFX_RECOVERY_REPORT.md`. Never rely on Studio-only VFX in Rojo-managed folders.
- Optional VFX: muzzle/impact/ricochet/burning templates are disabled by empty `TemplateName` until installed and intentionally enabled. Death keeps `TankExplosionTemplate` with procedural fallback. Shot readability baseline is `Shot.SoundId = "rbxassetid://139771888058836"` and `Shot.Projectile.Size` around `1.2`.
- Mobile controls v0.1: `WOBMobileControls.client.luau` creates touch-only joystick/aim/fire UI and writes intent into `Input/WOBClientInputState`; `WOBTankInputController` remains the single client sender for `TankInputEvent` and `ShootRequestEvent`. Config: `MobileControlsConfig`; plan/checklist: `docs/MOBILE_CONTROLS_V01_PLAN.md`.
- DuelPad: `LobbyService` now exposes `DuelQueueCount`, `DuelQueueRequired`, `DuelCountdown`, and `DuelState` on root/lobby/duelpad. Duel starts after a cancellable 3 second countdown. Visual repair helper: `docs/patches/CREATE_OR_REPAIR_DUELPAD_VISUAL_COMMAND.lua`.
- Round reset guard: `RoundMatchService` uses tokens plus a short reentry guard so delayed/manual reset races do not run reset twice.
- Graphify: local `graphify` binary exists, but no graph pipeline was run or installed for this sprint. Manual architecture map lives in `docs/ARCHITECTURE_GRAPH.md`.
- Verification required before commit: `git diff --check`; `rojo build default.project.json --output /private/tmp/wob-stable-fun-duel-v01-check.rbxm`; local Luau checker only if available.
- Manual Studio checks: 1-player elevated lobby wall blocking, Training arena wall/cover blocking, no-damage lobby shooting, dummy damage/result/return; 2-player DuelPad `0/2 -> 1/2 -> 2/2`, countdown cancel on leaving, both queued players enter duel, result only for participants.
- Recommended commit message: `Stabilize duel movement VFX and DuelPad flow`.

## Current Add-on Sprint — Free Drive Battle Arena v0.1

- Статус: отдельный режим поверх Stable Fun Duel, не замена Duel/Training.
- План и контракт: `docs/BATTLE_ARENA_V01_PLAN.md`.
- Scene repair: run `docs/patches/CREATE_OR_REPAIR_BATTLE_ARENA_COMMAND.lua` outside Play Mode only when the BattleArena scene is missing or needs full creation. After manual arena moves, prefer `AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua` and `REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua`, then `File -> Save to File`. Do not edit `.rbxl` directly.
- Lobby pad contact contract: `docs/PAD_CONTACT_ZONE_CONTRACT.md`. After moving any pad visual in Studio, run `docs/patches/REPAIR_ALL_LOBBY_PADS_COMMAND.lua`, then `docs/patches/AUDIT_LOBBY_PADS_COMMAND.lua`, then `File -> Save to File`.
- BattleArena collision/HUD debug: `docs/BATTLE_ARENA_COLLISION_AND_HUD_DEBUG.md`. After manually moving the arena, run `docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua`; if warnings appear, run `docs/patches/REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua`, audit again, then `File -> Save to File`.
- Scene-space separation: run `docs/patches/AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua`; if Lobby and BattleArena overlap in XZ, run `docs/patches/MOVE_BATTLE_ARENA_TO_SAFE_ZONE_COMMAND.lua`, then audit/repair collision again.
- VFX template sanitizer: run `docs/patches/CLEAN_VFX_TEMPLATES_COMMAND.lua` if any donor script such as `FIRE.Play` runs from cloned runtime VFX.
- New scene objects: `Workspace.WOB_Generated.BattleArena` with `Floor`, `Boundaries`, `Cover`, `RicochetWalls`, `SpawnPoints/ArenaSpawn1..8`, plus `Workspace.WOB_Generated.Lobby.ArenaPad`.
- New server owner: `ArenaCombatService.luau`. It tracks arena sessions, score, death, respawn, temporary upgrades, and leave/reset. Do not move this logic into `RoundMatchService`.
- New PlayerModes: `InBattleArena` and `ArenaRespawning`. `Result` remains duel/training only.
- Score attributes are session-only: `ArenaScore`, `ArenaKills`, `ArenaDeaths`, `ArenaStreak`, `ArenaUpgradeIds`.
- Temporary upgrades are arena-only and reset on leave: `DamageUp`, `FireRateUp`, `DoubleShot`, `MoveSpeedUp`, `TripleSpread`.
- Projectile/movement modifiers are read only while participant state is `InBattleArena`; Duel still uses default weapon and movement stats.
- Arena overlay: `WOBBattleArenaOverlay.client.luau` shows HP, Arena Level/XP, score, kills, deaths, streak, upgrades, death, respawn, upgrade choices, and return. Desktop keeps the fuller layout. Mobile uses compact top-corner HP/score and hides `Return to Lobby` behind `Menu -> Return to Lobby`; details in `docs/MOBILE_HUD_LAYOUT_PASS.md`. Duel HUD remains owned by `WOBRoundStatusOverlay.client.luau`.
- Verification required before commit: `git diff --check`; conflict marker scan; `rojo build default.project.json --output /private/tmp/wob-battle-arena-v01-check.rbxm`; Luau/StyLua/Selene only if installed.
- Manual checks: use `docs/FIRST_PLAYTEST_CHECKLIST.md`.
- Recommended commit message: `Add battle arena mode v0.1`.

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

- Статус: выполнено. Созданы read-only ModuleScript configs в `src/ReplicatedStorage/Shared/Configs/`; они не подключены к Studio gameplay scripts.
- Цель: создать read-only ModuleScript configs в `src/ReplicatedStorage/Shared/Configs/` без подключения к Studio gameplay scripts.
- Файлы можно трогать: только новые config modules в `src/ReplicatedStorage/Shared/Configs/` и документацию, если нужно уточнить результат.
- Ожидаемый результат: config modules существуют, но `WOBGameplayServer`, `WOBClientController`, `WOBHudController` и другие Studio scripts еще не используют их.
- Критерий проверки в Roblox Studio: Rojo синхронизируется без ошибок; Play behavior не меняется.
- Какой коммит сделать: `Create read-only config modules`.

### Task 00.06 — Wire first responsibility config in smallest possible slice

- Статус: следующий безопасный шаг. Начинать только с одной низкорисковой группы constants, без изменения core gameplay loop.
- Цель: подключить только одну безопасную группу constants из одного responsibility config.
- Файлы можно трогать: один выбранный config module и минимальный один потребитель, только после отдельного согласования.
- Ожидаемый результат: поведение в Play Mode не меняется; config начинает использоваться в одном узком месте.
- Критерий проверки в Roblox Studio: Play без ошибок, проверка именно той механики/визуала, к которой подключен config.
- Какой коммит сделать: `Wire first config slice`.

Важно: не создавать и не подключать `GameplayConfig` как общий контейнер. Если позже понадобится `GameplayConfig`, он может содержать только global match/round values, которых сейчас в snapshot нет.

### Task 00.07 — Migrate WOBPerformanceServer to Rojo ownership

- Статус: подготовлено в уже Rojo-owned ветке `Server`; не добавлять mapping на Studio-owned `ServerScriptService/Services`.
- Цель: подготовить Rojo-managed замену `WOBPerformanceServer`, которая читает значения из `PerformanceConfig`, без передачи всей Studio-папки `Services` под Rojo ownership.
- Файлы можно трогать: `src/ServerScriptService/Server/Services/WOBPerformanceServer.server.luau`, `src/ReplicatedStorage/Shared/Configs/PerformanceConfig.luau`, `docs/CODEX_TASKS.md`.
- Ожидаемый результат: Rojo-managed версия живет как `ServerScriptService/Server/Services/WOBPerformanceServer`, а Studio-owned папка `ServerScriptService/Services` остается нетронутой.
- Ручной шаг перед Play test: в Roblox Studio отключить или удалить старый `ServerScriptService/Services/WOBPerformanceServer`, иначе одновременно будут работать старая Studio-owned и новая Rojo-managed версии.
- План миграции: первый active migration идет через уже Rojo-owned `ServerScriptService/Server`; не добавлять mapping на всю Studio `ServerScriptService/Services`, пока все скрипты из нее не мигрированы отдельными задачами.
- Критерий проверки в Roblox Studio после будущего включения: Play без ошибок; в Output один раз появляется performance message; shadows disabled; generated parts and characters keep `CastShadow = false`.
- Риск дубля: высокий, если старый Studio-owned script останется включенным во время Play test.
- Какой коммит сделать: `Move WOBPerformanceServer migration to Rojo Server folder`.

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

### Task 02.04 — Improve tank wall blocking unstuck behavior

- Статус: текущий milestone; Wall Blocking V1 блокирует стены, но имеет sticky-wall issue при плотном контакте; V2 patch подготовлен, active `.rbxl` script still needs manual Studio paste.
- Цель: не дать `PlayerTankPrototype` проходить через `Workspace/WOB_Generated/Map/RicochetWalls`, `Workspace/WOB_Generated/Map/Cover`, `Wall_North`, `Wall_South`, `Wall_East`, `Wall_West`, `RicochetWall_*`, `Cover_Block_*`.
- Файлы можно трогать: `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`, `docs/patches/README_VISIBLE_SPRINT.md`, `docs/PROJECT_AUDIT.md`, `docs/CODEX_TASKS.md`.
- Ожидаемый результат: minimal server-side movement check in `WOBGameplayServer` before applying proposed tank position; full movement is tried first, then X-only, then Z-only, then stop; fallback overlap check prevents passing through walls if `Blockcast` misses.
- Ручной шаг: replace `ServerScriptService/Services/WOBGameplayServer` Source in Roblox Studio with `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`.
- Риски: `WOBGameplayServer` remains the main monolith; `Workspace:Blockcast` must not hit floor/spawns; overlap box must not be too large; V2 is axis fallback rather than full physics sliding; do not change RemoteEvent contracts, WASD, turret aim, projectile damage, or ricochet logic.
- Play Mode checks: WASD works; tank rotates; turret aims with mouse; tank cannot pass through perimeter walls, `RicochetWall_*`, or `Cover_Block_*`; tank can reverse away from wall contact; tank can turn near walls; projectile still flies/ricochets; dummy damage and HUD still work; Output has no red errors and `[WALL]` debug is not noisy.
- Какой коммит сделать: `Improve tank wall blocking unstuck behavior`.

## Milestone 2.5 — Migrate WOBGameplayServer to Rojo Ownership

### Task 02.50 — Add WOBGameplayServer Rojo migration plan

- Статус: выполнено.
- Цель: описать безопасный путь отказа от ручной вставки patch-кода в Studio-owned `ServerScriptService/Services/WOBGameplayServer`.
- Файлы можно трогать: `docs/WOBGAMEPLAYSERVER_ROJO_MIGRATION_PLAN.md`, `docs/CODEX_TASKS.md`.
- Ожидаемый результат: есть понятный план, почему migration нужна, какие риски у duplicate server scripts, как использовать уже существующий Rojo mapping `src/ServerScriptService/Server`, и что все еще требует manual `File -> Save to File`.
- Критерий проверки в Roblox Studio: не требуется, задача только документационная.
- Какой коммит сделать: `Add WOBGameplayServer Rojo migration plan`.

### Task 02.51 — Prepare WOBGameplayServer Rojo-managed replacement, without enabling duplicate

- Статус: выполнено.
- Цель: создать replacement в уже Rojo-owned зоне, чтобы будущий gameplay-код менялся через Git/Rojo, а не через manual Source paste.
- Предпочтительный путь: `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`.
- Файлы можно трогать: `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`, optional Rojo meta file for disabled startup, docs with manual switch steps.
- Запрещено: менять `.rbxl`, менять `default.project.json`, включать два `WOBGameplayServer`, мигрировать всю `ServerScriptService/Services`, рефакторить gameplay monolith одновременно with migration.
- Ручной шаг перед Play: в Studio отключить старый `ServerScriptService/Services/WOBGameplayServer`; Rojo-managed replacement должен быть единственным active gameplay server.
- Expected check: ровно один `[WOB] Gameplay server started`; WASD, turret aim, shoot, ricochet, dummy damage, wall blocking and HUD still work; Output has no duplicate event behavior or red errors.
- Какой коммит сделать: `Prepare WOBGameplayServer Rojo replacement`.

### Task 02.52 — Extract services from WOBGameplayServer to prevent Luau register limit

- Статус: выполнено.
- Цель: превратить `WOBGameplayServer` в тонкий оркестратор, вынеся логику в специализированные сервисы.
- Созданные сервисы:
    - `RoundMatchService.luau`: управление состоянием раундов и матчей, переходы между `Menu`, `Playing`, `Result`.
    - `ProjectileService.luau`: жизненный цикл снарядов, стрельба, обновление позиций, VFX выстрелов.
    - `TankSpawnResetService.luau`: расчет точек спавна, расстановка моделей (`layoutTank`), управление цветами и видимостью.
    - `PlayerPossessionService.luau`: привязка игроков к танкам, подавление персонажей Roblox, управление вводом.
- Ожидаемый результат: `WOBGameplayServer` содержит менее 400 строк кода, Luau register limit больше не является проблемой, функциональность игры сохранена.
- Какой коммит сделать: `Implement Thin Gameplay Orchestrator Refactor v1`.

### Task 02.53 — PvP Foundation and Refactor Verification

- Статус: выполнено.
- Цель: превратить WOBGameplayServer в тонкий оркестратор и подготовить PvP.
- Результаты:
    - Исправлена ошибка `Out of local registers`.
    - Логика вынесена в `RoundMatchService`, `ProjectileService`, `TankSpawnResetService`, `PlayerPossessionService` и `ProjectileCombatService`.
    - Исправлена привязка камеры к танку владельца (Task 02.53a), теперь она стабильно следует за танком в состоянии `Playing`.
    - Добавлен `Player2Spawn` (Task 02.53b).
    - Отключен дебаг-спам `[BOUNCE]` (Task 02.53c).
- Какой коммит сделать: `Implement thin gameplay orchestrator and fix PvP camera/spawn`.

### Task 02.55 — Training Possession and Camera Part Fix

- Статус: выполнено.
- Цель: починить 1-player Training режим и следование камеры за танком.
- Изменения:
    - `WOBTankPossessionCamera.client.luau`: реализована функция `getTankFocusPart` с глубоким поиском `Body` и fallback на любой `BasePart`. Добавлено информативное логирование `camera follow started` с именем найденной части.
    - `TankSpawnResetService.luau`: добавлена безопасная установка `PrimaryPart = Body` для модели танка при спавне на сервере.
    - `WOBTankInputController.client.luau` & `WOBGameplayServer.server.luau`: добавлено throttled логирование для отладки ввода.
- Результат: камера стабильно следует за танком даже если `Body` не является прямым потомком модели, в Output четко видны этапы владения танком и передачи ввода.

### Task 02.56 — Physical Tank Model Resolution for Camera

- Статус: выполнено.
- Цель: исправить ситуацию, когда камера находит пустой proxy-объект вместо физической модели танка.
- Изменения:
    - `WOBTankPossessionCamera.client.luau`: расширен `getTankFocusPart`. Теперь если BasePart не найден в текущем объекте, скрипт ищет физическую модель в `Workspace.WOB_Generated.TestObjects` по атрибуту `TankId`. Добавлена функция `printTankDiagnostics` для вывода структуры объекта при ошибках.
    - `TankParticipantRegistry.luau`: обеспечена установка всех атрибутов (включая `OwnerUserId` и `TankId`) на физическую модель при регистрации и обновлении видимости.
    - `TankSpawnResetService.luau`: улучшена логика установки `PrimaryPart` — теперь используется глубокий поиск `Body` или любого `BasePart` внутри модели.
- Результат: камера успешно находит физическую часть танка для фокуса, даже если локальный `ownedTank` ссылается на метаданные. Исправлен баг "no BasePart for PlayerTankPrototype".

## Stable MVP Contracts

### Tank Model Contract

- Physical tank models live under `Workspace/WOB_Generated/TestObjects`.
- Required models for MVP: `PlayerTankPrototype`, `Player2TankPrototype`, `DummyTank`.
- Each physical tank model must contain visible/physical parts: `Body` or `Hull`, `Turret`, `Barrel`, `ShootPoint`, and `Hitboxes`.
- `Hitboxes` must not be the only descendant of a physical tank model.
- `PrimaryPart` must be assigned as `Body`, else `Hull`, else the first descendant `BasePart`.
- Required attributes on the physical model: `TankId`, `OwnerUserId`, `OwnerName`, `TeamId`, `ControllerType`, `IsPlayerTank`.
- Scene repair source of truth: `docs/patches/CREATE_TANK_MODEL_CONTRACT_COMMAND.lua`. It is a repair tool, not a per-run dependency.

### TankParticipant Contract

- `TankParticipant` is the combat entity for a tank.
- `ControllerType` identifies the decision source: `Player`, `Dummy`, and later `Bot`.
- `OwnerUserId` and `OwnerName` are set only for player-controlled tanks.
- `Dummy` and future non-player controllers do not write DataStore player stats.
- The registry must register the physical model, not a wrapper, and must warn critically when the model has no `BasePart`.

### Possession Contract

- Client code finds the owned physical tank by `OwnerUserId == LocalPlayer.UserId`.
- If a wrapper is ever found, client code resolves the physical tank by `TankId` through `TankModelResolver`.
- Camera follows `PrimaryPart`, then `Body`, then first descendant `BasePart`.
- Input sends `TankId`; server validates `Player -> TankParticipant` ownership before applying movement or shooting.
- `WOBGameplayServer` stays a thin orchestrator. Possession, reset, projectiles, combat, and stats stay in services.

### Stats Contract

- Runtime match stats are per player-controlled `TankParticipant` and mirrored to the owning `Player` as `Stats*` attributes.
- Legacy root `Workspace.WOB_Generated.Stats*` attributes remain a compatibility fallback for `PlayerTankPrototype` only.
- Persistent stats are stored by the existing per-user DataStore key format (`Player_<UserId>`).
- Training: local player receives Win/Loss relative to `DummyTank`; `DummyTank` is never saved to DataStore.
- PvP: winner and loser receive separate Win/Loss and separate shots/hits/ricochets/self-hits/damage/round stats.
- Studio DataStore warnings are acceptable; session/unsaved attributes must still let UI show useful stats.

### Scene Repair Scripts

- Run repair scripts only from Studio Command Bar outside Play Mode, then `File -> Save to File`.
- Tank contract: `docs/patches/CREATE_TANK_MODEL_CONTRACT_COMMAND.lua`.
- Spawn points: `docs/patches/CREATE_SPAWN_POINTS_COMMAND.lua` and, if only Player2 needs repair, `docs/patches/CREATE_PLAYER2_SPAWN_COMMAND.lua`.
- Modular HUD: `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua`, then `docs/patches/CLEAN_LEGACY_HUD_COMMAND.lua` if old HUD objects remain.
- Legacy Studio-owned duplicates: `docs/patches/DISABLE_LEGACY_STUDIO_SCRIPTS_COMMAND.lua`.
- These scripts are repair tools after scene corruption or migration, not commands that should be required for every Play test.

### Smoke Test Checklist

- 1-player Training: menu opens, Play starts `Training`, camera follows `PlayerTankPrototype`, WASD/A-D movement works, laser/shoot works, dummy takes damage, result and stats show local player data.
- 2-player PvP: Studio test with 2 clients assigns `PlayerTankPrototype` and `Player2TankPrototype`, each client follows and controls only its own tank, shots/damage replicate, winner/loser stats are separate.
- HUD: `StarterGui/HUD/Root` exists, persistent combat HUD is visible only while playing, `RoundStatusPanel` appears only for round/match result.
- Result/Stats: text is local perspective (`You/Opponent` or local player stats), not global `Player/Enemy` stats for both clients.
- Output: no red errors, no `Out of local registers`, no repeated `camera cannot follow`, and no per-frame debug spam.

## Next Milestone — Player HP / Damage / Win-Lose-Restart

- Статус: first code slice implemented in Rojo-managed `WOBGameplayServer` + `WOBRoundStatusOverlay`.
- Scope: player health attributes, ricochet self-hit player damage after first bounce, win/lose attributes, R reset through existing `ResetDummyRequestEvent`.
- Play Mode checks: one active `WOBGameplayServer`; Player HP visible; dummy death shows WIN; player death shows LOSE; R resets player/dummy HP and round result.
- TODO: tune self-hit grace/rules later; no angle damage, PvP, or full state machine yet.
- Какой коммит сделать: `Add player health and round result loop`.

## Current Sprint — Gameplay Feel & Core Rules

- Статус: code-first sprint; priority is stable round loop, readability, shadows, and predictable tank controls.
- Изменения: reverse movement uses a small reverse speed multiplier; A/D steering remains throttle-independent; Player HP overlay is locked/readable; shadows restored through `PerformanceConfig`; ricochet rules captured in `docs/RICOCHET_RULES.md`.
- Future milestone: angle-based ricochet damage after the current round loop is stable; not implemented now.
- Какой коммит сделать: `Improve tank controls UI shadows and ricochet rules`.

## Current Sprint — Editable Player Round UI

- Статус: historical helper only. Earlier Player HP / WIN / LOSE / restart view used editable `StarterGui/HUD/MainPanel`; current HUD work uses modular `StarterGui/HUD/Root/*Panel`.
- Изменения: `WOBRoundStatusOverlay.client.luau` is now a Rojo-managed controller that binds to named Studio HUD elements and only updates text, fill size, colors, and visibility.
- Ручной шаг: do not run this for current HUD work; use `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua`, then `docs/patches/CLEAN_LEGACY_HUD_COMMAND.lua` if legacy `MainPanel` UI is still present.
- Какой коммит сделать: `Make player round UI editable in Studio`.

## Current Sprint — Editable Modular HUD Panels

- Статус: code-first HUD layout cleanup. `WOBRoundStatusOverlay` binds to `StarterGui/HUD/Root` modular panels; `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua` creates missing editable panels.
- Изменения: Enemy HP now binds to `EnemyStatusPanel`; reload state/progress now binds to `WeaponStatusPanel`; Player/Round/Match panels continue reading server attributes.
- Legacy cleanup: run `docs/patches/CLEAN_LEGACY_HUD_COMMAND.lua` after modular HUD setup to remove old `MainPanel`, old dummy/reload/player/result labels, `FeedbackLabel`, and old `WOBHudController` without touching `HUD/Root`.
- Center panel fix: the empty active-game rectangle was `RoundStatusPanel` staying visible while its labels were hidden. `WOBRoundStatusOverlay` now hides the whole panel until WIN/LOSE/restart text is needed; setup/cleanup commands also default it hidden.
- Diagnostic helper: run `docs/patches/PRINT_VISIBLE_HUD_FRAMES_COMMAND.lua` during Play Mode to print visible HUD frames, size/position/transparency, and child label text.
- Play Mode checks: only modular persistent panels are visible during active rounds; Enemy HP, reload, Player HP, round/match labels update; `RoundStatusPanel` appears on WIN/LOSE and disappears after `R`; Output has no red errors.
- HUD naming rule: every logical HUD block must be its own named `*Panel`; scripts bind to named labels/fills inside panels; do not put all UI into one giant `MainPanel`; layout stays editable in Roblox Studio.
- Какой коммит сделать: `Make HUD modular and editable by panels`.

## Current Sprint — Armor / Penetration / Tank Ricochet

- Статус: code-first implementation in Rojo-managed `WOBGameplayServer`, `ProjectileCatalog`, `TankConfig`, and `RicochetMath`.
- Изменения: shells now have penetration/max damage/speed loss; tanks have Front/Side/Rear armor; non-penetrating or auto-ricochet tank hits bounce instead of applying damage; aim laser is visual-only and stops on raycast obstacles.
- Future skeleton: `RicochetMath` is the shared pure module for later corner detection, critical zones, and richer armor math.
- Какой коммит сделать: `Add armor penetration and tank ricochet combat rules`.

## Current Sprint — Armor Hitbox Contract + Spawn Placement

- Статус: code-first sprint. Projectile combat raycast should include map obstacles and tank `Hitboxes`, not turret/barrel/body visuals.
- Изменения: armor zone comes from explicit hitbox name (`FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor`); hitboxes cover hull edges and visibility is config-driven; editable `Map/SpawnPoints/PlayerSpawn` and `DummySpawn` are supported with fallback positions.
- Ручной Studio helper: run `docs/patches/CREATE_SPAWN_POINTS_COMMAND.lua` outside Play Mode to create editable spawn parts, then `File -> Save to File`.
- Play Mode checks: front/side/rear armor hits resolve by hitbox; turret/barrel visual hits do not produce armor result; wall ricochets still work; player/dummy spawn symmetrically and R reset returns them to spawn parts.
- Какой коммит сделать: `Fix armor hitbox targeting and spawn placement`.

## Current Sprint — Combat Feedback Cleanup + Armor Zone Visibility

- Статус: code-first cleanup. Wall ricochets keep `[BOUNCE]` Output debug but no longer show floating `BOUNCE` text.
- Изменения: tank feedback is one screen text per armor hit: damage, `NO PEN`, `RICOCHET`, or `SELF HIT -X`; armor zone visibility is owned by `TankArmorConfig.Visuals`.
- Какой коммит сделать: `Polish combat feedback and restore armor zone visuals`.

## Current Sprint — Remove Direction Arrow + Thin Armor Panels + Match Series

- Статус: code-first sprint. Direction arrow removed; armor panels are now the primary hull orientation visual.
- Изменения: armor panels are thinner/config-driven; SpawnPoints are the source of truth for initial spawn and `R` reset; match series to `MatchConfig.TargetWins` started with round/score attributes.
- Какой коммит сделать: `Remove direction arrow fix spawns and add match series`.

## Current Sprint — TankParticipant v1 Architecture Slice

- Статус: small code slice in current real project only; `New project 2` remains quarantine/reference only.
- Contract: `WOBGameplayServer` now creates runtime participants for `PlayerTankPrototype` and `DummyTank` with `TankId`, `Model`, `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`, `OwnerPlayer`, `OwnerUserId`, `TeamId`, `IsBot`, `SpawnName`, `SpawnTransform`, `WeaponTypeId`, `WeaponConfig`, `LastShotTime`, `WeaponReadyAt`, `Health`, `MaxHealth`, `DefaultMaxHealth`, and `IsDead`.
- What changed: health attribute get/set/reset, damage application, death handling, armor-hitbox-to-target resolution, projectile owner metadata, and player shooting cooldown now flow through participant helpers.
- Preserved behavior: movement, turret aim, shooting, ricochet, armor/penetration, combat feedback events/overlay compatibility, modular HUD attributes, match series to `MatchConfig.TargetWins`, `R` reset, and projectile cleanup on reset.
- Intentionally still hardcoded: the original slice started with `PlayerTankPrototype` and `DummyTank`; PvP Foundation v1 adds a second player slot, but dummy has no AI/shooting, teams are still simple string ids, health defaults remain `100`, and layout, movement, round/match state, and player-slot perspective still live inside the monolithic `WOBGameplayServer`.
- Next recommended task: add a read-only participant debug/audit helper or tiny module boundary only after Play Mode verifies no behavior drift; do not start bot AI, PvP, DataStore, menu, scene edits, or service splitting yet.
- Recommended commit message: `Add TankParticipant v1 runtime slice`.

## Current Sprint — Runtime Match Stats v1

- Статус: runtime-only stats slice in `WOBGameplayServer`; no DataStore, menu, result screen, `.rbxl`, or `default.project.json` changes.
- Storage: stats are exposed as attributes directly on `Workspace.WOB_Generated`: `StatsShotsFired`, `StatsHits`, `StatsRicochets`, `StatsRicochetHits`, `StatsSelfHits`, `StatsDamageDealt`, `StatsDamageTaken`, `StatsRoundsWon`, `StatsRoundsLost`, and `StatsMatchResult`.
- Semantics: `StatsShotsFired` counts accepted player shots; `StatsHits` counts valid tank armor hits from player-fired projectiles; `StatsRicochets` counts actual wall or armor ricochets from player-fired projectiles; `StatsRicochetHits` counts tank armor hits after at least one ricochet; `StatsSelfHits` counts player self-damage from their own projectile; `StatsDamageDealt` excludes self-damage; `StatsDamageTaken` includes self-damage and future enemy damage.
- Reset behavior: stats reset on server start and when `R` starts a new match after `MatchConfig.TargetWins` has ended the current match. Stats do not reset on every round, and `R` during an active or non-final ended round preserves current-match totals.
- Verification: in Play Mode, select `Workspace/WOB_Generated` and inspect Attributes while firing, hitting dummy armor, ricocheting off walls/armor, self-hitting after ricochet, winning/losing rounds, and pressing `R`.
- Preserved behavior: HUD, match flow, `CombatFeedbackEvent`, ricochet/armor rules, participant ownership, projectile cleanup, and current reset behavior are unchanged.
- Next recommended task: Result Screen v1 should read these runtime attributes and display final match stats after `MatchEnded`, without adding DataStore or menu flow yet.
- Recommended commit message: `Add runtime match stats attributes`.

## Current Sprint — WOBGameplayServer Decomposition Plan

- Статус: documentation-only plan in `docs/WOBGAMEPLAYSERVER_DECOMPOSITION_PLAN.md`.
- Context: `WOBGameplayServer` is the current prototype orchestrator for input, movement, participants, shooting, projectiles, ricochet, combat, feedback, round/match state, runtime stats, HUD attributes, and reset flow.
- Rule: do not rewrite it all at once; use phased extraction with Play Mode checks after every phase.
- Next safe extraction candidate: MatchStats, because it is runtime-only, attribute-based, and has low gameplay risk compared with movement, projectile runtime, or match state.
- Recommended commit message: `Add WOBGameplayServer decomposition plan`.

## Current Sprint — Playable Shell v1

- Статус: visible playable shell is implemented and button flow is fixed for editable Studio-created UI plus runtime fallback pieces in `src/StarterPlayer/StarterPlayerScripts/Client/WOBPlayableShell.client.luau`.
- Expected UI hierarchy/names: `StarterGui/WOBPlayableShellGui`; `MainMenuPanel/MenuContent/PlayButton`; optional placeholders `TrainingButton`, `StatsButton`, `SettingsButton`; `StatsPanel/StatsContent/StatsList/*Row/*Label` with `TotalMatchesLabel`, `TotalWinsLabel`, `TotalLossesLabel`, `WinRateLabel`, `TotalShotsFiredLabel`, `TotalHitsLabel`, `AccuracyLabel`, `TotalRicochetsLabel`, `TotalRicochetHitsLabel`, `TotalSelfHitsLabel`, `TotalDamageDealtLabel`, `TotalDamageTakenLabel`, and `StatsBackButton`; `ResultScreenPanel/ResultContent/StatsList/*Row/*Value`; result value labels `MatchResultValue`, `RoundsWonValue`, `RoundsLostValue`, `ShotsFiredValue`, `HitsValue`, `AccuracyValue`, `RicochetsValue`, `RicochetHitsValue`, `SelfHitsValue`, `DamageDealtValue`, `DamageTakenValue`; result buttons `PlayAgainButton` and `BackToMenuButton`. `MenuButton` is accepted as a Back to Menu alias.
- UI ownership: editable Studio setup helpers are `docs/patches/CREATE_MAIN_MENU_COMMAND.lua`, `docs/patches/CREATE_STATS_PANEL_COMMAND.lua`, and `docs/patches/CREATE_RESULT_SCREEN_COMMAND.lua`; the client binds recursively to the editable UI and only creates fallback panels/buttons/labels when required names are missing.
- GameState flow: server starts at `Workspace.WOB_Generated.GameState = "Menu"`; Play and Play Again immediately hide all shell menu panels locally, fire `StartMatchRequestEvent`, reset tanks/projectiles/match/runtime stats on the server, then server confirms `GameState = "Playing"`; reaching final `MatchConfig.TargetWins` sets `GameState = "Result"`; Back to Menu immediately returns the shell locally, fires `ReturnToMenuRequestEvent`, clears projectiles on the server, and confirms `GameState = "Menu"`. Active-game `R` reset remains gameplay-only while `GameState = "Playing"`.
- Runtime stats storage: result screen reads `StatsShotsFired`, `StatsHits`, `StatsRicochets`, `StatsRicochetHits`, `StatsSelfHits`, `StatsDamageDealt`, `StatsDamageTaken`, `StatsRoundsWon`, `StatsRoundsLost`, and `StatsMatchResult` directly from `Workspace.WOB_Generated`.
- Debug verification logs: client prints `[SHELL] bound main menu`, `[SHELL] Play clicked`, `[SHELL] PlayAgain clicked`, `[SHELL] BackToMenu clicked`, and `[SHELL] GameState changed -> ...`; server prints `[SERVER] StartMatch requested ...` and `[SERVER] ReturnToMenu requested ...`.
- Play Mode verification: start Play Mode and confirm Main Menu appears with HUD hidden; Play immediately hides every `WOBPlayableShellGui` menu panel, changes `GameState` to `Playing`, and shows HUD; tank movement, turret aim, shooting, ricochet, armor/penetration, combat feedback, match score to `TargetWins`, runtime stats, and active-game `R` reset still work; final match result changes `GameState` to `Result`; Result Screen displays stats; Play Again starts a fresh match and resets runtime stats; Back to Menu returns to menu and combat stops; no duplicate MainMenu/ResultScreen UI and no red Output errors.
- Recommended commit message: `Fix playable shell flow`.

## Current Sprint — Persistent Player Stats v1

- Статус: DataStore-backed cumulative stats are added as a small module at `src/ServerScriptService/Server/Gameplay/Stats/PersistentPlayerStatsService.luau`; no DataStore writes happen during shots or rounds.
- Save timing: persistent totals save once at final match result, after `MatchConfig.TargetWins` ends the match and `StatsMatchResult` is set.
- DataStore storage: store name is `WOBPersistentPlayerStatsV1`; player key is `Player_<UserId>`.
- Exposed loaded totals: player attributes `PersistentTotalMatches`, `PersistentTotalWins`, `PersistentTotalLosses`, `PersistentTotalShotsFired`, `PersistentTotalHits`, `PersistentTotalRicochets`, `PersistentTotalRicochetHits`, `PersistentTotalSelfHits`, `PersistentTotalDamageDealt`, and `PersistentTotalDamageTaken`.
- Local/session fallback totals: every completed match also updates `SessionTotalMatches`, `SessionTotalWins`, `SessionTotalLosses`, `SessionTotalShotsFired`, `SessionTotalHits`, `SessionTotalRicochets`, `SessionTotalRicochetHits`, `SessionTotalSelfHits`, `SessionTotalDamageDealt`, `SessionTotalDamageTaken`, plus `UnsavedTotal*` attributes for DataStore failures/retries.
- Failure behavior: DataStore access is acquired lazily, not during module require; all `DataStoreService` reads/writes are wrapped in `pcall`; failure logs use `[DATASTORE]` warnings and gameplay continues. `PersistentStatsLoaded` and `PersistentStatsLastSaveSucceeded` tell the client whether to prefer persistent totals or local fallback totals.
- Studio DataStore requirements: publish the experience, then enable `Game Settings -> Security -> Enable Studio Access to API Services`; test final-match saving in Studio or Roblox. Without API access, persistent load/save can warn with `[DATASTORE]`, but gameplay should continue.
- Verification: after a final match with API services enabled, inspect the controlling `Player` attributes and confirm totals increased by the match's runtime stats; with API services disabled, confirm only `[DATASTORE]` warnings appear and the shell/gameplay flow still works.
- Next recommended task: Result Screen polish or Main Menu mode selection.
- Recommended commit message: `Add persistent player stats`.

## Current Sprint — Stats Panel v1 + Clean Shell HUD

- Статус: `StatsButton` now opens an in-shell `StatsPanel`; no profile screen, monetization, multiplayer, `.rbxl`, or `default.project.json` changes.
- Stats source: `WOBPlayableShell.client.luau` prefers `PersistentTotal*` player attributes when they are loaded and current; when DataStore is unavailable or the last save failed, it displays `SessionTotal*` or persistent plus `UnsavedTotal*` fallback values.
- Calculated values: `WinRate` is `TotalWins / TotalMatches * 100`; `Accuracy` is `TotalHits / TotalShotsFired * 100`; both safely show `0%` when the denominator is zero.
- HUD visibility rules: `Menu`, `StatsPanel`, and `Result` hide combat HUD ScreenGuis/panels, aim laser, combat feedback, and impact feedback; `Playing` shows the combat HUD and hides Main Menu, StatsPanel, and Result Screen.
- HUD cooperation: `WOBRoundStatusOverlay` respects `Workspace.WOB_Generated.GameState` and keeps its ScreenGui disabled outside `Playing`; combat/impact feedback clear themselves outside `Playing`.
- Play Mode verification: start game and confirm Main Menu is clean with no Enemy HP/Reload/Player HP/MatchSeries behind it; click Stats and confirm totals/win rate/accuracy display; Stats Back returns to Main Menu; Play shows HUD and starts gameplay; final match shows only Result Screen; completed match increments persistent totals when DataStore works or session/unsaved totals when DataStore is unavailable; BackToMenu returns to clean Main Menu.
- Next recommended task: Result Screen polish or Main Menu mode selection.
- Recommended commit message: `Add stats panel and clean shell HUD visibility`.

## Current Sprint — Playable Shell Editor UI Helpers

- Статус: editor-only command scripts live in `docs/patches`; they are for Roblox Studio outside Play Mode and do not change runtime `GameState` behavior.
- Hide shell UI in editor: run `docs/patches/HIDE_PLAYABLE_SHELL_UI_EDITOR_COMMAND.lua` to set `StarterGui/WOBPlayableShellGui/MainMenuPanel`, `ResultScreenPanel`, and `StatsPanel` invisible without disabling `WOBPlayableShellGui.Enabled`.
- Show main menu for editing: run `docs/patches/SHOW_MAIN_MENU_EDITOR_COMMAND.lua`; it shows `MainMenuPanel` and hides `ResultScreenPanel` plus `StatsPanel`.
- Show stats panel for editing: run `docs/patches/SHOW_STATS_PANEL_EDITOR_COMMAND.lua`; it shows `StatsPanel` and hides `MainMenuPanel` plus `ResultScreenPanel`.
- After manual UI edits in Studio, use `File -> Save to File` so `RicochetTanksPrototype.rbxl` captures the editable UI changes.
- Play Mode rule: the game still shows/hides shell panels from `WOBPlayableShell.client.luau` using `Workspace.WOB_Generated.GameState`; editor helper visibility is only for Studio editing comfort.
- Recommended commit message: `Add playable shell editor UI helpers`.

## Current Sprint — PvP Foundation v1

- Статус: possession-oriented foundation slice inside the current `WOBGameplayServer`; no matchmaking, lobby, DataStore, `.rbxl`, `default.project.json`, or full orchestrator rewrite.
- Bootstrap order: `src/ServerScriptService/Server/WOBPvPBootstrap.server.luau` runs as a small early server script. It sets `Players.CharacterAutoLoads = false`, creates `ReplicatedStorage/Remotes` with `TankInputEvent`, `ShootRequestEvent`, `ResetDummyRequestEvent`, `StartMatchRequestEvent`, `ReturnToMenuRequestEvent`, and `CombatFeedbackEvent`, removes/suppresses any already spawned characters, and guarantees `Workspace/WOB_Generated/Runtime`, `Runtime/Projectiles`, and `Runtime/VFX` exist before client overlays need them.
- StartMatch startup fix: `WOBGameplayServer` connects `StartMatchRequestEvent.OnServerEvent` before waiting on full scene objects, logs `[SERVER] StartMatch handler connected`, and queues early Play clicks until the gameplay server is ready. This avoids the failure mode where `[SHELL] Play clicked` appears but no server handler has been connected yet.
- Server tank layer: `src/ServerScriptService/Server/Gameplay/PlayerTankSpawner.luau` creates or reuses a runtime `Player2TankPrototype` clone from `PlayerTankPrototype` under `Workspace/WOB_Generated/TestObjects`.
- Participant contract: `TankParticipant` is the combat entity for a tank, independent from who controls it. Current participants include `TankId`, `OwnerPlayer`, `OwnerUserId`, `TeamId`, `SpawnName`/spawn transform, health state, `WeaponState`, `ControllerType`, and replicated model attributes `OwnerUserId`, `OwnerName`, `TankId`, `TeamId`, `IsPlayerTank`, and `ControllerType`.
- Controller/Brain model: `ControllerType` is the current seam for future control sources. Supported contract values are `"Player"`, `"Bot"`, and `"Dummy"`; this slice only implements `"Player"` tanks plus the existing `"Dummy"` training target. `BotBrain` is not implemented yet, but the participant model should allow a future brain to drive any `TankParticipant`.
- Player assignment: first joined/assigned player gets `PlayerTankPrototype`; second joined/assigned player gets `Player2TankPrototype`; server-side `TankInputEvent` and `ShootRequestEvent` resolve `player -> TankParticipant` before moving or firing, so one client cannot drive another client's tank.
- Mode behavior: `Workspace/WOB_Generated.MatchMode` is `Training` with one assigned player and `PvP` when two player tank slots are occupied. In Training the dummy is active; in PvP the dummy is hidden/inactive and `Player2TankPrototype` is active.
- Possession behavior: `Players.CharacterAutoLoads = false` is set as early as possible; any already existing character is hidden, made non-colliding/non-querying, anchored, moved far below the arena, and destroyed. Players should not run around as humanoid characters during menu, training, or PvP.
- Client tank control: `WOBTankInputController.client.luau` is the single active possession input controller. The server bootstrap disables the legacy Studio-owned `StarterPlayerScripts/WOBClientController` before it is copied when possible; the client controller also safely disables any remaining `PlayerScripts/WOBClientController` copy, then waits for the local owned tank by `OwnerUserId == LocalPlayer.UserId` before sending WASD/arrow movement or mouse shoot through existing remotes. Server validation remains the authority.
- Camera possession: `WOBTankPossessionCamera.client.luau` finds the local owned tank by `OwnerUserId == LocalPlayer.UserId` and follows its `Body` with the top-down camera config; it logs `[PVP] local owned tank found: ...` and `[PVP] camera following ...`.
- Client-local team colors: `WOBTankLocalTeamVisuals.client.luau` recolors only local visual parts (`Body`, `Turret`, `Barrel`) so the owned tank appears friendly blue/green and enemy player/dummy tanks appear red. Armor hitbox parts are not recolored and damage/armor logic does not depend on these colors.
- Projectile metadata: projectiles keep `OwnerPlayer`, `OwnerUserId`, `OwnerTankId`, `OwnerTeamId`, and `OwnerParticipant` for both player tanks.
- Round result: damage/death resolution now checks the destroyed `TankParticipant`; in PvP, death of `PlayerTankPrototype` counts as a loss for player slot 1 and death of `Player2TankPrototype` counts as a win for player slot 1. Existing `TargetWins`, `PlayerWins`, `DummyWins`, and result screen flow are preserved for now.
- Aim laser: client laser resolves the local player's owned tank via `OwnerUserId`, so Studio 2-player clients aim from their own tank. It no longer falls back to a possibly чужой `PlayerTankPrototype` while ownership is still replicating.
- Studio 1-player test: start Play with one player, confirm no humanoid walking, Play starts `Training`, camera follows `PlayerTankPrototype`, dummy is target, shooting/ricochet/damage/result still work.
- Startup order contract: bootstrap remotes/folders and disable legacy input, gameplay server assigns tanks, clients find owned tank, then input/camera/laser start. Clients must not fall back to another player's `PlayerTankPrototype`.
- Impact feedback rule: `WOBImpactFeedbackOverlay` must not infinite-yield on `DummyTank.Body`; in PvP the dummy can be inactive or late, so dummy-specific pulse styling is skipped when the body is unavailable.
- Studio 2-player test: use `Test -> Clients and Servers` with `Players = 2`, keep only one active Rojo-managed `WOBGameplayServer`, click `Play`, confirm no humanoid walking, no infinite-yield warnings for `StartMatchRequestEvent`, `CombatFeedbackEvent`, `Runtime/Projectiles`, or `Runtime/VFX`, client 1 camera/aim/input uses `PlayerTankPrototype`, client 2 camera/aim/input uses `Player2TankPrototype`, own tank is friendly color, enemy tank is red, projectiles/damage replicate to both, and destroying one tank ends the round to `TargetWins`.
- Useful logs: server logs `[PVP] CharacterAutoLoads disabled`, `[PVP] remotes bootstrapped`, `[PVP] runtime folders bootstrapped`, `[PVP] assigned PlayerName -> TankId`, `[PVP] mode = Training/PvP`, `[PVP] character removed/suppressed for PlayerName`, and first input ownership; clients log local tank/camera possession and `[PVP] legacy input controller disabled: WOBClientController` when the old controller is suppressed.
- Still hardcoded: two player controller slots only; no matchmaking/lobby/mode selection; player 2 tank is a clone of player 1 art; score attributes are still player-slot-1 perspective (`PlayerWins` vs `DummyWins`); HUD labels are not yet fully per-client PvP perspective; disconnect handling is minimal; the old Studio-owned scripts still need to stay non-conflicting until fully migrated.
- Next recommended task: TankBrain/Controller abstraction v1, then PvP lobby/free-drive test mode later.
- Recommended commit message: `Fix PvP tank possession`.

## Current Sprint — PvP Possession Stability Audit + Contract Fix

- Статус: code-first stabilization after fast PvP/refactor edits.
- Audit: `docs/PVP_POSSESSION_STABILITY_AUDIT.md` records Rojo mapping, current runtime scene expectations, snapshot mismatch, tank registration/clone points, client possession lookup points, HUD warning cause, Player2 spawn path bug, legacy conflict risks, blockers, likely root causes, and minimal fix order.
- Server tank contract: every `TankParticipant.Model` must be the physical tank `Model`. The model must have `Body` or `Hull` or at least one `BasePart`, plus `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`, `PrimaryPart`, and attributes `TankId`, `OwnerUserId`, `OwnerName`, `TeamId`, `ControllerType`, and `IsPlayerTank`. Server logs `[TANK] registered TankId model=... primaryPart=... baseParts=...`; if no part exists it warns `[TANK] warning TankId has no BasePart`.
- Runtime self-heal: `PlayerTankSpawner` can repair missing physical parts at runtime so a wrapper-only `PlayerTankPrototype` no longer breaks camera/input/shoot immediately. This is a safety net, not a replacement for saving the fixed scene.
- Scene repair command: run `docs/patches/CREATE_TANK_MODEL_CONTRACT_COMMAND.lua` in Roblox Studio outside Play Mode, then `File -> Save to File`. It creates/updates `Workspace/WOB_Generated/TestObjects/PlayerTankPrototype`, `Player2TankPrototype`, and `DummyTank` with physical parts, hitboxes, attributes, health attributes, and `PrimaryPart`.
- HUD setup command: run `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua` outside Play Mode, then `docs/patches/CLEAN_LEGACY_HUD_COMMAND.lua`, then `File -> Save to File`. Expected path is `StarterGui/HUD/Root` with `EnemyStatusPanel`, `WeaponStatusPanel`, `PlayerStatusPanel`, `RoundStatusPanel`, and `MatchSeriesPanel`.
- Spawn setup commands: run `docs/patches/CREATE_SPAWN_POINTS_COMMAND.lua`, then `docs/patches/CREATE_PLAYER2_SPAWN_COMMAND.lua`, then `File -> Save to File`. `Player2Spawn` must be created at `Workspace/WOB_Generated/Map/SpawnPoints/Player2Spawn`, not `Workspace/Map`.
- Legacy cleanup command: run `docs/patches/DISABLE_LEGACY_STUDIO_SCRIPTS_COMMAND.lua` outside Play Mode after Rojo sync to disable old Studio-owned `WOBClientController`, `WOBHudController`, `WOBDummyRespawnServer`, and old server helpers that may duplicate Rojo-managed behavior.
- Client possession: camera, input, aim laser, team colors, and round HUD resolve the local owned physical tank by `OwnerUserId == LocalPlayer.UserId`; they do not fall back to another player's `PlayerTankPrototype`.
- HUD PvP perspective: `WOBRoundStatusOverlay` now treats the local owned tank as Player HP and uses Dummy in Training or the other active player tank in PvP as Enemy HP.
- Verification: 1-player Training should log `[PVP] mode = Training`, `[SERVER] Match started -> Playing mode=Training`, `[PVP] camera follow started: PlayerTankPrototype part=...`, input received/applied, aim laser/shoot/dummy damage/result/stats working. 2-player PvP should assign Player1/Player2 to separate tanks, log `[PVP] mode = PvP`, and each client camera should follow its own tank.
- Known limitations: still only two player tank slots; no BotBrain, lobby, matchmaking, mode selection, new weapons, or changed armor formulas.
- Recommended commit message: `Stabilize PvP tank possession contract`.

## GDD Parity Backlog

1. Core combat parity:
   - penetration;
   - max damage;
   - armor zones;
   - effective armor;
   - tank armor ricochet.

2. Feedback parity:
   - `NO PEN` / `RICOCHET` / `DAMAGE` feedback;
   - floating hit text;
   - death/wreck feedback.

3. Match flow parity:
   - series to 3 wins;
   - round break timer;
   - final result.

4. Product loop parity:
   - main menu;
   - statistics;
   - recent matches.

5. AI parity:
   - enemy tank AI;
   - aim at player;
   - line of sight;
   - obstacle avoidance.

6. Mobile parity:
   - mobile arcade controls;
   - thumb UI.

- Аудит: `docs/GDD_PARITY_AUDIT.md`.
- Какой коммит сделать: `Audit Roblox GDD parity with Unity design`.

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

### Task 08.01a — Prepare projectile ground glow patch

- Статус: config updated + patch prepared; active `.rbxl` script still needs manual Studio paste.
- Цель: добавить visual-only glow under projectile so fast shots are easier to read in top-down camera.
- Файлы можно трогать: `src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau`, `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau`, `docs/patches/TANK_BLOCKING_AND_PROJECTILE_GLOW_STUDIO_STEPS.md`, `docs/PROJECT_AUDIT.md`, `docs/CODEX_TASKS.md`.
- Ожидаемый результат: `ProjectileVisualConfig` owns `GroundGlowEnabled`, `GroundGlowSize`, `GroundGlowTransparency`, `GroundGlowHeightOffset`, `GroundGlowColor`; visual enhancer creates and follows a non-colliding `WOBGroundGlow`.
- Ручной шаг: replace `ServerScriptService/Services/WOBProjectileVisualEnhancer` Source in Roblox Studio with `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau` after Rojo syncs `ProjectileVisualConfig`.
- Риски: do not move damage/speed/max ricochets into `ProjectileVisualConfig`; glow must keep `CanQuery = false`; cleanup must stay tied to projectile visual destruction.
- Play Mode checks: projectile flies as before; ricochets and dummy damage still work; glow is visible under projectile; glow does not block raycast; glow is removed with projectile; Output has no errors.
- Какой коммит сделать: `Add projectile ground glow patch`.

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

## Mobile Playtest Performance Checklist

- Phone join from the published link.
- Lobby FPS feels stable near pads, signs, and showcases.
- BattleArena FPS feels stable during driving, shooting, death, and respawn.
- Shooting does not stutter badly.
- HP/reload world bars are readable at mobile distance and do not duplicate after respawn.
- No fire/campfire loop sound after death VFX.
- No repeated output spam in Studio.
- No new orphan `Assets`, `UI`, `VFX`, `UX`, or runtime folders outside the WOB contracts.
- Old Player HP / Enemy HP / Reload HUD panels do not cover mobile combat.
- Manual scene performance edits require visual review; do not run repair/organize/clean/move scripts.

## Gameplay/UX Fix Checklist

- TrainingPad/StartPad starts Training and does not route players into Duel or BattleArena.
- Main Menu Play still starts quick Training.
- DuelPad still queues two players for PvP Duel.
- ArenaPad still starts BattleArena.
- Mobile BattleArena stats fit the screen width with Arena Level/XP, K/D, Crystals, and optional Bolts.
- Mobile Duel/Training match stats fit the screen width.
- World HP/reload bars stay anchored to the tank body/hull while turret and barrel rotate.
- Duel tanks spawn facing each other.
- Training player spawns facing DummyTank.
- BattleArena spawn/respawn is unchanged.
- No VFX/UI template, Rojo mapping, mobile controls, camera, bot, upgrade, or Extraction changes in this pass.

## Duel HUD And Projectile Boundary Checklist

- Duel hides legacy `You HP`, `Opponent HP`, and `Reload` panels when world HP/reload bars are enabled.
- Duel round/score/first-to-3 UI remains visible.
- Mobile Duel round/score panel uses a compact top-center layout and keeps old HP/reload panels hidden.
- Projectile movement uses previous-to-next swept raycast.
- Active armor hitboxes are queryable before projectile raycast.
- Armor zones are welded to the stable tank body/hull, visible by default, and not treated as separate smoothed visuals.
- `ProjectileCatalog` owns damage/penetration/speed/lifetime values.
- `WeaponConfig` chooses the projectile id and weapon cooldown.
- VFX/audio configs remain visual/audio only.
