# Muzzle Obstruction Rule

## Problem

Tanks use a long `Barrel` and a forward `ShootPoint`. When a player drives close to thin cover, the hull/turret can remain on one side of the wall while `ShootPoint` ends up on the other side. If the projectile spawns directly at `ShootPoint`, it appears to shoot through the wall.

## Rule

Before a shot is created, the server checks the line from a safe internal tank point to the muzzle:

- use `Turret.Position` when available;
- otherwise use `Body.Position + Vector3.new(0, 2, 0)`;
- otherwise use `participant.ControlState.Position + Vector3.new(0, 2, 0)`;
- raycast from that safe point to `ShootPoint.Position`;
- only map movement obstacles, cover, boundaries, and ricochet walls are considered blockers;
- the owner tank and other tanks are not considered for this muzzle safety check.

If an obstacle is between the safe point and the muzzle, `ProjectileService.tryShoot` returns `false` and no projectile is created.

## Server Authority

The check runs inside `ProjectileService.tryShoot`, so it applies to:

- local players;
- remote players;
- Training bot shots;
- future server-controlled participants using the same shooting API.

The client does not decide whether a muzzle is clear. The projectile origin is not corrected on the client because damage, ricochet, armor penetration, and hit ownership must stay server-authoritative.

## Feedback

`WeaponSafetyConfig.BlockedShotFeedbackEnabled` controls short owner-only feedback. The default text is:

```text
BARREL BLOCKED
```

`WeaponSafetyConfig.Debug` enables server logs such as:

```text
[MUZZLE BLOCKED] tank=... reason=raycast obstacle=...
```

## Config

`WeaponSafetyConfig.luau` contains:

- `MuzzleObstructionCheckEnabled`
- `MuzzleClearancePadding`
- `MuzzleCheckRadius`
- `BlockedShotFeedbackEnabled`
- `BlockedShotFeedbackText`
- `Debug`

## Manual Test

1. Drive close to a thin wall or cover piece so the barrel/ShootPoint crosses the wall.
2. Shoot.
3. No projectile should appear on the far side of the wall.
4. Owner should see `BARREL BLOCKED` if feedback is enabled.
5. Reverse away until the muzzle is clear.
6. Shoot again.
7. Normal projectiles and ricochets should still work.
8. In Training, the dummy bot should also fail to shoot when its muzzle is blocked.
9. PvP damage, armor, and ricochet formulas should be unchanged.
