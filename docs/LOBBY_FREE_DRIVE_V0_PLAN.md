# Lobby / Free Drive v0 Plan

## 1. Current GameState flow

- Server state lives on `Workspace.WOB_Generated` via `RoundMatchService`.
- `GameState` currently has three values: `Menu`, `Playing`, `Result`.
- The server starts in `Menu`.
- `StartMatchRequestEvent` calls `RoundMatchService.startNewMatch()`.
- `startNewMatch()` resets projectiles, stats, health, spawns, then sets `GameState = "Playing"`.
- Final match result sets `GameState = "Result"` and destroys projectiles.
- `ReturnToMenuRequestEvent` can set `GameState = "Menu"`.
- Client systems such as shell UI, camera, input, aim laser, combat feedback, impact feedback, and round HUD currently treat root `GameState == "Playing"` as the authority for active gameplay.

## 2. Where the match starts today

- Main client entry is `WOBPlayableShell.client.luau`.
- `PlayButton` and `PlayAgainButton` fire `ReplicatedStorage.Remotes.StartMatchRequestEvent`.
- Server handler is in `WOBGameplayServer.server.luau`.
- The handler checks that the caller has a player participant, then calls `RoundMatchService.startNewMatch()`.
- There is no duel queue yet; any valid caller can start the current global match.

## 3. How PlayerPossessionService assigns tanks

- `PlayerPossessionService.assignPlayer(player)` loads persistent stats and asks `TankParticipantRegistry.getAvailablePlayerParticipant()`.
- The registry returns the first `IsPlayerTank` participant with no `OwnerPlayer`.
- Current registered player participants are fixed at startup:
  - `PlayerTankPrototype`
  - `Player2TankPrototype`
- The service assigns `OwnerPlayer`, `OwnerUserId`, `OwnerName`, mirrors those attributes onto the physical model, suppresses the Roblox character, initializes input state, and logs `[PVP] assigned PlayerName -> TankId`.
- Because only two player participants exist, a third player cannot receive a tank.

## 4. How RoundMatchService starts Training/PvP

- `RoundMatchService.updateMatchMode()` counts owned player participants.
- If two or more player participants are owned, mode is `PvP`; otherwise it is `Training`.
- Training uses `PlayerTankPrototype` vs `DummyTank`.
- PvP uses `PlayerTankPrototype` vs `Player2TankPrototype`.
- `RoundMatchService.startNewMatch()` and `resetRound()` apply spawns only to those fixed participants.
- Match end semantics are still legacy side-based: `PlayerWins` vs `DummyWins`, with `PlayerTankPrototype` treated as the player side and `Player2TankPrototype`/`DummyTank` as opponent side.

## 5. How Result / Rematch / BackToMenu work today

- Result screen is shown when root `GameState == "Result"`.
- `PlayAgainButton` fires `StartMatchRequestEvent` immediately.
- There is no two-player rematch vote; one player can restart the global match.
- `BackToMenuButton` fires `ReturnToMenuRequestEvent`.
- Server currently accepts return to menu only from `PlayerPossessionService.getControllingPlayer()`.
- This flow is global, so it cannot safely handle two duel participants while other players stay in lobby unless clients switch to local player state.

## 6. How Stats Panel chooses local player stats

- `StatsPanel` reads cumulative stats from local `Player` attributes:
  - `PersistentTotal*`
  - `SessionTotal*`
  - `UnsavedTotal*`
- Result screen reads runtime stats using `runtimeAttribute()`:
  - Prefer local `Player` `Stats*` attributes.
  - Fallback to root `Workspace.WOB_Generated.Stats*`.
- `MatchStatsService` stores runtime stats per participant and mirrors them to the owning `Player`.
- Root `Stats*` attributes remain a legacy compatibility mirror for `PlayerTankPrototype`.

## 7. Current hardcoded PlayerTankPrototype / Player2TankPrototype areas

- `WOBGameplayServer.server.luau`
  - Creates `Player2TankPrototype` from `PlayerTankPrototype`.
  - Registers only `PlayerTankPrototype`, `Player2TankPrototype`, and `DummyTank`.
  - Movement raycast excludes only those tank models.
  - Damage winner/loser logic compares fixed player participants.
  - Input, shooting, and heartbeat movement require global `GameState == "Playing"`.
- `RoundMatchService.luau`
  - PvP opponent is hardcoded to `Player2TankPrototype`.
  - Match winner/loser side is hardcoded around `PlayerTankPrototype`.
  - Spawn reset applies only Player/Player2/Dummy transforms.
- `TankSpawnResetService.luau`
  - `configureActiveParticipants()` toggles only `PlayerTankPrototype`, `Player2TankPrototype`, `DummyTank`.
- Client scripts
  - Most systems resolve local ownership by `OwnerUserId`, which is good for dynamic tanks.
  - Several systems still gate on root `GameState == "Playing"`.
  - `WOBRoundStatusOverlay` has Player2-specific local score/result inversion.
  - `WOBAimLaser` and local team visuals scan `TestObjects`; dynamic lobby tanks should remain under `TestObjects` for compatibility.

## 8. Changes needed for 3/4/5+ lobby players

- Add dynamic tank creation from `PlayerTankPrototype` as a template.
- Use per-player tank names such as `PlayerTank_<UserId>`.
- Register a new participant for each connecting player.
- Set physical model contract attributes:
  - `TankId`
  - `OwnerUserId`
  - `OwnerName`
  - `TeamId`
  - `ControllerType`
  - `IsPlayerTank`
- Add participant/player state:
  - `PlayerMode = "Lobby" | "QueuedForDuel" | "InMatch" | "Result"`
  - `MatchId`
  - `TankId`
  - participant mirror attributes `ParticipantState` and `MatchId`.
- Spawn players on `Workspace.WOB_Generated.Lobby.SpawnPoints.LobbySpawn*`.
- Keep legacy `PlayerTankPrototype` and `Player2TankPrototype` present for compatibility, but stop using them as the lobby scaling limit.

## 9. How to keep Duel 1v1 without putting everyone into match state

- Root `GameState` can remain as a legacy/dev compatibility signal.
- Real lobby/match gating should use local `PlayerMode` and `MatchId`.
- `LobbyService` will own DuelPad queue and per-player mode transitions.
- When two lobby participants enter the DuelPad:
  - choose only those two participants;
  - create a `MatchId`;
  - set only those two players/participants to `InMatch`;
  - pass the two participants into `RoundMatchService`;
  - spawn only those two on arena `PlayerSpawn`/`Player2Spawn`;
  - leave other players as `Lobby`.
- Client UI must show Result only when local `PlayerMode == "Result"`.
- Camera/input should work for `Lobby`, `QueuedForDuel`, and `InMatch`.
- Combat damage and match stats should record only for active duel participants. Lobby shots can use visual projectiles but no damage/stats.

## 10. Files likely touched

- `src/ServerScriptService/Server/Gameplay/PlayerTankSpawner.luau`
- `src/ServerScriptService/Server/Gameplay/TankParticipantRegistry.luau`
- `src/ServerScriptService/Server/Gameplay/Players/PlayerPossessionService.luau`
- `src/ServerScriptService/Server/Gameplay/Round/RoundMatchService.luau`
- `src/ServerScriptService/Server/Gameplay/Tanks/TankSpawnResetService.luau`
- `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
- `src/ServerScriptService/Server/Gameplay/Combat/ProjectileCombatService.luau`
- `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`
- `src/ServerScriptService/Server/WOBPvPBootstrap.server.luau`
- new `src/ServerScriptService/Server/Gameplay/Lobby/LobbyService.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBPlayableShell.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankInputController.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankPossessionCamera.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBRoundStatusOverlay.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBCombatFeedbackOverlay.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBImpactFeedbackOverlay.client.luau`
- `src/ReplicatedStorage/Shared/Utils/TankModelResolver.luau`
- `docs/patches/CREATE_LOBBY_COMMAND.lua`

## Short implementation plan

1. Add dynamic player tank spawning/registration using `PlayerTank_<UserId>` cloned from `PlayerTankPrototype`.
2. Add lobby spawn helpers and `LobbyService` with per-player mode attributes, DuelPad queue, Return to Lobby, and vote-based PvP rematch.
3. Extend `RoundMatchService` with a v0 active-duel context so it can run a 1v1 between arbitrary participants while preserving Training/dev fallback.
4. Let movement, camera, input, aim laser, and minimal shell UI use local `PlayerMode` instead of only root `GameState`.
5. Allow lobby shooting through no-damage/no-stats projectiles and keep damage/stats restricted to `InMatch` participants with the same `MatchId`.
6. Add `CREATE_LOBBY_COMMAND.lua` to create `Workspace.WOB_Generated.Lobby` with eight lobby spawns and a visible DuelPad.
7. Verify `git diff --check` and `rojo build default.project.json --output /private/tmp/wob-lobby-free-drive-v0-check.rbxm`.
