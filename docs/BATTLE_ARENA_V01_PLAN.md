# Battle Arena v0.1 Plan

Дата: 2026-05-14.

## Preflight

Перед изменениями выполнено:

- `pwd`: `/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox`
- `git status --short`: рабочее дерево уже было dirty до текущей задачи, включая `.rbxl`, docs, VFX/config files, `RoundMatchService`, `ProjectileService`, `WOBGameplayServer`, mobile/input files.
- `git branch --show-current`: `main`
- `git remote -v`: `origin https://github.com/Incube700/WorldOfBalance_Roblox.git`
- `git log --oneline -8`: последний коммит `b997c18 VFX templates: optional names and collector`
- conflict markers scan по `src docs default.project.json`: маркеры не найдены.

## 1. Battle Arena vs Duel

Stable Fun Duel v0.1 остается round-based режимом: игроки попадают в `InMatch`, смерть завершает раунд, серия идет до `MatchConfig.TargetWins`, затем появляется Result/Rematch/Return.

Battle Arena v0.1 это отдельный free-drive режим:

- вход из лобби через `Workspace.WOB_Generated.Lobby.ArenaPad`;
- бесконечная сессия без раундов и без match result;
- свободная стрельба между всеми участниками арены;
- смерть выключает контроль танка, увеличивает deaths и запускает respawn delay;
- убийца получает score/kills, victim получает death;
- игрок может выйти через Return to Lobby;
- upgrades действуют только в текущей arena session и сбрасываются при выходе.

## 2. Почему не смешивать с RoundMatchService

`RoundMatchService` владеет дуэльным контрактом: active match, round result, match score, result screen, rematch votes, round reset timers and final result transition. Если добавить туда arena deathmatch, смерть в арене начнет конкурировать с `RoundEnd`, `MatchEnd`, `GameState = Result` и duel score.

Arena должна жить отдельно, потому что ее смерть не означает конец раунда, score не является `PlayerWins/DummyWins`, а respawn не должен вызывать match reset или Result UI. Интеграция нужна только через безопасные hooks: projectile damage can target arena participants, death hook reports killer/victim to `ArenaCombatService`, lobby can enter/leave arena.

## 3. PlayerMode

Используем текущие режимы и добавляем arena modes:

- `Lobby`: свободное лобби.
- `QueuedForDuel`: ожидание DuelPad countdown.
- `InMatch`: Training/Duel, owned by `RoundMatchService`.
- `Result`: только duel/training final result.
- `InBattleArena`: активная arena session, controls/shooting enabled.
- `ArenaRespawning`: arena death countdown, controls/shooting disabled.

`Result` не используется для arena players.

## 4. Scene Objects

Scene changes делаются только через `docs/patches/*_COMMAND.lua`. Use `docs/patches/CREATE_OR_REPAIR_BATTLE_ARENA_COMMAND.lua` for initial creation. After manual arena moves, use `docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua` and `docs/patches/REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua` so the current arena position is preserved.
Lobby pads/contact zones следуют общему контракту из `docs/PAD_CONTACT_ZONE_CONTRACT.md`;
после ручного перемещения pad visual нужно запускать
`docs/patches/REPAIR_ALL_LOBBY_PADS_COMMAND.lua`, чтобы trigger и label снова совпали с visual/root.

Ожидаемый контракт:

- `Workspace.WOB_Generated.BattleArena`
- `BattleArena.Floor`
- `BattleArena.Boundaries`
- `BattleArena.Cover`
- `BattleArena.RicochetWalls`
- `BattleArena.SpawnPoints`
- `ArenaSpawn1` ... `ArenaSpawn8`
- `Workspace.WOB_Generated.Lobby.ArenaPad`
- `Workspace.WOB_Generated.Lobby.ArenaPad.Trigger`
- `Workspace.WOB_Generated.Lobby.ArenaPad.Label`

`Boundaries`, `Cover`, `RicochetWalls` должны иметь `Anchored = true`, `CanCollide = true`, `CanQuery = true`, `WOBMovementObstacle = true`. Ricochet walls также имеют `WOBRicochetSurface = true`. `ArenaPad` имеет `WOBPadType = "BattleArena"` и `RequiredPlayers = 1`.

## 5. Respawn

Когда arena participant погибает:

1. Сервер ставит tank dead/non-controllable flags.
2. `ArenaCombatService.OnParticipantKilled(killerParticipant, victimParticipant)` обновляет score/deaths.
3. PlayerMode жертвы становится `ArenaRespawning`.
4. На player ставятся `ArenaRespawnAt` и `ArenaRespawnDelay`.
5. Через `BattleArenaConfig.RespawnDelay` сервис проверяет session token.
6. Если игрок все еще в arena session, танк получает здоровье, colors reset, новый spawn из 8 точек, PlayerMode возвращается в `InBattleArena`.

Self-hit death допускается, но не дает kill score.

## 5.1 Collision Repair

Manual Studio moves can desync the visible arena, old blockers, and spawn points. Use `docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua` to list blockers, invisible parts, spawn positions, and stale obstacles near the preserved BattleArena center. Use `docs/patches/REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua` to repair the collision contract without resetting the arena to its default position.

Only `Boundaries`, `Cover`, and `RicochetWalls` should be movement obstacles. `Floor`, `SpawnPoints`, pads, triggers, labels, and VFX must not be movement obstacles.

BattleArena must also live in a separate XZ space from Lobby. If `AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua` reports `Lobby/BattleArena overlap XZ = true`, run `MOVE_BATTLE_ARENA_TO_SAFE_ZONE_COMMAND.lua` to shift the whole BattleArena root without moving Lobby or ArenaPad.

## 6. Score

Arena score хранится как session-only attributes на player:

- `ArenaScore`
- `ArenaKills`
- `ArenaDeaths`
- `ArenaStreak`
- `ArenaUpgradeIds`

Правила v0.1:

- Kill another player: `ArenaScore += BattleArenaConfig.KillScore`, `ArenaKills += 1`, `ArenaStreak += 1`.
- Victim death: `ArenaDeaths += 1`, `ArenaStreak = 0`.
- Self kill: only death/streak reset, no score.
- Leaving arena resets score/upgrades.

HUD v0.1 shows HP, ArenaScore, ArenaKills, ArenaDeaths, ArenaStreak, temporary upgrades, and respawn countdown in `WOBBattleArenaOverlay.client.luau`. Duel/training HUD remains owned by `WOBRoundStatusOverlay.client.luau`.

## 7. Temporary Upgrades

Upgrades are server-authoritative and session-only. They are enabled only while `PlayerMode = InBattleArena`.

Thresholds:

- `ArenaScore >= 2`: `DamageUp`, projectile damage `+20%`.
- `ArenaScore >= 4`: `FireRateUp`, shoot cooldown `-15%`.
- `ArenaScore >= 6`: `DoubleShot`, two projectiles with lateral offset.
- `ArenaScore >= 8`: `MoveSpeedUp`, movement speed `+10%`.
- `ArenaScore >= 10`: `TripleSpread`, three projectiles with `-8/0/+8` degree spread.

The service writes participant modifiers such as `ArenaDamageMultiplier`, `ArenaFireRateMultiplier`, `ArenaMoveSpeedMultiplier`, `ArenaProjectileCount`, and `ArenaSpreadDegrees`. Projectile and movement systems read these safely and ignore them outside `InBattleArena`.
