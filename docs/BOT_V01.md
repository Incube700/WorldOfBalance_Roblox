# Bot v0.1

Bot v0.1 is a small BattleArena-only feature. It exists to make the arena feel alive when one player enters alone.

## Runtime Shape

- `BotService` owns arena bot lifecycle.
- `BotController` owns one bot tank.
- `BotBrain` makes simple movement/aim/fire decisions.
- `BotTargeting` finds valid BattleArena targets.
- `BotSpawnPlanner` chooses an existing arena spawn transform without mutating the scene.

Bots are normal tank participants:

- spawned through `TankFactory`;
- role `ArenaBot`;
- stats profile `BotDefault`;
- `IsBot = true`;
- `TeamId = "Bots"`;
- participant state `InBattleArena`.

## Config

`src/ReplicatedStorage/Shared/Configs/BotConfig.luau` controls the feature.

Disable all bots:

```lua
Enabled = false
```

Disable only BattleArena bots:

```lua
BattleArena = {
    Enabled = false,
}
```

Important fields:

- `BattleArena.MinBots`: minimum bots when the arena needs filler.
- `BattleArena.MaxBots`: normal cap.
- `BattleArena.SpawnWhenPlayerCountLessThan`: if player count is below this number, bots are ensured.
- `BattleArena.RespawnDelay`: bot respawn delay after death.
- `Safety.MaxBotsHardLimit`: hard cap against accidental bot floods.
- `Brain.TickRate`: decision refresh interval.
- `Brain.SearchRadius`: max target search distance.
- `Brain.PreferredDistance`: range the bot tries to hold.
- `Brain.AimToleranceDegrees`: turret alignment needed before shooting.
- `Brain.FireChance`: non-perfect firing randomness.

`Debug = false` by default. When enabled, bot logs are throttled.

## Behavior

When at least one player is in BattleArena and the player count is below the configured threshold, `BotService` ensures the configured minimum bot count. If no players remain, bots are deactivated and hidden.

The bot does not use pathfinding. It:

- finds the nearest alive player participant in BattleArena;
- turns hull toward or around the target;
- aims turret toward the target body;
- moves closer, jitters/strafe-ish near preferred range, and may reverse when too close;
- shoots through `ProjectileService.tryShoot`, so existing cooldown/projectile/armor/VFX logic applies.

## Known Limitations

- No obstacle avoidance beyond existing tank movement collision.
- No pathfinding.
- No difficulty levels.
- No special bot loadouts.
- Bot scoring is minimal: players can score kills on bots through existing BattleArena kill handling, but bot-side stats are not surfaced in UI.
- Deactivated bots are hidden/unregistered from arena sessions, not removed from `TankParticipantRegistry`, because the registry does not yet expose unregister semantics.

## Manual Test

1. Enter BattleArena with one player.
2. Confirm an `ArenaBot_*` tank appears.
3. Confirm the bot moves, aims, and shoots.
4. Confirm player shots damage/ricochet/no-pen against bot armor.
5. Confirm bot shots can damage the player.
6. Kill the bot and confirm it respawns after `BotConfig.BattleArena.RespawnDelay`.
7. Return to Lobby and confirm bots disappear.
8. Start Duel and confirm no BattleArena bots join Duel.
