# Armor Debug Checklist

Armor debug is off by default.

Config:

```text
src/ReplicatedStorage/Shared/Configs/DebugCombatConfig.luau
ArmorDebug = false
ArmorDebugVisuals = false
ProjectileDebug = false
ProjectileRaycastDebug = false

src/ReplicatedStorage/Shared/Configs/TankArmorConfig.luau
Visuals.ArmorZonesVisible = true
```

When temporarily enabled in Studio, expected logs look like:

```text
[ARMOR] zone=Front angle=12.0 effective=81.8 pen=70.0 result=NoPen damage=0
[ARMOR] zone=Front angle=63.0 effective=176.2 pen=70.0 result=Ricochet damage=0
[ARMOR] zone=Side angle=20.0 effective=58.5 pen=70.0 result=Penetration damage=99
```

## Manual Tests

1. Direct front low-penetration hit gives `NoPen`, shell stops, no damage flash.
2. Angled hull hit above threshold gives `Ricochet`, shell continues, no damage flash.
3. Corner hit ricochets more easily than side/rear.
4. Direct side hit penetrates more often than front.
5. Rear hit penetrates most easily.
6. Damage flash appears only when final damage is greater than zero.
7. Self-hit after wall ricochet still works.
8. Wall ricochet behavior is unchanged.
9. No normal-mode output spam after `ArmorDebug=false`.
10. Armor zones are visible in normal play and welded to `Body`/`Hull`.
11. If armor zones are unexpectedly invisible, check `TankArmorConfig.Visuals.ArmorZonesVisible`.

## Projectile Tunneling Checklist

1. Shoot a stationary tank directly from medium range and verify the hit resolves.
2. Shoot at the tank while driving fast and verify the shell does not obviously pass through.
3. Confirm projectile simulation uses previous-position to next-position swept raycast.
4. Confirm active armor hitboxes have `CanQuery=true`.
5. Confirm active armor hitboxes have `CanCollide=false`, `CanTouch=false`, and `Massless=true`.
6. Confirm owner ignore is limited to spawn/initial travel and self-hit becomes possible after ricochet.
7. Confirm enemy tanks are included in projectile raycast targets.
8. Confirm `ArmorHitResolver` logs appear when `ArmorDebug=true`.
9. Confirm `NoPen` stops the shell.
10. Confirm `Ricochet` continues the shell.
11. Confirm `Penetration` applies damage and triggers damage flash.

## BaseTankTemplate-Specific Tunneling Checklist

If a tank spawned from `BaseTankTemplate` has projectile pass-through issues:

1. **Hitbox folder**: Run `AUDIT_TANK_TEMPLATE_RIG_COMMAND.lua`. Verify the tank shows `ArmorZones` folder, not `Hitboxes`.
2. **participant.Hitboxes**: After server start, `participant.Hitboxes` must point to the `ArmorZones` folder (verified by the audit or `[PROJECTILE COLLISION]` debug logs).
3. **Weld**: Each armor part in `ArmorZones` must have a `WOBArmorBodyWeld` WeldConstraint to Body.
4. **Transparency / active**: Inactive `Startup_*` tanks must NOT appear in projectile targets (`IsActive=false`).
5. **Debug**: Enable `DebugCombatConfig.ProjectileDebug = true`. Look for:
   - `[PROJECTILE COLLISION] targets=...` — should list active tank hitbox folders.
   - `[PROJECTILE HIT] part=FrontArmor tank=PlayerTank_... active=true` — confirms armor zone was hit.
   - If you see `skip=... active=false hitboxes=nil` — the participant is inactive or has no hitbox folder.

## Legacy vs BaseTankTemplate Folder Names

| Template            | Hitbox folder | participant.Hitboxes |
|---------------------|---------------|----------------------|
| `BaseTankTemplate`  | `ArmorZones`  | ArmorZones folder    |
| `PlayerTankPrototype` | `Hitboxes`  | Hitboxes folder      |
| `Player2TankPrototype` | `Hitboxes` | Hitboxes folder      |
| `DummyTank`         | `Hitboxes`    | Hitboxes folder      |

`PlayerTankSpawner.ensurePhysicalTankModel` skips creating a `Hitboxes` folder if `ArmorZones` already exists, preventing duplicate / mispositioned hitboxes.

## Safety

Do not edit `.rbxl` directly while testing armor. Do not mutate VFX/UI templates for armor tests. Keep Duel/BattleArena/Training entry flows intact.
