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
- BattleArena can later support bot participants.
- Progression and temporary run upgrades are allowed here because it is not pure competitive Duel.

## Future Extraction

- Extraction should be its own session/zone concept.
- A player leaves the lobby into a larger sandbox.
- The player collects, fights, and extracts to bank loot.
- Death before extraction loses unbanked run loot.

## Factory Direction

`TankFactory` is the adapter layer that should eventually own tank spawning:

- Role: `Player`, `DuelOpponent`, `Dummy`, `Bot`.
- Loadout: skin, weapon, future sidegrades.
- Stats profile: `DuelNormalized`, `ArenaDefault`, `TrainingDummy`.

Legacy prototypes remain valid sources until the project migrates to one shared base tank template.
