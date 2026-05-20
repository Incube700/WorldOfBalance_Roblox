# World Of Balance: Ricochet Rules

## Current MVP

- Projectile flies fast but remains readable.
- Projectile can bounce from arena walls.
- Maximum ricochets are defined by `ProjectileCatalog`.
- Damage decreases after ricochets.
- Projectile can damage dummy and player tanks.
- Projectile can damage its owner only after a ricochet through `CanHitOwner`.
- Direct self-shot should not instantly hit owner.

## Core Rule: Armor, Penetration, And Angle

Projectile penetration decides whether a shell can pass through effective armor.

Ricochet is not only wall bounce:

- Direct hit into weak armor can penetrate.
- Direct low-penetration front hit gives `NoPen`, not ricochet.
- Glancing hit increases effective armor and can ricochet.
- Corner hits have strong ricochet tendency.
- Positioning and hull angle matter more than raw stats.

The current armor policy lives in:

```text
src/ServerScriptService/Server/Gameplay/Combat/ArmorHitResolver.luau
src/ReplicatedStorage/Shared/Configs/TankArmorConfig.luau
```

Low-level reflection math remains in:

```text
src/ReplicatedStorage/Shared/Utils/RicochetMath.luau
```

## Tank Forward Convention

Current Roblox tank models use local `-Z` as front.

- `Barrel` points toward local `-Z`.
- `ShootPoint` is placed toward local `-Z`.
- `FrontArmor` is placed toward local `-Z`.
- Local `+Z` is rear.
- Local `+/-X` are sides.

Do not reintroduce older `+Z = Front` assumptions.

## Armor Resolver Contract

`ArmorHitResolver.ResolveHit(params)` returns:

```text
Result = Penetration | NoPen | Ricochet
Zone = Front | Side | Rear | Corner
ImpactAngleDegrees
EffectiveArmor
FinalDamage
NormalWorld
RicochetDirection optional
```

The resolver uses stable hull orientation:

1. `Body`
2. `Hull`
3. `PrimaryPart`

Turret and barrel rotation must not decide hull armor zone.

## Angle And Effective Armor

Angle definition:

- `0` degrees = perpendicular/direct hit.
- `90` degrees = glancing/parallel skim.

Formula:

```text
EffectiveArmor = BaseArmor / max(cos(angle), EffectiveArmorMinCos)
```

Design principle: a more glancing hit means higher effective armor and higher ricochet chance.

## Current Combat Values

Projectile:

- `Damage = 110`
- `MaxDamage = 110`
- `PenetrationPower = 70`
- legacy `Penetration = 45` remains for compatibility
- `MaxRicochets = 3`
- `BounceSpeedMultiplier = 0.78`
- `DamageMultiplierPerBounce = 0.75`
- `MinProjectileSpeed = 5`

Armor:

- Front armor = 80, damage multiplier = 0.65, ricochet angle = 60.
- Side armor = 55, damage multiplier = 0.9, ricochet angle = 62.
- Rear armor = 35, damage multiplier = 1.15, ricochet angle = 65.
- Corner armor = 90, damage multiplier = 0.5, ricochet angle = 45.
- `EffectiveArmorMinCos = 0.25`.

Resolution:

```text
if impactAngle >= RicochetAngleDegrees:
    result = Ricochet
    damage = 0
elseif PenetrationPower < EffectiveArmor:
    result = NoPen
    damage = 0
else:
    result = Penetration
    damage = Damage * ZoneDamageMultiplier
```

## Examples

Direct front hit:

```text
FrontArmor = 80
EffectiveArmor = 80
PenetrationPower = 70
70 < 80 -> NoPen
```

Direct side hit:

```text
SideArmor = 55
EffectiveArmor = 55
PenetrationPower = 70
70 >= 55 -> Penetration
```

Glancing front hit:

```text
impactAngle >= 60 -> Ricochet
```

Rear hit:

```text
RearArmor = 35
PenetrationPower = 70
70 >= 35 -> Penetration
```

## Ricochets

Projectile reflects from:

- walls;
- cover;
- tank armor only when the armor resolver returns `Ricochet`.

Reflection:

```lua
reflected = direction - 2 * direction:Dot(normal) * normal
```

After ricochet:

- direction stays on the XZ plane;
- speed decreases by config;
- current damage cap decreases by config;
- bounce count increases;
- after max ricochets, the next contact destroys projectile.

`NoPen` consumes the shell and does not bounce.

## Aim Helper

Aim laser/readability overlays are visual only:

- they start from the muzzle/barrel;
- they should stop on first wall, cover, or tank;
- they must not own damage, penetration, armor, or ricochet rules.

## Parity Backlog Notes

Unity design also includes first-to-3 match flow, round break timer, final result, local statistics, world-space HP bars, floating hit text, and visible `DAMAGE` / `NO PEN` / `RICOCHET` feedback. These are future Roblox milestones, not discarded features.
