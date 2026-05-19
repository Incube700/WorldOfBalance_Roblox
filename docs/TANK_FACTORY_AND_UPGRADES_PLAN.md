# Tank Factory And Upgrades Plan

Current prototypes are temporary and should not be deleted in this stabilization pass:

- `PlayerTankPrototype`
- `Player2TankPrototype`
- `DummyTank`

They exist because the current playtest loop depends on known scene objects and attributes.

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
- `Dummy`
- `Bot`
- `Enemy`

`TankLoadout` examples:

- `SkinId`
- `WeaponId`
- `UpgradeLevels`

## Upgrade Currencies

Bolts can cover basic upgrades:

- HP
- Damage
- Reload
- Speed

Crystals can cover rarer unlocks:

- skins;
- special weapons;
- VFX;
- premium cosmetics.

## Not In This Pass

Do not migrate prototypes, combat stats, upgrades, spawning, or cosmetics in the source-of-truth cleanup pass.
