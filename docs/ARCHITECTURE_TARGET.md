# Architecture Target

This is the target shape for Ricochet Tanks / World Of Balance. It is a refactor roadmap, not permission to rewrite or add features in one pass.

## Server Target

### `WOBGameplayServer.server.luau`

Composition root only:

- create runtime folders;
- load configs and services;
- wire dependencies;
- bind remotes;
- start heartbeat/update loops.

It should not own combat, mode, projectile, reward, bot, VFX, or HUD behavior.

### `LobbyService`

Owns lobby state and mode entry:

- player mode transitions;
- lobby spawn/return;
- Duel queue entry/exit;
- Training entry;
- BattleArena entry.

It should call entry/session services, not perform raw pad geometry.

### `LobbyPadResolver`

Owns pad detection only:

- pad contract attributes;
- trigger detection;
- overlap checks.

It must not start matches, change player modes, or call Arena/Duel/Training services.

### `RoundMatchService` / Future `DuelSessionService`

Owns Duel/Training round flow:

- Duel uses exactly two participants;
- Training uses player plus practice dummy/bot participant;
- scores;
- round reset;
- win/loss/result publication;
- normalized Duel stats.

Future helpers:

- `RoundScoreTracker`;
- `RoundSpawnPlanner`;
- `RoundResultResolver`.

### `ArenaCombatService` / Future `BattleArenaSessionService`

Owns BattleArena state:

- many players;
- future bot participants;
- respawn;
- score/kills/deaths;
- future run upgrades.

Future helpers:

- `ArenaSessionStore`;
- `ArenaScoreTracker`;
- `ArenaRespawnPlanner`;
- `ArenaUpgradeRuntime`.

### `TankFactory`

Spawn adapter now, future spawn boundary:

- current: adapter over legacy prototypes;
- future: `BaseTankTemplate`;
- roles: Player/Bot/Dummy/DuelOpponent;
- loadout/stats/team/owner attributes;
- participant registration.

Do not delete legacy prototypes until all active spawn flows use the factory.

### `ArmorHitResolver`

Pure combat math:

- stable hull/body facing;
- armor zone detection;
- impact angle;
- effective armor;
- `Penetration` / `NoPen` / `Ricochet`;
- ricochet direction.

It should not own projectile lifetime, VFX, audio, stats, rewards, or UI.

### `ProjectileService`

Projectile lifecycle/simulation:

- fire request intake;
- projectile state creation until split;
- movement/lifetime;
- wall ricochet until split;
- muzzle safety until split.

It should not own armor math, UI, mode logic, or reward logic.

### `ProjectileCollisionService`

Raw collision:

- swept raycast;
- future radius/capsule checks;
- raycast filtering;
- active armor hitbox queryability.

It should not apply damage or VFX.

### `ProjectileCombatService`

Hit interpretation:

- calls `ArmorHitResolver`;
- applies penetration/no-pen/ricochet behavior;
- self-hit rules;
- damage/stats handoff.

It should not simulate projectile movement.

### Future `ProjectileVfxDispatcher`

Server VFX/event dispatch only:

- muzzle;
- impact;
- ricochet;
- no-pen;
- damage hit;
- death/explosion handoff.

It must not own combat rules.

### Economy Services

`PlayerWalletService` and reward services own economy/rewards:

- Duel rewards may grant currency;
- Duel power advantage should not come from permanent stat upgrades by default;
- BattleArena/Extraction can later allow run progression.

## Client Target

### Input Controllers

Send intent only:

- movement intent;
- turret/aim intent;
- fire intent.

No client combat authority.

### `WOBRoundStatusOverlay`

Round/score/result display:

- Duel/Training score;
- round result;
- match result;
- rematch/reset controls.

It should not make gameplay decisions.

### `WOBBattleArenaOverlay`

Arena display:

- arena score/stats;
- compact mobile stats;
- death/respawn panel;
- return/menu UI.

No combat authority.

### `HudVisibilityRules`

Single place for HUD visibility rules:

- legacy HP panel visibility;
- legacy reload panel visibility;
- round score visibility;
- result panel visibility;
- BattleArena stats visibility;
- compact mobile stats rules.

### World Health Bars

`WorldHealthBars/*` owns HP/reload bars only:

- scan tank models;
- create billboards;
- create/update anchors;
- update HP/reload fill;
- cleanup.

### Feedback Overlays

Visual feedback only:

- combat floating text;
- impact feedback;
- projectile readability;
- damage flash.

### Mobile Controls

Input UI only:

- movement joystick;
- aim stick;
- fire button.

No combat/mode authority.

## Mode Target

- Lobby = hub.
- Duel = normalized 1v1 top-down.
- Training/Practice = later proper bot practice.
- BattleArena = many players plus future bots/run upgrades.
- Future Extraction = separate later mode, not now.

Do not mix all modes immediately. The current priority remains a stable playable loop built around readable Ricochet Duel.
