# Architecture Separation Audit

## 1. Executive Summary

Current playable state is valuable and should be preserved before adding more BattleArena features. Lobby, Training, Duel, and BattleArena all work; BattleArena upgrade icons use `UpgradeIconConfig` with ImageLabel assets on desktop and mobile; aim laser and world HP/reload bars have smoothing; bot spawn staggering reduced Arena entry stutter; ArmorZones are prebaked in the Studio template; post-5 ArenaLevel preparation exists; paid revive preserves the current run; free respawn resets run powers and keeps the player in BattleArena.

Feature work should pause briefly because several files are now carrying too many responsibilities. The highest-risk growth points are `ArenaCombatService.luau`, `WOBGameplayServer.server.luau`, `ProjectileService.luau`, `WOBBattleArenaOverlay.client.luau`, and `WOBPlayableShell.client.luau`. They are still playable, but future Movement / Shooting / Defense / Vampire / Ricochet branches, post-5 rewards, revive polish, VFX pooling, and record/king/pedestal systems will make them harder to change safely if ownership is not separated first.

The next refactor should make BattleArena ownership clearer: run/session state, level/XP, upgrade offers/effects, revive/free respawn, rewards, bot direction, HUD presentation, projectile gameplay, and VFX should each have a narrower owner.

The goal is not a giant rewrite. The goal is staged extraction of responsibilities while keeping the game playable after every step.

Must be preserved during refactors:

- Duel behavior and balance.
- Training behavior.
- Movement, shooting, projectile collision, damage, armor, ricochet, shield/reflect behavior.
- Wallet spend/save semantics.
- Current remotes and upgrade protocol until a migration is complete.
- `UpgradeIconConfig` asset ids.
- `BaseTankTemplate` ArmorZones names and template ownership.
- BattleArena paid revive and free respawn behavior.
- Current mobile controls and HUD usability.

## 2. Current Runtime Ownership Map

| Area | Current Owner(s) | Current Responsibilities | Problem | Future Owner |
| --- | --- | --- | --- | --- |
| Lobby | `WOBPlayableShell.client.luau`, `WOBGameplayServer.server.luau`, start/rematch/return remotes | Start menu, result/stats popups, mode start buttons, return-to-menu flow | Client shell also owns popup layout and mode UI state; server mode flow is mixed with participant spawning | `ModeHudRouter`, `LobbyHudPresenter`, `GameModeService` / `LobbyMode` |
| Training | `WOBGameplayServer.server.luau`, tank input client scripts | Participant creation, match start, respawn/death handling shared with other modes | Shared server path makes accidental Training changes possible during Arena work | `TrainingMode`, shared tank spawn helpers |
| Duel | `WOBGameplayServer.server.luau`, `WOBDuelHudOverlay.client.luau` | Duel match flow, HUD, death/result handling | Duel is mostly separate in intent, but still shares server gameplay paths | `DuelMode`, `DuelHudPresenter` |
| BattleArena run state | `ArenaCombatService.luau`, `WOBGameplayServer.server.luau` | Enter/leave Arena, sessions, tank state, death state, revive pending, free respawn, cleanup | Run lifecycle is mixed with upgrades, rewards, respawn, shield attributes, and bot sessions | `BattleArenaMode`, `ArenaRunService`, `ArenaSessionRepository` |
| ArenaLevel / XP | `ArenaCombatService.luau`, `BattleArenaConfig.luau` | ArenaXP, ArenaLevel, CoreBuildLevel/MaxUpgradeLevel, post-5 progression formula | Level math and level-up side effects are embedded in combat service | `ArenaLevelService` |
| Upgrade offer / apply | `ArenaCombatService.luau`, `BattleArenaConfig.luau`, `BattleArenaUpgradeHud.luau` | Offer selection, max stacks, chosen ids, modifiers, repair/shield effects, UI card display | Offer rules, effect application, and UI are split by accident, not a clean contract | `ArenaUpgradeService`, `UpgradeOfferService`, `UpgradeEffectApplier`, `UpgradeChoicePresenter` |
| Revive / free respawn | `ArenaCombatService.luau`, `WOBBattleArenaOverlay.client.luau`, `PlayerWalletService.luau` | Paid revive validation/spend/respawn, free respawn reset, death panel options | Economy, session state, and death UI are tightly coupled | `ArenaReviveService`, `DeathPanelPresenter`, wallet boundary |
| Arena rewards / Bolts | `ArenaCombatService.luau`, `PlayerWalletService.luau` | Bot kill rewards, ricochet/self-hit reward reasons, wallet add/spend | Reward reasons and wallet internals are too close to combat/death flow | `ArenaRewardService`, `PlayerWalletService` boundary |
| Bot director / bot spawning | `BotService.luau`, `ArenaCombatService.luau`, `BattleArenaConfig.luau` | Desired bot count, spawn records, staggered spawning, bot sessions, respawn updates | Bot lifecycle is mostly in one service, but Arena session linkage and desired count are not clearly separated | `ArenaBotDirector`, existing bot brain/controller modules |
| Projectile gameplay | `ProjectileService.luau`, `WOBGameplayServer.server.luau` | Shot validation, projectile simulation, raycasts, hit resolution hooks | Projectile lifecycle and cosmetic hooks live together; server gameplay loop calls update directly | `ProjectileGameplayService`, `ProjectileEventService` |
| Projectile VFX | `ProjectileService.luau`, `WOBProjectileReadabilityOverlay.client.luau`, impact feedback modules | Muzzle flashes, trails, impact visuals, readability overlays | VFX object churn and gameplay simulation are not fully separated | `ProjectileVfxPresenter`, `VfxPool`, `CombatFeedbackPresenter` |
| Combat feedback text | `WOBCombatFeedbackOverlay.client.luau`, `WOBGameplayServer.server.luau`, `ProjectileService.luau` | Floating DAMAGE / NO PEN / RICOCHET / SELF HIT / REFLECT text | Event payloads are usable, but presentation creation is still per event | `CombatFeedbackPresenter` |
| World HP/reload bars | `WorldHealthBarsController`, scanner/factory/record/anchor modules | Tank discovery, BillboardGui creation, smoothed HP/reload display | This area is already partially split; future risk is discovery and UI churn | `WorldBarsPresenter` with existing modules |
| Aim laser | `WOBAimLaser.client.luau` | Client visual laser, cached obstacle collection, smoothing, muzzle refresh | Mostly presentation-owned now; should stay isolated from shooting logic | `AimLaserVisual` |
| Wallet | `PlayerWalletService.luau` | DataStore/in-memory fallback, balances, signed pending deltas, add/spend/save | Correctness-sensitive economy code should not absorb Arena reward/revive rules | `PlayerWalletService` as storage boundary, `ArenaRewardService` / `ArenaReviveService` as callers |
| Persistent stats | Stats/profile modules, `WOBPlayableShell.client.luau`, server stats providers | Profile defaults, request stats, UI result/stats text | Stats formatting/UI can drift from profile/storage ownership | `StatsService` boundary, `CompactStatsFormatter`, shell presenter |
| HUD overlays | `WOBBattleArenaOverlay.client.luau`, `WOBPlayableShell.client.luau`, `WOBDuelHudOverlay.client.luau`, `BattleArenaUpgradeHud.luau` | Mode HUD, death panel, upgrade choice, stats/result popups, wallet state | Client files mix UI construction, data binding, remote calls, and layout rules | `ModeHudRouter`, mode presenters, `DeathPanelPresenter`, `UpgradeChoicePresenter` |
| Templates / Studio-owned place assets | `RicochetTanksPrototype.rbxlx`, `BaseTankTemplate`, Rojo source files | Scene data, templates, prebaked ArmorZones, code/config via Rojo | Some important data is Studio-owned and not obvious from code-only reads | Documentation plus careful template ownership checklist |

## 3. God Script Audit

| File | Current Mixed Responsibilities | Why It Is Risky | What To Extract | Priority | Risk Level |
| --- | --- | --- | --- | --- | --- |
| `src/ServerScriptService/Server/Gameplay/Arena/ArenaCombatService.luau` | Arena sessions, player/bot Arena attributes, XP/level, upgrade offers, upgrade application, shield state, rewards, revive/free respawn, respawn, death summaries, POIs/medkits/supply/control/survival XP, bot session linkage | Any new Arena feature increases the chance of breaking revive, rewards, upgrades, or death flow. It is the main pressure point for future branches | `ArenaSessionRepository`, `ArenaLevelService`, `ArenaUpgradeService`, `ArenaReviveService`, `ArenaRewardService`, `ArenaRunService`, `ArenaSpawnService` | P0 | High |
| `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau` | Remote creation, participant spawning, tank setup, movement parameters, damage/death flow, recoil, combat feedback, debug bot remotes, player lifecycle, main Heartbeat update, input/shoot routing | Mode-specific logic and shared tank gameplay live together. Arena changes can accidentally affect Duel/Training | `GameModeService`, `TrainingMode`, `DuelMode`, `BattleArenaMode`, shared `TankSpawnService`, remote registry helper | P0 | High |
| `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau` | Shot cooldown checks, shot pattern, projectile parts/trails, projectile simulation, raycasts, hit feedback, muzzle obstruction checks, VFX toggles, cleanup | Gameplay correctness and presentation performance are coupled. VFX pooling later is harder while visuals live inside simulation | `ProjectileGameplayService`, `ProjectileEventService`, `ProjectileVfxAdapter`, later `VfxPool` | P1 | High |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau` | Arena HUD creation, mobile/desktop layout, wallet display, death panel, revive/free respawn/return buttons, upgrade choice remote binding, health/stats state, menu popup | Client UI changes can break death options or upgrade display. Hard to test individual panels | `BattleArenaHudPresenter`, `BattleArenaDeathPanel`, `UpgradeChoicePresenter`, `ModeHudRouter` coordinator | P1 | Medium-High |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBPlayableShell.client.luau` | Main menu, lobby buttons, result popup, stats popup, settings popup, runtime stats, result stats formatting, start/rematch/return flow | Shell is still the main catch-all for lobby and result UI. Popup fixes are fragile because layout and data binding are together | `LobbyHudPresenter`, `StatsPopupPresenter`, `ResultPanelPresenter`, shared UI primitives | P2 | Medium |
| `src/ServerScriptService/Server/Gameplay/Bots/BotService.luau` | Desired bot count, spawn records, activation/deactivation, spawn staggering, bot model lifecycle, respawn updates, per-frame bot update delegation | Safer after spawn staggering, but Arena count/direction policy should not be tied to low-level bot lifecycle | `ArenaBotDirector` for Arena policy, keep bot lifecycle/brain modules below it | P2 | Medium |
| `src/ServerScriptService/Server/Services/PlayerWalletService.luau` | DataStore reads/writes, in-memory fallback, loaded/session balances, signed pending deltas, add/get/spend API, player attributes | Economy is correctness-sensitive. It should remain a storage boundary and not absorb Arena reward/revive rules | Keep as wallet boundary; extract reward/revive policy out of callers, add tests/checklist around signed deltas | P1 | Medium-High |
| `src/StarterPlayer/StarterPlayerScripts/Client/Hud/WorldHealthBars/*` | Discovery, anchors, records, factory, controller, config | This is already split well. Remaining risk is discovery/recreation cost and hidden UI blocking if future changes bypass modules | Keep current split; add presenter boundary only if HUD routing grows | P3 | Low-Medium |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau` | Visual laser anchors, cached obstacle discovery, muzzle refresh, smoothing, visibility | Mostly isolated and recently improved. Risk comes from tying visual smoothing to actual aim/shooting in future | Keep as `AimLaserVisual`; do not move server aim logic into it | P3 | Low |
| Combat feedback / damage flash / projectile readability overlays | Floating text, hit flashes, projectile readability effects, event presentation, object creation/cleanup | Presentation object churn is a known later optimization target. Gameplay events should remain separate | `CombatFeedbackPresenter`, `DamageFlashPresenter`, `ProjectileReadabilityPresenter`, later `VfxPool` | P2 | Medium |

## 4. Target Architecture

The target should stay practical for Roblox/Rojo:

- Server gameplay modules live under `ServerScriptService/Server`.
- Client presenters/controllers live under `StarterPlayerScripts/Client`.
- Shared configs/catalogs live under `ReplicatedStorage/Shared`.
- Rojo is the source of truth for code/config.
- Studio-owned template/scene data may remain in `RicochetTanksPrototype.rbxlx` until explicitly migrated.
- Existing remotes should stay stable until a replacement protocol is fully staged.

### Server Modules

| Module | Responsibility | Inputs | Outputs / Events | Must Not Know |
| --- | --- | --- | --- | --- |
| `GameModeService` / `ModeRouter` | Route players into Lobby, Training, Duel, or BattleArena and dispatch mode lifecycle calls | Start/return/rematch remotes, player state | Calls mode modules; sets high-level mode state | Upgrade math, HUD layout, projectile details |
| `LobbyMode` / `LobbyService` cleanup | Own lobby entry/exit state and lobby spawn/menu flow | Player, return-to-lobby request | Lobby state, lobby spawn placement | Duel/Arena internals |
| `TrainingMode` | Own Training start/death/respawn rules | Player start request, tank spawn helpers | Training participant lifecycle | Arena upgrades/revive/rewards |
| `DuelMode` | Own Duel rules and result flow | Duel start/rematch requests, participants | Duel lifecycle and winner/result state | Arena progression, Bolts revive |
| `BattleArenaMode` | High-level coordinator for Arena run services | Player enter/exit, Arena configs | Calls run/level/upgrade/revive/reward/bot services | Low-level projectile simulation, HUD layout |
| `ArenaRunService` | Enter/leave Arena run, alive/dead/revive-pending lifecycle, free respawn starts a new run inside Arena | Player, session repository, spawn service | Session lifecycle changes, respawn calls | Upgrade effect math, wallet internals, HUD layout |
| `ArenaSessionRepository` | Per-player Arena session table, lookup/create/delete, immutable-ish snapshots for UI | Player keys, initial session data | Session records and snapshots | Gameplay decisions |
| `ArenaLevelService` | ArenaXP, ArenaLevel, CoreBuildLevel/MaxUpgradeLevel, post-5 formula, level-up decisions | Session, XP reason/amount, `BattleArenaConfig` | Level-up events, next XP threshold | Upgrade card UI, revive, wallet |
| `ArenaUpgradeService` | Selected upgrade ids, offer generation, stack limits, metadata, calls effect applier | Session, config/catalog, level event | Upgrade offers, applied upgrade result | Death flow, wallet, bot spawning |
| `ArenaReviveService` | Paid revive validation, free respawn validation, revive count, revive pending/final death rules | Session, player, wallet boundary, revive config | Revive/free respawn result, respawn request | HUD layout, wallet storage details, projectile logic |
| `ArenaRewardService` | Bot kill rewards, ricochet/self-hit rewards, future post-5 rewards, reward reason strings | Kill/event summary, session, config | Calls wallet boundary, reward event/snapshot | Wallet internals, upgrade selection |
| `ArenaBotDirector` | Desired bot count, staggered spawn policy, bot lifecycle decisions, future device/profile bot cap | Arena state, config, player count/perf profile | Calls `BotService` spawn/despawn/update policy | Bot brain internals, wallet, ArenaLevel |
| `ArenaSpawnService` | Safe Arena spawn selection and tank placement rules | Player/bot, spawn context, arena scene refs | Spawn CFrame/model placement | Upgrade math, wallet, HUD |
| `ProjectileGameplayService` | Projectile simulation, raycast/update, hit event production | Shoot requests, tank state, projectile config | Hit events, projectile lifecycle events | Floating text UI, VFX object creation |
| `ProjectileEventService` / `CombatEventService` | Normalize gameplay events for feedback/reward/VFX consumers | Hit events, damage events, reflect events | Remote payloads, server-side event signals | UI construction, wallet storage |
| Wallet boundary / `PlayerWalletService` cleanup | Store and mutate player currencies safely | Add/spend/get/save calls | Balance attributes, success/failure | Arena reward policy, revive policy |
| `StatsService` boundary | Persistent and run stats ownership | Match/run events, profile data | Stats snapshots for UI | Popup layout |

### Client Modules

| Module | Responsibility | Inputs | Outputs / Events | Must Not Know |
| --- | --- | --- | --- | --- |
| `ModeHudRouter` | Show/hide mode-specific HUD presenters | Current mode attributes/remotes | Presenter activation/deactivation | Server gameplay decisions |
| `BattleArenaHudPresenter` | Coordinate Arena HUD widgets without owning each panel's internals | Arena attributes, wallet state, remotes | Updates Arena HUD views | Upgrade effect math, wallet storage |
| `UpgradeChoicePresenter` | Render upgrade choices and bind selected id to the existing remote | Upgrade offer payload, `UpgradeIconConfig` | Upgrade choice request | Server offer rules |
| `DeathPanelPresenter` | Render paid revive, free respawn, and exit states | Death state snapshot, balance, revive config | Revive/free respawn/exit requests | Server validation, wallet mutation |
| `CombatFeedbackPresenter` | Render floating combat text and later pool text labels | Combat feedback remote payloads | Visual feedback only | Damage rules |
| `WorldBarsPresenter` | Own world HP/reload bar presenter lifecycle using existing modules | Tank discovery/config/remotes if needed | Billboard updates | Health/damage authority |
| `AimLaserVisual` | Own visual-only aim laser and smoothing | Local tank/muzzle/camera/obstacle cache | Visual laser parts | Actual shot direction authority |
| `LobbyHudPresenter` / `TrainingHudPresenter` / `DuelHudPresenter` | Mode-specific UI presentation | Mode state and existing remotes | UI updates and user requests | Other modes' internal rules |

### Shared Modules

| Module | Responsibility | Inputs | Outputs / Events | Must Not Know |
| --- | --- | --- | --- | --- |
| `BattleArenaConfig` | Arena tuning, level caps/formula, revive defaults, current compatibility fields | Design tuning | Frozen config tables | Runtime player state |
| `UpgradeCatalog` | Upgrade metadata by id | Existing pool data, future branch metadata | Upgrade records | Effect implementation details |
| `UpgradeBranchConfig` | Movement/Shooting/Defense/Vampire/Ricochet branch definitions | Design tuning | Branch metadata | Runtime offer state |
| `UpgradeOfferRules` | Pure data/rules for offer eligibility | Catalog fields | Rule constants/helpers | UI and player wallet |
| `ReviveConfig` | Revive/free respawn tuning | Design tuning | Costs, caps, HP percent | Wallet implementation |
| `HudConfig` | Presentation tuning and toggles | Design tuning | UI sizes, world bars, display toggles | Gameplay outcomes |
| `PerformanceConfig` | Diagnostic/presentation toggles | Test/perf tuning | World bars/VFX/bot overrides | Balance decisions |

## 5. BattleArena Refactor Target

BattleArena is the priority because it is the fastest-growing mode and the planned branches all depend on cleaner run, level, upgrade, revive, reward, and bot boundaries.

Implementation note: R1 has been completed as a behavior-preserving storage extraction. `ArenaSessionRepository.luau` now owns the player/participant session maps and safe lookup/removal helpers; `ArenaCombatService.luau` still owns the current session data shape and all Arena behavior.

Implementation note: R2 has been completed as a behavior-preserving progression extraction. `ArenaLevelService.luau` now owns XP addition, level thresholds, max Arena level, max upgrade level, level-up detection, and level-based upgrade eligibility. `ArenaCombatService.luau` still owns upgrade offer creation, remotes, rewards, revive/free respawn, and publishing player attributes. The next recommended extraction is `ArenaReviveService`.

Implementation note: R3 has been completed as a behavior-preserving revive extraction. `ArenaReviveService.luau` now owns revive/free-respawn config reads, eligibility, pending flags, revive cost/HP restore values, affordability checks, paid revive wallet consumption, and revive/free-respawn request validation results. `ArenaCombatService.luau` still owns death orchestration, run reset, respawn, rewards, remotes, and attribute publishing. The next recommended extraction is `ArenaRewardService`.

Implementation note: R4 has been completed as a behavior-preserving reward extraction. `ArenaRewardService.luau` now owns Arena run summary text, player kill score calculation, bot-kill Bolts reward calculation, reward reason strings, and Bolts application through the existing wallet boundary. `ArenaCombatService.luau` still decides when death/kill reward handling runs and still owns XP, kill/streak mutation ordering, death orchestration, remotes, and attribute publishing. The next recommended extraction is `ArenaUpgradeService`.

Implementation note: R5 has been completed as a narrower behavior-preserving offer extraction. `ArenaUpgradeOfferService.luau` now owns active upgrade candidate eligibility, offer card payload creation, random choice selection, pending offer state helpers, and offered-choice validation. `ArenaCombatService.luau` still decides when to show offers, still fires the existing upgrade remote, and still owns upgrade effect application. The next recommended extraction is `ArenaUpgradeEffectApplier`.

Implementation note: R6 has been completed as a behavior-preserving upgrade effect extraction. `ArenaUpgradeEffectApplier.luau` now owns selected upgrade effect application, session modifier recalculation, `Repair` healing, `ReflectShield` upgrade charges, and upgrade-related participant/model attributes. `ArenaCombatService.luau` still handles upgrade choice remotes, accepted-choice orchestration, HUD attribute publishing, and all non-upgrade Arena flow. The next recommended extraction is `BattleArenaDeathPanel` / `DeathPanelPresenter`.

### ArenaRunService

Owns:

- Entering and leaving a BattleArena run.
- Run lifecycle.
- Alive/dead/revive-pending state.
- Free respawn starting a new run inside BattleArena.
- Calling spawn/respawn helpers through a narrow spawn boundary.

Must not own:

- Upgrade effect math.
- Wallet spending.
- HUD layout.
- Projectile collision.

### ArenaSessionRepository

Owns:

- Per-player Arena session table.
- Safe lookup / create / delete.
- Session snapshots for UI and logging.
- A single place to define the session shape.

Must not own:

- Gameplay decisions.
- Upgrade/revive/reward policy.

### ArenaLevelService

Owns:

- ArenaXP.
- ArenaLevel.
- CoreBuildLevel / MaxUpgradeLevel.
- Post-5 level formula.
- Level-up events and next-threshold calculations.

Must not own:

- Upgrade card UI.
- Revive.
- Wallet.

### ArenaUpgradeService

Owns:

- Selected upgrade ids and stack counts.
- Upgrade offer generation.
- Upgrade tags/branches/rarity later.
- Applying upgrade effects through a separate effect applier.
- Compatibility with current active `BattleArenaConfig.UpgradePool`.

Must not own:

- Death flow.
- Wallet.
- Bot spawning.

### ArenaReviveService

Owns:

- Paid revive validation.
- Free respawn validation.
- Revive count.
- Revive pending/final death rules.
- Calling wallet spend through a wallet boundary.
- Returning a result object the run service can apply.

Must not own:

- HUD layout.
- Actual wallet storage.
- Projectile/damage logic.

### ArenaRewardService

Owns:

- Rewards for bot kills.
- Ricochet/self-hit reward reasons.
- Future post-5 rewards.
- Reward reason strings and reward snapshots.

Must not own:

- Wallet internals.
- Upgrade selection.

### ArenaBotDirector

Owns:

- Desired bot count.
- Staggered spawning.
- Bot lifecycle decisions at Arena policy level.
- Future device/profile bot cap.

Must not own:

- Bot brain internals.
- Arena level/revive/wallet.

## 6. Upgrade System Refactor Target

Future build branches:

- Movement.
- Shooting.
- Defense.
- Vampire.
- Ricochet.

Do not implement or activate new branches during the architecture refactor. The target is to prepare metadata and ownership so future branches do not have to be wedged into `ArenaCombatService`.

Future shared catalog shape:

```lua
UpgradeCatalog = {
	[UpgradeId] = {
		Title = "...",
		Description = "...",
		Branch = "Shooting",
		Tags = { "Damage" },
		Rarity = "Common",
		MaxStacks = 3,
		RequiresUpgrade = nil,
		BlocksUpgrade = nil,
		MinArenaLevel = 1,
		MaxOfferLevel = 5,
		Enabled = true,
		FutureOnly = false,
		IconIdKey = "DamageUp",
	},
}
```

Server-side target:

- `UpgradeOfferService`: chooses legal offers from the catalog based on session state.
- `UpgradeEffectApplier`: applies chosen upgrades to session modifiers or tank state through explicit handlers.
- Optional effect handlers later:
  - `DamageUpgradeEffect`.
  - `FireRateUpgradeEffect`.
  - `MovementUpgradeEffect`.
  - `DefenseUpgradeEffect`.
  - `RicochetUpgradeEffect`.
  - `VampireUpgradeEffect` later, disabled until gameplay exists.

Migration strategy:

- Keep current `BattleArenaConfig.UpgradePool` working.
- Add metadata gradually without changing active behavior.
- Treat `FutureOnly` upgrades as design data only until their effect exists.
- Preserve all existing `UpgradeIconConfig` asset ids.
- Preserve current upgrade choice remote protocol until server and client migration is complete.
- Move offer generation first, then effect application, then branch-specific metadata.
- Keep active upgrade ids stable: `DamageUp`, `FireRateUp`, `MoveSpeedUp`, `DoubleShot`, `TripleSpread`, `RicochetUp`, `Repair`, `ReflectShield`.

## 7. Death / Revive Flow Refactor Target

Current BattleArena flow:

- Death enters a death choice state.
- Paid revive costs Bolts and keeps ArenaLevel, XP, selected upgrades, score/session stats, and modifiers.
- Free respawn costs 0 Bolts, stays in BattleArena, and resets run powers/progression.
- Exit/return sends the player back to Lobby as fallback.

Target state model:

- `Alive`.
- `Downed`.
- `RevivePending`.
- `FreeRespawnPending`.
- `Exited`.

Target ownership:

- Server owns the authoritative death state.
- Client only presents available options.
- Paid revive request validates server-side:
  - player is in BattleArena;
  - session exists;
  - session is in a valid death/revive-pending state;
  - revive count is below cap;
  - wallet spend succeeds.
- Free respawn request validates server-side:
  - player is in BattleArena;
  - session exists;
  - player is in a valid death state;
  - free respawn is enabled.
- Lobby exit request stays separate from free respawn.

Do not change behavior now. Extract the current behavior behind an `ArenaReviveService` only after session access is isolated.

## 8. HUD / Presenter Split

Current HUD files:

- `WOBBattleArenaOverlay.client.luau`: BattleArena HUD, death panel, revive/free respawn buttons, upgrade choice binding, wallet display, layout.
- `BattleArenaUpgradeHud.luau`: upgrade card/template rendering and ImageLabel icon binding.
- `WOBDuelHudOverlay.client.luau`: Duel HUD.
- `WOBPlayableShell.client.luau`: lobby/start menu, stats popup, result popup, settings popup, runtime stats.
- `CompactStatsFormatter.luau`: result/stats text formatting.
- `WorldHealthBars` modules: world HP/reload bar presentation.
- `WOBAimLaser.client.luau`: visual aim laser.
- Combat feedback overlays: floating text, damage flash, projectile readability.

Target:

- Views create UI only.
- Presenters bind data and remotes.
- Client controllers do not decide gameplay.
- Mode-specific presenters own mode-specific display:
  - `LobbyHudPresenter`.
  - `TrainingHudPresenter`.
  - `DuelHudPresenter`.
  - `BattleArenaHudPresenter`.
  - `DeathPanelPresenter`.
  - `UpgradeChoicePresenter`.

Extraction plan:

1. Extract death panel creation and state binding into a `BattleArenaDeathPanel` module.
2. Extract upgrade choice card binding into `UpgradeChoicePresenter` while keeping `BattleArenaUpgradeHud` as the card/template helper.
3. Keep `WOBBattleArenaOverlay.client.luau` as the coordinator temporarily.
4. Later split a mode HUD router once Lobby/Training/Duel/Arena presenters have stable boundaries.

## 9. Projectile / VFX Separation

Current risk:

- `ProjectileService` mixes projectile lifecycle, shot pattern, raycast/hit resolve, readability/VFX hooks, projectile part/trail creation, and feedback payloads.
- VFX/object churn remains a known later optimization area.
- Server-side cosmetic VFX can create replication cost if more effects are added.
- Client overlays create objects per event and should eventually pool them.

Target:

- `ProjectileGameplayService` owns only projectile simulation and hit event production.
- `ProjectileEventService` or `CombatEventService` normalizes damage/ricochet/reflect/self-hit events.
- `ProjectileVisualService` or client `ProjectileVfxPresenter` owns presentation.
- `CombatFeedbackPresenter` owns floating text pooling later.
- `VfxPool` is a later optimization, not the first extraction.

Migration steps:

1. Introduce an event boundary while keeping current behavior.
2. Move presentation calls behind adapters.
3. Verify projectile collision/damage/ricochet behavior is unchanged.
4. Only then add pooling for combat text, impact VFX, muzzle flashes, and projectile readability visuals.

## 10. Studio-Owned Assets and Rojo Source of Truth

Current rule:

- Code/config source of truth is the Rojo repo.
- Some scene/template data is still Studio-owned.
- `RicochetTanksPrototype.rbxlx` contains important scene/template data.
- `BaseTankTemplate` ArmorZones are prebaked in the Studio place/template.
- ArmorZones naming must not be changed casually.
- Legacy scripts inside the Studio place must remain disabled/removed carefully and should not drive new work.
- Old snapshots should not override current Rojo source files.

Checklist before touching `.rbxlx`:

1. Make a checkpoint/commit first.
2. Know the exact Explorer path being changed.
3. Know whether the change is template, scene, UI, or script ownership.
4. Confirm whether Rojo already owns the equivalent code/config.
5. Run a Studio Play test.
6. Run `rojo build` after code/config changes.
7. Update docs when template ownership changes.

## 11. Cleanup Plan Before Refactor

### Phase C0 — Preserve current behavior

- Ensure the current work is checkpointed.
- Verify README files point to `docs/DOCS_INDEX.md`.
- Verify current state and cleanup docs are tracked.
- Do not start refactor work until the playable baseline is known.

### Phase C1 — Studio duplicate verification

- Check old `WOBGameplayServer` / `WOBPerformanceServer` scripts in Studio are disabled or removed.
- Check old root `StarterPlayerScripts` scripts.
- Do not delete yet unless there is a separate confirmed cleanup task.

### Phase C2 — Docs hygiene

- Mark old docs historical where needed.
- Keep `docs/DOCS_INDEX.md` current.
- Do not delete old docs yet.

### Phase C3 — Root/temp hygiene

- Inspect root duplicate/reference files.
- Inspect suspicious `.rbxl` / `.rbxlx` snapshots.
- Propose archive/delete plan.
- No deletion without confirmation.

### Phase C4 — Architecture refactor preparation

- Add a manual playtest checklist for Lobby, Training, Duel, BattleArena, revive, free respawn, upgrade icons, mobile controls.
- Freeze core expected behavior before extracting services.
- Keep refactor tasks small enough to roll back.

## 12. Refactor Roadmap

| Phase | Goal | Files Likely Touched | Risk Level | Validation | Rollback Plan | What Not To Touch |
| --- | --- | --- | --- | --- | --- | --- |
| R1 — Extract `ArenaSessionRepository` | Isolate session table access and define session shape. Behavior change: none | New server module under Arena; `ArenaCombatService.luau` call sites | Medium | BattleArena starts; paid revive/free respawn; upgrades; bot kills; `rojo build`; diff check | Revert new module and call-site changes | Duel, Training, wallet internals, projectile logic, upgrade effects |
| R2 — Extract `ArenaLevelService` | Isolate XP/level/post-5 logic. Behavior change: none | New Arena level module; `ArenaCombatService.luau`; possibly tests/docs | Medium | Level 1-5 upgrade offers; post-5 levels continue; no infinite full-power offers; build | Revert level module and restore inline helpers | Upgrade effects, HUD layout, Duel |
| R3 — Extract `ArenaReviveService` | Isolate paid revive/free respawn/death pending validation. Behavior change: none | New revive module; `ArenaCombatService.luau`; wallet boundary calls remain same | Medium-High | Paid revive spends 5; free respawn resets powers; exit to Lobby; no Duel revive; build | Revert revive module and restore current ArenaCombatService flow | Wallet storage semantics, remotes, Duel/Training death flow |
| R4 — Extract `ArenaRewardService` | Isolate Bolts rewards and reward reason strings. Behavior change: none | New reward module; `ArenaCombatService.luau`; `PlayerWalletService` callers | Medium | Bot kill rewards; ricochet/self-hit rewards; wallet deltas persist; build | Revert reward module and restore inline calls | Wallet internals, DataStore design, reward amounts |
| R5 — Extract `ArenaUpgradeService` / `UpgradeCatalog` | Prepare branches without activating new gameplay. Behavior change: none or minimal | New shared catalog/module; `BattleArenaConfig`; `ArenaCombatService`; `BattleArenaUpgradeHud` only if metadata key needed | High | Existing upgrade ids/effects/icons; mobile icons; no Vampire active; build | Revert catalog/service and keep current UpgradePool | `UpgradeIconConfig` asset ids, active effects, protocol unless staged |
| R6 — Extract `DeathPanelPresenter` | Client UI cleanup. Behavior change: none | New client module; `WOBBattleArenaOverlay.client.luau` | Low-Medium | Death panel states; paid revive; free respawn; exit; mobile layout | Revert presenter and restore inline panel code | Server revive logic, wallet, UpgradeIconConfig |
| R7 — Projectile/VFX event boundary | Prepare VFX pooling later. Behavior change: none | `ProjectileService.luau`, new event/adapter module, client VFX presenters | High | Projectile collision, damage, ricochet, reflect, feedback text, build | Revert adapter and inline calls | Damage math, collision rules, shot cooldown, Duel |
| R8 — BotDirector cleanup | Isolate desired bot count/stagger from BotService lifecycle. Behavior change: none | New `ArenaBotDirector`; `BotService.luau`; `ArenaCombatService.luau` | Medium | BattleArena bot spawn staggering; bot cap; no entry stutter regression; build | Revert director and restore current calls | Bot brain behavior, target logic, movement decisions |

## 13. First Three Recommended Implementation Tasks

### 1. Extract ArenaSessionRepository

Codex-ready prompt:

```text
Task: Extract ArenaSessionRepository without behavior changes.

Goal:
Move BattleArena per-player session table access out of ArenaCombatService into a new server module.

Rules:
- Do not change gameplay behavior.
- Do not change Duel, Training, movement, shooting, projectile collision, damage, bot behavior, wallet, remotes, or UpgradeIconConfig asset ids.
- Keep paid revive and free respawn behavior identical.
- Keep current session fields and defaults identical.

Implementation:
- Add ArenaSessionRepository under Server/Gameplay/Arena.
- Move only session create/get/delete/snapshot helpers.
- Update ArenaCombatService to call repository helpers.
- Do not move level, upgrade, reward, or revive logic yet.

Validation:
- git diff --check
- rojo build default.project.json --output /tmp/wob-arena-session-repository.rbxm
- grep -R "<<<<<<<\|=======\|>>>>>>>" -n src docs --exclude-dir=.git
- Manual: BattleArena starts, upgrade choice works, paid revive works, free respawn works, exit to Lobby works.
```

### 2. Extract ArenaLevelService

Codex-ready prompt:

```text
Task: Extract ArenaLevelService without behavior changes.

Goal:
Move BattleArena XP, ArenaLevel, CoreBuildLevel/MaxUpgradeLevel, and post-5 threshold logic out of ArenaCombatService.

Rules:
- Do not change upgrade effects.
- Do not change offer timing or active UpgradePool.
- Do not change Duel/Training.
- Do not change HUD layout or remotes.
- Do not change BattleArenaConfig values unless only adding comments/docs.

Implementation:
- Add ArenaLevelService under Server/Gameplay/Arena.
- Preserve current XP thresholds and post-5 behavior exactly.
- Return explicit results for level changed / should offer upgrade.
- Keep ArenaCombatService as coordinator.

Validation:
- git diff --check
- rojo build default.project.json --output /tmp/wob-arena-level-service.rbxm
- grep -R "<<<<<<<\|=======\|>>>>>>>" -n src docs --exclude-dir=.git
- Manual: levels 1-5 still grant upgrade offers, post-5 levels continue without infinite full-power upgrade offers.
```

### 3. Extract ArenaReviveService

Codex-ready prompt:

```text
Task: Extract ArenaReviveService without behavior changes.

Goal:
Move BattleArena paid revive, free respawn, revive count, and death-pending validation out of ArenaCombatService.

Rules:
- Do not change wallet spend/save semantics.
- Do not change revive cost, max revives, HP restore percent, or free respawn reset behavior.
- Do not change Duel or Training death flow.
- Do not change remotes.
- Do not change movement, shooting, projectile collision, damage, upgrades, bot behavior, or HUD layout.

Implementation:
- Add ArenaReviveService under Server/Gameplay/Arena.
- Keep current ArenaReviveRequestEvent and ArenaFreeRespawnRequestEvent paths.
- Server validation must remain at least as strict as current behavior.
- ArenaCombatService remains coordinator for actual tank respawn until ArenaRunService exists.

Validation:
- git diff --check
- rojo build default.project.json --output /tmp/wob-arena-revive-service.rbxm
- grep -R "<<<<<<<\|=======\|>>>>>>>" -n src docs --exclude-dir=.git
- Manual: paid revive spends 5 Bolts and preserves build; free respawn spends 0 and resets powers; max revives still disables paid path; exit returns to Lobby; Duel unchanged.
```

## 14. Do Not Do Yet

- Do not add Vampire gameplay yet.
- Do not add King/Pedestal gameplay yet.
- Do not add full upgrade branches yet.
- Do not rewrite `WOBGameplayServer.server.luau` in one pass.
- Do not rewrite `ArenaCombatService.luau` in one pass.
- Do not touch Duel balance.
- Do not delete old docs/root files casually.
- Do not move Studio-owned templates blindly.
- Do not change `UpgradeIconConfig` asset ids.
- Do not change movement, shooting, projectile collision, damage, armor, ricochet, shield, or bot behavior during architecture extraction.
- Do not change wallet spend/save behavior while extracting Arena services.
