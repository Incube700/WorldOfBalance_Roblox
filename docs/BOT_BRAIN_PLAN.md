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

- it thinks on `BotConfig.ThinkInterval`;
- it switches strafe direction every 1.0-2.2 seconds;
- it has `AimErrorDegrees`;
- it checks fire at `FireCheckInterval`;
- it uses `FireChance` and random reaction delays instead of firing every frame.

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
