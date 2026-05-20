# Config Ownership

This document records where gameplay, projectile, VFX, and audio values should live.

## HudConfig

File:

```text
src/ReplicatedStorage/Shared/Configs/HudConfig.luau
```

Owns HUD behavior flags:

- world HP/reload bar flags;
- legacy HP/reload hiding rules;
- reload text;
- damage flash presentation;
- combat HUD compact behavior.

HUD visibility decisions should be interpreted through `HudVisibilityRules` on the client.

## WeaponConfig

File:

```text
src/ReplicatedStorage/Shared/Configs/WeaponConfig.luau
```

Owns weapon-level values:

- weapon id;
- cooldown;
- projectile type id;
- muzzle/barrel offsets;
- future spread/burst/multishot values.

It should reference a projectile id. It should not duplicate armor zone tuning.

## ProjectileCatalog

File:

```text
src/ReplicatedStorage/Shared/Configs/ProjectileCatalog.luau
```

Owns projectile physical/combat stats:

- speed;
- lifetime;
- radius;
- base damage;
- penetration power;
- max ricochets;
- bounce speed multiplier;
- damage multiplier per bounce;
- minimum projectile speed;
- hit behavior type.

Canonical current values:

- `BaseDamage = 110`;
- `Damage = 110` compatibility/current alias;
- `MaxDamage = 110` legacy compatibility alias;
- `PenetrationPower = 70`;
- `Penetration = 45` legacy compatibility alias.

New code should read `PenetrationPower` first and `BaseDamage`/`Damage` before legacy aliases.

## TankArmorConfig

File:

```text
src/ReplicatedStorage/Shared/Configs/TankArmorConfig.luau
```

Owns armor policy tuning:

- armor zones;
- damage multipliers;
- ricochet angle thresholds;
- effective armor min cosine;
- default penetration fallback.

Do not duplicate armor numbers in weapon/projectile configs.

## ProjectileVisualConfig

File:

```text
src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau
```

Owns visual-only projectile readability:

- projectile shape/size/color;
- trail;
- glow;
- light;
- impact readability values.

It must not own damage, penetration, armor, or cooldown.

## VfxConfig

File:

```text
src/ReplicatedStorage/Shared/Configs/VfxConfig.luau
```

Owns VFX template/procedural visual settings:

- muzzle flash;
- smoke;
- impact sparks;
- no-pen feedback;
- ricochet feedback;
- death/explosion visuals.

It must not own combat damage/penetration.

## AudioCatalog

File:

```text
src/ReplicatedStorage/Shared/Configs/AudioCatalog.luau
```

Owns audio ids and playback settings:

- shot sound;
- ricochet sound;
- hit/no-pen sound;
- UI/reward sounds.

It must not own combat behavior.

## DebugCombatConfig

File:

```text
src/ReplicatedStorage/Shared/Configs/DebugCombatConfig.luau
```

Owns opt-in debug flags only:

- `ArmorDebug`;
- `ProjectileDebug`;
- `ProjectileRaycastDebug`.

All debug flags should be `false` by default.

## Known Compatibility Aliases

Some aliases remain intentionally:

- `ProjectileCatalog.DefaultRicochetShell.Damage` and `BaseDamage` both point at the current base damage.
- `MaxDamage` remains for older notes/callers.
- `Penetration` remains as a legacy field, but resolver-facing code should prefer `PenetrationPower`.

Do not remove aliases until all callers and docs have moved to canonical fields.
