# Stable Fun Duel v0.1 Audit

Дата аудита: 2026-05-13.

## Preflight

Команды выполнены до кодовых изменений:

```text
pwd
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox

git status --short
 M src/ReplicatedStorage/Shared/Configs/VfxConfig.luau

git branch --show-current
main

git remote -v
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (fetch)
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (push)

git log --oneline -8
ef40f19 Add conflicting SoundId variants in VfxConfig
31e12c9 Update VFX assets and add new rbxl scene
bf8e2fc Add shared VFX assets folder
5854013 Add VFX template storage folder
7beaa09 Support particle texture bursts for shot VFX
68c3bdd Add configurable shot particle asset slots
fdfa22b Keep shot sound alive independently from muzzle flash
4fb8b7b Merge branch 'main' of https://github.com/Incube700/WorldOfBalance_Roblox
```

Рабочее дерево было не чистым до начала исправлений: изменен `src/ReplicatedStorage/Shared/Configs/VfxConfig.luau`. В этом файле также были committed conflict markers вокруг `Shot.SoundId`, поэтому файл был невалидным Luau еще до текущей задачи. Локальные изменения `Smoke.TextureId` и `ImpactFlash.TextureId` нужно сохранить.

## Current Working Flow

1. Игрок подключается, `PlayerPossessionService` создает или переиспользует динамический `PlayerTank_<UserId>`, подавляет Roblox character и назначает владельца танку.
2. `LobbyService.playerAssigned` переводит игрока в `PlayerMode = Lobby` и спавнит танк на elevated lobby spawn.
3. В лобби игрок может свободно ездить и стрелять без урона, потому что `LobbyService.isNoDamageProjectile` возвращает true вне active match.
4. `StartMatchRequestEvent` запускает Training против `DummyTank`, если активного матча нет.
5. `DuelPad` собирает очередь из двух игроков. До исправления дуэль стартовала сразу при двух игроках на паде.
6. `RoundMatchService.startTrainingMatch` или `startPvPMatch` настраивает active match, сбрасывает здоровье/статы/снаряды, применяет arena spawn transforms и переводит `GameState` в `Playing`.
7. `ProjectileService` создает снаряд, raycast'ит карту и hitboxes, а `ProjectileCombatService` решает penetration, ricochet, damage, self-hit и combat feedback.
8. При финальном результате `RoundMatchService` ставит `GameState = Result`, `LobbyService.onMatchEnded` переводит только участников в `PlayerMode = Result`.
9. Return to Lobby очищает снаряды, сбрасывает match state и возвращает участников на elevated lobby spawns. Rematch требует голоса обоих PvP-участников.

## Server Responsibilities

- `WOBGameplayServer.server.luau`: тонкий orchestrator. Поднимает remotes, runtime folders, регистрирует participants, инициализирует сервисы, принимает input/shoot/rematch/return requests, запускает heartbeat movement/projectiles.
- `PlayerPossessionService.luau`: player to tank ownership, скрытие humanoid character, input state per player.
- `TankParticipantRegistry.luau`: participant registry, owner/model attributes, health/death state, armor hitbox resolution.
- `TankSpawnResetService.luau`: spawn transform lookup, elevated lobby Y normalization, tank layout, armor hitbox layout, visibility and colors.
- `LobbyService.luau`: lobby/free-drive modes, training start, duel queue, return/rematch flow, no-damage rules outside match.
- `RoundMatchService.luau`: active match, round/match attributes, spawn application, match end callbacks.
- `ProjectileService.luau`: projectile lifecycle, projectile visuals, projectile raycast target collection, muzzle/impact effects.
- `ProjectileCombatService.luau`: armor math, penetration, ricochet, damage callbacks, combat feedback events.

## Client Responsibilities

- `WOBTankInputController.client.luau`: reads WASD/mouse, sends throttled `TankInputEvent`, sends shoot requests.
- `WOBTankPossessionCamera.client.luau`: finds owned tank by `OwnerUserId`, follows the physical focus part with scriptable top-down camera.
- `WOBAimLaser.client.luau`: local-only laser from current barrel/shoot point, using map and hitbox targets.
- `WOBRoundStatusOverlay.client.luau`: binds to modular HUD, shows health, reload, round/match result from replicated attributes.
- `WOBHudBootstrap.client.luau`: clones `StarterGui/HUD` into `PlayerGui/HUD` when needed.
- `WOBCombatFeedbackOverlay.client.luau`, `WOBImpactFeedbackOverlay.client.luau`, `WOBProjectileReadabilityOverlay.client.luau`: presentation-only combat readability.

## Movement And Collision Flow

1. Client sends throttle, steer, aim position.
2. Server validates `player -> participant` and `LobbyService.canParticipantDrive`.
3. Heartbeat updates `BodyYaw`, computes desired flat move from body yaw and throttle.
4. `TankMovementService.resolveTankMovement` tries full move, then X-only, then Z-only.
5. Collision check uses `Workspace:Blockcast` and `Workspace:GetPartBoundsInBox`.
6. Old obstacle detection only considered `map`, `Map/RicochetWalls`, `Map/Cover`, explicit `Wall_*`, `RicochetWall_*`, `Cover_Block_*` names.
7. `TankSpawnResetService.layoutTank` applies the final server state to Body/Turret/Barrel/ShootPoint and preserves lobby Y through spawn state normalization.

## Projectile And VFX Flow

1. `ProjectileService.tryShoot` validates cooldown, shoot point, match/lobby shooting rules.
2. `createProjectile` spawns a neon projectile with trail and owner metadata.
3. Muzzle VFX currently use procedural parts, optional particle `TextureId`, and separate `SFX_CannonShotEmitter`.
4. Projectile raycast includes map obstacles and active participant hitboxes.
5. Map hits create impact flash and bounce until max ricochets.
6. Tank hits call `ProjectileCombatService.handleProjectileTankHit`, which creates impact flash, resolves armor, sends combat feedback and applies damage when legal.
7. Current `VfxConfig` supports raw `TextureId` fields, but not cloned Toolbox templates yet.

## Known Bugs And Risks

- Critical: tanks can drive through lobby railings because `Lobby/Railings` is outside `Map` and names like `LobbyRailing_North` are not accepted by `isTankMovementObstacle`.
- Critical: `Blockcast` uses broad exclude params and only post-filters the first hit. A non-obstacle hit can hide a real obstacle behind it.
- High: movement overlap scans only `map`, so non-map containment parts are invisible to the fallback.
- High: committed conflict markers in `VfxConfig.luau` break Luau parsing and Rojo build until resolved.
- Medium: obstacle cache only remembered `RicochetWalls` and `Cover`, so dynamic/scene-repaired folders are easy to miss.
- Medium: DuelPad queue starts immediately at 2 players, with no cancellable countdown attributes for UI.
- Medium: turret yaw currently follows aim instantly and shoot direction uses mouse aim directly, so a future turret turn delay would be cosmetic unless shooting uses current turret facing.
- Low: Graphify skill and local `graphify` binary exist, but the documented workflow can generate a new `graphify-out` corpus. Do not run or install anything blindly for this sprint.

## Wall Clipping Root-Cause Hypotheses

Confirmed likely causes:

- Lobby railings are not in `Map`, while `TankMovementService.getTankMovementObstacleParts` only scans `map:GetDescendants()`.
- `LobbyRailing_*` names do not match `Wall_*`, `RicochetWall_*`, or `Cover_Block_*`.
- `findTankBlockcastObstacle` ignores any `Blockcast` result that is not recognized as an obstacle, instead of casting only against known obstacle parts.
- Scene parts with `CanQuery = false` cannot be detected by movement casts even if `CanCollide = true`.

Additional plausible causes to guard against:

- Arena boundary folders may be named `Boundary`, `Boundaries`, `BoundaryWalls`, or be loose `Wall_*` parts.
- Some cover/boundary parts may be outside `Map/RicochetWalls` and `Map/Cover`.
- Thin/low walls can be missed by a short cast box if scene repair created them below the body-center band.
- Spawns or transitions can place the tank partly inside a wall; overlap fallback must stop further penetration while allowing movement away.

## Safe Files To Change

- `src/ServerScriptService/Server/Gameplay/Movement/TankMovementService.luau`
- `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`
- `src/ServerScriptService/Server/Gameplay/Lobby/LobbyService.luau`
- `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
- `src/ServerScriptService/Server/Gameplay/VFX/CombatVfxService.luau`
- `src/ReplicatedStorage/Shared/Configs/VfxConfig.luau`
- `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`
- `src/ReplicatedStorage/Shared/Assets/VFX/.gitkeep`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBDuelPadVisual.client.luau`
- `docs/patches/CREATE_OR_REPAIR_ARENA_CONTAINMENT_COMMAND.lua`
- `docs/patches/CREATE_OR_REPAIR_DUELPAD_VISUAL_COMMAND.lua`
- `docs/VFX_TEMPLATE_SETUP.md`
- `docs/ARCHITECTURE_GRAPH.md`
- `docs/CODEX_TASKS.md`

Do not edit `.rbxl` directly. Scene changes must be Studio command scripts.

## Acceptance Criteria

Movement:

- Training tank cannot pass through arena walls, cover, ricochet walls, or boundary walls.
- Lobby tank cannot pass through elevated railings.
- Elevated lobby Y is preserved on spawn and return.
- Arena spawn remains at arena height.
- Movement is still server-authoritative and does not rely only on magic X/Z clamp.
- No `Out of local registers`, no new infinite yields, no severe output spam.

VFX:

- Empty `TemplateName` keeps old procedural/TextureId behavior.
- Valid template under `ReplicatedStorage/Shared/Assets/VFX` clones, pivots, emits particles, plays sounds and is cleaned by Debris.
- Bad template names do not crash and warn only once per missing template/effect.

DuelPad:

- Queue attributes replicate `DuelQueueCount`, `DuelQueueRequired`, `DuelCountdown`, `DuelState`.
- Counter shows `0/2`, `1/2`, `2/2`.
- Countdown starts only at `2/2`, lasts about 3 seconds, and cancels if a player leaves.
- Only the queued pair enters the duel; other lobby players stay in lobby.

Combat feel:

- Existing damage, ricochet, no-penetration and self-hit feedback remains server-decided and client-presented.
- Turret turn speed is configurable and shooting uses current turret facing if enabled by the new server flow.

Verification:

- `git diff --check`
- `rojo build default.project.json --output /private/tmp/wob-stable-fun-duel-v01-check.rbxm`
- Luau checks only if a local checker is available.

## Implemented Fix Notes

- Movement now collects obstacle parts from `Workspace/WOB_Generated`, not only `Map`, so elevated `Lobby/Railings` and arena boundary folders are visible to the server movement check.
- Movement `Blockcast` now uses an include filter containing known obstacle parts. This avoids the old failure mode where the first non-obstacle world hit could hide a wall behind it.
- `CREATE_OR_REPAIR_ARENA_CONTAINMENT_COMMAND.lua` marks repaired walls/railings with `WOBMovementObstacle = true`, sets `CanQuery = true`, and keeps the DuelPad trigger non-blocking.
- `VfxConfig.luau` conflict markers were removed and the local texture changes for smoke and impact flash were preserved.
- `CombatVfxService.luau` adds template lookup, clone pivoting, particle emit, sound playback and Debris cleanup for Toolbox-style VFX assets.
- DuelPad queue now has server attributes and a cancellable 3 second countdown before `startPvPMatch`.
- `TankConfig.Movement` now owns turret turn speed, and shooting uses the current server turret facing.
- Graphify was not run. `docs/ARCHITECTURE_GRAPH.md` provides a manual architecture graph instead.
