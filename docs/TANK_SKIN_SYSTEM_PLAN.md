# Tank Skin System Plan

## Goal

Skin v0 is a safe cosmetic layer. It lets the server apply named visual presets without changing combat, movement, armor, projectile rules, match flow, inventory, economy, or DataStore behavior.

## What Exists Now

- `SkinCatalog.luau` defines skin IDs and visual colors/materials.
- `TankCustomizationService.luau` applies a skin to a tank model.
- `WOBGameplayServer.server.luau` applies the default skin after `PlayerTankSpawner.ensurePhysicalTankModel`.

No shop, Robux, inventory, ownership list, equip UI, or player data save exists in this version.

## Contract

Gameplay contract parts remain:

```text
Body
Turret
Barrel
ShootPoint
Hitboxes
  FrontArmor
  RearArmor
  LeftArmor
  RightArmor
```

Skins must not change:

- `Hitboxes`
- `ShootPoint`
- health or max health
- damage values
- projectile formulas
- armor zones
- match logic
- PvP rules
- `CanQuery`, `CanCollide`, `Anchored`, `Size`, or `CFrame`

Skins may change:

- visual colors;
- visual materials;
- decals later;
- cosmetic mesh IDs later;
- muzzle/trail/kill visual effects later.

## Visual Folder First

Future tank prefabs should use:

```text
TankModel
  Body
  Turret
  Barrel
  ShootPoint
  Hitboxes
  Visual
    HullVisual
    TurretVisual
    BarrelVisual
    TrackLeft
    TrackRight
    Decorations
```

When `Visual` exists, `TankCustomizationService` colors `BasePart` descendants in that folder. When `Visual` does not exist, v0 falls back to coloring only `Body`, `Turret`, and `Barrel`.

The fallback is temporary for prototype tanks. It avoids a scene refactor while keeping `ShootPoint` and `Hitboxes` untouched.

## Player Data Later

Future saved player data should store IDs, not whole models:

- `EquippedTankId`
- `EquippedSkinId`
- `EquippedTurretSkinId` later
- `EquippedBarrelSkinId` later
- projectile trail cosmetic ID later
- kill effect cosmetic ID later

DataStore should never save full Roblox tank models.

## Bolts Later

Soft currency v0 adds persistent `Bolts`, but spending is not implemented yet. Future skins may be bought with Bolts through a server-authoritative shop/inventory flow. For now, `SkinCatalog` is only a safe cosmetic catalog and no skin purchase/equip UI exists.

## Future Services

Safe future steps:

- `TankModelFactory`: clone physical tank templates from `ServerStorage/WOBAssets/TankTemplates`;
- `TankParticipantFactory`: register participants consistently for players and bots;
- `TankCustomizationService`: expand cosmetic slots without touching gameplay rules;
- `PlayerLoadoutService`: resolve saved IDs to server-approved catalog entries;
- `BotParticipantFactory`: create bot participants from the same tank template contract.

## Not In v0

Do not add yet:

- shop;
- DataStore inventory;
- Robux purchase flow;
- owned skins list;
- equip UI;
- gameplay stat skins;
- separate turret/barrel gameplay modules;
- marketplace asset search;
- mesh import pipeline;
- full bot arena mode.

## Manual Test

1. Play.
2. Confirm player tank, player2 tank, and dummy tank still exist.
3. Confirm default visual colors apply.
4. Confirm `Hitboxes` still exist and remain queryable.
5. Confirm `ShootPoint` still exists and projectiles spawn from it.
6. Confirm armor hit detection still works.
7. Confirm no gameplay behavior changes except visuals.
