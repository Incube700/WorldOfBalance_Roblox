# Armor And Ricochet Combat

This document is the design contract for tank armor hits. It describes gameplay intent and the current v0.1 resolver behavior.

## Core Mechanic

Ricochet is not only wall bounce. Tank armor angle matters.

The player can angle the hull like a diamond to increase ricochet chance. Direct front hits can still penetrate, but front armor reduces damage. Sharp angle hits ricochet. Corners strongly favor ricochet. Hull angle is skill expression.

## Tank Convention

Current Roblox tank models use local `-Z` as the front.

Evidence in the current prototype:

- `Barrel` is placed toward negative local Z.
- `ShootPoint` is placed toward negative local Z.
- `FrontArmor` is placed toward negative local Z.

Armor code must not use turret or barrel rotation as the hull facing source. The stable hull source is `Body`, then `Hull`, then `PrimaryPart`.

## Angle Definition

`impactAngleFromNormal`:

- `0` degrees means the projectile hits armor straight/perpendicular.
- `90` degrees means the projectile skims almost parallel to the armor surface.
- High angle means a glancing hit and a higher ricochet chance.

## V0.1 Rules

Configured in `src/ReplicatedStorage/Shared/Configs/TankArmorConfig.luau`.

- `RicochetAngleDegrees` defaults to `60`.
- `GlancingAngleDegrees` is `45`.
- `EffectiveArmorMinCos` is `0.25`.
- `NoPenDamage` is `0`.
- `MinPenetrationDamage` is `1`.
- `DefaultPenetrationPower` is `70`.

Effective armor:

```text
EffectiveArmor = BaseArmor / max(cos(impactAngle), EffectiveArmorMinCos)
```

Resolution:

```text
if impactAngle >= RicochetAngleDegrees:
    result = Ricochet
elseif PenetrationPower < EffectiveArmor:
    result = NoPen
else:
    result = Penetration
```

Direct low-penetration front hits return `NoPen`, not ricochet. Only glancing hits at or above the zone ricochet threshold bounce.

## Armor Zones

Initial zones:

- `Front`: high armor, reduced damage on penetration.
- `Side`: medium armor, near-normal damage.
- `Rear`: low armor, increased damage on penetration.
- `Corner`: high armor, lower damage, lower ricochet threshold.

Corner detection uses the hit position in stable hull local space and upgrades the zone when the hit is near both width and length edges.

## Projectile Outcomes

`Penetration`:

- applies final damage;
- updates normal damage stats;
- triggers damage VFX and damage flash through `LastDamageSerial`;
- consumes the shell.

`NoPen`:

- applies no damage by default;
- does not update `LastDamageSerial`;
- triggers no-penetration feedback;
- consumes the shell.

`Ricochet`:

- applies no damage;
- does not update `LastDamageSerial`;
- reflects the shell using the resolver's ricochet direction;
- consumes one ricochet count.

Wall ricochet remains separate from tank armor policy.

## Future Tuning

Do not tune permanent power into normalized Duel by default. Future tuning should focus on readability, longer maneuver fights, and clear feedback for `Penetration`, `NoPen`, and `Ricochet`.
