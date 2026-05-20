# BattleArena Bots

BattleArena bots are filler participants for solo arena play. They are not part of Duel, Lobby free drive, or Training quick flow.

## Integration Contract

- Spawn path: `TankFactory:SpawnTank`.
- Role: `TankRole.ArenaBot`.
- Stats profile: `TankStatsProfile.BotDefault`.
- Team: `Bots`.
- Session owner: `ArenaCombatService.RegisterBotParticipant`.
- Movement: `TankMovementService.resolveTankPose`.
- Layout: `TankSpawnResetService.layoutTank`.
- Shooting: `ProjectileService.tryShoot`.
- Damage: existing `ProjectileCombatService` plus `ArmorHitResolver`.

Because bots use the same tank participant and projectile paths as players, world HP/reload bars, damage flash, no-pen, ricochet, death VFX, and reload presentation attributes should continue to work without bot-specific client code.

## Count Rules

`BotService` reads `BotConfig.BattleArena`:

- if bots are disabled, no bots spawn;
- if no players are in BattleArena, active bots are deactivated;
- if player count is below `SpawnWhenPlayerCountLessThan`, the service ensures `MinBots`;
- bot count is capped by `MaxBots` and `Safety.MaxBotsHardLimit`.

## Why Duel Stays Bot-Free

Duel is the normalized competitive 1v1 mode. Bot v0.1 is intentionally scoped to BattleArena so it does not alter Duel queueing, Duel scoring, Duel normalized stats, or top-down Duel readability.

## Future Improvements

- Bot difficulty presets.
- Basic obstacle avoidance.
- Line-of-sight scoring.
- Predictive aim with deliberate inaccuracy.
- Bot loadouts through `TankFactory` loadout requests.
- Arena waves.
- Arena bot score UI if bot-vs-player scoring becomes visible.
