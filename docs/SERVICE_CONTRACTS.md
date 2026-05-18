# Service Contracts

This document describes the current Roblox/Rojo service boundaries for World of Balance: Ricochet Tanks.

Core rule:

```text
Gameplay services produce facts.
Presentation controllers produce feelings.
```

Server gameplay remains authoritative for position resolution, projectile creation, damage, death, match state, arena state, rewards, and persistent data. Client scripts own input intent, camera, local readability, HUD, overlays, audio playback, and visual smoothing.

## WOBGameplayServer.server.luau

### Responsibility

`WOBGameplayServer.server.luau` is the gameplay orchestrator. It wires services together, creates/gets remotes, registers initial participants, owns the server heartbeat loop, and bridges server gameplay facts to clients.

It should stay thin. New feature logic should live in focused services instead of growing this file into a god object.

### What It Owns

- Server bootstrap order.
- Core service initialization.
- `Workspace.WOB_Generated.Runtime.Projectiles` and `Runtime.VFX` folder setup.
- Initial prototype participant registration for player, dummy, and Player2.
- RemoteEvent creation/wiring.
- Player lifecycle wiring.
- The heartbeat order:
  - `LobbyService.update(deltaTime)`
  - server-authoritative player movement application
  - `TrainingBotService.update(deltaTime)`
  - `ProjectileService.updateProjectiles(deltaTime)`
- `damageParticipant` bridge used by projectile combat.
- `CombatFeedbackEvent` payload emission helper.
- Death VFX orchestration through `ProjectileService.getVFXHelpers()`.

### What It Must Not Own

- Match rules beyond orchestration.
- Lobby queue/pad rules.
- Arena session rules.
- Projectile formulas.
- Armor/ricochet/damage formulas.
- Wallet/economy rules.
- Bot intelligence.
- Client UI/audio/VFX presentation decisions.
- Tank prefab/customization systems beyond initialization wiring.

### Public Functions / Entry Points

This is a server script, not a ModuleScript. Its entry points are Roblox lifecycle hooks and RemoteEvent handlers:

- `Players.PlayerAdded`
- `Players.PlayerRemoving`
- `game:BindToClose`
- `RunService.Heartbeat`
- `StartMatchRequestEvent.OnServerEvent`
- `ReturnToMenuRequestEvent.OnServerEvent`
- `RematchRequestEvent.OnServerEvent`
- `ResetDummyRequestEvent.OnServerEvent`
- `TankInputEvent.OnServerEvent`
- `ShootRequestEvent.OnServerEvent`
- `DebugSpawnBotRequestEvent.OnServerEvent`
- `DebugRemoveBotRequestEvent.OnServerEvent`

Important local bridge functions:

- `registerTankParticipant(config)`
- `getOrCreatePlayerParticipantForPlayer(player)`
- `damageParticipant(participant, amount, sourceProjectile)`
- `sendCombatFeedbackPayload(feedbackType, pos, text, color, audioOnly)`
- `collectMapTargets()`

### Events / Remotes / Attributes It Uses

Remotes:

- `TankInputEvent`
- `ShootRequestEvent`
- `ResetDummyRequestEvent`
- `CombatFeedbackEvent`
- `StartMatchRequestEvent`
- `ReturnToMenuRequestEvent`
- `RematchRequestEvent`
- `DebugSpawnBotRequestEvent`
- `DebugRemoveBotRequestEvent`

Attributes read/written indirectly through services include:

- `GameState`
- `RoundState`
- `RoundResult`
- `RoundNumber`
- `PlayerMode`
- `MatchId`
- tank model health/control attributes
- arena attributes
- wallet/stat attributes through economy/stat services

### Manual Play Mode Checks

- Start one-player Training and confirm the player tank spawns and can move/shoot.
- Confirm the Training bot updates after player movement and before projectile simulation.
- Kill the dummy and confirm death VFX, round result, Bolts reward, and result flow.
- Start two-player local server and confirm each player controls only their own tank.
- Confirm Return to Lobby and Rematch remotes still work.
- Confirm no client can damage or grant currency directly by sending UI-only actions.

## TankMovementService

### Responsibility

`TankMovementService` resolves server-authoritative tank movement against movement obstacles and world bounds.

It is the shared movement collision authority for player tanks and the Training bot. It decides whether a proposed pose or movement is blocked and returns a safe position/body yaw.

### What It Owns

- Movement obstacle discovery from `Workspace.WOB_Generated`.
- Obstacle classification by:
  - `WOBMovementObstacle`
  - obstacle folder membership such as `Boundaries`, `Cover`, `RicochetWalls`
  - known wall/cover names.
- Blockcast and overlap checks for tank bodies.
- World bounds clamping from `TankConfig.Movement`.
- Debug logging for blocked movement when enabled.

### What It Must Not Own

- Player input.
- Bot decision-making.
- Tank layout/part placement.
- Match or arena mode rules.
- Damage/projectile collision.
- Client smoothing.
- Scene repair or command scripts.

### Public Functions / Entry Points

- `init(params)`
- `isTankMovementObstacle(instance)`
- `getTankMovementObstacleParts()`
- `collectMovementObstacleRoots()`
- `getTankMovementCastSize()`
- `getTankMovementCastCFrame(position, bodyYaw)`
- `findTankBlockcastObstacle(fromPosition, bodyYaw, movement)`
- `findTankOverlapObstacle(position, bodyYaw)`
- `isTankPoseValid(position, bodyYaw)`
- `isTankMovementBlocked(fromPosition, bodyYaw, movement, debugContext)`
- `clampTankPosition(position)`
- `resolveTankMovement(fromPosition, bodyYaw, desiredMove)`
- `resolveTankPose(fromPosition, currentBodyYaw, desiredMove, desiredBodyYaw, debugContext)`

### Events / Remotes / Attributes It Uses

No remotes.

Scene attributes/properties:

- `WOBMovementObstacle`
- `CanQuery`
- obstacle folder names under `Workspace.WOB_Generated`

Config:

- `TankConfig.Movement.CollisionBoxSize`
- `TankConfig.Movement.CollisionBoxYOffset`
- `TankConfig.Movement.CollisionSkinWidth`
- `TankConfig.Movement.WorldBoundsMinX`
- `TankConfig.Movement.WorldBoundsMaxX`
- `TankConfig.Movement.WorldBoundsMinZ`
- `TankConfig.Movement.WorldBoundsMaxZ`
- `TankConfig.Movement.DebugCollision`
- `BattleArenaConfig.DebugCollision` through orchestrator init

### Manual Play Mode Checks

- Drive into walls/cover: tank should stop instead of passing through.
- Drive away from an obstacle after touching it: tank should be allowed to escape.
- Drive across lobby, duel arena, Training, and BattleArena floors: floors should not block movement.
- Confirm bot cannot leave configured Training bounds.
- With debug collision enabled, verify blocked logs identify the obstacle path.

## TankSpawnResetService

### Responsibility

`TankSpawnResetService` owns spawn transform lookup and physical tank layout. It places `Body`, `Turret`, `Barrel`, `ShootPoint`, and `Hitboxes` from participant control state or spawn state.

### What It Owns

- Spawn part lookup from the map.
- Spawn transform construction.
- Required tank physical layout.
- Armor hitbox sizing/material/visibility setup.
- Tank color capture/restore/darken on death.
- Applying spawns to participants.
- Configuring which participants are active/visible for Training/PvP.

### What It Must Not Own

- Player input.
- Bot AI.
- Match decisions.
- Damage formulas.
- Projectile spawning.
- Skin/economy/loadout rules.
- Movement collision decisions.

### Public Functions / Entry Points

- `init(gameMap)`
- `getSpawnTransform(spawnName, fallbackPosition, fallbackTargetPosition)`
- `getAllSpawnTransforms()`
- `layoutTank(tank, position, bodyYaw, turretYaw)`
- `captureTankColors(participantId, model)`
- `restoreTankColors(participantId)`
- `restoreAllTankColors()`
- `darkenTank(model)`
- `applySpawnToParticipant(participant, spawnState)`
- `configureActiveParticipants(matchMode, player2HasOwner, activeParticipants)`

### Events / Remotes / Attributes It Uses

No remotes.

Scene parts/folders:

- map spawn parts such as player/dummy/player2/lobby spawns.
- tank model children:
  - `Body`
  - `Turret`
  - `Barrel`
  - `ShootPoint`
  - `Hitboxes`
  - armor hitboxes.

Participant fields/attributes are updated through `TankParticipantRegistry` and physical model layout.

### Manual Play Mode Checks

- Training start places player and dummy at expected spawn points.
- PvP start places two player participants on separate sides.
- Round reset restores tank colors and health.
- Tank death darkens the destroyed tank.
- `ShootPoint` stays aligned with the barrel after turret rotation.
- Armor hitboxes remain positioned around the body and still register hits.

## PlayerPossessionService

### Responsibility

`PlayerPossessionService` binds Roblox `Player` objects to server `TankParticipant` objects and stores the latest input intent received from clients.

### What It Owns

- Suppressing default Roblox character gameplay.
- Assigning players to dynamic or existing player participants via callback.
- `player -> participant` map.
- Latest input table by player.
- Initial participant input state on assignment.
- Cleanup on player remove.

### What It Must Not Own

- Movement resolution.
- Shooting validation.
- Match/lobby/arena rules.
- Damage/death.
- Bot control.
- Client UI.

### Public Functions / Entry Points

- `init(options)`
- `suppressCharacter(player, character)`
- `setInitialInputForParticipant(player, participant)`
- `assignPlayer(player)`
- `removePlayer(player)`
- `getInputByPlayer()`
- `getControllingPlayer()`
- `getPlayerParticipantByPlayer(player)`

### Events / Remotes / Attributes It Uses

Callbacks from `WOBGameplayServer`:

- `getOrCreateParticipantForPlayer(player)`
- `onParticipantAssigned(player, participant)`

Player lifecycle:

- character suppression through `CharacterAdded`.

Participant/model attributes are published by `TankParticipantRegistry`, not owned here.

### Manual Play Mode Checks

- On player join, default character does not become the gameplay avatar.
- Player gets a player tank participant.
- Rejoining or multiple local clients do not steal another player’s participant.
- Player input moves only the assigned tank.
- On leaving, the participant/input mapping is cleaned up.

## ProjectileService

### Responsibility

`ProjectileService` owns projectile lifecycle: shoot validation, muzzle obstruction check, projectile object creation, projectile movement raycasts, wall ricochet handling, projectile visuals, and delegation to `ProjectileCombatService` for tank hits.

### What It Owns

- Server-authoritative projectile creation.
- Projectile runtime state.
- Projectile part/trail visual.
- Muzzle flash/smoke VFX.
- Wall impact and ricochet VFX.
- Death/burning VFX helper functions.
- Projectile cooldown enforcement.
- Arena weapon modifiers:
  - damage multiplier
  - fire rate multiplier
  - projectile count
  - spread degrees
- Muzzle obstruction safety check through `WeaponSafetyConfig`.
- `Shot` and wall `Ricochet` feedback facts through callback.

### What It Must Not Own

- Armor penetration formulas.
- Tank damage/death application.
- Match results.
- Currency rewards.
- Audio playback or `SoundId` ownership.
- Client UI text decisions.
- Player input collection.
- Bot aiming decisions.

### Public Functions / Entry Points

- `init(orchestratorRoot, projFolder, effectsFolder, options)`
- `setMapRaycastTargets(targets)`
- `destroyProjectile(projectile)`
- `destroyAllProjectiles()`
- `createProjectile(ownerParticipant, origin, direction, options)`
- `tryShoot(participant, direction)`
- `updateProjectiles(deltaTime)`
- `getVFXHelpers()`

Callbacks accepted in `init`:

- `getGameState`
- `getRoundState`
- `getRoundStateForProjectile`
- `damageParticipant`
- `getPlayerParticipant`
- `canParticipantShoot`
- `isNoDamageProjectile`
- `shouldRecordShot`
- `areProjectilesEnabled`
- `sendBlockedShotFeedback`
- `sendCombatFeedback`

### Events / Remotes / Attributes It Uses

No direct remotes. It emits feedback through callbacks.

Feedback facts:

- `Shot`
- `Ricochet`
- `BlockedShot` through blocked-shot callback.

Projectile attributes:

- `OwnerTankId`
- `OwnerTeamId`
- `OwnerIsBot`
- `OwnerUserId`
- `WeaponTypeId`

Config:

- `ProjectileCatalog`
- `WeaponConfig`
- `WeaponSafetyConfig`
- `VfxConfig`

### Manual Play Mode Checks

- Open shooting creates one projectile and muzzle VFX.
- Wall ricochet changes direction and emits `CombatFeedbackEvent` with `Type = "Ricochet"`.
- Projectile visuals still render after the audio migration.
- Muzzle obstruction blocks shots when `ShootPoint` is behind cover.
- Lobby shots are no-damage.
- Training/PvP/BattleArena shots use the same projectile path.
- DoubleShot/TripleSpread still preserve owner participant data.

## ProjectileCombatService

### Responsibility

`ProjectileCombatService` owns tank-hit combat resolution: armor zone lookup usage, armor penetration, no-penetration, armor ricochet, self-hit handling, damage feedback, and projectile ricochet math after armor results.

### What It Owns

- Armor hit resolution through `RicochetMath.ResolveArmorHit`.
- Applying projectile ricochet after wall/armor bounce.
- Recording projectile/tank hit stats.
- Deciding whether a tank hit penetrates, ricochets, or no-pens.
- Sending combat feedback facts for:
  - `Damage`
  - `ArmorRicochet`
  - `NoPenetration`

### What It Must Not Own

- Projectile creation and lifetime.
- Raw player input.
- Match/arena mode rules.
- Health storage.
- Death result flow.
- Bolts rewards.
- Sound playback or UI style.

### Public Functions / Entry Points

- `init(deps)`
- `handleProjectileTankHit(projectile, targetParticipant, hitPosition, hitNormal, armorZone, options)`
- `applyProjectileRicochet(projectile, hitPosition, hitNormal, options)`
- `printBounce(projectile)`

Dependencies accepted in `init`:

- `getParticipantIsDead`
- `createDamageHitVfx`
- `createNoPenVfx`
- `createSelfHitVfx`
- `createRicochetVfx`
- `destroyProjectile`
- `sendCombatFeedback`
- `damageParticipant`
- `canDamageParticipant`

### Events / Remotes / Attributes It Uses

No direct remotes. Uses `sendCombatFeedback` dependency.

Config:

- `TankConfig.Armor`
- `RicochetMath`

Feedback payloads:

- `Damage`
- `ArmorRicochet`
- `NoPenetration`

### Manual Play Mode Checks

- Front armor/no-pen cases show no-pen feedback and do not reduce HP.
- Rear/side penetration reduces HP and shows damage feedback.
- Armor ricochet bounces projectile and enables self-hit after bounce.
- Self-hit shows self-hit text/VFX and applies damage through normal server path.
- Projectile stats still update.
- No gameplay sound should originate here.

## RoundMatchService

### Responsibility

`RoundMatchService` owns Training/PvP match state, active match membership, round result, match series score, win/loss transitions, round reset timing, and published match/round attributes.

### What It Owns

- `GameState`: `Menu`, `Playing`, `Result`.
- `MatchMode`: `Training` or `PvP`.
- Active match object and participants.
- Round state/result.
- Match score and first-to target.
- Reset/result delays.
- Runtime/final stats hooks through `MatchStatsService`.
- Participant controllability during round end and match end.

### What It Must Not Own

- Lobby pad overlap/polling.
- Arena endless respawn mode.
- Projectile formulas.
- Damage calculation.
- Player input.
- UI rendering.
- Bot decisions.
- Economy reward validation.

### Public Functions / Entry Points

- `init(orchestratorRoot, options)`
- `getGameState()`
- `setGameState(nextGameState)`
- `getMatchMode()`
- `getActiveMatch()`
- `isParticipantInActiveMatch(participant)`
- `getOpponentForParticipant(participant)`
- `getRoundResultForDestroyedParticipant(participant)`
- `updateMatchMode()`
- `setRoundResult(result)`
- `setMatchAttributes()`
- `resetMatchState()`
- `endRound(result)`
- `getRoundState()`
- `resetRound()`
- `setActivePvPMatch(matchId, playerSideParticipant, opponentParticipant)`
- `setActiveTrainingMatch(matchId, playerSideParticipant, dummyParticipant)`
- `clearActiveMatch(matchId)`
- `startPvPMatch(matchId, playerSideParticipant, opponentParticipant)`
- `startTrainingMatch(matchId, playerSideParticipant, dummyParticipant)`
- `startNewMatch()`

Callbacks accepted in `init`:

- `onDestroyAllProjectiles`
- `onConfigureParticipants`
- `onRestoreColors`
- `onResetCombatAttributes`
- `onMatchEnded`
- optional `onGameStateChanged`

### Events / Remotes / Attributes It Uses

No direct remotes.

Root attributes:

- `GameState`
- `MatchMode`
- `ActiveMatchId`
- `PlayerSideTankId`
- `OpponentSideTankId`
- `PlayerWins`
- `DummyWins`
- `PlayerSideScore`
- `OpponentSideScore`
- `RoundNumber`
- `TargetWins`
- `RoundResult`
- `RoundEnded`
- `RoundState`
- `RoundWinner`
- `RoundWinnerTankId`
- `RoundLoserTankId`
- `RoundResetAt`
- `MatchResultAt`
- `NextRoundStartsIn`
- `ResultStartsIn`
- `MatchEnded`
- `MatchResult`
- `MatchWinnerTankId`
- `MatchLoserTankId`

### Manual Play Mode Checks

- Training match starts with `GameState = Playing` and `MatchMode = Training`.
- Two-player duel starts with `MatchMode = PvP`.
- Destroying a tank ends only one round unless target wins reached.
- Round reset happens after configured delay.
- Match result appears after target wins.
- Participants cannot drive/shoot during round end.
- BattleArena death does not enter this service’s result flow.

## LobbyService

### Responsibility

`LobbyService` owns player modes around lobby/free drive, pad detection, DuelPad queue/countdown, TrainingPad entry, ArenaPad entry, return-to-lobby, rematch voting, and mode-based drive/shoot/damage gating.

### What It Owns

- Player mode flow:
  - `Lobby`
  - `QueuedForDuel`
  - `InMatch`
  - `Result`
  - `InBattleArena`
  - `ArenaRespawning`
- Pad polling/overlap detection for lobby pads.
- Duel queue and countdown.
- Training start from button/pad.
- BattleArena entry via `ArenaCombatService`.
- Return-to-lobby behavior.
- Rematch votes.
- No-damage lobby projectiles.
- Whether participants can drive/shoot based on current mode.

### What It Must Not Own

- Round scoring internals.
- Arena kill/respawn/upgrade rules.
- Projectile physics.
- Tank movement collision.
- UI rendering.
- DataStore.
- Audio/VFX playback.

### Public Functions / Entry Points

- `init(options)`
- `setPlayerMode(player, participant, mode, matchId, opponentTankId)`
- `spawnPlayerInLobby(player, participant)`
- `playerAssigned(player, participant)`
- `playerRemoving(player)`
- `handleStartMatchRequest(player)`
- `handleReturnToLobbyRequest(player)`
- `handleRematchRequest(player)`
- `onMatchEnded(activeMatch)`
- `canParticipantDrive(participant)`
- `canParticipantShoot(participant)`
- `isNoDamageProjectile(participant)`
- `shouldRecordShot(participant)`
- `canDamageParticipant(projectile, targetParticipant)`
- `areProjectilesEnabled()`
- `update(deltaTime)`

Dependencies accepted in `init`:

- `root`
- `tankSpawnResetService`
- `roundMatchService`
- `projectileService`
- `arenaCombatService`
- `dummyParticipant`

### Events / Remotes / Attributes It Uses

Called by server remote handlers for:

- start match
- return to lobby
- rematch

Player attributes:

- `PlayerMode`
- `MatchId`
- `TankId`
- `OpponentTankId`
- `RematchStatus`

Pad attributes:

- `WOBPadType`
- `RequiredPlayers`
- `WOBPadEnabled`
- `WOBPadTrigger`
- Duel queue/countdown/status attributes on lobby/pad roots.

### Manual Play Mode Checks

- Lobby free-drive works and shots deal no damage.
- DuelPad displays queue count, starts countdown at two players, and cancels when a player leaves the pad.
- TrainingPad starts Training for one player.
- ArenaPad sends one player into BattleArena.
- Return to Lobby works from arena and result states.
- Result/rematch flow works for Training and PvP.
- Player cannot shoot/drive when mode forbids it.

## ArenaCombatService

### Responsibility

`ArenaCombatService` owns Free Drive Battle Arena session state: entering/leaving arena, arena score, kills/deaths/streaks, temporary upgrades, death/respawn, and arena-only damage eligibility.

### What It Owns

- Per-player arena sessions.
- Arena spawn selection.
- Arena player attributes.
- Arena session score/kills/deaths/streak.
- Session-only upgrades:
  - damage multiplier
  - fire-rate multiplier
  - move-speed multiplier
  - projectile count/spread.
- Arena death state and respawn delay.
- Arena damage permission between arena participants.

### What It Must Not Own

- Duel/Training round results.
- Persistent progression.
- Permanent inventory or skin ownership.
- Projectile formulas.
- Player input.
- Lobby pad polling.
- UI rendering.

### Public Functions / Entry Points

- `init(options)`
- `IsEnabled()`
- `IsPlayerInArena(player)`
- `IsParticipantInArena(participant)`
- `GetSession(player)`
- `EnterArena(player)`
- `ResetArenaSession(player)`
- `LeaveArena(player)`
- `GetArenaScore(player)`
- `ApplyUpgrade(player, upgradeId)`
- `RespawnPlayer(player)`
- `OnParticipantKilled(killerParticipant, victimParticipant)`
- `CanDamageParticipant(projectile, targetParticipant)`
- `IsArenaProjectile(projectile)`
- `PlayerRemoving(player)`

Dependencies accepted in `init`:

- `root`
- `tankSpawnResetService`
- `setPlayerMode`
- `clearPlayerInput`
- `restoreTankColors`

### Events / Remotes / Attributes It Uses

No direct remotes; called by `LobbyService` and death flow.

Player attributes:

- `PlayerMode`
- `ArenaScore`
- `ArenaKills`
- `ArenaDeaths`
- `ArenaStreak`
- `ArenaRespawnAt`
- `ArenaRespawnDelay`
- `ArenaStatus`
- `ArenaUpgradeIds`
- `ArenaDamageMultiplier`
- `ArenaFireRateMultiplier`
- `ArenaMoveSpeedMultiplier`
- `ArenaProjectileCount`
- `ArenaSessionId`

Participant/model arena attributes mirror active modifiers where needed.

Scene attributes:

- `Workspace.WOB_Generated.BattleArena`
- `ArenaCenter`
- `ArenaHalfSize`
- `SpawnPoints`

### Manual Play Mode Checks

- ArenaPad enters arena and sets `PlayerMode = InBattleArena`.
- Player spawns at an arena spawn point.
- Arena kill increments killer score/kills and victim deaths.
- Self-kill does not award killer score.
- Victim enters `ArenaRespawning`, controls are disabled, and respawns after delay.
- Return to Lobby clears arena session and upgrades.
- Duel/Training flows still use `RoundMatchService`, not arena result logic.

## CombatVfxService

### Responsibility

`CombatVfxService` clones and plays configured VFX templates from `ReplicatedStorage.Shared.Assets.VFX` into the runtime VFX folder. It provides template pivoting, particle emission, and safe fallback behavior for missing templates.

### What It Owns

- Runtime VFX folder reference.
- VFX template folder lookup.
- Template clone preparation.
- Particle emitter emission.
- VFX pivoting to world position/direction.
- Throttled warnings for missing/failed VFX templates.
- Legacy sound helpers kept only for compatibility.

### What It Must Not Own

- Combat audio ownership.
- `SoundId` catalog decisions.
- Damage/projectile logic.
- Client UI.
- Economy.
- Scene repair.

### Public Functions / Entry Points

- `init(effectsFolder)`
- `getVfxTemplatesFolder()`
- `findVfxTemplate(templateName, effectName, warnIfMissing)`
- `pivotVfxClone(clone, cframe, effectName)`
- `emitAllParticles(rootInstance, emitCount)`
- `playAllSounds(rootInstance, soundVolumeOverride)` legacy helper
- `playConfiguredSound(position, config, effectName)` legacy helper
- `playVfxTemplate(position, direction, config, effectName)`

### Events / Remotes / Attributes It Uses

No remotes.

Folders:

- `ReplicatedStorage.Shared.Assets.VFX`
- runtime `Workspace.WOB_Generated.Runtime.VFX`

VFX config fields:

- `TemplateName`
- `TemplateFallbackName`
- `TemplateFallbackNames`
- `TemplateLifetime`
- `TemplateEmitCount`
- `WarnIfMissingTemplate`
- particle fallback config fields.

### Manual Play Mode Checks

- Muzzle flash/smoke plays on shot.
- Wall ricochet sparks play on wall bounce.
- Damage/no-pen/self-hit VFX play on armor events.
- Tank destroyed explosion/burning VFX play.
- Missing optional templates warn at most once and fall back safely.
- No combat sound should be newly routed through this service.

## Client Input, Camera, HUD, Presentation Scripts

### Responsibility

Client scripts own input intent, camera, local HUD, readability overlays, mobile controls, audio playback, visual smoothing, and client-only presentation.

They do not own gameplay truth.

### What They Own

Input:

- `WOBTankInputController.client.luau`
- `WOBMobileControls.client.luau`
- `Input/WOBClientInputState.luau`

Camera/readability:

- `WOBTankPossessionCamera.client.luau`
- `WOBAimLaser.client.luau`
- `WOBProjectileReadabilityOverlay.client.luau`
- `WOBTankVisualSmoothing.client.luau`
- `WOBTankLocalTeamVisuals.client.luau`

HUD/UI:

- `WOBHudBootstrap.client.luau`
- `WOBRoundStatusOverlay.client.luau`
- `WOBPlayableShell.client.luau`
- `WOBBattleArenaOverlay.client.luau`
- `WOBWalletOverlay.client.luau`
- `WOBDuelPadVisual.client.luau`

Feedback/presentation:

- `WOBCombatFeedbackOverlay.client.luau`
- `WOBImpactFeedbackOverlay.client.luau`
- `WOBAudioController.client.luau`

### What They Must Not Own

- Health/damage authority.
- Projectile creation authority.
- Ricochet or armor formulas.
- Match/arena result authority.
- Bolts grants or wallet mutation.
- Server-side movement collision.
- Bot decisions.
- Arbitrary `SoundId` injection from remotes.

### Public Functions / Entry Points

These are LocalScripts/ModuleScripts, so entry points are Roblox events and module state:

- `UserInputService.InputBegan`
- `UserInputService.InputEnded`
- touch input handlers
- `RunService.RenderStepped`
- `RunService.Heartbeat` for purely local visual updates
- `CombatFeedbackEvent.OnClientEvent`
- local player/root/model `GetAttributeChangedSignal`
- RemoteEvent `:FireServer()` calls for input/requests
- `WOBClientInputState` shared input state used by mobile/desktop input.

### Events / Remotes / Attributes They Use

Client -> server remotes:

- `TankInputEvent`
- `ShootRequestEvent`
- `StartMatchRequestEvent`
- `ReturnToMenuRequestEvent`
- `RematchRequestEvent`
- `ResetDummyRequestEvent`

Server -> client remotes:

- `CombatFeedbackEvent`

Important attributes read:

- `PlayerMode`
- `GameState`
- `RoundState`
- `RoundEnded`
- `RoundResult`
- `MatchMode`
- `MatchResult`
- `RoundWinnerTankId`
- `RoundLoserTankId`
- `MatchWinnerTankId`
- `MatchLoserTankId`
- `PlayerSideScore`
- `OpponentSideScore`
- `TankId`
- `OwnerUserId`
- `IsBot`
- `IsPlayerTank`
- `IsActive`
- `IsDead`
- `IsControllable`
- `CanMove`
- `CanShoot`
- `Health`
- `CurrentHealth`
- `MaxHealth`
- `ArenaScore`
- `ArenaKills`
- `ArenaDeaths`
- `ArenaStreak`
- `ArenaUpgradeIds`
- `ArenaRespawnAt`
- `PersistentBolts`
- `SessionBoltsEarned`
- `UnsavedBolts`
- `LastBoltsRewardAmount`
- `LastBoltsRewardReason`
- `LastBoltsRewardSequence`

### Manual Play Mode Checks

- Desktop: WASD/body steering, mouse aim, and fire still work.
- Mobile: left MOVE stick, right AIM stick, and FIRE button work simultaneously.
- Local player tank remains responsive while remote tanks/bots are visually smoother.
- Camera follows only the owned active tank.
- HUD shows HP/reload/round state in Training/PvP.
- BattleArena HUD shows HP, score, kills, deaths, streak, upgrades, and respawn countdown.
- Combat feedback text ignores `AudioOnly` events.
- Audio plays from `AudioCatalog` categories and not from arbitrary remote `SoundId`.
- Wallet overlay shows `+1 Bolt` from server-set attributes only.
- Result/rematch/return UI does not mutate gameplay directly beyond request remotes.

