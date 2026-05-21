# Tank Armor Plate Sync Debug

## What These Parts Are

The current `FrontArmor`, `RearArmor`, `LeftArmor`, and `RightArmor` parts are gameplay-visible armor zones.

They live under each tank model. Two valid folder names are supported:

```text
TankModel                         (BaseTankTemplate / new workflow)
`-- ArmorZones
    |-- FrontArmor
    |-- RearArmor
    |-- LeftArmor
    `-- RightArmor

TankModel                         (legacy PlayerTankPrototype / DummyTank)
`-- Hitboxes
    |-- FrontArmor
    |-- RearArmor
    |-- LeftArmor
    `-- RightArmor
```

`TankArmorPartsService` looks for `ArmorZones` first, then falls back to `Hitboxes`. Both folder names are fully supported at runtime.

Players should see these zones so front/side/rear armor strength is readable. `ArmorHitResolver` also uses the same parts through raycast/query behavior.

## Runtime Contract

`TankArmorPartsService` configures hitboxes after tank spawn/reset:

- welded to stable `Body`, `Hull`, or `PrimaryPart`;
- `Anchored = false`;
- `Massless = true`;
- `CanCollide = false`;
- `CanTouch = false`;
- `CanQuery = true`;
- `CastShadow = false`;
- visible by default through `TankArmorConfig.Visuals`.

`CanQuery=true` is required so projectile swept raycasts can hit the armor zones.

## Why They Looked Detached

Client visual smoothing moves the readable tank visuals (`Body`, `Turret`, `Barrel`, `ShootPoint`) for smoother motion. Before the sync fix, armor zones were moved separately from the body, so they could look like panels lagging behind the tank.

The safe fix is to keep them welded to the stable body/hull server-side while leaving them visible as gameplay readability zones.

## Visibility Config

Normal config:

```text
TankArmorConfig.Visuals.ArmorZonesVisible = true
TankArmorConfig.Visuals.FrontColor = cyan/green
TankArmorConfig.Visuals.SideColor = yellow/orange
TankArmorConfig.Visuals.RearColor = red
TankArmorConfig.Visuals.FrontTransparency = 0.35
TankArmorConfig.Visuals.SideTransparency = 0.45
TankArmorConfig.Visuals.RearTransparency = 0.45
```

If armor zones are invisible in normal play, check `TankArmorConfig.Visuals.ArmorZonesVisible` first. `DebugCombatConfig.ArmorDebugVisuals` is not the switch for core gameplay armor zone visibility.

## Manual Checks

1. Spawn in Lobby, Training, Duel, and BattleArena.
2. Confirm front/side/rear armor zones are visible in normal play.
3. Fire at the front hull and confirm `NoPen` or penetration still resolves.
4. Angle the hull and confirm ricochet still resolves.
5. Shoot side/rear and confirm penetration is still more likely.
6. Confirm bots have visible synced armor zones and can take armor hits.
7. Confirm no armor parts drift away from the tank body while driving or rotating the turret.
8. Confirm world HP/reload bars still follow the body/hull.
