# Armor Debug Checklist

Armor debug is off by default.

Config:

```text
src/ReplicatedStorage/Shared/Configs/DebugCombatConfig.luau
ArmorDebug = false
ProjectileDebug = false
ProjectileRaycastDebug = false
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

## Projectile Tunneling Checklist

1. Shoot a stationary tank directly from medium range and verify the hit resolves.
2. Shoot at the tank while driving fast and verify the shell does not obviously pass through.
3. Confirm projectile simulation uses previous-position to next-position swept raycast.
4. Confirm active armor hitboxes have `CanQuery=true`.
5. Confirm owner ignore is limited to spawn/initial travel and self-hit becomes possible after ricochet.
6. Confirm enemy tanks are included in projectile raycast targets.
7. Confirm `ArmorHitResolver` logs appear when `ArmorDebug=true`.
8. Confirm `NoPen` stops the shell.
9. Confirm `Ricochet` continues the shell.
10. Confirm `Penetration` applies damage and triggers damage flash.

## Safety

Do not edit `.rbxl` directly while testing armor. Do not mutate VFX/UI templates for armor tests. Keep Duel/BattleArena/Training entry flows intact.
