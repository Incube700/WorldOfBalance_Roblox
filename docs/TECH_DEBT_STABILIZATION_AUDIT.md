# Tech Debt Stabilization Audit

Дата аудита: 2026-05-09

## Preflight

Перед изменениями выполнено:

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

## 1. Current Architecture

`WOBGameplayServer.server.luau` сейчас является тонким оркестратором:

- получает `Workspace.WOB_Generated`, `Runtime`, `Map`, `TestObjects`;
- создает/находит remotes;
- берет физические tank models;
- регистрирует `TankParticipant`;
- инициализирует сервисы;
- связывает server remotes с possession, shooting, reset/menu flow;
- в `Heartbeat` применяет player input к participant control state и вызывает layout/projectile update.

Сервисы:

- `PlayerTankSpawner`: runtime safety net для физического tank model contract, создает недостающие `Body/Turret/Barrel/ShootPoint/Hitboxes`.
- `TankParticipantRegistry`: registry боевых сущностей танков, owner attributes, visibility, health/death attributes, lookup по TankId/model/hitbox.
- `TankSpawnResetService`: spawn transform lookup, tank layout, health/weapon reset support, active participant visibility.
- `PlayerPossessionService`: назначение Roblox Player -> player tank participant, suppression humanoid character, input state bucket.
- `TankMovementService`: blockcast/overlap movement against map obstacles.
- `ProjectileService`: projectile lifecycle, shooting cooldown, raycast target collection, hit dispatch.
- `ProjectileCombatService`: armor result, penetration/ricochet/self-hit handling, combat feedback.
- `RoundMatchService`: game state, match mode, round/match result, series score, reset/start flow.
- `MatchStatsService`: runtime match stats, currently global on `Workspace.WOB_Generated`.
- `PersistentPlayerStatsService`: per-user DataStore/session/unsaved totals on Player attributes.

Training critical path:

- `WOBGameplayServer`
- `PlayerTankSpawner`
- `TankParticipantRegistry`
- `TankSpawnResetService`
- `PlayerPossessionService`
- `TankMovementService`
- `ProjectileService`
- `ProjectileCombatService`
- `RoundMatchService`
- `MatchStatsService`
- `PersistentPlayerStatsService`
- client camera/input/laser/HUD/shell.

PvP critical path adds:

- second player assignment to `Player2TankPrototype`;
- `RoundMatchService.updateMatchMode`;
- `TankSpawnResetService.configureActiveParticipants`;
- per-player stats/result perspective.

Runtime stats are currently stored in `MatchStatsService.matchStats` and mirrored as attributes on `Workspace.WOB_Generated`:

- `StatsShotsFired`
- `StatsHits`
- `StatsRicochets`
- `StatsRicochetHits`
- `StatsSelfHits`
- `StatsDamageDealt`
- `StatsDamageTaken`
- `StatsRoundsWon`
- `StatsRoundsLost`
- `StatsMatchResult`

Persistent stats are in `PersistentPlayerStatsService`:

- DataStore name: `WOBPersistentPlayerStatsV1`;
- key format: `Player_<UserId>`;
- persistent attributes on Player: `PersistentTotal*`;
- session fallback attributes on Player: `SessionTotal*`;
- unsaved attributes on Player: `UnsavedTotal*`.

Client scripts:

- `WOBTankPossessionCamera`: owned tank lookup and top-down camera.
- `WOBTankInputController`: keyboard/mouse input and shoot remote.
- `WOBAimLaser`: local aim laser from owned tank muzzle.
- `WOBTankLocalTeamVisuals`: local friendly/enemy coloring.
- `WOBRoundStatusOverlay`: combat HUD, HP/reload/round/series text.
- `WOBPlayableShell`: menu/result/stats panels.
- `WOBCombatFeedbackOverlay`: floating damage feedback.
- `WOBImpactFeedbackOverlay`: local impact readability VFX.
- `WOBProjectileReadabilityOverlay`: local projectile glow readability.

## 2. File Review Summary

Server files reviewed:

- `WOBGameplayServer.server.luau`: orchestration only, but still contains input application loop and damage/end-round bridge. Should not receive more business logic.
- `RoundMatchService.luau`: stores global match result and score as Player vs Dummy, even when mode is PvP.
- `ProjectileService.luau`: records `recordShotFired` using legacy `getPlayerParticipant`, so Player2 shots are not counted.
- `ProjectileCombatService.luau`: receives a single `playerParticipant` for stats, so Player2 hit/damage stats are not correct.
- `TankParticipantRegistry.luau`: physical model contract is stable; critical warning exists for no BasePart.
- `TankSpawnResetService.luau`: uses root-level `SpawnPoints` with legacy `Map/SpawnPoints` fallback; `PLAYER2_INITIAL_POSITION` still falls back to dummy position if no scene spawn exists.
- `PlayerPossessionService.luau`: assigns first available player participant and owner attrs; persistence load is per player.
- `MatchStatsService.luau`: critical debt, global runtime stats.
- `PersistentPlayerStatsService.luau`: per-user key is correct; win/loss deltas assume `PlayerMatchWin`/`DummyMatchWin`, not per-player `Win`/`Loss`.
- `PlayerTankSpawner.luau`: runtime repair should remain safety net only; command script should be scene source of truth.

Client files reviewed:

- `WOBTankPossessionCamera`: correct physical model lookup; repeated failure log is throttled.
- `WOBTankInputController`: input alive; `[INPUT]` logs every 2s while playing, debug-only candidate.
- `WOBAimLaser`: uses physical owned tank and muzzle.
- `WOBTankLocalTeamVisuals`: colors physical tanks; useful owned tank log can be debug-only.
- `WOBPlayableShell`: Result Screen reads global `Workspace` stats; StatsPanel reads local Player persistent/session/unsaved totals.
- `WOBRoundStatusOverlay`: HUD reads local owned tank and enemy tank, but labels still say `Player`/`Enemy`; PvP wording is not correct.
- `WOBCombatFeedbackOverlay`, `WOBImpactFeedbackOverlay`, `WOBProjectileReadabilityOverlay`: mostly visual; startup logs are not critical.

Shared files reviewed:

- `TankModelResolver`: correct physical tank lookup by `OwnerUserId`, `PhysicalModelPath`, `TankId`; excludes hitboxes from focus part.
- `CameraConfig`: camera/input constants only.
- `HudConfig`: legacy wording still includes Dummy health.
- `MatchConfig`: series enabled, target wins = 3.
- `WeaponConfig`, `ProjectileCatalog`: values should not change in this pass.

## 3. Debug Prints

Always keep:

- `[WOB] Gameplay server started`
- `[SERVER] StartMatch handler connected`
- `[SERVER] Match started -> Playing mode=...`
- `[PVP] assigned PlayerName -> TankId`
- `[PVP] camera follow started: TankId part=...`
- `[TANK] CRITICAL ... has no BasePart`
- `[DATASTORE] ... unavailable/failed`
- `[WOB] Modular HUD not found ...`
- `[SPAWN] ... using fallback ...`

Debug-only or throttle:

- `[INPUT] client sending move/shoot ...`
- `[SERVER] TankInput received ...`
- `[SERVER] input applied ...`
- `[BOUNCE]`
- `[PEN]`
- `[NO-PEN]`
- `[SELF-HIT]`
- repeated `[PVP] camera cannot follow ...`
- `[SHELL] clicked/state changed`
- most startup `[WOB] ... overlay started`

Remove or avoid expanding:

- per-frame projectile/update logs; none found active.
- repeated ownership-found logs across multiple client scripts should be debug-only.

## 4. Stats Flow

Current state:

- Runtime stats are global, not per-player.
- `ProjectileService.tryShoot` records shots only when owner is the legacy `playerParticipant` (`PlayerTankPrototype`).
- `ProjectileCombatService` records hits/damage using the same single `playerParticipant`.
- `RoundMatchService.endRound(result)` treats `Win/Lose` as "PlayerTankPrototype vs Dummy" even in PvP.
- At match end, the same global stats snapshot is saved for every player participant.
- `PersistentPlayerStatsService` itself is per-user and uses `Player_<UserId>`, but it receives the wrong snapshot/result in PvP.

Training:

- Usually works for Player1 vs Dummy because global perspective matches local player.
- Dummy is not persisted because it has no `OwnerPlayer`.

PvP:

- If Player1 destroys Player2, global result is `PlayerMatchWin` and can be saved as win for both players.
- If Player2 destroys Player1, global result becomes `DummyMatchWin` style loss and can be saved as loss for both players.
- Player2 shots/hits/damage are not reliably counted.
- Client2 Result Screen can show Player1/global stats instead of its own.

Answer:

- stats are global today;
- DataStore is per-user but fed with global snapshot;
- local player sees global match result stats in Result Screen;
- StatsPanel sees local player persistent/session attributes;
- winner/loser are not guaranteed correct in PvP;
- shots/hits/damage are tied to legacy PlayerTankPrototype perspective, not owner UserId.

## 5. UI Wording

Acceptable in Training:

- `Player`
- `Enemy`
- `Dummy`

Breaks in PvP:

- `Enemy HP`
- `Player HP`
- `Score: Player / Enemy`
- `PlayerMatchWin`/`DummyMatchWin` style result text if shown to both clients.

Preferred minimal wording:

- health HUD: `You HP` / `Opponent HP`;
- score HUD: `Score: You X / Opponent Y`;
- Result Screen: `Victory` / `Defeat` from local player's result;
- Stats Panel: `Your Stats`.

`Player 1 / Player 2` is only useful for neutral spectator/admin views; local client UI should be `You / Opponent`.

## 6. Scene Contract

Expected saved scene contract:

```text
Workspace/WOB_Generated/TestObjects/PlayerTankPrototype
Workspace/WOB_Generated/TestObjects/Player2TankPrototype
Workspace/WOB_Generated/TestObjects/DummyTank
```

Each tank should have:

- `Body`
- `Turret`
- `Barrel`
- `ShootPoint`
- `Hitboxes`
- `PrimaryPart`
- `BaseParts > 0`
- attributes: `TankId`, `OwnerUserId`, `OwnerName`, `TeamId`, `ControllerType`, `IsPlayerTank`.

Spawn contract:

```text
Workspace/WOB_Generated/SpawnPoints/PlayerSpawn
Workspace/WOB_Generated/SpawnPoints/Player2Spawn
Workspace/WOB_Generated/SpawnPoints/DummySpawn
```

Legacy fallback:

```text
Workspace/WOB_Generated/Map/SpawnPoints
```

UI contract:

```text
StarterGui/HUD/Root
StarterGui/WOBPlayableShellGui
```

The binary `.rbxl` was not modified or inspected directly in this pass.

## 7. Command Scripts

One-time scene setup, then repair tools:

- `CREATE_TANK_MODEL_CONTRACT_COMMAND.lua`
- `CREATE_SPAWN_POINTS_COMMAND.lua`
- `CREATE_PLAYER2_SPAWN_COMMAND.lua`
- `CREATE_MODULAR_HUD_COMMAND.lua`

Cleanup/repair tools:

- `CLEAN_LEGACY_HUD_COMMAND.lua`
- `DISABLE_LEGACY_STUDIO_SCRIPTS_COMMAND.lua`

Issues found:

- required scripts do not have `RunService:IsRunning()` guard yet.
- safe to keep them as repair tools, but dangerous to run in Play Mode because they mutate `Workspace`, `StarterGui`, or script enabled flags.
- later they can be combined into one "repair scene contract" command, but that is not necessary now.

## 8. Legacy Scripts

Known legacy scene scripts:

- `StarterPlayer/StarterPlayerScripts/WOBClientController`
- `StarterGui/HUD/WOBHudController`
- `ServerScriptService/Services/WOBGameplayServer`
- `ServerScriptService/Services/WOBDummyRespawnServer`
- `ServerScriptService/Services/WOBPerformanceServer`
- `ServerScriptService/Services/WOBProjectileVisualEnhancer`

Current safeguards:

- bootstrap and input controller disable legacy `WOBClientController`;
- `DISABLE_LEGACY_STUDIO_SCRIPTS_COMMAND.lua` disables known Studio-owned legacy duplicates;
- Rojo does not own these scene paths, so manual command + save is still required after scene corruption/import.

## Critical Issues

1. Runtime match stats are global, not per-player.
2. PvP result semantics are PlayerTankPrototype-centric, so winner/loser persistence is wrong.
3. Player2 shots/hits/damage are not counted because stats callbacks use legacy Player1 participant.
4. Result Screen reads root global stats, so Client2 can see Player1/global values.
5. Command scripts lack Play Mode guards.

## High Priority Tech Debt

- UI wording in HUD/result should be local perspective in PvP.
- `RoundMatchService` score attributes are `PlayerWins`/`DummyWins`; okay for legacy display, but need per-player result attributes for correct client UI.
- `[INPUT]`, `[SERVER] input applied`, `[SHELL]` logs should be debug-only/throttled.
- `PersistentPlayerStatsService.getMatchDeltas` should accept per-player `Win`/`Loss`, not only global `PlayerMatchWin`/`DummyMatchWin`.

## Medium Priority Tech Debt

- Command scripts can later be consolidated.
- Startup overlay logs can be quieter.
- `HudConfig` wording still mirrors Dummy-era UI.
- `PLAYER2_INITIAL_POSITION` fallback still equals dummy initial position if no spawn exists.

## Low Priority Cleanup

- Old docs in `docs/patches/README_VISIBLE_SPRINT.md` still mention Studio-owned `WOBGameplayServer`.
- `ServerHello`/`ClientHello` smoke logs are still present.
- Some visual overlay scripts have hardcoded legacy naming, but they do not block MVP.

## Minimal Safe Fix Plan

1. Refactor `MatchStatsService` to per-player/per-participant runtime stats while keeping root attributes for legacy Player1 compatibility.
2. Persist final match stats with local `Win`/`Loss` result per player.
3. Update projectile stat calls to use owner/target participant, not legacy Player1.
4. Update `WOBPlayableShell` Result Screen to read local Player runtime stats attributes.
5. Adjust HUD wording to `You/Opponent` with minimal text-only changes.
6. Add debug constants for input/server/shell/camera logs.
7. Add `RunService:IsRunning()` guard to required command scripts.
8. Document Stable MVP Contracts in `docs/CODEX_TASKS.md`.
9. Run `git diff --check` and `rojo build`.

