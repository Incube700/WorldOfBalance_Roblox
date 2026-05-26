# Gameplay Audio Inventory

## Summary

Current runtime audio is client-owned by `WOBAudioController.client.luau`.
The server sends existing `CombatFeedbackEvent` payloads, and the client resolves them through `AudioCatalog.luau`.

Three release gameplay sounds currently have real `SoundId` values:

- `Shoot` / `Shot`: `rbxassetid://139771888058836`
- `RicochetImpact`: `rbxassetid://140602821561280`
- `TankExplosion`: `rbxassetid://4810729508`

Imported FX template sounds are intentionally not used. Visual FX services mute/stop template `Sound` instances; gameplay audio should be cataloged in `AudioCatalog`.

## Inventory

| Sound key | Found? | Current SoundId/source | Current hook | Works now? | Missing action |
| --- | --- | --- | --- | --- | --- |
| `Shoot` / `Shot` | Yes | `AudioCatalog.DefaultCannonShot` = `rbxassetid://139771888058836` | `ProjectileService.tryShoot` sends `Type = "Shot"` through `CombatFeedbackEvent`; `WOBAudioController` plays it. | Yes | None. |
| `ProjectileImpact` | Catalog key prepared | `AudioCatalog.DefaultProjectileImpact`, empty `SoundId` | Damage feedback maps to `ProjectileImpact`; final wall impact has VFX but no audio-only event because no sound is configured. | No | Add a vetted impact `SoundId`; then wire final wall impact if needed. |
| `RicochetImpact` | Yes | `AudioCatalog.DefaultRicochet` = `rbxassetid://140602821561280` | Wall ricochet sends `Type = "Ricochet"`; armor ricochet sends `Type = "ArmorRicochet"`; both map to `RicochetImpact`. | Yes | None. |
| `TankExplosion` | Yes | `AudioCatalog.DefaultExplosion` = `rbxassetid://4810729508` | Tank death already sends `Type = "TankDestroyed"`; client maps it to `TankExplosion`. | Yes | None. |
| `UpgradeSelect` | Catalog key prepared | `AudioCatalog.DefaultUpgradeSelect`, empty `SoundId` | Upgrade select visual hook exists in `ArenaCombatService`; no audio event is fired while sound id is empty. | No | Add a vetted UI/gameplay `SoundId`, then fire an audio-only event on accepted upgrade. |
| `LevelUp` | Catalog key prepared | `AudioCatalog.DefaultLevelUp`, empty `SoundId` | Level-up visual hook exists in `ArenaCombatService`; no audio event is fired while sound id is empty. | No | Add a vetted level-up `SoundId`, then fire an audio-only event when the offer appears. |
| `ReflectShield` | Catalog key prepared | `AudioCatalog.DefaultReflectShield`, empty `SoundId` | Shield reflect feedback sends `Type = "ShieldReflect"`; client maps it to `ReflectShield`. | No | Add a vetted shield `SoundId`. |
| `Repair` | Catalog key prepared | `AudioCatalog.DefaultRepair`, empty `SoundId` | Repair visual hook plays only after HP increases; no audio event is fired while sound id is empty. | No | Add a vetted repair `SoundId`, then fire an audio-only event only after actual healing. |
| `EngineLoop` | Catalog key prepared | `AudioCatalog.DefaultEngineLoop`, empty `SoundId` | No hook; optional future continuous audio. | No | Add vetted loop asset and a dedicated loop controller later. |

## Existing Working Hooks

- Shoot sound:
  - `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
  - `tryShoot()` calls `sendProjectileFeedback("Shot", shotOrigin, "", ..., true)`.
  - `WOBGameplayServer.server.luau` forwards it via `CombatFeedbackEvent`.
  - `WOBAudioController.client.luau` resolves `Shot` to `DefaultCannonShot`.

- Ricochet sound:
  - Wall ricochet: `ProjectileService.updateProjectiles()` calls `sendProjectileFeedback("Ricochet", result.Position, "", ..., true)`.
  - Armor ricochet: `ProjectileCombatService.handleProjectileTankHit()` sends `Type = "ArmorRicochet"`.
  - `WOBAudioController.client.luau` maps both to `RicochetImpact`, which resolves to `DefaultRicochet`.

## Hookup Pass

This pass added:

- explicit release audio keys in `AudioCatalog`;
- safe empty catalog entries for missing sounds;
- client-side sound throttling using existing `AudioConfig.MaxSoundsPerSecond`;
- per-sound `ThrottleSeconds` for frequent combat sounds;
- category mapping for `ProjectileImpact`, `RicochetImpact`, `TankExplosion`, `ReflectShield`, `UpgradeSelect`, `LevelUp`, and `Repair`.

This pass did not add:

- new marketplace asset ids;
- audio from imported FX templates;
- shop/equip/save logic;
- continuous engine loop playback;
- audio events for empty/missing `SoundId` entries.

## Manual Audio Asset Organization

| Found asset/file | Current path | Sound name | SoundId | Suggested audio key | Notes |
| --- | --- | --- | --- | --- | --- |
| `ExplosionTankSFX.rbxm` | `src/ReplicatedStorage/Shared/Assets/VFX/ExplosionTankSFX.rbxm` | `ExplosionTank` | `rbxassetid://4810729508` | `TankExplosion` | Manually added legacy-path sound asset. Copied to canonical audio structure and mapped to `DefaultExplosion`. |

Canonical release audio folder:

```text
src/ReplicatedStorage/Assets/Audio/Gameplay
  ProjectileImpact
  TankExplosion
    TankExplosion_Default.rbxm
  UpgradeSelect
  LevelUp
  ReflectShield
  Repair
  EngineLoop
```

`TankExplosion_Default.rbxm` is a source/reference copy only. Runtime still plays through `AudioCatalog` and `WOBAudioController`; it does not play `Sound` instances directly from this folder.

No other source-controlled `.rbxm` / `.rbxmx` files with `SoundId` were found under `src`.
No local `.mp3`, `.wav`, `.ogg`, `.flac`, `.m4a`, or `.aac` files were found in the project.

## Manual SoundId Fill List

Before wiring more events, add vetted `SoundId` values for:

1. `DefaultProjectileImpact`
2. `DefaultUpgradeSelect`
3. `DefaultLevelUp`
4. `DefaultReflectShield`
5. `DefaultRepair`
6. `DefaultEngineLoop` only if a proper loop controller is planned

Future manually imported audio should be saved under:

```text
src/ReplicatedStorage/Assets/Audio/Gameplay/<AudioKey>/<AudioKey>_Default.rbxm
```

Then copy only the vetted `SoundId` into `AudioCatalog.luau`.
