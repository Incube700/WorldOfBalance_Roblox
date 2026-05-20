# Architecture Refactor Audit

Date: 2026-05-20

This audit records current boundaries and safe refactor opportunities after source-of-truth cleanup, world health bar module split, mobile performance work, ArmorHitResolver, TankFactory foundation, LobbyPadResolver, Hud helpers, and ProjectileCollisionService.

This is an architecture document, not a feature request. Do not use it to justify changing scene objects, Rojo mappings, VFX/UI templates, mobile controls, camera, armor tuning, projectile balance, or the published playtest loop.

## Current Pass Summary

Safe changes in this pass:

- Expanded `HudVisibilityRules` so Duel/Training/BattleArena HUD visibility rules live in one helper.
- Added `ProjectileHitResult` constants so future projectile code can talk about outcomes without inventing strings in multiple files.
- Left Round/Arena/Runtime folder deeper splits as audit-only because they touch live session flow.

Previously extracted and still valid:

- `LobbyPadResolver` from `LobbyService`.
- `HudDeviceUtils` and `CompactStatsFormatter` from HUD overlays.
- `ProjectileCollisionService` from `ProjectileService`.

## Server Audit

| File | Lines | Current responsibilities | Problems | Coupling risk | Suggested split | Safe now? | Why | Priority |
|---|---:|---|---|---|---|---|---|---|
| `WOBGameplayServer.server.luau` | ~830 | Composition root, runtime folders, service wiring, prototype bootstrap, remotes, damage/death helpers, training bot debug hooks, heartbeat | Entry point still owns real gameplay helpers and direct legacy prototype setup | High | `GameplayBootstrap`, `RuntimeFolderService`, `GameplayRemoteBinder`, death/VFX feedback facade | No | It is the startup spine and touches every live mode | P1 |
| `LobbyService.luau` | ~950 | Lobby player modes, Duel queue, Training entry, Arena entry, rematch/return flow | Still mixes mode transitions, queue state, lobby spawn, and pad polling | Medium | `LobbyPlayerModeService`, `DuelQueueService`, keep `LobbyPadResolver` | Partly | Pad geometry already extracted; mode flow should wait | P1 |
| `LobbyPadResolver.luau` | ~167 | Pad root lookup, trigger detection, pad contract attributes, tank-in-trigger overlap | Focused; no match/mode side effects | Low | Keep | Yes | Already a clean helper boundary | P2 |
| `RoundMatchService.luau` | ~715 | Duel/Training match state, score, round reset, match result, attributes | Session state, score, result, reset timing, participant setup are coupled | High | `RoundScoreTracker`, `RoundSpawnPlanner`, `RoundResultResolver`, future `DuelSessionService` | No | Recent Duel facing/results fixes make behavior sensitive | P1 |
| `ArenaCombatService.luau` | ~567 | BattleArena sessions, scoring, death/respawn, arena upgrades, player attributes | Session store, scoring, upgrades, respawn are in one file | Medium | `ArenaSessionStore`, `ArenaScoreTracker`, `ArenaRespawnPlanner`, `ArenaUpgradeRuntime` | No | BattleArena is working and upgrade/respawn flow is easy to regress | P1 |
| `ProjectileService.luau` | ~1020 | Projectile spawn, shot pattern, muzzle safety, VFX creation, lifecycle/simulation, wall ricochet | Very large; still mixes projectile factory, simulation, muzzle safety, and VFX | Medium | `ProjectileSpawnService`, `ProjectileSimulationService`, `MuzzleSafetyService`, `ProjectileVfxDispatcher` | Partly | Collision and result constants extracted; VFX split should wait | P1 |
| `ProjectileCombatService.luau` | ~237 | Tank hit interpretation, ArmorHitResolver call, damage/no-pen/ricochet, stats, combat feedback | VFX callbacks and damage/stats are still mixed | Medium | `ProjectileDamageApplier`, `ProjectileVfxDispatcher`, `ProjectileHitResult` | Partly | Constants are safe; moving VFX calls risks feedback regressions | P1 |
| `ProjectileCollisionService.luau` | ~73 | Projectile swept raycast targets, active armor hitbox queryability, previous/next segment cast | Focused; future radius/capsule check belongs here | Low | Add radius checks only after pass-through repro | Yes | Current behavior preserved | P1 |
| `TankSpawnResetService.luau` | ~480 | Spawn transform lookup, duel facing, tank layout, reset, visibility | Spawn planning and scene mutation/layout are coupled | Medium | `TankSpawnPlanner`, `TankLayoutService`, `TankVisibilityService` | No | Spawn orientation was recently fixed; avoid churn | P1 |
| `TankFactory.luau` | ~181 | Adapter-level spawn/register pipeline over legacy models | New foundation still depends on legacy prototypes | Low | `TankRole`, `TankSpawnRequest`, `TankStatsProvider` | Docs only | API should settle before more modules | P2 |
| `ArmorHitResolver.luau` | ~261 | Pure armor zone/angle/effective armor/result math | New tuning needs playtest; no split needed | Low | Keep resolver + config | No split | Focused enough | P2 |
| `PlayerWalletService.luau` | ~365 | Persistent/session wallet values, player attributes, reward bookkeeping | Economy persistence and presentation attributes are coupled | Medium | `WalletDataStoreAdapter`, `WalletAttributePublisher` | No | Data persistence is risky without tests | P2 |
| `MatchRewardService.luau` | ~122 | Duel match reward rules | Focused; Duel-only reward gate is clear | Low | Keep | No | No need yet | P2 |
| `KillRewardService.luau` | ~113 | Kill reward rules by match mode | Focused; uses mode strings | Low | Future `RewardRulesByMode` | No | No need yet | P2 |
| `TrainingBotService.luau` | ~671 | Training dummy AI, target acquisition, movement/shooting decisions | Bot behavior exists but should stay behind debug/training boundaries | High | Future `BotBrain`, `BotController`, `BotParticipantAdapter` | No | User explicitly does not want bot feature expansion in this pass | P2 |
| `TankMovementService.luau` | ~583 | Movement/collision physics | Gameplay feel sensitive; no architecture-only gain right now | High | `MovementCollisionResolver`, `TankKinematics` later | No | Do not disturb movement | P2 |
| `CombatVfxService.luau` | ~452 | VFX template lookup/playback, sound muting behavior | VFX dispatch and template hygiene are related but manageable | Medium | `VfxTemplateResolver`, `VfxSoundPolicy` | No | VFX templates/source-of-truth recently stabilized | P2 |

## Client Audit

| File | Lines | Current responsibilities | Problems | Coupling risk | Suggested split | Safe now? | Why | Priority |
|---|---:|---|---|---|---|---|---|---|
| `WOBRoundStatusOverlay.client.luau` | ~970 | Duel/Training HUD binding, legacy HP/reload, score, result, rematch input | UI binding, visibility, state reads, input, emergency UI in one file | Medium | `RoundHudBinder`, `RoundResultPresenter`, `CombatHudVisibilityRules` | Partly | Visibility rules extracted; binding split should wait | P1 |
| `WOBBattleArenaOverlay.client.luau` | ~719 | Arena HUD construction, layout, stats, death panel, return menu | UI creation/layout/state reading mixed | Medium | `BattleArenaOverlayFactory`, `BattleArenaStatsPresenter` | Partly | Device/compact/visibility helpers extracted | P1 |
| `WOBPlayableShell.client.luau` | ~1236 | Main shell/menu/UI flow | Largest client file; contains mode visibility and menu behavior | High | `PlayableShellMenu`, `PlayableShellStatePresenter` | No | Menu is user-facing and not part of current issue | P1 |
| `WOBMobileControls.client.luau` | ~612 | Mobile joystick/aim/fire UI and input state | Input UI and visibility are coupled | High | `MobileControlWidgets`, `MobileControlVisibilityRules` later | No | Mobile controls must not change | P2 |
| `WOBAimLaser.client.luau` | ~350 | Aim laser targets/rendering | Target collection and rendering in one file | Medium | `AimLaserTargetProvider`, `AimLaserRenderer` | No | Readability is sensitive | P2 |
| `WOBTankDamageFlash.client.luau` | ~355 | Damage flash discovery/highlight pulse | Focused enough; discovery and rendering could split later | Low | `DamageFlashScanner`, `DamageFlashRenderer` | No | Working and small enough | P2 |
| `WOBCombatFeedbackOverlay.client.luau` | ~250 | Floating combat feedback visuals | Repeats PlayerMode checks | Low | Use `HudVisibilityRules` later | Not now | Not worth extra churn | P2 |
| `WOBImpactFeedbackOverlay.client.luau` | ~295 | Impact feedback visuals | Repeats PlayerMode checks | Low | Use `HudVisibilityRules` later | Not now | Focused enough | P2 |
| `WOBProjectileReadabilityOverlay.client.luau` | ~185 | Projectile readability glows | Focused | Low | Keep | No | No issue | P3 |
| `WOBHudBootstrap.client.luau` | ~64 | HUD clone/cleanup | Small and focused | Low | Keep | No | No issue | P3 |
| `WorldHealthBars/*` | 45-277 each | Scanner, config, billboard factory, anchor service, record/controller | Already modular; anchor/runtime folder helper can improve later | Low | Future `ClientRuntimeFolders` | Not now | Working after recent refactor | P2 |
| `Hud/*` | 14-113 each | Device detection, compact formatting, visibility rules | Healthy helper boundary | Low | Add tests later if tooling exists | Yes | Current pass expanded safely | P2 |

## Config Audit

| File | Lines | Current responsibilities | Problems | Coupling risk | Suggested split | Safe now? | Why | Priority |
|---|---:|---|---|---|---|---|---|---|
| `HudConfig.luau` | ~68 | HUD behavior flags, world bars, reload text, damage flash | Owns both legacy and world HUD flags | Low | Keep; document ownership | Yes | Small, clear | P1 |
| `TankArmorConfig.luau` | ~42 | Armor zones/tuning | New tuning; no split | Low | Keep | No | Avoid tuning changes | P1 |
| `ProjectileCatalog.luau` | ~49 | Projectile combat/physical stats | Legacy aliases remain | Low | Keep aliases, document canonical fields | Yes | Compatibility needed | P1 |
| `WeaponConfig.luau` | ~14 | Weapon id/cooldown/projectile id | Single primary weapon only | Low | Future `WeaponCatalog` | No | No new weapons now | P2 |
| `VfxConfig.luau` | ~274 | VFX template/procedural settings | Large but visual-only | Medium | Future split by domain | No | VFX source-of-truth stable; avoid churn | P2 |
| `AudioCatalog.luau` | ~114 | Sound ids/playback | Focused | Low | Keep | No | No issue | P3 |
| `DebugCombatConfig.luau` | ~8 | Armor/projectile debug flags | Healthy | Low | Keep | Yes | Debug off by default | P2 |
| `BattleArenaConfig.luau` | ~32 | Arena scoring/respawn/upgrades | Progression config mixed into arena | Medium | Future `ArenaUpgradeConfig` | No | No feature change | P2 |
| `MobileControlsConfig.luau` | ~43 | Mobile input UI | Do not change | High | Later experiment only | No | User forbids mobile controls change | P3 |
| `MatchConfig.luau` | ~10 | Round/match presentation rules | Small | Low | Keep | No | No issue | P3 |
| `TankConfig.luau` | ~88 | Movement, armor hitbox visibility, presentation | Mixed tank domains | Medium | Future `TankMovementConfig`, `TankPresentationConfig` | No | Movement sensitive | P2 |

## Cross-Cutting Findings

1. Entry point does too much:
   - `WOBGameplayServer.server.luau` still owns bootstrap plus damage/death feedback helpers.
2. Session/mode/state are mixed:
   - `LobbyService`, `RoundMatchService`, and `ArenaCombatService` all publish mode attributes.
3. Scene/pad detection and business logic:
   - Improved by `LobbyPadResolver`; `LobbyService` still owns queue/mode actions.
4. Projectile simulation/collision/combat/VFX:
   - Improved by `ProjectileCollisionService` and `ProjectileHitResult`.
   - `ProjectileService` still owns VFX creation.
5. Weapon vs projectile config:
   - Weapon selects projectile and cooldown.
   - Projectile owns damage/penetration/speed/lifetime.
6. UI creation/layout/visibility/state reading:
   - Improved by `HudVisibilityRules`, `HudDeviceUtils`, `CompactStatsFormatter`.
   - Round/Battle overlays still build UI directly.
7. Player/bot/dummy/tank spawning:
   - `TankFactory` adapter exists.
   - Legacy prototypes still used by design.
8. Hardcoded prototype references:
   - `WOBGameplayServer.server.luau` and `TankSpawnResetService.luau` still reference `PlayerTankPrototype`, `Player2TankPrototype`, `DummyTank`.
9. Duplicated `PlayerMode` checks:
   - Still present in input/camera/feedback/shell scripts.
   - Centralize only when touching those scripts for related work.
10. Runtime folders:
   - Server and multiple client scripts create `Workspace.WOB_Runtime` folders independently.
   - Candidate for `ClientRuntimeFolders`/`ServerRuntimeFolders`, but not worth broad touch in this pass.
11. Debug/log spam:
   - Debug configs remain false by default.
   - Training bot debug prints remain guarded by debug flow.
12. Mobile lag risks:
   - Large client overlays and visual loops exist, but no new loops were added.
13. Future bots/upgrades/extraction:
   - Need session abstraction and TankFactory migration before adding real features.

## Refactors Not Done

| Candidate | Why not now |
|---|---|
| `RoundScoreTracker` / `RoundSpawnPlanner` | Round reset/result flow is live and recently touched; needs a dedicated pass with Studio verification. |
| `ArenaScoreTracker` / `ArenaRespawnPlanner` | BattleArena score/respawn/upgrades are tightly coupled and working. |
| `ProjectileVfxDispatcher` | Projectile VFX is still inside `ProjectileService`; extracting safely requires careful callback parity. |
| `RuntimeFolderService` | Would touch many client/server scripts; folder hygiene is stable enough for now. |
| Full TankFactory migration | Legacy prototypes are still active source objects and should not be deleted or bypassed yet. |

## Safety Notes

- No patch scripts were created or run.
- No scene mutation was performed.
- No `.rbxl` edit was performed by code.
- No `default.project.json` change was made.
- No `ReplicatedStorage.Assets/UI/VFX/UX` or `Workspace.Assets/UI/VFX/UX` path was introduced.
