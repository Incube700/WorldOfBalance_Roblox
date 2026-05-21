# Projectile And Weapon Architecture

This document defines the target boundaries for future weapon/projectile work. Do not add new weapons in the current architecture pass.

## Current State

Current cannon behavior still uses:

- `WeaponConfig.PrimaryWeapon.ProjectileTypeId = "DefaultRicochetShell"`;
- `ProjectileCatalog.Projectiles.DefaultRicochetShell`;
- `ProjectileService` for spawn, movement, lifetime, raycast, muzzle safety, and VFX callbacks;
- `ProjectileCollisionService` for swept raycast target collection and segment casting;
- `ProjectileHitResult` for stable result labels;
- `ProjectileCombatService` for interpreting tank/wall hit outcomes;
- `ArmorHitResolver` for tank armor penetration/no-pen/ricochet.

## Target Architecture

### WeaponCatalog / WeaponConfig

Owns weapon-level decisions:

- weapon id;
- cooldown;
- projectile id;
- future burst/multishot/spread;
- future muzzle sound/vfx profile;
- future allowed modes/unlock rules.

Weapon config should not own armor math or projectile damage resolution.

### ProjectileCatalog

Owns projectile physical/combat stats:

- projectile id;
- speed;
- lifetime;
- radius;
- base damage;
- penetration power;
- max ricochets;
- hit behavior type;
- visual profile id later.

Current canonical damage source is `BaseDamage` / `Damage` on `DefaultRicochetShell`. `MaxDamage` remains as a compatibility alias.

### ProjectileSpawnService

Future split. It should create projectile state from a weapon fire request:

- owner participant;
- origin;
- direction;
- weapon id;
- projectile id;
- spread/multishot output.

It should not resolve combat.

### ProjectileSimulationService

Future split. It should advance projectile state:

- previous position;
- next position;
- speed;
- lifetime;
- destroyed state.

It should not apply damage.

### ProjectileCollisionService

Current lightweight module:

- builds projectile raycast targets;
- keeps active armor hitboxes queryable;
- performs swept raycast from previous position to next position.

It does not apply damage, VFX, or match rules.

### ProjectileHitResult

Current lightweight constants module:

- `WallRicochet`;
- `TankPenetration`;
- `TankNoPen`;
- `TankRicochet`;
- `Expired`;
- `NoHit`.

It is an architectural boundary for future analytics/debug/UI hooks. It must not change combat behavior by itself.

### ProjectileCombatService

Owns hit interpretation:

- tank hit through `ArmorHitResolver`;
- wall ricochet;
- no-penetration;
- penetration damage;
- self-hit rules;
- combat feedback callbacks.

### ProjectileVfxDispatcher

Future split. It should own effect dispatch. It was not extracted in the current pass because projectile VFX callbacks are still tightly tied to `ProjectileService` helper functions.

- muzzle;
- wall impact;
- ricochet;
- no-penetration;
- damage hit;
- self-hit;
- death/explosion handoff.

### Client Projectile Readability

Client overlays/trails are visual only:

- no damage authority;
- no armor authority;
- no hit result authority.

Future Shell Research / Ricochet Research can extend this layer without changing projectile damage:

- clearer or longer aim laser;
- aim laser preview for 1 wall ricochet;
- aim laser preview for 2 wall ricochets;
- impact point marker after ricochet;
- armor interaction hint for likely `Penetration`, `NoPen`, or `Ricochet`.

BattleArena and future Extraction may use this as progression. Normalized Duel should either disable these helpers, equalize them for both players, or reserve them for a future casual/unranked mode.

## Tunneling Contract

Server projectile simulation must use swept collision:

```text
previousPosition = projectile.Position
nextPosition = previousPosition + projectile.Direction * projectile.Speed * deltaTime
raycast(previousPosition, nextPosition - previousPosition)
```

The projectile may render as a small ball, but hit detection must use the whole segment for fast shots.

## Extension Rules

- Add new weapons by adding weapon ids and projectile ids, not by branching core combat logic.
- Keep armor policy in `ArmorHitResolver`.
- Keep wall ricochet separate from tank armor ricochet.
- Do not make VFX/audio configs own damage or penetration numbers.
- Do not change Duel balance through permanent upgrades by default.
- Prefer readability progression over permanent Duel power progression.
