# World of Balance: Ricochet Tanks — GDD v0.3

Дата обновления: 2026-05-24  
Платформа: Roblox  
Стек: Luau + Rojo + Roblox Studio  
Рабочее название: **World of Balance: Ricochet Tanks**

## 1. Краткое описание

**World of Balance: Ricochet Tanks** — top-down Roblox arena game про маленькие танки, где игрок побеждает не за счёт больших чисел, а за счёт позиции, угла корпуса, независимого наведения башни и рикошетов.

Игрок управляет танком на компактной арене, стреляет быстрыми видимыми снарядами, использует стены и броню для рикошетов, пробивает слабые стороны противника и рискует получить урон от собственного снаряда после отскока.

Текущая цель проекта — не «идеальная большая игра», а **стабильный Roblox-прототип с понятным фаном за первые 10–20 секунд**.

## 2. Текущий статус проекта

Проект работает под Roblox/Rojo workflow. Кодовая база значительно продвинулась вперёд от базового прототипа.

Кодовая структура:

- `ReplicatedStorage.Shared` — shared configs and utilities.
- `ServerScriptService.Server` — server bootstrap and gameplay services.
- `StarterPlayer.StarterPlayerScripts.Client` — client input, camera, UI, VFX readability.

### Реализовано (по состоянию на v0.3)

**Ядро боя:**
- Server-authoritative player possession.
- Player tank and Player2 tank possession.
- Training mode against DummyTank.
- Tank body movement with wall blocking.
- Independent turret aiming.
- Projectile shooting with cooldown.
- Raycast projectile movement.
- Wall ricochets.
- Armor hitbox based tank hits.
- Armor penetration / no-penetration / armor ricochet rules (`ArmorHitResolver`, `RicochetMath`).
- Self-hit after ricochet.
- Player and opponent HP attributes.
- Round win/lose result.
- Match series (`EnableMatchSeries = true`, `TargetWins = 3`).
- Round reset delay (`RoundResetDelay = 2.0`).
- Match result delay (`MatchResultDelay = 2.0`).
- Runtime match stats per player/participant (`MatchStatsService`).
- Persistent player stats service with DataStore fallback (`PersistentPlayerStatsService`).
- Separate `TankArmorConfig` for armor zone values.

**Визуальная обратная связь:**
- Modular HUD with local perspective: `You` / `Opponent` (`WOBDuelHudOverlay`).
- Combat feedback overlay: `DAMAGE`, `NO PEN`, `RICOCHET`, self-hit text (`WOBCombatFeedbackOverlay`).
- Impact flash and damage pulse (`WOBImpactFeedbackOverlay`, `WOBTankDamageFlash`).
- Round status overlay (`WOBRoundStatusOverlay`).
- World-space HP and reload bars on tanks (`WOBTankWorldHealthBars`, `WorldHealthBarsController`).
- Aim laser from muzzle with obstacle stop (`WOBAimLaser`).
- Projectile readability overlay: glow, trail, neon material (`WOBProjectileReadabilityOverlay`).
- Tank visual smoothing for network-replicated tanks (`WOBTankVisualSmoothing`).
- Team color visuals per local perspective (`WOBTankLocalTeamVisuals`).
- VFX system: muzzle flash, smoke, impact sparks, ricochet sparks, tank explosion, burning tank (`CombatVfxService`, `VfxConfig`, `VfxTemplateCatalog`).

**Режимы:**
- Training: solo vs DummyTank.
- Duel / PvP: 2-player match with series score.
- BattleArena: multiplayer arena with bots (`ArenaCombatService`, `WOBBattleArenaOverlay`).
- Lobby with duel pads (`LobbyService`, `LobbyPadResolver`, `WOBDuelPadVisual`).

**Боты:**
- Full bot AI suite: `BotBrain`, `BotController`, `BotService`, `BotSpawnPlanner`, `BotTargeting`.
- Training-specific bot service: `TrainingBotService`.
- Difficulty profiles: Easy, Normal (configurable in `BotConfig`).
- Line-of-sight, preferred distance, anti-stuck, strafe logic.

**Экономика:**
- Player wallet with Bolts and Crystals currencies (`PlayerWalletService`, `CurrencyConfig`).
- Kill reward service (`KillRewardService`).
- Match reward service (`MatchRewardService`).
- Wallet HUD overlay (`WOBWalletOverlay`).

**Скины и кастомизация:**
- Skin catalog and cosmetic catalog (`SkinCatalog`, `CosmeticCatalog`).
- Tank skin applier service (`TankSkinApplier`).
- Skin unlock service (`SkinUnlockService`).
- Tank customization service (`TankCustomizationService`).

**Мобильное управление:**
- Mobile controls client script (`WOBMobileControls`).
- Mobile controls config (`MobileControlsConfig`).
- HUD layout adapts to mobile (`HudDeviceUtils`, `HudVisibilityRules`).

**Прочее:**
- Performance server (`WOBPerformanceServer`).
- Debug configs: `DebugBotConfig`, `DebugCombatConfig`.
- Aim assist config (`AimAssistConfig`).

### Не реализовано / требует работы

- **Main menu screen** — игра начинается сразу с арены/лобби. Главного меню нет.
- **Audio (8/10 SoundId пустые)** — `DefaultCannonShot` и `DefaultRicochet` имеют реальные ID; остальные 8 записей в `AudioCatalog` имеют `SoundId = ""` и не воспроизводятся.
- **3 VFX-шаблона отсутствуют** — `DamageHitTemplate`, `NoPenTemplate`, `SelfHitTemplate` не существуют как `.rbxm` файлы; система использует процедурный фолбэк (работает, но хуже выглядит).
- **Final match result screen** — полноценный экран итогов матча (не раунда) не реализован.

## 3. Product direction

The project should stop being treated as a pure technical port from Unity. The Roblox version should become:

> **A fast, readable ricochet tank arena with short rounds, instant rematch, strong hit feedback, and simple PvP/training flow.**

The core fantasy is still tactical ricochet combat, but Roblox requires faster readability:

- the player should understand the goal immediately;
- shooting should feel powerful;
- hits, ricochets, no-penetration and self-hit moments should be obvious;
- menu/lobby should not block the first fun moment;
- bots/training should keep the game alive when there are not enough players.

## 4. Design pillars

### 4.1 Angle mastery

Position, hull angle and shot angle matter. A good player wins by using geometry, not only reaction speed.

### 4.2 Readable arcade feel

The game must remain readable from top-down camera:

- clear tank silhouettes;
- clear projectile trail/glow;
- clear hit feedback;
- clear HP/reload UI;
- clear result state.

### 4.3 Fast rounds

A player should enter action quickly. Long setup, unclear lobby flow and slow round restart should be avoided until the core fight is fun.

### 4.4 Server truth, client feel

Server owns damage, health, round result, match result and stats. Client owns input, camera, HUD, local readability and visual feedback.

### 4.5 Roblox practicality

The game should be simple enough to test, publish, iterate and expand. Avoid systems that require a large team before the core loop is proven.

### 4.6 Feedback / Presentation Architecture

Gameplay logic and presentation are separate responsibilities. Gameplay services produce facts: shot, ricochet, damage, death, reward, win or loss. Presentation controllers produce feelings: VFX, audio, HUD, overlays and short feedback text.

Current MVP ownership is explicit: `VfxConfig` owns visual effects only, `AudioConfig` owns audio playback settings, and `AudioCatalog` owns allowed sound definitions and `SoundId` values. Do not duplicate sound ownership in VFX configs.

Future target: gameplay services emit facts through `CombatFeedbackService`, then client VFX, audio and UI controllers decide how to show or play them. Player audio customization should select validated catalog IDs, never arbitrary client-provided sound assets.

## 5. Core gameplay loop

Current target loop:

1. Player opens the experience.
2. Player presses Play or enters Training quickly.
3. Player spawns into a compact top-down arena.
4. Player drives the tank body with keyboard.
5. Player aims the turret with mouse.
6. Player fires a fast visible shell.
7. Shell hits wall, cover or armor hitbox.
8. Shell may ricochet, lose speed/damage and continue.
9. Shell may penetrate weak armor and deal damage.
10. Destroyed tank gives round win/lose.
11. Series score updates.
12. Player presses restart/play again and continues.

Desired Roblox feel:

- first shot within 5–10 seconds;
- first hit/ricochet within 10–20 seconds;
- restart without confusion;
- no long waiting state for the current MVP.

## 6. Current MVP definition

Current MVP is no longer just "one local tank and dummy". Current MVP is:

### Training MVP

- One local player controls a tank.
- Opponent is `DummyTank` (or a bot via `TrainingBotService`).
- Player can drive, aim, shoot, ricochet, damage and destroy the dummy.
- Dummy can serve as target for armor/ricochet testing.
- Round and match result can be shown from local perspective.

### 2-player PvP smoke MVP

- Two Roblox clients can be assigned to different tanks.
- Each client follows and controls only its own physical tank.
- Each client sees local HUD perspective: `You` and `Opponent`.
- Shots, damage, round result and match result replicate correctly.
- Per-player runtime stats are not mixed between Player1 and Player2.

### MVP exit criteria

The prototype is considered MVP-stable only when both checks pass:

- Training: Play → drive → aim → shoot → ricochet → damage → win/lose → restart.
- 2-player PvP: two clients → separate possession → separate cameras → separate controls → separate damage/results/stats.

## 7. What is not in the current build

Not yet built (as of v0.3):

- main menu screen;
- complete audio (8/10 SoundId values are empty);
- `DamageHitTemplate`, `NoPenTemplate`, `SelfHitTemplate` VFX assets;
- final match result screen (match-end, not round-end);
- ranked matchmaking;
- wager/stake arenas;
- many maps;
- complex lobby progression;
- daily rewards;
- public matchmaking backend.

Note: mobile controls, economy (Bolts/Crystals), basic cosmetics/skins, BattleArena, and bots **are already implemented** as of v0.3.

## 8. Modes

### 8.1 Training

Training is the default safety mode when there are not enough players for PvP.

Purpose:

- test controls;
- test shooting;
- test ricochet rules;
- test armor zones;
- test win/lose/restart loop;
- let a solo player understand the game.

Current opponent: `DummyTank`. Bot AI available via `TrainingBotService` (BotBrain v0 exists).

### 8.2 Duel / PvP

PvP is the long-term core mode, but currently it should stay as a controlled smoke-test mode.

Minimum PvP target:

- two player tanks;
- separate ownership;
- separate camera;
- separate input;
- separate HP and stats;
- series to target wins.

Future PvP:

- 1v1 public duel;
- quick rematch;
- short intermission;
- simple queue or join flow;
- maybe 2v2 or free-for-all later if 1v1 feels too empty for Roblox.

### 8.3 BattleArena

Multiplayer arena with bots. Multiple players and bots fight together. Bots spawn and respawn based on player count.

Current status: implemented. `ArenaCombatService`, `BotService`, `BattleArenaConfig`, `WOBBattleArenaOverlay`.

Future: survival/roguelite upgrade loop (see section 29).

### 8.4 Lobby

Players can idle in lobby and join duels via pads. `LobbyService`, `LobbyPadResolver`, `WOBDuelPadVisual`.

## 9. Controls

Current PC controls:

- `W` / `S` — move forward/backward.
- `A` / `D` — turn body.
- Mouse — aim turret.
- Left Mouse Button — shoot.
- `R` — reset / next round / restart current flow depending on current state.

Current design note:

- Reverse movement is slower than forward movement.
- Body steering is independent from throttle.
- Turret currently follows aim direction directly.

Mobile controls:

- Left virtual joystick — move/steer tank body.
- Right virtual joystick — aim turret.
- Fire button — shoot.
- Implemented via `WOBMobileControls.client.luau` and `MobileControlsConfig`.

## 10. Camera

Current target:

- top-down camera;
- camera follows the owned physical tank;
- client resolves owned tank by player ownership attributes;
- camera should use physical model focus part, not metadata wrapper.

Camera must support:

- Training player tank;
- Player1 tank;
- Player2 tank;
- future bot/enemy visualization.

Do not change camera feel randomly. It directly affects perceived control quality.

## 11. Tank design

Current tank model contract:

Each physical tank model should contain:

- `Body` or valid focus part;
- `Turret`;
- `Barrel`;
- `ShootPoint`;
- `ArmorZones` folder (with `FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor` children);
- legacy `Hitboxes` folder — if present alongside `ArmorZones`, it is automatically destroyed by `PlayerTankSpawner` to prevent duplicate floating panels.

Required model attributes include:

- `TankId`;
- `OwnerUserId` when player-owned;
- `OwnerName` when player-owned;
- `TeamId`;
- `ControllerType`;
- `IsPlayerTank`;
- `IsActive`;
- `Health`;
- `MaxHealth`;
- `IsDead`.

Current tanks:

- `PlayerTankPrototype`.
- `Player2TankPrototype`.
- `DummyTank`.

Future tanks should not be added until the current contract is stable.

## 12. Movement

Current movement:

- server-authoritative control state;
- body yaw updated from steer input;
- movement follows body forward vector;
- server resolves movement against map obstacles;
- movement uses blockcast + overlap fallback;
- fallback allows backing away from wall contact.

Important design requirement:

- movement should feel predictable, not physically realistic.
- wall blocking should avoid sticky-wall frustration.
- tank should be readable and controllable before adding inertia.

Future:

- acceleration/deceleration;
- light drift/weight;
- different tank mobility stats;
- smoother wall sliding.

## 13. Turret aiming

Current:

- turret aims at client-provided aim position;
- server calculates turret yaw;
- shot origin comes from `ShootPoint`;
- aim laser/helper is visual-only, stops on obstacles.

Future:

- limited turret turn speed;
- turret stabilization delay;
- different turret types;
- optional aim prediction for learning/readability.

## 14. Shooting

Current weapon:

- `PrototypeCannon`.
- Cooldown: `0.45` seconds.
- Projectile type: `DefaultRicochetShell`.

Current projectile:

- speed: `160`;
- max damage: `110`;
- penetration: `45`;
- max ricochets: `3`;
- bounce speed multiplier: `0.78`;
- damage multiplier per bounce: `0.75`;
- lifetime: `4` seconds.

Design rule:

- shell must be fast but visible;
- projectile readability is more important than visual realism;
- projectile mechanics and projectile visuals should remain separate.

## 15. Ricochet rules

Ricochet is the central identity of the game.

Current rules:

- Projectile can bounce from arena walls.
- Projectile can bounce from cover.
- Projectile can bounce from tank armor if no penetration or auto-ricochet occurs.
- Projectile can hit the shooter only after at least one bounce.
- Maximum ricochets: `3`.
- After ricochet, projectile speed decreases.
- After ricochet, projectile damage cap decreases.
- After max ricochets, next valid contact destroys the projectile.

Do not implement yet:

- tank corner detection;
- different material ricochets;
- multiple projectile behavior types;
- complex trajectory prediction.

## 16. Armor and damage

Current armor zones:

- Front — strongest.
- Side — medium.
- Rear — weak.

Current values (from `TankArmorConfig`):

- FrontArmor = `50`.
- SideArmor = `40`.
- RearArmor = `10`.
- AutoRicochetAngleDegrees = `72`.
- Projectile penetration = `45`.

Current logic:

1. Projectile hits explicit armor hitbox.
2. Armor zone is resolved by hitbox name.
3. Effective armor is calculated from hit angle.
4. If hit angle reaches auto-ricochet threshold, result is ricochet.
5. If penetration is below effective armor, result is no penetration / ricochet behavior.
6. If penetration passes effective armor, damage is applied.
7. Damage is capped by current projectile damage after ricochets.

Design rule:

- front should be dangerous to shoot directly;
- side/rear should reward positioning;
- glancing hits should reward hull angling;
- no-penetration and ricochet feedback must be readable.

## 17. Health, death, win/lose

Current:

- participants have health and max health;
- destroyed participant receives `IsDead` state;
- destroyed tank visual: darkened + burning tank VFX (`TankBurningTemplate`) + explosion VFX (`TankExplosionTemplate`);
- round result is set from local player perspective;
- match series to target wins (3 by default).

Current target:

- round win/lose should be obvious;
- match win/lose should be obvious;
- restart/next round should be simple.

Future:

- better match result screen (match-end, not just round-end);
- automatic next round after delay (round reset delay already configured at 2 sec).

## 18. Match flow

Current match config:

- series enabled;
- target wins: `3`;
- round reset delay: `2.0` sec;
- match result delay: `2.0` sec;
- small round result overlay shown;
- small match result shown before full result.

Current states:

- `Menu`;
- `Playing`;
- `Result`.

Current results:

- `Playing`;
- `Win`;
- `Lose`;
- final match result values for player/opponent side.

Next improvement:

- clarify whether `R` means next round, reset current round, or rematch depending on state;
- add simple countdown only after the core loop is stable;
- avoid long lobby/intermission before fun is proven.

## 19. UI and feedback

Current HUD (implemented):

- `You HP` / `Opponent HP` bars (HUD panels + world-space bars on tanks).
- Reload bar (HUD + world-space reload bar below HP bar).
- Round number and score: `You / Opponent`.
- First-to target win count.
- Round result overlay.
- Match result state.
- Combat feedback labels: `DAMAGE`, `NO PEN`, `RICOCHET`, self-hit.
- Impact flash on tank hit.
- Wallet overlay (Bolts/Crystals).
- BattleArena overlay.
- Compact Training HUD (hides redundant panels when `TrainingCompactHud = true`).
- Mobile layout adaptation.

Current shell UI:

- result panel;
- stats panel;
- lobby / duel pad UI.

Still missing:

- main menu;
- final match result screen;
- floating damage numbers in-world (combat feedback labels exist but are screen-space, not world-space).

## 20. Visual style

Current MVP style:

- simple Roblox parts;
- readable colored teams;
- visible projectile glow/trail;
- armor hitboxes are visible and intentional (not debug-only).

Near-term visual priority:

- not final art;
- better readability;
- better hit feedback (VFX template assets for DamageHit, NoPen, SelfHit still missing);
- better top-down silhouettes;
- muzzle flash and explosion VFX already have templates.

Do not spend too much time hunting assets until gameplay feel is better.

## 21. Sound

Current sound status:

- `DefaultCannonShot` — `rbxassetid://139771888058836` ✅ (plays).
- `DefaultRicochet` — `rbxassetid://140602821561280` ✅ (plays).
- `DefaultHit`, `DefaultNoPenetration`, `DefaultExplosion`, `DefaultBarrelBlocked`, `DefaultBoltReward`, `DefaultButtonClick`, `DefaultWin`, `DefaultLose` — `SoundId = ""` ❌ (silent).

Audio controller exists (`WOBAudioController.client.luau`) and is wired up. The gaps are missing asset IDs in `AudioCatalog.luau`, not missing code.

Near-term sound needs:

- no-penetration clang (add SoundId for `DefaultNoPenetration`);
- penetration hit (add SoundId for `DefaultHit`);
- tank destroyed explosion (add SoundId for `DefaultExplosion`);
- UI result sounds (add SoundId for `DefaultWin`, `DefaultLose`);
- button click (add SoundId for `DefaultButtonClick`);
- barrel blocked (add SoundId for `DefaultBarrelBlocked`).

Sound should be added as SoundId values in `AudioCatalog.luau`. No code changes needed, only asset IDs.

## 22. Architecture rules

Current architecture direction is valid and should not be rewritten from scratch.

Rules:

- `WOBGameplayServer` stays a thin orchestrator.
- Do not add new business logic into `WOBGameplayServer` unless it is temporary glue.
- Combat rules live in combat/projectile services and shared math/configs.
- Tank model ownership and participant lookup live in registry/resolver logic.
- Server owns damage, death, stats and match result.
- Client owns camera, input, HUD and local readability.
- No new dependencies until MVP-stable.
- No large refactor without a specific regression or blocker.

Current important services:

- `RoundMatchService` — game state, match mode, round/match result.
- `ProjectileService` — projectile lifecycle, shooting, raycast update.
- `ProjectileCombatService` — armor penetration, ricochet, damage feedback.
- `TankSpawnResetService` — spawn transforms, layout, visibility, reset support.
- `TankMovementService` — wall blocking and movement resolution.
- `TankParticipantRegistry` — tank participants, health/death, armor hitbox ownership.
- `PlayerPossessionService` — player-to-tank assignment.
- `MatchStatsService` — runtime stats per participant/player.
- `BotService` / `BotBrain` — bot AI lifecycle and decision loop.
- `ArenaCombatService` — BattleArena combat coordination.
- `PlayerWalletService` — economy/wallet.
- `LobbyService` — lobby state management.

## 23. Scene contract

Roblox Studio scene remains part of the project source of truth because Rojo does not map all scene objects.

Expected scene roots:

```text
Workspace/WOB_Generated
Workspace/WOB_Generated/Map
Workspace/WOB_Generated/TestObjects
Workspace/WOB_Generated/Runtime
StarterGui/HUD/Root
StarterGui/WOBPlayableShellGui
```

Expected tanks:

```text
Workspace/WOB_Generated/TestObjects/PlayerTankPrototype
Workspace/WOB_Generated/TestObjects/Player2TankPrototype
Workspace/WOB_Generated/TestObjects/DummyTank
```

Expected spawn points:

```text
Workspace/WOB_Generated/SpawnPoints/PlayerSpawn
Workspace/WOB_Generated/SpawnPoints/Player2Spawn
Workspace/WOB_Generated/SpawnPoints/DummySpawn
```

or supported fallback under:

```text
Workspace/WOB_Generated/Map/SpawnPoints
```

Manual Studio command scripts are repair tools, not part of normal Play workflow.

## 24. Current biggest risks

### 24.1 Document drift

Some docs describe old pre-migration state. This can cause confusion and repeated redesign anxiety.

Decision: treat this GDD v0.3, current source code and latest task notes as primary context. Older audit documents are historical.

### 24.2 Scene/code drift

Rojo owns code, but `.rbxl` owns map/HUD/tank scene objects. If Studio scene is not saved, Git may not reflect reality.

Decision: after every scene repair, use `File -> Save to File` and commit the `.rbxl` intentionally.

### 24.3 Feature creep

Adding more modes, more currencies, more bots, and more skins before the core loop is fun will hide problems.

Decision: stabilize and improve feel first. Phase B (fight feel) before Phase C (retention shell).

### 24.4 Roblox fun gap

The mechanics can be correct but still feel slow or unclear.

Decision: after stability, focus on feedback, readability and pace. Audio and VFX are the next highest-leverage improvements.

### 24.5 Audio and VFX gaps

8/10 audio catalog entries have empty SoundId values. 3 VFX templates are missing (procedural fallback used instead).

Decision: add missing SoundId values from Roblox audio library. Create `.rbxm` template files for DamageHit, NoPen, SelfHit impact types.

## 25. Next development direction

### Phase A — Stabilize current runtime contract ✅ Largely complete

Goal: make the current project boringly reliable.

Status as of v0.3:
- ✅ Only one gameplay server active.
- ✅ Training smoke test works.
- ✅ 2-player PvP foundation exists.
- ✅ Modular HUD exists and works.
- ✅ Tank physical model contract defined (ArmorZones, attributes).
- ✅ Spawn points exist.
- ✅ Result/stats are local per player.
- ✅ Legacy Hitboxes folder cleanup automated.
- ✅ World-space HP bars attached via Attachment (no jitter for local tank).

Remaining Phase A work:
- Verify 2-player PvP smoke test end-to-end.
- Play-test Training: shoot → ricochet → armor hit → damage → win/lose → restart loop.

### Phase B — Make the fight feel good (current focus)

Goal: make the existing core loop fun before expanding.

Tasks:

- Add missing SoundId values to `AudioCatalog.luau` (8 empty entries).
- Create `DamageHitTemplate`, `NoPenTemplate`, `SelfHitTemplate` VFX assets (.rbxm).
- Tune projectile visibility (color, size, trail).
- Tune movement speed/turn speed.
- Tune camera height/FOV.
- Reduce confusion in result/restart flow.
- Add main menu or simple mode selection screen.
- Add proper final match result screen.

This phase is about feel, not architecture.

### Phase C — Roblox retention shell

Only after Phase A and B are good.

Possible features:

- cosmetics expansion;
- daily reward;
- small quest list;
- 2–3 additional tank skins;
- one more arena;
- menu polish;
- thumbnail/icon testing.

Do not add Robux wager/stake arenas. That risks violating platform expectations and moves the game toward gambling-like design. Monetization should stay cosmetic/convenience, not betting.

## 26. Immediate next milestone

The next milestone should be:

> **Stable Fun Duel v0.1**

Definition:

- Training works without errors.
- 2-player local server test works without possession/camera/stat bugs.
- The fight is understandable without reading code.
- Every shot/ricochet/hit has readable feedback (visual + audio).
- Result/rematch flow is clear.
- GDD and current code agree. ✅ Done in v0.3.

Primary blockers remaining:
1. Audio: 8 missing SoundIds — no sound on hit, no-pen, death, win/lose.
2. VFX: 3 templates missing — DamageHit, NoPen, SelfHit use generic spark fallback.
3. Match result screen: no clean match-end screen.

## 27. Stop doing for now

Stop doing these until the current loop feels good:

- rewriting the whole architecture;
- adding new systems because the game feels unclear;
- searching for final asset packs as a substitute for gameplay feel;
- adding complex lobby;
- adding ranked or matchmaking;
- adding many projectile types;
- adding many tanks;
- changing camera style every day.

## 28. Final design statement

World of Balance should become a small, sharp Roblox arena game where a player immediately understands:

- I am a tank.
- I can move and aim separately.
- Walls are weapons.
- Armor angle matters.
- My own shot can punish me.
- A clever ricochet feels amazing.

Everything else is secondary until this feeling works.

## 29. Arena — Survival Roguelite Direction (Future Concept)

Core idea:
- Arena becomes a large open map stretched across the full available space.
- Survival loop: the longer a tank survives, the stronger it becomes.
- Upgrades accumulate while alive (same upgrade pool as ARENA_V2_DESIGN.md).
- On death: upgrades reset. Score/kills/XP from the run may partially persist (TBD).
- Enemies scale over time: bots appear and increase in difficulty the longer the player survives.
- This creates a "king of the hill" dynamic — high-level tanks are powerful but targeted.

Map direction:
- Large arena, scattered cover blocks and walls (not a tight duel arena).
- Points of interest: medkits, supply crates, control zones (already planned in ARENA_V2_DESIGN.md).
- Possible minimap (low priority, nice to have).
- Top-down camera stays.

Progression feel:
- Early game: weak tank, learning the map.
- Mid game: upgraded tank, hunting others.
- Late game: very strong but every player/bot targets you.
- Death feels meaningful because upgrades are lost.

Relation to Extraction (section 25 future modes):
- This is a lighter version of Extraction — no loot banking, no leaving the map.
- Pure survival + upgrade loop within the arena bounds.
- May evolve into full Extraction later.

Not doing now:
- Do not implement until Duel Phase A and B are complete.
- Do not expand map until core combat feel is good.
- Do not add minimap until the large map exists.
