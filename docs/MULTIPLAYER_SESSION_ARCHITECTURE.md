# Multiplayer Session Architecture

This is the participant/session direction for future Duel, BattleArena, bot, and Extraction work.

## Participant Model

Tanks should be treated as participants:

- player tank;
- bot tank;
- dummy tank;
- future enemy tank.

Bots are participants, not magic scene objects. Dummy tanks are participants used for practice/training.

## Duel

- Duel uses exactly two active participants.
- `Player1` and `Player2` are DuelSession concepts only.
- Do not hardcode Player1/Player2 assumptions into global tank systems.
- Duel should be normalized and skill-based.

## Lobby

- Lobby can contain many connected players.
- Players not in a Duel can remain in Lobby, BattleArena, or a future Extraction space.
- Lobby camera/controls may become third-person later, but not in the current pass.

## BattleArena

- BattleArena can support many player participants.
- BattleArena supports Bot v0.1 participants as arena filler when one player is alone.
- Bots are registered in `ArenaCombatService` sessions and spawned through `TankFactory` as `ArenaBot`.
- Progression and temporary run upgrades are allowed here because it is not pure competitive Duel.

## Future Extraction

- Extraction should be its own session/zone concept.
- A player leaves the lobby into a larger sandbox.
- The player collects, fights, and extracts to bank loot.
- Death before extraction loses unbanked run loot.

## Factory Direction

`TankFactory` is now the server spawn boundary for migrated tank creation:

- Role: `Player`, `DuelOpponent`, `Dummy`, `Bot`, `ArenaPlayer`, `ArenaBot`.
- Loadout: skin, weapon, future sidegrades.
- Stats profile: `DuelNormalized`, `ArenaDefault`, `TrainingPlayer`, `TrainingDummy`, `BotDefault`.
- `TankTemplateProvider` resolves legacy scene prototypes.
- `TankStatsProvider` supplies initial stats and keeps Duel normalized by default.

Legacy prototypes remain valid template sources until the project migrates to one shared base tank template. Gameplay services should request participants by role/profile, not clone or select prototype names directly.

## Bot v0.1

- BattleArena bots use `Role = ArenaBot`, `StatsProfileId = BotDefault`, and `TeamId = "Bots"`.
- Bot movement and shooting run server-side through existing tank movement and projectile services.
- Duel remains exactly two human/player participants by default; BattleArena bots never join Duel.
- Future bot AI should stay behind participant/session boundaries instead of becoming scene-specific scripts.
