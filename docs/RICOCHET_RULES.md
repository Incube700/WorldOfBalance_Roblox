# World of Balance: Ricochet Tanks — Ricochet Rules

## Current MVP

- Projectile flies fast but visible.
- Projectile can bounce from arena walls.
- Maximum ricochets: 3.
- Damage decreases after ricochets.
- Projectile can damage dummy.
- Projectile can damage player only after first ricochet through `CanHitOwner`.
- Direct self-shot should not instantly hit owner.

## Core Rule: Armor, Penetration, and Angle

- Projectile penetration decides whether a shell can pass through effective armor.
- Max damage is only an upper cap, not guaranteed damage.
- Direct hit into weak armor can penetrate.
- Glancing hit increases effective armor and can ricochet.
- Ricochet can return and kill the shooter after the first bounce.
- Positioning and hull angle matter more than raw stats.

## Implementation Notes

- Ricochet math should live separately from projectile visuals.
- Current module: `src/ReplicatedStorage/Shared/Utils/RicochetMath.luau`.
- Projectile mechanics should use `ProjectileCatalog`.
- Projectile visuals should use `ProjectileVisualConfig`.
- Weapon firing should use `WeaponConfig`.
- Do not put projectile rules into generic `GameplayConfig`.

## Do Not Implement Yet

- Tank corner detection.
- Different projectile behavior types.

These are future milestones after current round loop is stable.

## Projectile

Projectile has two separate combat parameters:

### Penetration

Penetration answers: can this shell pass through effective armor?

### Max Damage

Max Damage is not guaranteed damage. It is the upper cap. Real damage depends on effective armor, penetration result, bounce count, and future critical zones.

## Tank Armor

Base zones:

- Front = strongest.
- Side = medium.
- Rear = weak.

Local orientation:

- `+Z` = Front.
- `-Z` = Rear.
- `+/-X` = Side.

## Angle And Effective Armor

Formula:

```lua
dot = Vector3.Dot(-incomingDirection.normalized, hitNormal.normalized)
angle = acos(clamp(dot, -1, 1))
effectiveArmor = armor / max(cos(angle), safeMinCos)
```

Design principle: more glancing hit = higher effective armor.

## Current Combat Values

- ProjectileMaxDamage = 110.
- ProjectilePenetration = 45.
- FrontArmor = 50.
- SideArmor = 40.
- RearArmor = 10.
- MaxRicochets = 3.
- BounceSpeedMultiplier = 0.78.
- DamageMultiplierPerBounce = 0.75.
- MinProjectileSpeed = 5.

Penetration:

```text
if penetration < effectiveArmor:
    result = NoPenetration
    damage = 0
else:
    result = Penetrated
    damage = currentDamage
```

Auto ricochet:

```text
if hitAngle >= AutoRicochetAngle:
    result = Ricochet
    damage = 0
```

After bounce:

```text
currentDamage = currentDamage * DamageMultiplierPerBounce
currentSpeed = Max(MinProjectileSpeed, currentSpeed * BounceSpeedMultiplier)
```

With `BounceSpeedMultiplier = 0.78`, visual speed loss may still be subtle. This is a tuning task, not a random fix.

## Examples

Direct front hit: `FrontArmor = 50`, `EffectiveArmor = 50`, `Penetration = 45`, so `45 < 50 -> NoPenetration / Ricochet`, `Damage = 0`.

Direct side hit: `SideArmor = 40`, `EffectiveArmor = 40`, `Penetration = 45`, so `45 >= 40 -> Penetrated`.

Angled side hit: `SideArmor = 40`, but `EffectiveArmor > 45` due to angle, so result is `NoPenetration / Ricochet`.

Rear hit: `RearArmor = 10`, `Penetration = 45`, so result is `Penetrated`.

## Ricochets

Projectile reflects from:

- walls;
- cover;
- tank armor when auto ricochet or no penetration happens.

Reflection in Roblox:

```lua
reflected = direction - 2 * direction:Dot(normal) * normal
```

After ricochet:

- direction stays on the XZ plane;
- speed decreases by config;
- current damage cap decreases by config;
- bounce count increases;
- after max ricochets, the next contact destroys projectile.

## Aim Helper

If an aim laser or helper is enabled, it is a visual-only readability layer:

- it starts from the muzzle/barrel;
- it must stop on the first wall, cover, or tank it would hit;
- it must not own damage, penetration, armor, or ricochet rules.

## Parity Backlog Notes

Unity design also includes first-to-3 match flow, round break timer, final result, local statistics, world-space HP bars, floating hit text, and visible `DAMAGE` / `NO PEN` / `RICOCHET` feedback. These are future Roblox milestones, not discarded features.
