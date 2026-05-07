# World of Balance: Ricochet Tanks — Ricochet Rules

## Current MVP

- Projectile flies fast but visible.
- Projectile can bounce from arena walls.
- Maximum ricochets: 3.
- Damage decreases after ricochets.
- Projectile can damage dummy.
- Projectile can damage player only after first ricochet through `CanHitOwner`.
- Direct self-shot should not instantly hit owner.

## Core Future Rule: Angle-based Damage

- Direct hit into tank side/face: full damage.
- Borderline/glancing hit: reduced damage.
- Sharp angle: ricochet, no damage.
- Hit exactly into tank corner: always ricochet.
- Ricochet can return and kill the shooter.
- Positioning and hull angle matter more than raw stats.

## Implementation Notes

- Ricochet math should live separately from projectile visuals.
- Future module candidate: `src/ReplicatedStorage/Shared/Utils/RicochetMath.luau`.
- Projectile mechanics should use `ProjectileCatalog`.
- Projectile visuals should use `ProjectileVisualConfig`.
- Weapon firing should use `WeaponConfig`.
- Do not put projectile rules into generic `GameplayConfig`.

## Do Not Implement Yet

- Full angle damage.
- Tank corner detection.
- Armor zones.
- Different projectile behavior types.

These are future milestones after current round loop is stable.
