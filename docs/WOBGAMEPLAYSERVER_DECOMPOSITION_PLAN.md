# WOBGameplayServer Decomposition Plan

## Scope

This is a planning document only. It audits the current Rojo-managed `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau` and proposes a phased decomposition path that preserves current Play Mode behavior.

Do not use this plan to justify a wholesale rewrite. Each phase should be implemented and Play-tested independently.

Out of scope for this decomposition work:

- `.rbxl` scene edits.
- `default.project.json` edits.
- Bot AI until Phase 6.
- PvP.
- DataStore.
- Menu flow.
- Result screen before the dedicated Result Screen v1 task.
- Gameplay tuning or behavior changes.

## 1. Current Responsibility Map

`WOBGameplayServer.server.luau` is currently the prototype gameplay orchestrator. It owns these responsibilities in one file:

| Responsibility | Current owner in script | Current contracts to preserve |
| --- | --- | --- |
| Player assignment/input | `controllingPlayer`, `inputByPlayer`, `assignPlayer`, `TankInputEvent`, `ShootRequestEvent` handlers | One controlling player; hidden Roblox character; existing remotes and payloads. |
| Tank movement | `updateTank`, wall/blockcast helpers, movement overlap helpers, clamp helpers | WASD movement, reverse multiplier, body rotation, wall blocking, unstuck behavior. |
| Tank layout/spawn/reset | spawn helpers, `layoutTank`, armor hitbox layout, `resetRound` | SpawnPoints with fallback positions; body/turret/barrel/shoot point placement; `R` reset restores both tanks. |
| TankParticipant runtime data | `tankParticipants`, participant lookup tables, `playerParticipant`, `dummyParticipant` | Two scene tanks only: `PlayerTankPrototype` and `DummyTank`; current owner/team/weapon/health fields. |
| Shooting/cooldown | `tryShoot`, `createProjectile`, participant `LastShotTime` and `WeaponReadyAt` | Existing cooldown, muzzle origin, player-only shooting. |
| Projectile creation/update/cleanup | projectile folder setup, projectile table, `createProjectilePart`, `updateProjectiles`, `destroyProjectile`, `destroyAllProjectiles` | Projectile visuals, lifetime, speed, cleanup on reset. |
| Ricochet | `applyProjectileRicochet`, `reflect`, `printBounce` | Current wall/armor ricochet count, speed/damage falloff, owner self-hit enabling after bounce. |
| Armor/penetration/damage | armor hitbox resolution, `resolveArmorHit`, `handleProjectileTankHit`, participant health/damage helpers | Front/side/rear armor, no-pen, armor ricochet, penetration damage, self-hit, death handling. |
| Combat feedback | `CombatFeedbackEvent`, `sendCombatFeedback`, hit text decisions | Existing overlay compatibility and feedback types/text/colors. |
| Round/match state | `roundState`, `matchState`, `endRound`, `resetMatchState`, match attributes | `MatchConfig`, `TargetWins`, `RoundNumber`, `PlayerWins`, `DummyWins`, `MatchEnded`, `MatchResult`. |
| Runtime match stats | `matchStats`, `Stats*` attribute helpers and record functions | Runtime-only stats attributes on `Workspace.WOB_Generated`; reset on new match, not every round. |
| HUD/server attributes | `setRoundResult`, `setMatchAttributes`, tank health attributes, runtime stats attributes | Current modular HUD reads existing attributes; do not rename existing round/match/health attributes. |
| Reset flow | `ResetDummyRequestEvent` handler, `resetRound`, projectile cleanup, match/new-round branching | `R` reset behavior, projectiles cleared, match score preserved until new match reset. |

## 2. Current Risks Of The Monolith

- A change intended for one behavior can accidentally alter another because event handling, movement, combat, HUD attributes, match flow, and stats share local state.
- There are many implicit ordering contracts: damage may end a round, end round may update match score, match end may update stats, reset may clear projectiles before moving tanks.
- Shared state is not isolated: `root`, `runtime`, `projectiles`, `roundState`, `matchState`, participants, and config constants are read from many sections.
- Play Mode regressions are hard to localize because the file owns both pure calculations and Roblox side effects.
- Future features such as BotBrain, PvP, and result screens would be risky if added directly into the orchestrator.
- The server currently mixes lifetime concerns: startup discovery, per-frame updates, remote events, combat resolution, UI attributes, and VFX creation.
- Duplicating old reference code or extracting too much at once could roll back current systems like combat feedback, modular HUD, match series, or runtime stats.

## 3. Safe Extraction Order

### Phase 1: Extract MatchStats

Goal: move runtime match stat state and helper functions into a small module/service without changing behavior.

Suggested module: `src/ServerScriptService/Server/Gameplay/MatchStats.luau` or `src/ServerScriptService/Server/Gameplay/Services/MatchStatsService.luau`.

Input dependencies:

- Root instance for attributes: `Workspace.WOB_Generated`.
- Player participant identity, or simple owner checks passed in by the orchestrator.

Expected API:

- `MatchStats.init(root)`
- `MatchStats.resetForNewMatch()`
- `MatchStats.recordShotFired(participant)`
- `MatchStats.recordRicochet(projectile)`
- `MatchStats.recordTankHit(projectile)`
- `MatchStats.recordDamage(projectile, targetParticipant, damage)`
- `MatchStats.recordRoundResult(result)`
- `MatchStats.setMatchResult(result)`

Behavior requirements:

- Keep exact attribute names: `StatsShotsFired`, `StatsHits`, `StatsRicochets`, `StatsRicochetHits`, `StatsSelfHits`, `StatsDamageDealt`, `StatsDamageTaken`, `StatsRoundsWon`, `StatsRoundsLost`, `StatsMatchResult`.
- Keep stats on `Workspace.WOB_Generated`.
- Keep reset on server start and when a new match starts after `TargetWins`.
- Do not reset stats on every round.

### Phase 2: Extract RoundMatchState

Goal: isolate round and match series state while preserving all current server attributes.

Suggested module: `RoundMatchState.luau` or `RoundMatchService.luau`.

Owns:

- `roundState`.
- `matchState`.
- `setRoundResult`.
- `setMatchAttributes`.
- `resetMatchState`.
- `endRound`.
- `printMatchScore` if kept as debug.

Must preserve:

- `MatchConfig.EnableMatchSeries`.
- `MatchConfig.TargetWins`.
- `RoundResult`, `RoundEnded`, `PlayerWins`, `DummyWins`, `RoundNumber`, `TargetWins`, `MatchEnded`, `MatchResult`.
- Current result values: `Playing`, `Win`, `Lose`, `PlayerMatchWin`, `DummyMatchWin`.
- Existing reset branching: active round reset, next round after ended round, new match after match ended.

### Phase 3: Extract TankParticipantRegistry / TankCombat Helpers

Goal: isolate participant registration, lookup, health, damage, death, and armor-target resolution without changing the current two-tank world.

Suggested modules:

- `TankParticipantRegistry.luau`
- `TankCombat.luau`

Registry owns:

- Participant registration.
- `tankParticipants`, `tankParticipantsById`, `tankParticipantsByModel`.
- Armor hitbox to participant resolution.
- Model to participant resolution.

Combat owns:

- Health/max health/dead attribute get/set/reset helpers.
- Damage application and death darkening, if visual death behavior remains server-owned.
- Armor zone lookup may live here or in the registry.

Must preserve:

- Exactly two participants at first.
- `PlayerTankPrototype` and `DummyTank` model assumptions.
- Current tank attributes: `Health`, `MaxHealth`, `IsDead`.
- Current player/dummy win/lose outcomes.
- Current armor zone names and hitbox behavior.

### Phase 4: Extract ProjectileRuntime / ProjectileService

Goal: isolate projectile table lifecycle, raycast target selection, projectile updates, ricochet application, and projectile cleanup.

Suggested module/service: `ProjectileRuntime.luau` or `ProjectileService.luau`.

Owns:

- `projectiles` table.
- Projectile folder setup and projectile part creation.
- Projectile owner metadata.
- `createProjectile`.
- `updateProjectiles`.
- `destroyProjectile`.
- `destroyAllProjectiles`.
- `applyProjectileRicochet`.
- Map/tank raycast target assembly.

Inputs/callbacks:

- Participant registry for hitbox targets.
- Combat resolver callback for tank hit.
- VFX callbacks for muzzle/impact flashes.
- MatchStats callbacks for shot/ricochet/hit/damage stats.

Must preserve:

- Current speed, lifetime, damage, penetration, max bounce, damage/speed falloff.
- Wall ricochet behavior.
- Armor ricochet behavior.
- Self-hit only after ricochet.
- Projectile cleanup on `R` reset.
- Existing projectile visual compatibility.

### Phase 5: Extract TankMovement

Goal: move movement and layout calculations after combat/match/projectile state has been stabilized in modules.

Suggested module: `TankMovement.luau`.

Owns:

- `updateTank` movement math.
- Wall blocking/blockcast helpers.
- Overlap fallback.
- Clamp/un-stuck helpers.
- Body/turret yaw calculations if kept coupled to movement.

May remain separate:

- `TankLayout.luau` for body/turret/barrel/shoot point/armor hitbox placement.
- `SpawnResolver.luau` for SpawnPoints and fallback transforms.

Must preserve:

- WASD behavior.
- Reverse speed multiplier.
- Steering independent of throttle.
- Turret follows aim position.
- Current wall blocking and unstuck behavior.
- Spawn and reset placement.

### Phase 6: Add BotBrain v0

Goal: add the first bot behavior only after participant, match, projectile, and movement ownership boundaries are clearer.

Suggested module: `BotBrain.luau`.

Uses:

- TankParticipant data.
- Projectile service `TryShoot` or orchestrator-preserved `tryShoot`.
- Match/round state read-only checks.

Initial scope:

- Extremely simple bot behavior.
- No PvP generalization beyond using existing participant identity.
- No DataStore or menu.

Must preserve:

- Existing player controls.
- Existing dummy target behavior until BotBrain is explicitly enabled.
- Current match/HUD/combat behavior.

## 4. Future Module Ownership Summary

| Module/service | Should own | Should not own |
| --- | --- | --- |
| `MatchStats` | Runtime stat counters and `Stats*` attributes on `Workspace.WOB_Generated`. | Damage rules, match winner rules, HUD UI. |
| `RoundMatchState` | Round/match state, `MatchConfig`, match attributes, result transitions. | Projectile physics, movement, armor math. |
| `TankParticipantRegistry` | Participant records and lookups. | Damage math, movement, bot decisions. |
| `TankCombat` | Health/death helpers, armor hit resolution, damage application coordination. | Projectile lifetime/raycast loop, UI widgets. |
| `ProjectileRuntime` | Projectile creation, owner metadata, per-frame projectile update, ricochet, cleanup. | Round scoring ownership, player input. |
| `TankMovement` | Movement, wall blocking, body/turret yaw update. | Shooting, projectile hits, match scoring. |
| `TankLayout` | Visual part placement and armor hitbox layout. | Movement collision and combat results. |
| `SpawnResolver` | SpawnPoint/fallback transform resolution. | Match state and combat. |
| `BotBrain` | Bot decision loop, aim/shoot decisions. | Core projectile mechanics, DataStore, menus. |

## 5. What Must Remain In WOBGameplayServer Temporarily

Until several phases are complete, `WOBGameplayServer` should remain the thin orchestrator for:

- Roblox service acquisition.
- Runtime object discovery: `Workspace.WOB_Generated`, `Runtime`, `Map`, `TestObjects`, `Remotes`.
- Remote event connections.
- `RunService.Heartbeat` wiring.
- Calling movement and projectile updates in the current order.
- Passing callbacks between modules where direct dependencies would create cycles.
- VFX helper ownership, unless extracted as its own small visual-only phase.
- The reset flow coordinator until RoundMatchState and ProjectileRuntime are both extracted.
- Any one-off compatibility glue for the current modular HUD attributes.

Temporary orchestrator rule: if moving a block requires changing behavior, leave it in `WOBGameplayServer` for another phase.

## 6. Play Mode Checks Required After Each Extraction

Run these after every phase:

- Only one active `WOBGameplayServer`.
- No red errors in Output.
- Player movement still works.
- Tank cannot pass through current walls/cover.
- Turret aim still works.
- Player can shoot.
- Cooldown still works.
- Projectiles spawn visibly.
- Projectiles ricochet from walls.
- Projectiles ricochet from armor on no-pen/auto-ricochet.
- Armor/penetration still resolves by front/side/rear hitboxes.
- Enemy/dummy takes damage.
- Player can self-hit only after ricochet.
- Combat feedback still appears with existing text/types.
- WIN/LOSE still works.
- Match series reaches `MatchConfig.TargetWins`.
- Match attributes still update: `PlayerWins`, `DummyWins`, `RoundNumber`, `TargetWins`, `MatchEnded`, `MatchResult`.
- Runtime stats still update: `StatsShotsFired`, `StatsHits`, `StatsRicochets`, `StatsRicochetHits`, `StatsSelfHits`, `StatsDamageDealt`, `StatsDamageTaken`, `StatsRoundsWon`, `StatsRoundsLost`, `StatsMatchResult`.
- `R` reset restores both tanks.
- `R` reset clears projectiles.
- `R` reset preserves current-match stats except when starting a new match after final match result.
- Modular HUD remains unchanged.

Additional phase-specific checks:

- Phase 1: inspect `Workspace/WOB_Generated` attributes during Play Mode and confirm stats behavior is identical before/after extraction.
- Phase 2: finish a full first-to-`TargetWins` match and confirm round/match attributes exactly match the pre-extraction behavior.
- Phase 3: verify armor hitboxes still resolve to the same target tank and health/death attributes update exactly as before.
- Phase 4: fire multiple projectiles, reset during flight, and confirm cleanup and ricochet/self-hit behavior.
- Phase 5: test wall contact, reversing away from walls, turning near walls, and turret aim while moving.
- Phase 6: verify bot behavior can be disabled or removed without affecting the pre-bot player-vs-dummy baseline.

## 7. Recommended Commit Messages For Future Phases

1. `Extract runtime match stats from WOBGameplayServer`
2. `Extract round match state from gameplay orchestrator`
3. `Extract tank participant and combat helpers`
4. `Extract projectile runtime from gameplay orchestrator`
5. `Extract tank movement helper from gameplay orchestrator`
6. `Add BotBrain v0 using tank participants`

Each phase should include only code and documentation needed for that phase. Avoid bundling UI, scene, tuning, or feature work with decomposition commits.
