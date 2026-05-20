# Mobile Performance Audit

Goal: improve the published phone playtest loop without changing gameplay, controls, camera, scene layout, combat, reload, movement, projectile rules, or UI/VFX templates.

## Audit Table

| System/file | Possible cost | Current behavior | Safe optimization | Risky optimization | Action taken |
| --- | --- | --- | --- | --- | --- |
| `PerformanceConfig` / `WOBPerformanceServer` | Shadows and lighting on many parts. | `ActiveProfile = "MobileLow"`, shadows off, runtime/decor shadows off. | Keep MobileLow and apply `CastShadow=false` to new runtime descendants. | Scene-wide material/geometry changes. | No code change; verified profile is mobile-safe. |
| `CombatVfxService` | Runtime VFX parts, lights, template clones. | Runtime holders use `CanTouch=false`, `CanQuery=false`, `CastShadow=false`, Debris cleanup. Template sounds are muted by config. | Keep short lifetimes and Debris cleanup. | Removing VFX or editing templates visually. | No VFX visual/template change. |
| `VfxConfig` particles/fire/explosions | Particle bursts and burning visuals. | Shot/explosion visuals enabled; BurningTank has `PlayTemplateSounds=false`, `SoundVolume=0`, `AllowLoopedSounds=false`. | Keep warnings off and sounds muted. | Lowering particle counts globally without visual review. | No visual tuning in this pass. |
| `WorldHealthBars` modules | BillboardGui draw cost and anchor updates. | Discovery loop scans once per second; Heartbeat moves anchors/reload only. | Reduce MaxDistance and skip per-frame work for hidden/dead records. | Changing bar layout or removing reload bar. | `MaxDistance` now uses `HudConfig.WorldHealthBars.MaxDistance = 120`; hidden bars skip Heartbeat work. |
| `TankModelScanner` | `GetDescendants` scan cost. | Scans `TestObjects` and `BattleArena` only in discovery loop. | Keep interval at least 1 second. | Per-frame scans or wider Workspace scans. | Config clamps discovery interval to `>= 1`. |
| `WOBTankDamageFlash` | Highlight and tween cost. | Reuses highlight per tank record; Debug false; no logs unless debug. | Keep short duration and reusable highlight. | Disabling hit flash. | No change; behavior already safe. |
| `WOBAimLaser` | Raycast target collection used `GetDescendants`. | Laser raycasts every frame, but target list was collected every frame. | Cache target list and refresh periodically. | Disabling aim laser or changing aim behavior. | Target list refresh throttled to 0.5s; raycast remains per frame. |
| `WOBCombatFeedbackOverlay` | RenderStepped callback. | Runs each frame even when no active feedback. | Early return when list is empty. | Removing feedback text. | Added empty-list early return; removed startup print. |
| `WOBImpactFeedbackOverlay` | Short pulse tasks and cache table. | Creates short-lived pulse parts with `CanQuery=false`, `CastShadow=false`. | Clean stale dedupe cache entries. | Removing impact pulses. | Added stale cache cleanup; removed startup print. |
| `WOBProjectileReadabilityOverlay` | Per-frame glow follow for active projectiles. | Tracks only projectile candidates; destroys glow parts when projectile disappears. | Avoid output spam; keep parts non-querying/non-shadowing. | Removing projectile readability. | Removed startup print; visuals unchanged. |
| `WOBMobileControls` | Mobile UI count and RenderStepped input update. | Joystick controls remain; `ForceEnabledInStudio=false`; `Debug=false`. | Do not force mobile UI on desktop. | Changing joystick/D-pad/camera controls. | No control changes. |
| `BattleArenaConfig` | Debug logs and collision diagnostics. | `Debug=false`, `DebugPad=false`, `DebugCollision=false`. | Keep debug disabled by default. | Changing arena collision. | No change. |
| Lobby pad polling | Server polling cost. | Pad polling is throttled by `PAD_POLL_INTERVAL`; debug logs throttled and disabled. | Keep throttling. | Changing pad geometry or trigger logic. | No change. |
| Projectiles/trails/readability | Runtime parts and trails. | Projectile service uses Debris cleanup and non-querying/non-shadowing visual parts. | Keep cleanup and avoid extra debug logs. | Changing projectile speed/damage/trails. | No gameplay change. |
| Output spam | Console cost/noise. | Several client overlays printed one startup line. | Remove non-debug startup prints. | Removing useful warnings. | Removed startup prints from client feedback/readability overlays. |

## Safe Changes Made

- `HudConfig.WorldHealthBars.MaxDistance` reduced from `180` to `120`.
- `WorldHealthBarsConfig` now reads `MaxDistance` and `DiscoveryInterval` from `HudConfig`, clamping discovery to at least 1 second.
- `TankHealthBarRecord:Step()` skips anchor/reload Heartbeat work while the billboard is hidden.
- `WOBAimLaser` caches expensive raycast target collection and refreshes it every 0.5 seconds instead of every frame.
- Removed non-debug startup prints from aim laser, combat feedback, impact feedback, and projectile readability overlays.
- `WOBCombatFeedbackOverlay` returns immediately on `RenderStepped` when there are no active feedback labels.
- `WOBImpactFeedbackOverlay` trims stale dedupe cache entries.

## Intentionally Not Changed

- No mobile controls changes; joystick remains.
- No camera changes.
- No combat/reload/movement/projectile behavior changes.
- No VFX/UI template edits.
- No scene or `.rbxl` edits.
- No repair/organize/clean/move scripts were run.
- No optional mobile performance overlay was added; it is safer to keep this pass production-clean.

## Manual Studio Scene Checklist

Review visually in Studio before any scene mutation:

1. Large transparent blue/ForceField surfaces: prefer frames or lower-cost materials; set `CastShadow=false`.
2. Decorative arrows/showcases: if purely visual, set `CanCollide=false`, `CanTouch=false`, `CanQuery=false`, `CastShadow=false`.
3. ParticleEmitters: lower `Rate`, shorter `Lifetime`, keep templates disabled where possible, use runtime bursts.
4. Lights: reduce constant `PointLight.Range` and `Brightness` where not needed.
5. BillboardGui: keep mobile combat bars around `MaxDistance` 80-120.
6. Shadows: keep off for decorative/runtime objects.

## Published Phone Test Checklist

1. Join from the published link on a phone.
2. Lobby FPS feels stable while driving.
3. BattleArena FPS feels stable while driving and shooting.
4. Shooting does not stutter badly.
5. HP/reload bars remain visible but do not clutter the screen.
6. No fire/campfire loop after death/burning VFX.
7. No output spam in Studio.
8. No new orphan folders in Workspace or ReplicatedStorage.
9. No duplicate HP bars after respawn/reset.
10. No old HUD garbage on mobile BattleArena/Training/Duel.
