# Cleanup Candidates

This is a cleanup map, not an instruction to delete files. The current build is playable and should be preserved. Inspect each candidate in Studio/Rojo before changing anything.

## 1. Duplicate / Legacy Scripts To Inspect

| Candidate | Why Inspect | Suggested Action |
| --- | --- | --- |
| `RicochetTanksPrototype.rbxlx` `ServerScriptService/Services/WOBGameplayServer` | Legacy Studio-owned gameplay server can duplicate the Rojo-managed server if enabled. | Confirm disabled/absent in Studio before Play Mode. Remove later only in a dedicated Studio cleanup. |
| `RicochetTanksPrototype.rbxlx` `ServerScriptService/Services/WOBPerformanceServer` | Legacy Studio-owned performance server can duplicate the Rojo-managed replacement if enabled. | Confirm disabled/absent in Studio before Play Mode. Remove later only after a saved backup. |
| `docs/studio_scripts_snapshot/*` | Historical snapshot of old Studio scripts. Useful for archaeology, but not runtime source of truth. | Keep archived or move under a clearer archive folder after confirming no active references. |
| Root `BattleArenaUpgradeHud.luau` | Looks like a local legacy/reference copy. Runtime path should be `src/StarterPlayer/StarterPlayerScripts/Client/Hud/BattleArenaUpgradeHud.luau`. | Compare once, then delete only if confirmed unused and not referenced by docs/tasks. |
| `docs/patches/*_COMMAND.lua` | Studio command snippets from previous repair passes. | Keep as historical repair scripts or archive by topic. Do not run blindly. |
| `RicochetTanksPrototype_snapshot.rbxlx` | Snapshot place file may be a backup, not source of truth. | Confirm whether it is still needed. Do not commit future snapshot churn unless intentional. |

## Root File Inspection Notes

Checked during cleanup audit:

| File | Git State | Current Finding | Cleanup Recommendation |
| --- | --- | --- | --- |
| `BattleArenaUpgradeHud.luau` | Tracked | Referenced by `README_RU.md` as a manual fallback/reference for the upgrade HUD refactor. Not part of `default.project.json`; runtime module is under `src/StarterPlayer/StarterPlayerScripts/Client/Hud/`. | Do not delete until `README_RU.md` is updated or the fallback workflow is declared obsolete. |
| `apply_arena_upgrade_hud_refactor.py` | Tracked | Referenced by `README_RU.md` as a one-off refactor helper. Not part of Rojo runtime. | Candidate for archive/removal only after confirming the refactor helper will not be reused. |
| `RicochetTanksPrototype.rbxl` | Tracked | Binary Studio place. Several docs say not to overwrite or delete casually. | Keep unless the team intentionally switches source of truth to `.rbxlx` or Rojo-only place generation. |
| `RicochetTanksPrototype.rbxlx` | Tracked | Serialized current playable/template state; contains BaseTankTemplate ArmorZones and disabled legacy scripts. | Keep and treat as important until template/place ownership is fully documented. |
| `RicochetTanksPrototype_snapshot.rbxlx` | Tracked | Older snapshot referenced by historical possession/PvP docs. | Archive or remove only after confirming those docs no longer need the old snapshot. |
| `ricTancs.rbxl` | Tracked | Extra binary place file with unclear current role. Not referenced by current Rojo project. | Highest-priority candidate for human confirmation before removal/archive. |
| `.DS_Store` | Ignored by `.gitignore` | Local macOS metadata file exists in the workspace but is ignored. | Safe to delete locally in a cleanup-only shell step, but not necessary for build hygiene. |

## 2. Large Files / God Scripts

These files are candidates for audit and decomposition, not immediate refactor.

| File | Approx Size | Current Risk |
| --- | ---: | --- |
| `src/ServerScriptService/Server/Gameplay/Arena/ArenaCombatService.luau` | about 2000 lines | Owns run state, level/XP, upgrades, revive/free respawn, arena damage rules, shield state, and session attributes. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBPlayableShell.client.luau` | about 1900 lines | Owns menu/start/result/stats UI and has accumulated popup/layout fixes. |
| `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau` | about 1300 lines | Orchestrates many systems and the main heartbeat. |
| `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau` | about 1100 lines | Mixes projectile lifecycle, raycasts, and presentation VFX hooks. |
| `src/StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau` | about 1000 lines | Owns BattleArena HUD, upgrade popup integration, death panel, revive/free respawn UI. |
| `src/ServerScriptService/Server/Gameplay/Bots/BotService.luau` | about 430 lines | Smaller than the others, but owns bot spawning, lifecycle, and performance gates. |

Suggested future split targets:

- `ArenaRunService`
- `ArenaLevelService`
- `ArenaUpgradeService`
- `ArenaReviveService`
- `ArenaRewardService`
- `ProjectileVfxPresenter` or similar presentation-only module
- `BattleArenaDeathPanel` client module

## 3. Old Docs That May Be Outdated

Do not delete docs during gameplay work. Mark or archive after reviewing against the current state.

| Doc | Why It May Be Outdated |
| --- | --- |
| `docs/ARENA_V2_DESIGN.md` | May predate current BattleArena progression v2 config and revive/free respawn flow. |
| `docs/BATTLE_ARENA_V01_PLAN.md` | Early plan likely superseded by current BattleArena implementation. |
| `docs/BATTLE_ARENA_COLLISION_AND_HUD_DEBUG.md` | Useful history, but may not reflect current HUD/icon/death panel state. |
| `docs/BOT_V01.md` and `docs/BOT_BRAIN_PLAN.md` | May predate current staggered BattleArena bot spawning. |
| `docs/MOBILE_PERFORMANCE_AUDIT.md` and `docs/MOBILE_PERFORMANCE_PASS.md` | Keep, but reconcile with `PERFORMANCE_FREEZE_AUDIT.md` and current toggles. |
| `docs/PLAYTEST_POLISH_MASTER_PASS.md` and `docs/PLAYTEST_V02_*` | May be old playtest scope rather than current checkpoint. |
| `docs/WOBGAMEPLAYSERVER_DECOMPOSITION_PLAN.md` | Still relevant, but should be refreshed after documenting current Arena service responsibilities. |

## 4. Studio-Owned Assets / Templates To Document

| Asset / Template | Current Note |
| --- | --- |
| `RicochetTanksPrototype.rbxlx` | Still contains the tuned playable scene, map, lobby, and serialized template state. Treat as important, not disposable. |
| BaseTankTemplate ArmorZones | Prebaked armor zones are now part of the working armor/penetration setup. Do not regenerate or rename casually. |
| BattleArena map/spawns/control objects | Some scene-owned objects may not be represented as standalone Rojo assets. Document before moving. |
| UI templates in Studio/serialized place | Confirm whether a UI is template-owned or runtime-created before changing layout in code. |
| VFX templates | Some are archived because they contained unsafe scripts. Preserve clean template ownership before deleting archives. |

## 5. Generated / Temp Files That Should Not Be Committed

| File Pattern | Note |
| --- | --- |
| `/tmp/wob-*.rbxm` | Local Rojo build validation outputs. These should remain outside the repo. |
| `*.tmp`, `*.bak`, editor swap files | Do not commit. |
| `.DS_Store` | macOS local metadata, never commit. |
| One-off generated scripts such as `apply_arena_upgrade_hud_refactor.py` | Confirm whether they are still useful. If not, remove in a cleanup-only commit. |
| Extra `.rbxlx` snapshots | Keep only intentional, named backups. Avoid committing automatic or stale snapshots. |
| Extra `.rbxl` place files such as `ricTancs.rbxl` | Confirm purpose before removal; binary place files are easy to lose and hard to diff. |

## 6. Suggested Cleanup Order

1. Freeze behavior with this current-state doc and a successful Rojo build.
2. In Studio, verify disabled legacy scripts:
   - `ServerScriptService/Services/WOBGameplayServer`
   - `ServerScriptService/Services/WOBPerformanceServer`
   - any old projectile visual enhancer scripts.
3. Confirm source of truth for templates:
   - BaseTankTemplate ArmorZones
   - BattleArena map/spawn objects
   - UI/VFX templates.
4. Archive or remove unused root/reference files in a docs-only or hygiene-only commit.
5. Reconcile old docs into one current index:
   - current state
   - performance audit
   - progression v2
   - architecture refactor plan.
6. Plan architecture work without changing behavior:
   - first extract read-only helpers,
   - then move one Arena responsibility at a time,
   - validate BattleArena, Duel, Training, mobile controls, revive/free respawn after each step.
7. Only after cleanup and architecture stabilization, resume gameplay features such as branches, VFX pooling, records, pedestal, or king systems.
