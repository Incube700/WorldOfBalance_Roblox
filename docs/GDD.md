# World of Balance: Ricochet Tanks — GDD v0.2

Дата обновления: 2026-05-10  
Платформа: Roblox  
Стек: Luau + Rojo + Roblox Studio  
Рабочее название: **World of Balance: Ricochet Tanks**

## 1. Краткое описание

**World of Balance: Ricochet Tanks** — top-down Roblox arena game про маленькие танки, где игрок побеждает не за счёт больших чисел, а за счёт позиции, угла корпуса, независимого наведения башни и рикошетов.

Игрок управляет танком на компактной арене, стреляет быстрыми видимыми снарядами, использует стены и броню для рикошетов, пробивает слабые стороны противника и рискует получить урон от собственного снаряда после отскока.

Текущая цель проекта — не «идеальная большая игра», а **стабильный Roblox-прототип с понятным фаном за первые 10–20 секунд**.

## 2. Текущий статус проекта

Проект уже переведён под Roblox/Rojo workflow.

Кодовая структура:

- `ReplicatedStorage.Shared` — shared configs and utilities.
- `ServerScriptService.Server` — server bootstrap and gameplay services.
- `StarterPlayer.StarterPlayerScripts.Client` — client input, camera, UI, VFX readability.

Текущее ядро уже содержит:

- Rojo-managed server gameplay orchestrator.
- Server-authoritative player possession.
- Player tank and Player2 tank foundation.
- Training mode against dummy.
- PvP foundation for two player-controlled tanks.
- Tank body movement with wall blocking.
- Independent turret aiming.
- Projectile shooting with cooldown.
- Raycast projectile movement.
- Wall ricochets.
- Armor hitbox based tank hits.
- Armor penetration / no-penetration / armor ricochet rules.
- Self-hit after ricochet.
- Player and opponent HP attributes.
- Round win/lose result.
- Match series to target wins.
- Runtime match stats per player/participant.
- Persistent player stats service with DataStore fallback/session attributes.
- Modular HUD with local perspective: `You` / `Opponent`.
- Result and stats UI shell.

Important: older audit documents may describe previous states where gameplay still lived in Studio-owned scripts. Current code is further ahead than those older snapshots.

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

Current MVP is no longer just “one local tank and dummy”. Current MVP is:

### Training MVP

- One local player controls a tank.
- Opponent is `DummyTank`.
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

## 7. What is not in the current MVP

Do not add these until Training + 2-player PvP smoke test is stable:

- shop;
- coins;
- Robux monetization;
- ranked matchmaking;
- wager/stake arenas;
- many tanks;
- many maps;
- mobile controls;
- advanced bot AI;
- complex lobby;
- daily rewards;
- cosmetics;
- progression;
- public matchmaking backend;
- huge refactor for architecture aesthetics.

These features may become future milestones, but they are not the next step.

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

Current opponent: `DummyTank`.

Future Training upgrade:

- BotBrain v0: dummy moves slowly, aims badly, shoots sometimes.
- Still simple. It should not become a complex AI milestone.

### 8.2 PvP

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

Future:

- mobile stick + aim zone;
- shoot button;
- optional aim helper tuning;
- optional controller support.

Mobile controls are not current priority.

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
- `Hitboxes` folder;
- `FrontArmor`;
- `RearArmor`;
- `LeftArmor`;
- `RightArmor`.

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
- aim laser/helper is visual-only.

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

Current values:

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
- destroyed tank visual is darkened;
- round result is set from local player perspective;
- match series can continue until target wins.

Current target:

- round win/lose should be obvious;
- match win/lose should be obvious;
- restart/next round should be simple.

Future:

- better death VFX;
- explosion;
- short round-end pause;
- automatic next round after delay;
- better match result screen.

## 18. Match flow

Current match config:

- series enabled;
- target wins: `3`;
- round reset delay: `0`.

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

Current HUD target:

- `You HP`;
- `Opponent HP`;
- reload status;
- round number;
- score: `You / Opponent`;
- first-to target;
- round result;
- match result.

Current shell UI:

- main menu;
- result panel;
- stats panel.

Feedback needed for fun:

- damage number;
- `NO PEN`;
- `RICOCHET`;
- self-hit message;
- win/lose;
- strong projectile readability.

Next UX priority:

- make the first Play → Fight → Result → Rematch loop impossible to misunderstand.

## 20. Visual style

Current MVP style:

- simple Roblox parts;
- readable colored teams;
- visible projectile glow/trail;
- armor hitboxes may be visible for debug/tuning.

Near-term visual priority:

- not final art;
- better readability;
- better hit feedback;
- better top-down silhouettes;
- simple explosions and muzzle flashes.

Do not spend too much time hunting assets until gameplay feel is better.

## 21. Sound

Sound is not yet a deep system, but for Roblox feel it becomes important soon.

Near-term sound needs:

- shot;
- ricochet;
- no-penetration clang;
- penetration hit;
- tank destroyed;
- UI result.

Sound should be added after the current combat loop is stable enough to test repeatedly.

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

Decision: treat this GDD v0.2, `TECH_CONTEXT.md`, current source code and latest task notes as primary context.

### 24.2 Scene/code drift

Rojo owns code, but `.rbxl` owns map/HUD/tank scene objects. If Studio scene is not saved, Git may not reflect reality.

Decision: after every scene repair, use `File -> Save to File` and commit the `.rbxl` intentionally.

### 24.3 Feature creep

Adding economy, cosmetics, mobile, bots, many modes or monetization now will hide core gameplay problems.

Decision: stabilize and improve feel first.

### 24.4 Roblox fun gap

The mechanics can be correct but still feel slow or unclear.

Decision: after stability, focus on feedback, readability and pace before adding meta systems.

## 25. Next development direction

### Phase A — Stabilize current runtime contract

Goal: make the current project boringly reliable.

Tasks:

- Verify only one gameplay server is active.
- Verify legacy Studio-owned scripts are disabled.
- Verify Training smoke test.
- Verify 2-player PvP smoke test.
- Verify modular HUD exists and no emergency HUD is needed.
- Verify tank physical model contract.
- Verify spawn points.
- Verify result/stats are local per player.
- Update old audits or mark them as historical.

No new gameplay features in this phase.

### Phase B — Make the fight feel good

Goal: make the existing core loop fun before expanding.

Tasks:

- improve shot impact feedback;
- add strong ricochet/no-penetration feedback;
- add simple destroy explosion;
- tune projectile visibility;
- tune movement speed/turn speed;
- tune camera height/FOV;
- reduce confusion in result/restart flow;
- optionally add BotBrain v0 for training.

This phase is about feel, not architecture.

### Phase C — Roblox retention shell

Only after Phase A and B are good.

Possible features:

- simple coins;
- simple cosmetics;
- daily reward;
- small quest list;
- 2–3 tank skins;
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
- Every shot/ricochet/hit has readable feedback.
- Result/rematch flow is clear.
- GDD and current code agree.

Do not chase public release until this milestone is true.

## 27. Stop doing for now

Stop doing these until the current loop feels good:

- rewriting the whole architecture;
- adding new systems because the game feels unclear;
- searching for final asset packs as a substitute for gameplay feel;
- adding monetization;
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
