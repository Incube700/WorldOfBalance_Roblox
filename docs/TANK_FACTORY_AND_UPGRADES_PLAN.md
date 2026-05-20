# Tank Factory And Upgrades Plan

Current prototypes are temporary and should not be deleted in this architecture pass:

- `PlayerTankPrototype`
- `Player2TankPrototype`
- `DummyTank`

They exist because the current playtest loop depends on known scene objects and attributes.

## Current Foundation

`src/ServerScriptService/Server/Gameplay/Tanks/TankFactory.luau` now exists as an adapter layer over the current prototype flow.

Current behavior:

- legacy prototypes remain the source models;
- `ExistingModel` can register an already-created tank;
- `TemplateModel` can be cloned into a provided parent;
- factory applies role, team, owner, loadout, stats profile, health, and weapon attributes;
- factory registers participants through `TankParticipantRegistry`;
- `WOBGameplayServer.server.luau` uses the factory wrapper for current participant creation.

This is not a full migration to one template yet.

## Staged Migration

Stage 0:

- `TankFactory` adapter exists.
- Legacy prototypes remain active:
  - `PlayerTankPrototype`
  - `Player2TankPrototype`
  - `DummyTank`

Stage 1:

- All new Bot/Dummy spawns go through `TankFactory`.
- Bots are participants, not special-case scene objects.

Stage 2:

- Player Duel spawns go through `TankFactory` requests.
- Duel stats use `DuelNormalized`.

Stage 3:

- Replace duplicated prototype sources with `BaseTankTemplate`.
- Keep old prototypes archived/backed up until no live flow references them.

Stage 4:

- Add loadout/stats/skin/upgrade application through factory dependencies.
- Duel ignores permanent stat upgrades by default.

Stage 5:

- Bot participants and session-based spawning use the same factory path as players.

Rule: do not delete legacy prototypes until all active spawn flows use `TankFactory`.

## Future Direction

Move toward a server-owned factory:

```text
ServerStorage.TankTemplates.BaseTankTemplate
TankFactory
TankRole
TankLoadout
TankStatsProvider
UpgradeConfig
```

## Future Data Model

`TankRole` examples:

- `Player`
- `DuelOpponent`
- `Dummy`
- `Bot`
- `Enemy`

`TankLoadout` examples:

- `SkinId`
- `WeaponId`
- `UpgradeLevels`

## Upgrade Currencies

Bolts can cover basic upgrades outside normalized Duel:

- HP
- Damage
- Reload
- Speed
- Projectile Speed

Crystals can cover rarer unlocks:

- skins;
- special weapons;
- VFX;
- sidegrades;
- premium cosmetics.

## Duel Normalization

Duel should stay skill-based and normalized by default. Permanent stat upgrades should not apply to Duel unless a separate non-ranked/fun mode explicitly allows it.

BattleArena and future Extraction can use progression because they are not pure competitive Duel.

## Not In This Pass

Do not delete prototypes, migrate the scene, create `ServerStorage.TankTemplates`, add a shop UI, add bots, or make permanent upgrades active in Duel in this pass.
