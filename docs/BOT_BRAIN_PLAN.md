# Bot Brain Plan

## Goal

`TrainingBotService` gives Training mode a server-controlled opponent without changing PvP flow. The bot controls the existing `DummyTank` participant as a normal `TankParticipant`.

The design rule is:

```text
Player: Player input -> RemoteEvent -> participant.ControlState
Bot:    BotBrain -> participant.ControlState
```

After decisions reach `TankParticipant.ControlState`, movement, shooting, projectile lifecycle, damage, death, stats, and round result continue through the existing services.

## Why Server-Side

The bot is not a Roblox `Player` and does not use client RemoteEvents. Server-side decisions keep the Training opponent authoritative and avoid a fake-client control path. This also makes PvP safer: player-owned participants still use the existing input remotes, while the dummy bot only runs when the active match is Training.

## Integration

`WOBGameplayServer.server.luau` requires and initializes `TrainingBotService` with explicit dependencies:

- `roundMatchService`
- `tankParticipantRegistry`
- `tankSpawnResetService`
- `tankMovementService`
- `projectileService`
- `dummyParticipant`

The service does not require `WOBGameplayServer` and does not create cyclic dependencies. `update(deltaTime)` is called from the main heartbeat after lobby/player movement work and before `ProjectileService.updateProjectiles(deltaTime)`.

## Activation Rules

The bot does nothing unless all of these are true:

- `BotConfig.Enabled == true`
- an active match exists;
- `activeMatch.MatchMode == "Training"`;
- `dummyParticipant` is in `activeMatch.Participants`;
- `dummyParticipant.ParticipantState == "InMatch"`;
- the current round has not ended;
- dummy is alive and controllable;
- the opponent participant exists, is in the active match, and is alive.

PvP matches do not activate the dummy bot.

## Bot v0 Behavior

The current v0 bot:

- finds its target via `RoundMatchService.getOpponentForParticipant(dummyParticipant)`;
- moves toward the target when too far away;
- reverses when too close;
- strafes/orbits when near preferred distance;
- aims the turret toward the player with small configurable aim error;
- uses `TankMovementService.resolveTankMovement` for wall-blocked movement;
- applies final layout through `TankSpawnResetService.layoutTank`;
- checks simple line of sight against movement obstacles;
- fires through `ProjectileService.tryShoot`;
- respects projectile cooldown, damage, ricochet, armor, and round rules.

## Human Feel

The bot is intentionally imperfect:

- it updates decisions on `BotConfig.ThinkInterval`;
- it still acts every server heartbeat, so body/turret rotation and layout do not wait for the next think tick;
- it switches strafe direction every 1.0-2.2 seconds;
- it has `AimErrorDegrees`;
- it checks fire at `FireCheckInterval`;
- it uses `FireChance` and random reaction delays instead of firing every frame.

## Smoothing Step

The current safe smoothing step has two layers:

- server-side bot movement separates think from act, with `BodyTurnSpeedRadians` and `TurretTurnSpeedRadians`;
- client-side `WOBTankVisualSmoothing.client.luau` smooths non-owned tanks and bot tanks visually only.

This does not move damage, hit detection, projectiles, or match result to the client. The smoothing script is a visual MVP for replicated remote tanks. The cleaner future version is a dedicated `Visual` folder or client visual proxy for every tank prefab.

## Arena Bounds

Training bot movement is constrained by `BotConfig` arena bounds:

- `ArenaBoundsEnabled`
- `ArenaMinX`
- `ArenaMaxX`
- `ArenaMinZ`
- `ArenaMaxZ`
- `ReturnToCenterDistance`

The bot checks its desired next position before movement is applied. If it is near or past the configured edge, it steers back toward the arena center and keeps using `TankMovementService.resolveTankMovement` for wall/cover blocking. The final dummy `ControlState.Position` is clamped inside the configured bounds.

This only affects the Training dummy bot. Player controls, PvP movement, projectile damage, armor, and ricochet formulas are unchanged.

Future scene support can replace these config values with a dedicated `Workspace.WOB_Generated.Map.ArenaBounds` or similar editor-authored bounds object.

## Debug Bot Hook

`DebugSpawnBotRequestEvent` and `DebugRemoveBotRequestEvent` exist as guarded test hooks. In v0 they do not create a second bot:

- requests are ignored outside Studio/allowed users;
- PvP does not spawn dummy bots;
- active Training already owns `DummyTank` through `RoundMatchService`;
- dynamic bot spawning is deferred until a real bot participant/model factory exists.

## What Bot v0 Does Not Do

Bot v0 does not:

- predict ricochet shots;
- solve one-bounce geometry;
- dodge projectiles;
- use pathfinding;
- change difficulty by player skill;
- use inventory/loadouts;
- create projectiles manually;
- write damage directly;
- bypass `ProjectileService`, `ProjectileCombatService`, or `RoundMatchService`.
- create multiple arena/practice bots.

## Future

Future improvements can be layered without changing the core combat path:

- simple one-bounce ricochet shot search;
- difficulty levels;
- bot personalities;
- aim delay by difficulty;
- basic projectile dodge;
- `BotBrain` modules per behavior;
- bot-controlled PvE participants outside Training;
- `TankParticipantFactory` and `TankModelFactory` for spawned bot templates.
- `BotManager` and `BotParticipantFactory`;
- `ArenaPractice` mode with multiple bots, respawn rules, score timer, and explicit arena bot lifecycle.
