# Arena Screenshot Guide

Use this as the quick release screenshot setup for Ricochet Tanks.

## Recommended Thumbnail Angle

- Aspect ratio: 16:9.
- Camera style: three-quarter top-down.
- Field of view: 55-65.
- Height: about 85-110 studs above the arena floor.
- Offset: about 90-130 studs behind and slightly to one side of the tank.
- Aim point: the player tank, a nearby wall, and at least one projectile trail or explosion FX.

For BattleArena screenshots, a good starting target is the arena center around:

```text
Vector3.new(-340, 0, 320)
```

Place the camera above and slightly south-west of that point, then look back toward the center. Keep yellow projectiles visible against the darker floor.

## Visual Polish Notes

- Runtime visual-only decorations are created under `Workspace/WOB_Runtime/ArenaVisualPolish`.
- The visual polish script supports both `Workspace/WOB_Generated/Map` and `Workspace/WOB_Generated/BattleArena`.
- Decorative props and floor grid lines are non-colliding and non-queryable.
- Existing arena wall, cover, and floor shapes are not resized or moved.
- The release screenshot pass should not be used to change gameplay readability, collision, or arena rules.

## Source Of Truth Notes

- Do not manually edit generated arena polish objects in Studio. Runtime/source scripts recreate them.
- Do not manually drag runtime FX clones to fix offsets. `CombatFXService` normalizes cloned templates to the requested muzzle/hit/ricochet CFrame.
- Save reusable FX templates into the Rojo source folders instead of editing temporary `Workspace/WOB_TemporaryFX` clones.
