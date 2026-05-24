# Performance Runtime Deep Dive

> Scope: investigation + safe recommendations + tiny diagnostic improvements only.
> This pass changes **no** gameplay balance, Duel rules, remotes, damage, shooting,
> projectile collision, movement, upgrade effects, tank controls, or `UpgradeIconConfig`
> asset ids. It does not add King/Pedestal/Vampire gameplay and does not rewrite systems.
>
> Companion document: `docs/PERFORMANCE_FREEZE_AUDIT.md` (earlier pass that added the
> diagnostic toggles referenced throughout). This document goes deeper into *why* and
> *where* the runtime cost concentrates.

## 1. Executive Summary

The freeze is almost certainly **cumulative**, not a single runaway loop. The steady-state
per-frame cost is reasonable: there is exactly one server `Heartbeat` connection, the lobby
pad poll and arena tick are throttled by accumulators, bot decisions are throttled to
`~0.15s`, and obstacle parts are cached. None of these alone explains a freeze.

The freeze most likely appears as a **frame spike concentrated at one moment**, and the
strongest candidate is **BattleArena entry**. The probable causes, in priority order:

1. **Arena-entry spawn spike (highest).** When the first player enters the Arena,
   `BotService.update` → `ensureBotCount` synchronously spawns *all* desired bots in a
   single Heartbeat frame. Each bot spawn clones a tank template, runs descendant scans,
   creates/welds up to four armor parts if the template lacks them, applies skin, and
   registers the participant. Simultaneously, every new `BasePart` fires
   `WOBPerformanceServer`'s `DescendantAdded` handler, and the client world-bars discovery
   scan picks up the new models. Several systems do their heaviest work on the same frame.

2. **Per-shot / per-hit VFX instance churn (medium).** Each projectile creates ~5 instances
   (Part + PointLight + 2 Attachments + Trail) at fire time with no pooling; muzzle, impact,
   ricochet, reflect, death, and burn effects each create more parts/lights or clone
   templates per event. Cleanup is guaranteed via `Debris`/`Destroy`, but sustained heavy
   combat causes instance creation/GC churn and replication traffic — micro-stutter that
   compounds with the entry spike.

3. **Duplicate legacy scripts in the live Studio place (medium, unverified).** The checked
   `.rbxlx` shows the legacy Studio-owned servers `Disabled=true`, but this can only be
   confirmed inside the exact Studio place used for Play. A second active
   `WOBGameplayServer` would double every per-frame cost above and would by itself produce a
   freeze. **This must be ruled out manually before deeper optimization.**

Lower-priority contributors: world-bars discovery `GetDescendants` over the whole
`BattleArena` folder every interval; per-frame `Blockcast` per moving tank; multiple client
`RenderStepped` overlays. These are normal costs that become visible only under the spike.

**What to test first:** enter the Arena with `BattleArenaBotsEnabled=false`. If the freeze
disappears, the entry/bot-spawn spike is confirmed as the dominant cause.

## 2. Runtime Systems Inventory

| System | Files | Runs On | Update Mechanism | Creates Instances? | Uses Raycast? | Uses GetDescendants? | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BotService | `Server/Gameplay/Bots/BotService.luau` | Server | Called from main Heartbeat (`BotService.update`) | Yes — spawns bot tanks via TankFactory (clone) on demand | No (delegates) | Indirect (via spawn) | **High** — spawns all desired bots in one frame |
| BotBrain | `Server/Gameplay/Bots/BotBrain.luau` | Server | Pure decision fn, called per bot at `~TickRate` | No | No | No | Low — pure math |
| BotController | `Server/Gameplay/Bots/BotController.luau` | Server | Per active bot, every frame (`:Update`) | No | Indirect (movement Blockcast) | No | Medium — per-frame movement+layout per bot |
| BotTargeting | `Server/Gameplay/Bots/BotTargeting.luau` | Server | Per bot at `~TickRate` (`FindClosestTarget`) | No | No | Yes (`findBasePart` fallback) | Low–Med — O(participants) scan per bot tick |
| ArenaCombatService | `Server/Gameplay/Arena/ArenaCombatService.luau` | Server | Heartbeat (`update`), accumulator-throttled | Yes — sessions, shields, upgrade payloads (not per frame) | No | Yes (spawn part discovery) | Medium — heavy on enter/upgrade, throttled steady-state |
| ProjectileService | `Server/Gameplay/Projectiles/ProjectileService.luau` | Server | Heartbeat (`updateProjectiles`), per projectile | **Yes — 5 instances/shot + VFX** | **Yes — 1 swept ray/projectile/frame** | Yes (init/target gather) | **High** under sustained fire |
| CombatVfxService | `Server/Gameplay/VFX/CombatVfxService.luau` | Server | Event-driven (per VFX call) | **Yes — clones template per effect** | No | Yes (per clone sanitize/pivot) | Medium — per-event clone, Debris cleanup |
| WOBProjectileReadabilityOverlay | `Client/WOBProjectileReadabilityOverlay.client.luau` | Client | RenderStepped | Yes — ground glow part per projectile | No | Yes (1) | Medium — per-frame move of glow parts |
| WOBImpactFeedbackOverlay | `Client/WOBImpactFeedbackOverlay.client.luau` | Client | Per-impact spawned RenderStepped:Wait loop | Yes — pulse parts per impact | No | Yes (1) | Low–Med — short-lived per impact |
| WOBCombatFeedbackOverlay | `Client/WOBCombatFeedbackOverlay.client.luau` | Client | RenderStepped while messages exist | **Yes — billboard/TextLabel per message** | No | No | Medium — no pooling of combat text |
| WOBTankDamageFlash | `Client/WOBTankDamageFlash.client.luau` | Client | `task.spawn` discovery loop (~0.5s) + highlights | Yes — Highlight per tank | No | Yes (2) | Medium — discovery scan + highlight churn |
| WorldHealthBarsController | `Client/WorldHealthBars/WorldHealthBarsController.luau` | Client | Heartbeat `Step` + discovery `task.wait` loop | Yes — billboards once per model | No | Yes (via scanner) | Medium — per-interval full-folder scan |
| WOBTankWorldHealthBars | `Client/WOBTankWorldHealthBars.client.luau` | Client | Bootstrap (7 lines) → controller | No | No | No | Low — thin entry point |
| WOBBattleArenaOverlay | `Client/WOBBattleArenaOverlay.client.luau` | Client | RenderStepped, throttled ~0.1s | Yes — HUD built once | No | No | Low–Med — reads attributes, refresh throttled |
| WOBDuelHudOverlay | `Client/WOBDuelHudOverlay.client.luau` | Client | RenderStepped (2 connections) | Yes — HUD (27 `Instance.new`) built once | No | Yes (1) | Medium — largest client HUD, build-once |
| TankFactory | `Server/Gameplay/Tanks/TankFactory.luau` | Server | On spawn request | **Yes — clones template** | No | Indirect (spawner/armor) | Medium — heavy per spawn, not per frame |
| PlayerTankSpawner | `Server/Gameplay/PlayerTankSpawner.luau` | Server | On spawn (`ensurePhysicalTankModel`) | **Yes — creates missing parts/armor** | No | **Yes (6)** | Medium–High on spawn |
| TankParticipantRegistry | `Server/Gameplay/TankParticipantRegistry.luau` | Server | Event/lookup driven | No (records only) | No | Yes (4) | Low — table bookkeeping |
| LobbyService | `Server/Gameplay/Lobby/LobbyService.luau` | Server | Heartbeat (`update`), pad-poll throttled | Yes — pad visuals (setup) | No | Yes (2) | Low–Med — throttled poll |
| WOBPerformanceServer | `Server/Services/WOBPerformanceServer.server.luau` | Server | Startup + `DescendantAdded` listeners | No | No | **Yes (2 + per-add)** | **Medium** — fires per part added during spawn |
| PlayerWalletService | `Server/Gameplay/Economy/PlayerWalletService.luau` | Server | Event-driven (rewards/spend) | No | No | No | Low |
| PersistentPlayerStatsService | `Server/Gameplay/Stats/PersistentPlayerStatsService.luau` | Server | Event-driven + DataStore | No | No | No | Low–Med (DataStore latency, see §9) |

## 3. Instance Creation Audit

| File | Function | What Is Created | When | Frequency | Cleanup | Risk |
| --- | --- | --- | --- | --- | --- | --- |
| ProjectileService | `createProjectilePart` | Part + PointLight + 2 Attachments + Trail (5) | Per shot fired | High under fire | `destroyProjectile` (`:Destroy`) | **High** — no pooling |
| ProjectileService | `createMuzzleFlashVfx` (+ blast/smoke) | Part(s) + PointLight, or template clone | Per shot | High | `Debris:AddItem` | Medium |
| ProjectileService | `createWallImpactVfx` / `createRicochetVfx` | Part + spark Part + PointLight, or template clone | Per wall hit/ricochet | Med–High | `Debris:AddItem` | Medium |
| ProjectileService | particle container helper (`Instance.new` Part/Attachment/Emitter) | Part + Attachment + ParticleEmitter | Per impact burst | Med | `Debris:AddItem` | Medium |
| CombatVfxService | `playVfxTemplate` | `template:Clone()` + holder Part/Attachment | Per VFX event | Med–High | `Debris:AddItem(lifetime)` | Medium |
| CombatVfxService | `createTemplateHolder` / `playConfiguredSound` | Holder Part + Sound | Per templated effect/sound | Med | `Debris:AddItem` | Low–Med |
| TankFactory | `_getRequestModel` | `templateModel:Clone()` (whole tank) | Per new tank/bot | Spikes on enter | Destroyed on cleanup/leave | **High at spawn** |
| PlayerTankSpawner | `ensurePart` | Part for missing Body/Turret/Barrel/ShootPoint | Per spawn if missing | Only when template incomplete | Lives with tank | Medium |
| PlayerTankSpawner | `ensureHitboxes` | Folder + up to 4 armor Parts | Per spawn if missing | **Every bot spawn if template lacks ArmorZones** | Lives with tank | **High at spawn** |
| TankArmorPartsService | `getOrCreateBodyWeld` | `WeldConstraint` per armor part | Per spawn (Configure) | 4 per tank | Lives with tank | Low–Med |
| WorldHealthBarsController | `CreateGuiFolder` | Folder (GUI) | Once at start | 1 | `Destroy` on stop | Low |
| HealthBarBillboardFactory | bar build (11 `Instance.new`) | BillboardGui + frames/labels | Once per discovered tank | 1/tank | Record `:Destroy` on invalid | Low–Med |
| WOBCombatFeedbackOverlay | message build (5 `Instance.new`) | BillboardGui + TextLabel | **Per combat message** | High | RenderStepped fade then destroy | Medium — no pooling |
| WOBTankDamageFlash | flash build (2 `Instance.new`) | Highlight per tank | Per discovered tank / hit | Med | Managed by record | Medium |
| WOBProjectileReadabilityOverlay | glow build (4 `Instance.new`) | Ground glow Part per projectile | Per projectile (client) | High under fire | Destroyed with projectile | Medium |

**Specific answers:**

- **Are VFX templates pre-created and cloned, or created from scratch at call time?** Both.
  `CombatVfxService.playVfxTemplate` clones a template **from `ReplicatedStorage` at call
  time** (one clone per effect), and `ProjectileService` has procedural `Instance.new`
  fallbacks (muzzle/blast/smoke/impact/spark) that build parts from scratch per event. There
  is **no warm pool**; every effect allocates fresh instances.
- **Are projectile trails/attachments/beams created per shot?** Yes. `createProjectilePart`
  builds the Part, PointLight, two Attachments, and a Trail for **every** projectile.
- **Are impact effects created per hit?** Yes — wall impact, ricochet, reflect, and death
  effects each allocate parts/lights or clone a template per hit.
- **Are BillboardGui/world bars created repeatedly?** No — world bars are built once per
  model and cached in `RecordsByModel`. Combat feedback text **is** created per message
  (no pool).
- **Are armor zones created at runtime every spawn?** Only if the cloned template lacks
  `ArmorZones`/`Hitboxes`. The Studio log line "creates missing ArmorZones" indicates the
  **bot template currently lacks pre-baked armor parts**, so 4 parts + 4 welds are created
  per bot spawn. This is avoidable (see Phase 1).
- **Are bot tank parts cloned/spawned in spikes?** Yes — `BotService.ensureBotCount` spawns
  all desired bots within a single frame; each is a full `templateModel:Clone()`.
- **Is there any pooling?** No object pooling anywhere. Inactive bots **are** reused
  (`activateBotRecord` re-activates an existing record rather than re-cloning), which is the
  one existing reuse path.
- **Is cleanup guaranteed?** For VFX: yes, via `Debris:AddItem` or explicit `Destroy`. For
  projectiles: yes, on hit/expire. For bots: deactivation hides + unregisters but keeps the
  model for reuse.

**Recommendations (documented as separate tasks — not implemented here):**

- Pre-bake `ArmorZones` (4 parts + welds) into the bot/tank templates so
  `ensureHitboxes`/`Configure` find them instead of allocating at spawn.
- Pre-create VFX template clones into a small warm pool keyed by effect; reuse + re-emit
  instead of clone-per-event.
- Pool floating combat text TextLabels and projectile ground glows.
- Keep `Debris` cleanup; add a hard cap on simultaneously active VFX.
- Reduce/disable procedural muzzle/impact lights on mobile via the existing diagnostics
  profile.

## 4. Loop / Tick Audit

| File | Loop Type | Frequency | Work Done | Can Spike? | Recommended Fix | Class |
| --- | --- | --- | --- | --- | --- | --- |
| WOBGameplayServer:1198 | `RunService.Heartbeat` | Every server frame | Drives lobby, player movement, training bots, arena, bots, projectiles | Yes (on enter) | Profile; keep single owner | safe (structure) |
| → LobbyService.update | accumulator (`PAD_POLL_INTERVAL`) | Throttled | Pad overlap polling | Low | none | safe |
| → player movement block | inline, per player tank | Every frame/tank | `resolveTankPose` Blockcast + layout | Low (few players) | none | safe |
| → TrainingBotService.update | called per frame | Every frame | Training dummy logic | Low | monitor | safe |
| → ArenaCombatService.update | accumulators | Throttled (pickup/zone/survival) | Medkits, control zone, survival XP | Low | none | safe |
| → BotService.update | called per frame | Every frame | `ensureBotCount` + per-bot `:Update` | **Yes — spawn burst** | Stagger spawns over frames | **likely freeze source (enter)** |
| → BotController:Update | per active bot | Every frame | decision (throttled) + movement + layout + maybe shoot | Med (per bot) | none needed | needs cache (already throttled) |
| → ProjectileService.updateProjectiles | per projectile | Every frame | swept Blockcast/raycast + hit resolve | Yes (many projectiles) | cap concurrent projectiles (later) | needs throttle/cap |
| BotController:_refreshDecision | accumulator `ThinkElapsed` | `~TickRate` 0.15s | target scan + BotBrain.Decide | Low | none | safe (throttled) |
| TankMovementService obstacle gather | cache (`OBSTACLE_CACHE_SECONDS`) | On cache miss | `GetDescendants` over obstacle roots | Low | none | cached (good) |
| WorldHealthBarsController:Step | `Heartbeat` | Every client frame | anchor-follow update of active records | Low–Med | only update visible tanks | needs cache |
| WorldHealthBarsController:Discover | `task.wait(DISCOVERY_INTERVAL)` | ≥1s | `GetDescendants` over TestObjects + BattleArena | Med | scan less / react to ChildAdded | needs throttle |
| WOBProjectileReadabilityOverlay:176 | `RenderStepped` | Every client frame | moves ground glow parts | Med (many shots) | cap, pool | needs pooling |
| WOBCombatFeedbackOverlay:260 | `RenderStepped` | While messages exist | move/fade combat text billboards | Med | pool text | needs pooling |
| WOBTankDamageFlash | `task.spawn` discovery (~0.5s) | ~0.5s | scan tank roots, manage highlights | Low–Med | reuse highlights | needs cache |
| WOBImpactFeedbackOverlay:279 | per-impact `RenderStepped:Wait` | During impact pulse | animate 2 pulse parts | Low | cap concurrent | safe-ish |
| WOBBattleArenaOverlay:870 | `RenderStepped` throttled ~0.1s | 0.1s | read attributes, update HUD | Low | none | safe |
| WOBDuelHudOverlay:1325/1628 | `RenderStepped` (2) | Every client frame | duel HUD updates | Low–Med | monitor | monitor |
| WOBRoundStatusOverlay:1228 | `RenderStepped` partial throttle | reload/frame, target ~0.2s | HUD + tank target refresh | Low–Med | monitor | monitor |
| WOBMobileControls:935 / WOBTankInputController:353 | `RenderStepped` | Every client frame | input/aim send | Low | do not change (controls) | safe |
| WOBAimLaser:333 | `RenderStepped`, target cache 0.5s | Every frame | aim raycast + laser | Low | do not change (aim) | safe |
| WOBTankLocalTeamVisuals:122 | `Heartbeat` | Every client frame | team color visuals | Low | monitor | safe |
| WOBTankVisualSmoothing:221 | `RenderStepped` | Every client frame | interpolate tank pose | Low–Med | monitor | safe |

**Notable:** there is exactly **one** server `Heartbeat` connection (good architecture). No
`while true do` busy loops were found; the only `while` loop is `WorldHealthBarsController`'s
discovery loop, which yields on `task.wait(DISCOVERY_INTERVAL)`. No `FindFirstChild` or
raycasts were found inside hot per-frame loops without a cache.

## 5. BattleArena Entry Spike Audit

Trigger chain when a player drives onto the Arena pad:

| Step | File/Function | Runtime Work | Risk |
| --- | --- | --- | --- |
| 1. Pad overlap detected | `LobbyService.update` → `updateArenaPadEntries` → `participantIsOnPad` | Pad poll (throttled by `PAD_POLL_INTERVAL`) | Low |
| 2. Enter call | `LobbyService:675` → `ArenaCombatService.EnterArena(player)` | Single call | Low |
| 3. Session + defaults | `EnterArena` → `makeSession`, `setPlayerArenaDefaults`, `resetParticipantArenaModifiers`, attribute writes | Table setup + attribute replication | Low–Med |
| 4. Player tank made visible/reset | `setParticipantModelVisible`, `resetParticipantHealth`, `applySpawnToParticipant` | Layout + visibility, attribute writes | Low–Med |
| 5. Upgrades + shield | `applySessionUpgrades`, `grantSpawnReflectShield` | Attribute publish | Low |
| 6. **Next Heartbeat: bots wanted** | `BotService.update` → `getDesiredBotCount` (now `playerCount>0`) → `ensureBotCount(N)` | **Spawns N bots in ONE frame** | **High** |
| 7. Per bot: clone tank | `TankFactory:SpawnTank` → `_getRequestModel` (`templateModel:Clone()`) | Full model clone per bot | **High** |
| 8. Per bot: ensure parts/armor | `PlayerTankSpawner.ensurePhysicalTankModel` → `ensureHitboxes` | `GetDescendants` scans; **creates 4 armor Parts if template lacks ArmorZones** | **High** |
| 9. Per bot: configure armor | `TankArmorPartsService.Configure` | `GetDescendants`, sizing, 4 `WeldConstraint`s | Medium |
| 10. Per bot: skin | `TankCustomizationService.applySkin` + `TankSkinApplier.Apply` | `GetDescendants` color/material passes | Medium |
| 11. Per bot: register | `registerTankParticipant`, `RegisterBotParticipant`, `captureTankColors` | Registry bookkeeping | Low–Med |
| 12. **Each new part fires shadow handler** | `WOBPerformanceServer` `root.DescendantAdded` → `applyShadowProfile` → `shouldCastShadow` | Runs **per BasePart added** during the clone burst (string match + `IsDescendantOf`) | **Medium (multiplied)** |
| 13. World bars pick up new tanks | `WorldHealthBarsController:Discover` (client, ≤1s later) | `GetDescendants` over `BattleArena`, build billboards for each new tank | Medium |
| 14. Damage-flash discovery picks up tanks | `WOBTankDamageFlash` (~0.5s) | scan + Highlight per tank | Low–Med |
| 15. Bots begin per-frame updates | `BotController:Update` × N | movement Blockcast + layout per bot per frame | Medium (steady) |

**Specific answers:**

- **Are bots spawned all at once?** Yes. `ensureBotCount` loops until the active count meets
  the desired count *within the same `update` call*, so the entire deficit is spawned on one
  frame. With `MaintainMinBots` and `MinBotsSolo` (commonly 2), the first arena entry spawns
  2 bots back-to-back. This is the single biggest controllable spike.
- **Are missing ArmorZones created every time?** Per spawn, `ensureHitboxes` checks and only
  creates what's missing. The Studio log "creates missing ArmorZones" means the **bot
  template lacks pre-baked armor**, so it pays the creation cost on every fresh bot clone
  (not on reuse of an existing record).
- **Can ArmorZones be pre-baked in the tank template instead?** **Yes — recommended.** If the
  bot template carries an `ArmorZones` folder with the four named parts,
  `ensureHitboxes`/`Configure` will find them and skip all `Instance.new`/weld creation,
  removing 8 instance ops per bot from the entry frame. This is a template/asset change, not
  a logic change, so it is safe (no gameplay numbers touched).
- **Are UI/HUD objects created at the same moment?** The big HUDs (`WOBDuelHudOverlay`,
  `WOBBattleArenaOverlay`) build their widgets once and then only update, so they don't
  rebuild on entry. World bars and damage-flash highlights, however, are created for the new
  tanks shortly after entry, overlapping the spawn frame's tail.
- **Does world-bars discovery react to many descendants being added at once?** Indirectly —
  it doesn't listen to `DescendantAdded`; it re-scans `BattleArena` on its interval and
  builds bars for any new tank models found. The cost is the `GetDescendants` over the whole
  folder plus billboard creation, landing within ~1s of the spawn burst.
- **Does WOBPerformanceServer DescendantAdded process every new part during bot spawn?**
  **Yes.** Both `root.DescendantAdded` and `wobRuntime.DescendantAdded` call
  `applyShadowProfile` for every part added. During a 2-bot clone burst (dozens of parts)
  this fires dozens of times on the spawn frame. Each call is cheap (shadows are already off
  in the active `MobileLow` profile, so it sets `CastShadow=false` after a few string
  checks), but it is pure overhead stacked onto the worst frame.

**Conclusion:** the freeze signature — a hitch *on entering the Arena* — is consistent with
spawn + armor creation + skin + registration + shadow-handler fan-out + (slightly later)
world-bars/flash discovery all landing in a narrow window. Staggering bot spawns across
frames and pre-baking armor will flatten the spike without touching gameplay.

## 6. VFX Architecture Review

- **Template-based effects:** muzzle flash, blast, smoke, impact, ricochet, reflect, death,
  burn — each first tries `CombatVfxService.playVfxTemplate` (clone of a template under
  `ReplicatedStorage/Shared/Assets/VFX`).
- **Procedural fallback effects:** when a template is missing/disabled, `ProjectileService`
  builds parts/lights/sparks from scratch (`createMuzzleFlashVfx`, `createWallImpactVfx`,
  `createRicochetVfx`, impact particle container).
- **Missing templates:** any effect whose configured `TemplateName` isn't found logs once
  via `warnOnce` and silently uses the procedural fallback — so a missing template quietly
  shifts cost to per-event `Instance.new`.
- **Created per shot/hit/death:** projectile body (Part+Light+2 Attachments+Trail) per shot;
  muzzle/blast/smoke per shot; impact/ricochet/reflect per hit; death/burn per kill.
- **Client-only effects:** projectile ground glow (`WOBProjectileReadabilityOverlay`), impact
  pulse (`WOBImpactFeedbackOverlay`), floating combat text (`WOBCombatFeedbackOverlay`),
  damage flash highlight (`WOBTankDamageFlash`).
- **Server-side effects:** projectile body, muzzle/impact/ricochet/death VFX, and template
  clones live in the server VFX folder and replicate to all clients.
- **Cleanup:** yes — `Debris:AddItem(lifetime)` for VFX, `Destroy` for projectiles. No leaks
  observed.
- **Caps:** none. There is no limit on concurrent projectiles or active VFX.

**Recommendations:**

- **Pre-create:** warm a small pool of template clones per effect at startup; re-pivot and
  re-emit instead of clone-per-event.
- **Pool:** projectile parts (Part+Trail), floating combat text, ground glows.
- **Client-only:** keep muzzle/impact *visual* sparkle client-side where possible so the
  server doesn't replicate dozens of short-lived parts; the server should own only what's
  gameplay-relevant.
- **Mobile reduce/disable:** drive procedural `PointLight`s, smoke, and ground glow off on
  the `MobileLow` profile (the diagnostics flags already allow this isolation).
- **Should not be spawned by server:** purely cosmetic per-shot lights/sparks — move to
  client or gate by profile.

> Do not implement a full pooling system in this pass. Track it as a dedicated Phase 2 task.

## 7. Bot AI Review

- **How many bots spawn by default?** Governed by `BattleArenaLoopConfig.Bots`
  (`MaintainMinBots`, `MinBotsSolo`, `MinBotsWithPlayers`) bounded by `MaxBots` and
  `Safety.MaxBotsHardLimit`. Earlier audit notes: min 2 solo, 1 with players, max 4, hard
  limit 6. They are created only once a player is in the Arena (`playerCount>0`).
- **How often does each bot choose a target?** At `Brain.TickRate` (`~0.15s`, floored to
  `0.05s`) — decisions are cached between ticks.
- **How often does each bot raycast line-of-sight?** `BotTargeting.FindClosestTarget` does
  **no raycast** — it's a squared-distance scan over arena participants. (LOS raycasting
  lives in `TrainingBotService`, not the arena bot path.)
- **How often does each bot update movement?** Every server frame: `_applyMovement` runs each
  Heartbeat and calls `TankMovementService.resolveTankPose` (one `Blockcast` against cached
  obstacle parts) + `layoutTank`.
- **How often does each bot fire?** At most once per frame when aim tolerance is met
  (`_maybeShoot`), gated by weapon cooldown inside `ProjectileService.tryShoot`.
- **Does a dead/inactive bot still tick?** No — `BotController:IsAlive` early-outs, and
  `BotService.update` skips records being respawned. Deactivated bots are hidden and not
  updated.
- **Are bots updated individually or centrally?** Centrally iterated in `BotService.update`,
  but each holds its own `BotController` state — effectively per-bot work serially each frame.
- **Are bot tanks respawned/destroyed or reused?** **Reused.** `activateBotRecord`
  re-activates an existing hidden record (no re-clone); fresh clones happen only when the
  pool needs to grow.

**Minimal, clearly-safe throttling suggestions (config-only, no gameplay change):**

- Target search interval / LOS interval / movement decision interval are already unified
  under `TickRate`; leaving them is fine.
- **Stagger bot spawns across frames** in `ensureBotCount` (e.g., spawn at most one bot per
  `update` call). This is the highest-value safe change and does not alter bot behavior once
  spawned.
- `max bots by profile`: expose a mobile cap via the existing `BattleArenaMaxBotsOverride`
  diagnostics flag for testing; keep gameplay default unchanged.
- Skipping inactive/dead bots is already implemented — keep it.
- Reusing bot tanks is already implemented — keep it; do not destroy on death.

> Do not change bot aim, fire, or movement gameplay. Staggering *when* a bot is spawned does
> not change *how* it plays.

## 8. World Bars / UI Review

- **Are BillboardGuis created once or repeatedly?** Once per model — cached in
  `RecordsByModel`; re-used until the model becomes invalid.
- **Does discovery scan workspace too often?** Discovery runs on `DISCOVERY_INTERVAL` (≥1s)
  and `GetDescendants` over `WOB_Generated/TestObjects` and `WOB_Generated/BattleArena`. The
  per-frame `Step` only iterates existing records (anchor-follow), not a fresh scan.
- **Does it attach bars to all tanks including dead/inactive/far tanks?**
  `TankModelScanner.IsTankModel` filters out `IsActive == false`, but does **not** filter by
  distance or alive state — far/idle tanks still get bars and per-frame `Step` updates.
- **Does it update every frame?** Yes — `Step` runs on `Heartbeat` for every record (anchor
  position follow). Cost scales with number of tanks, not with visibility.
- **Are ImageLabels/icons created once per card or repeatedly?** Upgrade HUD icons
  (`BattleArenaUpgradeHud`) bind `IconImage` once per choice card and fall back to `★` only
  when an id is missing — built once, not per frame. (`UpgradeIconConfig` asset ids untouched.)
- **Does mobile layout create separate objects?** HUD layouts adapt via device utils but
  build their widget tree once; no evidence of per-frame mobile-specific re-creation.
- **Are combat feedback TextLabels pooled/reused or created per message?** **Created per
  message** (`WOBCombatFeedbackOverlay`, 5 `Instance.new` each), faded on `RenderStepped`,
  then destroyed. No pool.

**Recommendations:**

- Cache tank refs (already cached in records) — keep.
- Update only active/visible tanks: add a distance/alive gate in `Step` so off-screen or
  dead tanks skip the per-frame anchor update.
- Pool floating combat text instead of create-per-message.
- Avoid the full-folder `GetDescendants` scan: consider reacting to `ChildAdded` on the
  arena tank container, or scan a narrower subfolder (Phase 2 — not in this pass).
- Cleanup bars on tank removal is already handled via the `OnInvalid` callback — keep.

## 9. DataStore / Save Review

`PersistentPlayerStatsService` and the economy/stats services use DataStores. In Studio,
DataStore API access is limited, so warnings are expected and the service falls back to
in-memory data. The risk is not steady-state cost but **synchronous-feeling save attempts on
exit/respawn**: a blocking/retrying `:SetAsync`/`:UpdateAsync` can stall a frame or the
leave path, which can read as a freeze when leaving the Arena or stopping Play.

> Saves are intentionally left intact. Do not remove or weaken them.

**Safe, Studio-only recommendations:**

- In Studio (`RunService:IsStudio()`), avoid repeated save **retries** — attempt once and
  fall back to the in-memory store rather than looping with backoff.
- Throttle/`warnOnce` the DataStore warnings so the Output isn't flooded (flooded Output
  itself can cause Studio hitches).
- Keep the in-memory fallback as the source of truth during Studio play so gameplay never
  blocks on a network round-trip.
- Ensure any save on `PlayerRemoving`/leave runs without a blocking retry loop on the main
  thread.

(These are behavioral guards gated to Studio; they do not change what is saved in production.)

## 10. Profiling Plan

Exact steps in Roblox Studio to confirm the cause before changing anything:

1. **MicroProfiler (Ctrl+Alt+F6, or `Ctrl+F6`):** open it, then drive onto the Arena pad.
   Freeze the capture (Ctrl+P) right after the hitch. Look for a tall frame at entry; expand
   it and read the labels — physics (`Blockcast`/spawn), `Instance` creation, script
   (`Heartbeat`), or replication.
2. **Script Performance window** (View → Script Performance): sort by Activity / Rate. After
   ~30s in the Arena, check whether `BotService`/`BotController`/`ProjectileService`/
   `WOBPerformanceServer` dominate, and whether any script appears **twice** (duplicate
   running scripts → §11 Phase 1).
3. **Developer Console (F9):** watch the Server and Client tabs separately. Check the
   "Scripts" and memory sections; note instance count before vs. after entry.
4. **Memory (Developer Console → Memory):** expand `Instances` and `PartInstance`/`GeometryCSG`.
   Enter the Arena and fire continuously — if `Instances` climbs and only slowly recovers,
   that's the VFX/projectile churn from §3/§6.
5. **Server vs. client separation:** use the Developer Console Server/Client toggle and the
   MicroProfiler's "Server" mode (in a local server test: Test → Start, with 1 server + 1
   player) to see whether the spike is server-side (spawn) or client-side (HUD/world bars/VFX).
6. **Published private server test:** publish and join a private server. Studio masks real
   DataStore latency and network replication; a private server reveals true save/replication
   cost and whether the freeze persists outside Studio.

**What to look for:**

- Long frame **during Arena enter** → spawn/armor/shadow spike (§5).
- Script-time spikes in `BotService`/`TankFactory`/`PlayerTankSpawner` → bot spawn burst.
- Physics spikes (`Blockcast`/welds) right after entry → armor weld + first-frame simulation.
- Render/VFX spikes on the client under sustained fire → projectile/VFX churn.
- Network/replication spikes → server-spawned VFX replicating to clients.
- Instance count jumps that don't recover → missing caps/pools (not a leak — `Debris` works —
  but high allocation rate).

## 11. Safe Fix Plan

**Phase 1 — no gameplay change (do first):**

- Manually confirm there are **no duplicate live scripts** in the Studio place (see §5 of the
  earlier audit and the manual checklist there): exactly one `WOBGameplayServer`, one
  `WOBPerformanceServer`, one of each client overlay.
- Reduce log spam (gate remaining diagnostic prints behind existing debug flags; `warnOnce`
  the DataStore warnings).
- Verify the diagnostic toggles in `PerformanceConfig.Diagnostics` all work end-to-end.
- **Pre-bake `ArmorZones`** (4 named parts + welds) into the bot/tank templates so runtime
  armor creation stops happening on entry. (Asset/template change; no logic, no numbers.)
- **Stagger bot spawns** so `ensureBotCount` adds at most one bot per `update` call.
- Avoid repeated creation of world bars (already once-per-model) — keep; add a visible/alive
  gate to the per-frame `Step`.
- Throttle the obvious scans (world-bars discovery interval; keep movement obstacle cache).

**Phase 2 — presentation optimization:**

- VFX template pooling (warm clones, re-emit).
- Combat-text pooling in `WOBCombatFeedbackOverlay`.
- Projectile trail/part pooling.
- Mobile VFX profile: disable procedural lights/smoke/ground-glow on `MobileLow`.

**Phase 3 — bot optimization:**

- Spread bot AI `:Update` across frames (round-robin) if profiling shows per-frame bot cost.
- Keep current throttles; cap bots by device profile.
- Continue reusing bot tanks (already done).

**Phase 4 — architecture cleanup:**

- Remove legacy/duplicate scripts from the Studio place permanently.
- Keep a single central runtime loop owner (already the case — preserve it).
- Define explicit service lifecycle (init → enter → leave → cleanup) and document it.

## 12. Immediate Safe Code Changes

This pass intentionally makes **no source logic changes** beyond what the earlier audit
already wired (the `Diagnostics` toggles). The two highest-value safe wins — pre-baking armor
into templates and staggering bot spawns — are deliberately **deferred**:

- *Pre-baking ArmorZones* is an asset/template (`.rbxlx`/template model) edit, which must be
  done in Studio and verified against the spawn path; doing it blindly from text risks
  breaking armor hit resolution. Tracked as a Phase 1 task.
- *Staggering bot spawns* touches `BotService.ensureBotCount` control flow. While it does not
  change bot gameplay, it changes spawn timing and should land with a focused test, not as an
  incidental edit in an investigation pass.

What *is* safe and acceptable here, and already in place or recommended as tiny follow-ups:

- Diagnostic flags exist and are honored (`BattleArenaBotsEnabled`,
  `BattleArenaMaxBotsOverride`, VFX/world-bars toggles).
- Debug logs are already gated behind config flags (`DEBUG_INPUT`, `BotConfig.Debug`,
  `DebugCombatConfig.*`); no new spam introduced.
- No configs overwritten, no systems rewritten, no gameplay numbers changed, and
  `UpgradeIconConfig` asset ids untouched.

If a single tiny change is desired now, the safest is adding a `BotSpawnStagger` boolean to
`PerformanceConfig.Diagnostics` (default preserving current behavior) so the staggering
behavior can be toggled when it's implemented in Phase 1 — but even that is left for the
implementing pass to avoid editing the frozen config speculatively.

## 13. Output

**Confirmed likely cause:** a **frame spike on BattleArena entry** produced by several
systems doing their heaviest work on the same frame — synchronous multi-bot spawning
(template clone + missing-armor creation + skin + registration), amplified by the
`WOBPerformanceServer` `DescendantAdded` shadow handler firing per added part, with
world-bars/damage-flash discovery landing immediately after. Steady-state per-frame cost is
healthy; the problem is concentration, not a runaway loop.

**Top 3 suspects:**

1. Arena-entry bot spawn burst (`BotService.ensureBotCount` + `TankFactory`/`PlayerTankSpawner`
   creating armor at runtime).
2. Per-shot/per-hit VFX + projectile instance churn with no pooling or caps.
3. A possible duplicate live `WOBGameplayServer`/`WOBPerformanceServer` in the Studio place
   (must be ruled out manually — would double everything).

**What to test first:**

1. Enter Arena with `Diagnostics.BattleArenaBotsEnabled = false` → freeze gone ⇒ confirms #1.
2. Then `BattleArenaMaxBotsOverride = 1` vs default → confirms it's the *burst*, not bot
   steady-state.
3. Then bots on + `ProjectileVfxEnabled = false` → isolates #2.
4. Capture MicroProfiler on the entry frame in a published private server (rules out Studio
   DataStore noise and #3).

**What NOT to touch yet:**

- Gameplay balance, Duel rules, remotes, damage, shooting, projectile collision, movement,
  upgrade effects, tank controls.
- `UpgradeIconConfig` `rbxassetid://` values.
- DataStore save *content* (only Studio-only retry/log behavior may be guarded later).
- Bot aim/fire/movement behavior (only spawn *timing* may be staggered in Phase 1).
- No King/Pedestal/Vampire gameplay; no full pooling system in this pass.

## 14. Phase 1 Implementation Log (BattleArena entry spike)

This section records the Phase 1 changes actually applied for the entry-spike fix.

### What changed

**A. Bot spawn staggering (code).**

- `src/ReplicatedStorage/Shared/Configs/BotConfig.luau` — added a frozen `Spawn`
  block:
  ```lua
  Spawn = table.freeze({
      IntervalSeconds = 0.35,
      MaxPerTick = 1,
  }),
  ```
- `src/ServerScriptService/Server/Gameplay/Bots/BotService.luau` —
  `ensureBotCount` now takes `deltaTime` and fills missing bots **gradually**:
  excess bots are still removed immediately (cheap), but missing bots are added at
  most `MaxPerTick` per call and only after `IntervalSeconds` has elapsed
  (module-level `spawnStaggerTimer`). Added `getSpawnStaggerConfig` and `spawnOneBot`
  helpers. `BotService.update` passes `deltaTime` through. `IntervalSeconds = 0`
  restores the legacy "fill immediately" behavior.

**B. ArmorZones pre-bake support (docs + manual).**

- The tank templates are not Rojo-managed (resolved at runtime by
  `TankTemplateProvider` from `ServerStorage.TankTemplates` /
  `Workspace.WOB_Generated.TestObjects`), so the risky 2.4 MB `.rbxlx` is **not**
  auto-edited. Precise manual Studio steps and the exact required hierarchy /
  properties are documented in `docs/ARMORZONES_TEMPLATE_SETUP.md`.
- The runtime fallback (`PlayerTankSpawner.ensureHitboxes` +
  `TankArmorPartsService.Configure`) is unchanged and still creates armor if a
  template lacks it.
- **Inspection of `RicochetTanksPrototype.rbxlx` (2026-05-24) confirmed the exact
  gap:** `BaseTankTemplate` (in `ServerStorage.TankTemplates`) is the *only* tank
  template in the place — the legacy prototypes are absent — so it serves both Player
  and ArenaBot. It already contains an **empty `ArmorZones` folder** (children: `Body`,
  `Turret`, `Barrel`, `ShootPoint`, `ArmorZones`, `Visuals`), which is why spawns log
  `created missing ...ArmorZones.FrontArmor` (×4) but not the `Hitboxes` line. The fix
  is to add the four named parts inside that existing folder — see
  `docs/ARMORZONES_TEMPLATE_SETUP.md`. The `.rbxlx` is the live Studio place (not a
  Rojo-built asset), so it is fixed manually in Studio, not by editing the serialized
  file.

### Why it is safe

- The eventual desired bot count is unchanged — `getDesiredBotCount`,
  `getConfiguredBotLimit`, `BattleArenaBotsEnabled`, and
  `BattleArenaMaxBotsOverride` all still apply. Only the *timing* of filling the
  deficit changed; bots that exist behave identically (no `BotBrain`/`BotController`
  changes).
- Bots-disabled still means zero bots: with `BattleArenaBotsEnabled = false`,
  `getDesiredBotCount` returns 0 and `ensureBotCount` despawns immediately.
- No changes to movement, shooting, projectile collision, damage, upgrades, remotes,
  wallet, DataStore, UI icons, or `UpgradeIconConfig`. No Duel rule changes.
- The ArmorZones work is template authoring guarded by an intact runtime fallback;
  armor values remain in `TankArmorConfig` (untouched), and `Configure` still owns
  size/colour/weld at spawn.

### Expected result

- BattleArena gets the same number of bots, but they appear **staggered** (roughly
  one every `~0.35s`) instead of all on the entry frame — the spawn burst that
  dominated the entry frame is removed.
- Once `ArmorZones` are pre-baked into the template(s), Output stops printing
  `[TANK] created missing ... ArmorZones/Hitboxes` for spawns, and the per-spawn
  instance-creation + weld cost is eliminated.
- Combined, the entry hitch should be noticeably reduced.

### How to test

1. **BattleArena with bots enabled (default):** enter the arena; confirm bots still
   appear and reach the normal count, just trickling in over ~1s rather than all at
   once. Watch the MicroProfiler entry frame — the tall spawn frame should be gone.
2. **`Diagnostics.BattleArenaMaxBotsOverride = 0`:** enter; confirm **no** bots spawn
   and no spawn-related work occurs.
3. **`Diagnostics.BattleArenaMaxBotsOverride = 1`:** enter; confirm exactly one bot
   spawns (after ~`IntervalSeconds`), no burst.
4. **Default bot count (override = `nil`):** confirm the configured min/max bot count
   is still reached over successive ticks (gameplay outcome unchanged).
5. **Output check:** before pre-baking, expect `[TANK] created missing ...ArmorZones...`
   on fresh spawns; after following `docs/ARMORZONES_TEMPLATE_SETUP.md`, those lines
   should no longer appear for bot/player tank spawns.

Optional: set `BotConfig.Spawn.IntervalSeconds = 0` to A/B against the legacy
all-at-once behavior and confirm the staggered version has the smaller entry frame.
