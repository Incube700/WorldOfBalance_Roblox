# Mobile Performance Pass

## Scope

This pass is a safe playtest polish pass, not a rewrite. The goal is smoother mobile feel while preserving shot readability, Duel/Training/BattleArena behavior, and mobile controls.

## Changes

- Debug defaults remain off:
  - `BattleArenaConfig.Debug = false`
  - `BattleArenaConfig.DebugPad = false`
  - `BattleArenaConfig.DebugCollision = false`
  - `TankConfig.Movement.DebugCollision = false`
  - `MobileControlsConfig.Debug = false`
- `PerformanceConfig.ActiveProfile = "MobileLow"` disables expensive global/runtime/tank/cover shadows for the current playtest build.
- `WOBPerformanceServer` now resolves an explicit profile from `PerformanceConfig.Profiles`.
- `WOBGameplayServer` clears `Runtime.Projectiles` and `Runtime.VFX` on startup.
- `WOBBattleArenaOverlay` throttles full overlay refresh to 0.1s instead of doing all work every rendered frame.
- `ProjectileService` procedural death fallback uses `FallbackPartCount` and a lower default part count.
- `CombatVfxService` prevents runtime VFX clones from running donor scripts or looped template sounds by default.

## Checklist

- Mobile FPS feels smoother in lobby, BattleArena, and Duel.
- Output has no debug spam from pad polling, collision checks, VFX missing templates, or audio.
- Runtime `Workspace.WOB_Generated.Runtime.VFX` does not keep old effects indefinitely.
- Runtime `Workspace.WOB_Generated.Runtime.Projectiles` is empty after old projectiles expire or match reset.
- No infinite fire/campfire sounds after tank death.
- Shot readability remains clear: muzzle, projectile trail, ricochet, impact, and death visual are still visible.
- Mobile controls remain responsive with simultaneous MOVE and AIM.
- BattleArena mobile HUD stays compact and does not cover FIRE/AIM/MOVE.
