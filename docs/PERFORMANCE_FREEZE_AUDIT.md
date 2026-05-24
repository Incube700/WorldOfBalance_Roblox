# Performance Freeze Audit

## Summary

The highest-probability freeze source is duplicate runtime code in the Studio place, especially old Studio-owned server scripts running beside Rojo-managed replacements. The checked `RicochetTanksPrototype.rbxlx` has the old `ServerScriptService/Services/WOBGameplayServer` and `ServerScriptService/Services/WOBPerformanceServer` disabled, while the Rojo-managed scripts are active, but Studio should still be inspected before Play testing.

The next risk tier is normal per-frame runtime cost: the server heartbeat updates lobby state, tank movement, bots, arena combat, projectiles, and projectile raycasts; the client has several presentation overlays using `RenderStepped`, `Heartbeat`, or discovery scans. This pass adds safe diagnostic toggles only, with defaults preserving current behavior.

## Highest-Risk Findings

| Risk | File/Path | Why It Can Freeze | Recommended Action | Status |
| --- | --- | --- | --- | --- |
| High | `RicochetTanksPrototype.rbxlx:49545` `ServerScriptService/Services/WOBGameplayServer` | If enabled in Studio, it duplicates the Rojo gameplay server heartbeat, projectile loop, movement, and old debug prints. | Keep disabled or remove later from Studio after confirming Rojo ownership. | Serialized file shows `Disabled=true`; documented only. |
| High | `RicochetTanksPrototype.rbxlx:49826` `ServerScriptService/Services/WOBPerformanceServer` | If enabled with the Rojo replacement, performance profile work can be applied twice and duplicate descendant listeners can run. | Keep disabled or remove later from Studio. | Serialized file shows `Disabled=true`; documented only. |
| High | `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau:1198` | One server heartbeat drives many systems every frame; duplicate copies multiply all costs. | Profile after duplicate check; do not rewrite in this pass. | Not changed. |
| Medium | `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau` | Per projectile swept raycasts run from the server heartbeat; muzzle, impact, ricochet, shield, death, and burn VFX create instances on events. | Use VFX toggles to isolate visual stutters; profile projectile count separately. | Presentation VFX toggles wired. |
| Medium | `src/StarterPlayer/StarterPlayerScripts/Client/WOBProjectileReadabilityOverlay.client.luau` | Ground glow parts are attached once per projectile and moved every `RenderStepped`. | Toggle during mobile/perf tests. | Toggle wired. |
| Medium | `src/StarterPlayer/StarterPlayerScripts/Client/WorldHealthBars/WorldHealthBarsController.luau` | Heartbeat updates active bars; discovery scans generated tank folders every configured interval. | Toggle world bars to isolate HUD cost. | Toggle wired. |
| Medium | `src/ServerScriptService/Server/Gameplay/Bots/BotService.luau` and `BotController.luau` | Arena bots update every server heartbeat, with decision refresh around `0.15s` per active bot. | Test Battle Arena with bots off or max bots forced low. | Bot toggles wired. |

## Duplicate Runtime Scripts

| Script | Rojo/Studio | Runs? | Duplicate? | Recommendation |
| --- | --- | --- | --- | --- |
| `RicochetTanksPrototype.rbxlx:49545` `ServerScriptService/Services/WOBGameplayServer` | Studio-owned legacy | No in checked file, `Disabled=true` | Duplicate of `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau` | Keep disabled; remove later in a dedicated Studio cleanup. |
| `RicochetTanksPrototype.rbxlx:49826` `ServerScriptService/Services/WOBPerformanceServer` | Studio-owned legacy | No in checked file, `Disabled=true` | Duplicate of `src/ServerScriptService/Server/Services/WOBPerformanceServer.server.luau` | Keep disabled; remove later in a dedicated Studio cleanup. |
| `RicochetTanksPrototype.rbxlx:50070` `ServerScriptService/Server/Services/WOBPerformanceServer` | Rojo-managed serialized copy | Yes, `Disabled=false` | Intended replacement | Keep. |
| `RicochetTanksPrototype.rbxlx:58003` `ServerScriptService/Server/Gameplay/WOBGameplayServer` | Rojo-managed serialized copy | Yes, `Disabled=false` | Intended gameplay server | Keep. |
| `RicochetTanksPrototype.rbxlx:20817` `WOBBattleArenaOverlay` | Serialized client script | Yes, `Disabled=false` | Should correspond to Rojo `StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau` | In Studio, verify it exists only under `StarterPlayer/StarterPlayerScripts/Client`. |
| `RicochetTanksPrototype.rbxlx:21645` `WOBTankWorldHealthBars` | Serialized client script | Yes, `Disabled=false` | Should correspond to Rojo `StarterPlayerScripts/Client/WOBTankWorldHealthBars.client.luau` | In Studio, verify no root-level duplicate outside `Client`. |
| `RicochetTanksPrototype.rbxlx:23072` `WorldHealthBarsController` | Serialized module | Required by world bars | Not a standalone runtime script | Keep under `Client/WorldHealthBars`. |
| `RicochetTanksPrototype.rbxlx:26448` `WOBDuelHudOverlay` | Serialized client script | Yes, `Disabled=false` | Should correspond to Rojo `StarterPlayerScripts/Client/WOBDuelHudOverlay.client.luau` | In Studio, verify no root-level duplicate outside `Client`. |
| `BattleArenaUpgradeHud.luau` at repo root | Local legacy/reference file, not in `default.project.json` | No Rojo runtime path | Duplicate of `src/StarterPlayer/StarterPlayerScripts/Client/Hud/BattleArenaUpgradeHud.luau` | Leave for now; clean in a separate repo hygiene pass if desired. |

## High-Frequency Loops

| File | Loop Type | Frequency | Cost | Proposed Fix |
| --- | --- | --- | --- | --- |
| `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau:1198` | `RunService.Heartbeat` | Every server frame | Lobby, player movement, bot services, arena combat, projectiles | Profile after duplicate check; keep gameplay logic unchanged. |
| `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau:957` | Called from heartbeat | Every server frame per active projectile | Swept raycast and tank hit resolution | Later profile projectile counts and raycast targets; not changed. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WorldHealthBars/WorldHealthBarsController.luau:134` | `RunService.Heartbeat` plus discovery loop | Every frame plus `>=1s` discovery | Per tank bar update and generated-folder scan | Added `WorldHealthBarsEnabledOverride`. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBProjectileReadabilityOverlay.client.luau:169` | `RunService.RenderStepped` | Every client frame | Moves projectile ground glow parts | Added `ProjectileVfxEnabled` gate. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBCombatFeedbackOverlay.client.luau:253` | `RunService.RenderStepped` | Every client frame while feedback exists | Moves/fades combat text billboards | Added `FloatingCombatTextEnabled` gate. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankDamageFlash.client.luau:345` | `task.spawn` discovery loop | Around `0.5s` by config | Scans generated tank roots and manages highlight records | Added `DamageFlashEnabled` gate. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBImpactFeedbackOverlay.client.luau:247` | Per-impact spawned `RenderStepped:Wait` loop | During impact pulse lifetime | Animates two local pulse parts | Added projectile/impact VFX gate. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau:870` | `RenderStepped`, throttled | `0.1s` overlay refresh | Reads attributes and updates arena HUD | Monitor; no change. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBRoundStatusOverlay.client.luau:1228` | `RenderStepped`, partial throttle | Reload every frame, tank refresh around `0.2s` | HUD updates and tank target refresh | Monitor; no change. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBMobileControls.client.luau:935` | `RenderStepped` | Every client frame | Mobile input presentation/control loop | Do not change under current constraints. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankInputController.client.luau:353` | `RenderStepped` | Every client frame | Input send/aim state | Do not change under current constraints. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau` | `RenderStepped` with cached target refresh | Every client frame, target refresh `0.5s` | Aim raycast and target collection | Leave unchanged because it affects aiming presentation. |

## Debug Spam

| File | Log Type | Frequency | Action |
| --- | --- | --- | --- |
| `src/ReplicatedStorage/Shared/Configs/DebugCombatConfig.luau` | `ArmorDebug`, `ProjectileDebug`, `DamageLog`, scene debug | Disabled by default | No change. |
| `src/ReplicatedStorage/Shared/Configs/BotConfig.luau` | Bot debug logs | `Debug=false` | No change. |
| `src/ReplicatedStorage/Shared/Configs/TankConfig.luau` and `BattleArenaConfig.luau` | Collision/pad debug | Disabled by default | No change. |
| `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau` | Input apply logs | Gated by local `DEBUG_INPUT=false` | No change. |
| `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau` | Muzzle/projectile debug | Gated by safety/debug configs | No change. |
| `src/ServerScriptService/Server/Gameplay/Lobby/LobbyService.luau` and arena/economy/stats services | State/event logs | Per transition or reward/stat event | Not frame spam; left intact. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankPossessionCamera.client.luau` | Tank diagnostics | On tank/camera acquisition | Suspicious if repeatedly reacquiring; not changed in this pass. |

## World Bars

World bars do not appear to rebuild every frame. `WorldHealthBarsController` keeps one record per model, updates records on `Heartbeat`, discovers tanks at `HudConfig.WorldHealthBars.DiscoveryInterval` with a minimum of `1s`, and cleans invalid records. `TankModelScanner` does use `GetDescendants()` on generated test/arena roots during discovery, so it is a useful isolation target on mobile.

Added test switch:

```lua
PerformanceConfig.Diagnostics.WorldHealthBarsEnabledOverride = false
```

`nil` uses `HudConfig.WorldHealthBars.Enabled`; `true` forces the controller on; `false` prevents the controller from creating bars or heartbeat work.

## Bots

Battle Arena bots are enabled by config. The current loop maintains at least `2` solo bots, `1` bot with players, max `4`, hard limit `6`. Each active bot is updated by `BotService.update(deltaTime)` from the main server heartbeat; `BotController` refreshes decisions around `BotConfig.Brain.TickRate = 0.15` and skips dead/inactive bots.

Added test switches:

```lua
PerformanceConfig.Diagnostics.BattleArenaBotsEnabled = false
PerformanceConfig.Diagnostics.BattleArenaMaxBotsOverride = 0
```

Use `BattleArenaBotsEnabled=false` to isolate arena without bots. Use `BattleArenaMaxBotsOverride=0`, `1`, or `2` to test bot count pressure without changing arena balance configs.

## VFX/Projectiles

Projectile collision and damage logic were not changed. The server still creates projectile parts and still updates projectile physics/raycasts normally. Presentation VFX are the safe isolation target: muzzle flash, impact bursts, ricochet/shield reflect visuals, death explosion, burning tank VFX, local projectile ground glows, local impact pulses, floating combat text, and damage flash.

Added test switches:

```lua
PerformanceConfig.Diagnostics.ProjectileVfxEnabled = false
PerformanceConfig.Diagnostics.MuzzleFlashEnabled = false
PerformanceConfig.Diagnostics.ImpactVfxEnabled = false
PerformanceConfig.Diagnostics.FloatingCombatTextEnabled = false
PerformanceConfig.Diagnostics.DamageFlashEnabled = false
```

`ProjectileVfxEnabled=false` disables the broad presentation VFX path wired in this pass. It does not change projectile collision, damage, cooldown, upgrades, or remotes.

## Upgrade Icons/UI Assets

`src/ReplicatedStorage/Shared/Configs/UpgradeIconConfig.luau` was not edited. Existing `rbxassetid://` values were preserved. `BattleArenaUpgradeHud` already binds `IconImage` once per choice card/template and falls back to `★` only when the configured image id is missing or empty. This pass made no upgrade HUD changes and did not activate Vampire/King/Pedestal gameplay.

## Safe Toggles Added

All toggles live in `src/ReplicatedStorage/Shared/Configs/PerformanceConfig.luau` under `Diagnostics`.

| Toggle | Default | Use |
| --- | --- | --- |
| `WorldHealthBarsEnabledOverride` | `nil` | `nil` uses HUD config; `false` disables world bars; `true` forces them on. |
| `ProjectileVfxEnabled` | `true` | Broad presentation VFX isolation switch. |
| `MuzzleFlashEnabled` | `true` | Disable muzzle flash/blast/smoke while leaving projectile logic intact. |
| `ImpactVfxEnabled` | `true` | Disable impact, ricochet, reflect, death, burn, and local impact pulse visuals. |
| `DamageFlashEnabled` | `true` | Disable client hit highlight/discovery overlay. |
| `FloatingCombatTextEnabled` | `true` | Disable floating combat text billboards. |
| `BattleArenaBotsEnabled` | `true` | Disable Battle Arena bots for isolation. |
| `BattleArenaMaxBotsOverride` | `nil` | Force a test max bot count such as `0`, `1`, or `2`. |
| `DebugRuntimeLogs` | `false` | Reserved global switch for future log gating; not broadly wired in this pass. |

## Manual Studio Checks

Inspect these Explorer paths in the exact Studio place used for Play Mode:

1. `ServerScriptService/Services/WOBGameplayServer` should be disabled or absent.
2. `ServerScriptService/Services/WOBPerformanceServer` should be disabled or absent.
3. `ServerScriptService/Services/WOBProjectileVisualEnhancer` should be disabled or absent if present.
4. `ServerScriptService/Server/Gameplay/WOBGameplayServer` should be the active Rojo-managed gameplay server.
5. `ServerScriptService/Server/Services/WOBPerformanceServer` should be the active Rojo-managed performance server.
6. `StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay` should exist only under `Client`, not also at the root.
7. `StarterPlayer/StarterPlayerScripts/Client/WOBTankWorldHealthBars` should exist only under `Client`, not also at the root.
8. `StarterPlayer/StarterPlayerScripts/Client/WOBDuelHudOverlay` should exist only under `Client`, not also at the root.
9. `StarterPlayer/StarterPlayerScripts/Client/Hud/BattleArenaUpgradeHud` should be the active upgrade HUD path.

## Test Matrix

1. Training with normal settings, then `WorldHealthBarsEnabledOverride=false`.
2. Battle Arena with `BattleArenaBotsEnabled=false` and VFX on.
3. Battle Arena with `BattleArenaMaxBotsOverride=0`, then `1`, then normal `nil`.
4. Battle Arena with bots on and `WorldHealthBarsEnabledOverride=false`.
5. Battle Arena with bots on and `ProjectileVfxEnabled=false`.
6. Battle Arena with `FloatingCombatTextEnabled=false` and `DamageFlashEnabled=false`.
7. Mobile emulation with upgrade popup open, confirming ImageLabel upgrade icons still show and no fallback stars appear for configured ids.
8. Mobile emulation with world bars off and VFX off, confirming MOVE/AIM/FIRE/REV still respond after popups close.

## What Was Not Changed

- No gameplay balance changes.
- No damage, armor, penetration, shield, or reflect logic changes.
- No projectile collision or projectile mechanics changes.
- No movement or tank control changes.
- No Duel rules changes.
- No server upgrade effect changes.
- No remotes or upgrade protocol changes.
- No King/Pedestal mechanics.
- No Vampire gameplay activation.
- No DataStore, shop, monetization, wallet, reward, or progression changes.
- No `UpgradeIconConfig.luau` asset ids changed.
