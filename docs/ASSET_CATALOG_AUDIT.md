# Asset Catalog Audit

This audit maps current VFX, audio, skin, and cosmetic-ready sources. It is documentation only; it does not imply shop or purchase logic exists.

## Source Contracts

- Final VFX templates live under `ReplicatedStorage.Shared.Assets.VFX`.
- Source files live under `src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxm/.rbxmx`.
- Cosmetic metadata lives in `CosmeticCatalog`.
- Runtime gameplay VFX selection still lives in `VfxConfig`.
- Projectile visuals still live in `ProjectileVisualConfig`.
- Tank skins still live in `SkinCatalog`.
- Audio still lives in `AudioCatalog`.

## Asset Table

| Asset / Template name | Path | Category | Current usage | Safe for gameplay | Safe for cosmetic unlock | Missing metadata | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `MuzzleEffectTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/MuzzleEffectTemplate.rbxm` | MuzzleFlash | `VfxConfig.Shot.MuzzleFlash.TemplateName` | Yes | Yes | Rarity/shop metadata now in `CosmeticCatalog` | Default muzzle flash candidate. |
| `MuzzleFlashTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/MuzzleFlashTemplate.rbxm` | MuzzleFlash | `VfxConfig.Shot.MuzzleBlast.TemplateName` | Yes | Yes | Rarity/shop metadata can be added later | Also used as muzzle blast template. |
| `MuzzleBlastTemplate` | Missing source file | MuzzleFlash | Fallback name in `VfxConfig.Shot.MuzzleBlast.TemplateFallbackNames` | Optional fallback only | Not yet | Source template missing | Do not catalog as installed until saved as its own template. |
| `RicochetTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/RicochetTemplate.rbxm` | RicochetImpact | `VfxConfig.Ricochet.TemplateName` | Yes | Yes | Rarity/shop metadata now in `CosmeticCatalog` | Core ricochet readability effect. |
| `ImpactSparksTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/ImpactSparksTemplate.rbxm` | RicochetImpact / NoPenImpact / PenetrationHit | fallback for wall/damage/no-pen/self-hit impacts | Yes | Yes | Specific cosmetic item metadata not added yet | Good common fallback for multiple impact slots. |
| `NoPenTemplate` | Missing source file | NoPenImpact | `VfxConfig.Impact.NoPen.TemplateName` | Optional; procedural/fallback exists | Future only | Marked `MissingTemplate=true` in `CosmeticCatalog` | Do not pretend installed. |
| `DamageHitTemplate` | Missing source file | PenetrationHit | `VfxConfig.Impact.DamageHit.TemplateName` | Optional; fallback exists | Future only | Marked `MissingTemplate=true` in `CosmeticCatalog` | Good future unlock category. |
| `SelfHitTemplate` | Missing source file | PenetrationHit / RicochetImpact | `VfxConfig.Impact.SelfHit.TemplateName` | Optional; fallback exists | Future only | Not cataloged yet | Could become a special self-hit cosmetic later. |
| `TankExplosionTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/TankExplosionTemplate.rbxm` | DeathExplosion | `VfxConfig.DeathExplosion.TemplateName` | Yes | Yes | Rarity/shop metadata now in `CosmeticCatalog` | Template sounds should stay muted by config. |
| `TankBurningTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/TankBurningTemplate.rbxmx` | BurningEffect | `VfxConfig.BurningTank.TemplateName` | Yes | Yes | Rarity/shop metadata now in `CosmeticCatalog` | Should stay visual-only: no scripts, no looping fire sound. |
| `SmokeTemplate` | `src/ReplicatedStorage/Shared/Assets/VFX/SmokeTemplate.rbxm` | MuzzleFlash / ProjectileTrail support | `VfxConfig.Shot.Smoke.TemplateName` | Yes | Maybe | Not cataloged yet | Could be separate muzzle smoke cosmetic later. |
| `ProjectileVisualConfig` trail | `src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau` | ProjectileTrail | Current projectile trail/ground glow visual settings | Yes | Yes | Metadata now via `default_projectile_trail` | Config-driven, not template-driven. |
| `SkinCatalog.Default` | `src/ReplicatedStorage/Shared/Configs/SkinCatalog.luau` | TankSkin | Default tank color/material | Yes | Yes | Metadata now via `default_tank_skin` | Existing gameplay skin path. |
| `SkinCatalog.RedTest` | `src/ReplicatedStorage/Shared/Configs/SkinCatalog.luau` | TankSkin | Test skin | Yes | Yes, after readability review | Shop metadata missing | Should not reduce team/enemy readability. |
| `SkinCatalog.DesertTest` | `src/ReplicatedStorage/Shared/Configs/SkinCatalog.luau` | TankSkin | Test skin | Yes | Yes, after readability review | Shop metadata missing | Needs mobile/top-down readability check. |
| `AudioCatalog.DefaultCannonShot` | `src/ReplicatedStorage/Shared/Configs/AudioCatalog.luau` | Audio | Default shot sound | Yes | Maybe | Cosmetic audio policy missing | Audio unlocks should not reduce combat clarity. |
| `AudioCatalog.DefaultRicochet` | `src/ReplicatedStorage/Shared/Configs/AudioCatalog.luau` | Audio | Default ricochet sound | Yes | Maybe | Cosmetic audio policy missing | Ricochet audio is gameplay feedback. Keep readable. |
| `TankArmorConfig.Visuals` | `src/ReplicatedStorage/Shared/Configs/TankArmorConfig.luau` | ArmorZoneStyle | Visible front/side/rear armor zones | Yes | Yes, but strict readability rules | Metadata now via `default_armor_zone_style` | Armor zones are gameplay UI, not debug-only. |
| `AimAssistConfig` | `src/ReplicatedStorage/Shared/Configs/AimAssistConfig.luau` | AimLaserStyle | Current aim laser styling | Yes | Yes, under readability rules | Metadata now via `default_aim_laser_style` | Shell Research can extend this later. |

## Current Gaps

- No shop or ownership service exists yet.
- `NoPenTemplate`, `DamageHitTemplate`, `SelfHitTemplate`, and `MuzzleBlastTemplate` are referenced but not present as source-backed VFX files.
- Cosmetic metadata exists only for default/common items.
- Audio cosmetics need stricter policy before any unlocks because sounds affect combat readability.
- Armor zone cosmetics must preserve front/side/rear meaning.

## Recommended Next Step

Run the audit-only `docs/patches/AUDIT_ASSET_CATALOG_COMMAND.lua` in Studio after Rojo sync. It should only print warnings and must not mutate scene, assets, or templates.
