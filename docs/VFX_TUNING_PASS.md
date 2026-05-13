# VFX Tuning Pass

## Audit

Rojo source currently contains the VFX folder contract but no concrete template objects:

```text
src/ReplicatedStorage/Shared/Assets/VFX/.gitkeep
src/ReplicatedStorage/Shared/Assets/VFX/VfxTemplateCatalog.luau
```

That means Studio may already have templates in `ReplicatedStorage/Shared/Assets/VFX`, but the repo snapshot itself only guarantees the folder/catalog. Runtime must therefore treat every configured `TemplateName` as optional and fall back safely.

`VfxTemplateCatalog` discovers real children under `ReplicatedStorage/Shared/Assets/VFX` and ignores `.gitkeep`/catalog modules. Candidate template names used by config are:

- `MuzzleFlashTemplate`
- `MuzzleBlastTemplate`
- `SmokeTemplate`
- `ImpactSparksTemplate`
- `ImpactFlashTemplate`
- `RicochetTemplate`
- `TankExplosionTemplate`
- `TankBurningTemplate`

## Connected Events

`CombatVfxService` is the central template playback layer. It clones templates into `Workspace/WOB_Generated/Runtime/VFX`, sanitizes `BasePart` collision/touch/query, emits all `ParticleEmitter`s, plays template sounds, and cleans up through `Debris`.

Connected combat events:

- Shot fired: `Shot.SoundId`, `Shot.MuzzleFlash`, `Shot.MuzzleBlast`, `Shot.Smoke`.
- Wall impact: `Impact.WallImpact`.
- Damage hit: `Impact.DamageHit`.
- No penetration: `Impact.NoPen`.
- Self hit: `Impact.SelfHit`.
- Wall bounce and armor ricochet: `Ricochet`, with `Impact.WallImpact` fallback.
- Tank death: `DeathExplosion`, then optional `BurningTank`.

The old generic tank-hit impact was removed from `damageParticipant`; projectile combat now chooses the effect after armor resolution so damage, no-pen, ricochet, and self-hit read differently.

## Fallbacks

Because source templates are not present in this repo snapshot, current readable defaults rely on procedural/texture fallback until Studio templates are installed:

- `MuzzleFlashTemplate`, `MuzzleBlastTemplate`, `SmokeTemplate`: optional; missing templates use short flash/blast/smoke fallback.
- `ImpactSparksTemplate`, `ImpactFlashTemplate`: optional; missing templates use small configured particles plus procedural spark/flash parts.
- `RicochetTemplate`: optional; missing template uses wall impact fallback and optional `Ricochet.SoundId`.
- `TankExplosionTemplate`: preferred; missing template uses procedural death explosion.
- `TankBurningTemplate`: optional; missing template is skipped quietly.

Missing optional templates do not crash gameplay. Template and sound warnings are throttled through `CombatVfxService`.

## Config Shape

`src/ReplicatedStorage/Shared/Configs/VfxConfig.luau` now groups slots by event:

```lua
Shot = {
	SoundId,
	MuzzleFlash,
	MuzzleBlast,
	Smoke,
	Projectile,
}

Impact = {
	WallImpact,
	DamageHit,
	NoPen,
	SelfHit,
}

Ricochet = {
	Enabled,
	TemplateName,
	TemplateLifetime,
	TemplateEmitCount,
	SoundId,
	SoundVolume,
}

DeathExplosion = {
	Enabled,
	TemplateName,
	TemplateLifetime,
	TemplateEmitCount,
	SoundVolume,
}

BurningTank = {
	Enabled,
	TemplateName,
	TemplateLifetime,
	TemplateEmitCount,
}
```

The previous `Shot.ImpactFlash` / `Shot.ImpactSparks` shape was replaced by `Impact.*` so shot presentation and hit presentation are separate.

`TemplateName` must be an object name under `ReplicatedStorage/Shared/Assets/VFX`, not an asset id. `TextureId` and `SoundId` are the only places for `rbxassetid://...` values.

## Tuned Defaults

- Muzzle is short and bright: flash/blast lives around `0.07` seconds, with small particles.
- Smoke is visible but low-density: fallback lifetime stays under `1.0` second.
- Wall impact is smaller than damage hit.
- Damage hit is orange/red and stronger than wall impact.
- No-pen is duller, smaller, and shorter.
- Self-hit is more obvious than normal damage hit.
- Ricochet is sharp and short, with optional configured sound.
- Death explosion lasts `4.0` seconds.
- Burning tank lasts `6.0` seconds and does not attach to the tank model, so it can survive reset/darken/respawn work as a runtime VFX clone.

`MatchConfig.RoundResetDelay` and `MatchConfig.MatchResultDelay` keep the death aftermath visible before the next round or full result screen. VFX clones live in runtime VFX and are cleaned by `Debris`, not by tank model destruction.

## Preview

Run this outside Play Mode in Studio Command Bar:

```text
docs/patches/PREVIEW_VFX_TEMPLATES_COMMAND.lua
```

It creates or refreshes:

```text
Workspace/WOB_Generated/VFXPreview
```

Preview points:

- `MuzzleFlashPreview`
- `SmokePreview`
- `ImpactPreview`
- `RicochetPreview`
- `ExplosionPreview`
- `BurningPreview`

Each real template under `ReplicatedStorage/Shared/Assets/VFX` is cloned, sanitized, emitted, and logged as:

```text
[WOB VFX PREVIEW] Previewed TankExplosionTemplate emitters=X sounds=Y
```

## Verification

Studio checklist:

1. Run `docs/patches/COLLECT_AND_INSTALL_VFX_TEMPLATES_COMMAND.lua` outside Play Mode if Toolbox donors exist in `Workspace`.
2. Run `docs/patches/PREVIEW_VFX_TEMPLATES_COMMAND.lua` outside Play Mode.
3. Confirm preview clones have `CanCollide=false`, `CanTouch=false`, `CanQuery=false`.
4. Play Training.
5. Fire: muzzle flash/blast/smoke and shot sound should be readable without blocking view.
6. Hit wall: wall impact or ricochet should be visible.
7. Hit tank: damage/no-pen/self-hit should be distinct.
8. Kill tank: explosion should play immediately and burning should remain if template exists.
9. Confirm next round/reset does not delete runtime death VFX immediately.
10. Confirm Output has no repeated missing-template or sound spam.
