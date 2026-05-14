# Round And Match Flow

Date: 2026-05-13.

## Contract

`RoundEnd` and `MatchEnd` are separate states.

`RoundEnd` means one active tank died, score changed, and the match is not finished yet. The server keeps `GameState = "Playing"` and keeps participants in `PlayerMode = "InMatch"`, but marks match participants non-controllable. The client shows only the small round overlay. No Result screen, Rematch, or Return to Lobby is available here.

`MatchEnd` means the score reached `MatchConfig.TargetWins`. The server still keeps `GameState = "Playing"` during the short aftermath window, marks participants non-controllable, shows final small summary attributes, and only after `MatchConfig.MatchResultDelay` changes `GameState` to `"Result"` and lets `LobbyService.onMatchEnded` move players to `PlayerMode = "Result"`.

## Stable Fun Duel v0.1

For v0.1, round flow is intentionally simple: one death ends the current round, a small overlay appears, controls are disabled, then the next round starts automatically once. The full Result screen, Rematch, and Return to Lobby belong only to `MatchEnd`.

## Config

Round timing lives in `src/ReplicatedStorage/Shared/Configs/MatchConfig.luau`:

- `RoundResetDelay = 2.0`: delay between non-final rounds.
- `MatchResultDelay = 2.0`: delay after final death before full Result.
- `ShowSmallRoundResultOverlay = true`: client shows the small round panel.
- `ShowSmallMatchResultBeforeFullResult = true`: client shows the small match summary before full Result.

## Server Attributes

`RoundMatchService` writes these attributes on `Workspace/WOB_Generated`:

- `RoundState`: `"Playing"`, `"RoundEnd"`, or `"MatchEnd"`.
- `RoundWinner`: `"PlayerSide"` or `"OpponentSide"`.
- `RoundWinnerTankId` / `RoundLoserTankId`.
- `PlayerSideScore` / `OpponentSideScore`.
- `RoundResetAt` and `NextRoundStartsIn` for regular round transitions.
- `MatchResultAt` and `ResultStartsIn` for final result transitions.

`PlayerWins` and `DummyWins` remain for existing HUD/stats compatibility.

## Reset Guard

`RoundMatchService` uses reset/result tokens plus a short `isRoundResetting` reentry guard. A delayed `RoundEnd` reset must only run while `RoundState == "RoundEnd"`, `GameState == "Playing"`, and the match is not ended. Manual reset during the VFX delay is ignored until `RoundResetDelay` expires, and a reset body cannot run twice in the same transition.

## UI

`WOBRoundStatusOverlay.client.luau` owns the small overlay. It stays small and does not dim the screen:

- `ROUND WON` / `ROUND LOST`
- `Score X / Y - Next round in N`
- `MATCH WON` / `MATCH LOST`
- `Final X / Y - Result in N`

`WOBPlayableShell.client.luau` still owns the full Result screen. It appears only after the server changes `GameState` to `"Result"` and player mode becomes `"Result"`.

## Death VFX

Death explosion and burning tank VFX are created immediately on death by the server. Template VFX are cloned into `Workspace/WOB_Generated/Runtime/VFX` and cleaned by Debris using `VfxConfig` lifetimes, so they are independent from the gameplay tank being reset.

Current readability timings:

- `VfxConfig.DeathExplosion.TemplateLifetime = 4`
- `VfxConfig.BurningTank.TemplateLifetime = 6`
- `MatchConfig.RoundResetDelay = 2.0`
- `MatchConfig.MatchResultDelay = 2.0`

## Dead Tank Control

On death, `TankParticipantRegistry.setParticipantIsDead(participant, true)` sets:

- `IsAlive = false`
- `IsDead = true`
- `IsControllable = false`
- `CanMove = false`
- `CanShoot = false`

At `RoundEnd` and `MatchEnd`, all active match participants are also marked non-controllable. The server rejects movement through `LobbyService.canParticipantDrive` and rejects firing through both `LobbyService.canParticipantShoot` and `ProjectileService.tryShoot`.

On round reset, match start, lobby spawn, or rematch start, `resetParticipantHealth` restores alive/controllable flags for active participants.
