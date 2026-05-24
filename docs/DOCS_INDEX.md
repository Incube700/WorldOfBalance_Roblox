# Documentation Index

Use this file as the current documentation entry point before cleanup or architecture work. Older docs are still useful, but many describe previous migration stages and should not be treated as current instructions without verification.

## Status Labels

| Status | Meaning |
| --- | --- |
| Current | Safe starting point for the current playable build. |
| Reference | Useful background, but verify against current code before acting. |
| Historical | Previous plan/audit; do not follow as live instructions without review. |
| Manual-only | Studio command or scene workflow; never run blindly. |
| Archive | Kept for recovery/history, not active source of truth. |

## Read First

| Doc | Status | Use |
| --- | --- | --- |
| `docs/CURRENT_PROJECT_STATE.md` | Current | Compact snapshot of what is playable now and what must be preserved. |
| `docs/CLEANUP_CANDIDATES.md` | Current | Cleanup map for root files, legacy scripts, large files, snapshots, and safe cleanup order. |
| `docs/DOCS_INDEX.md` | Current | This index. |
| `docs/TECH_CONTEXT.md` | Reference | Rojo mappings, run workflow, and broad project structure. Some preferred future folder examples are not yet fully implemented. |
| `docs/SOURCE_OF_TRUTH_CLEANUP.md` | Reference | Source-of-truth rules for Rojo, Studio scene assets, templates, and archives. |
| `docs/SAFE_PATCH_WORKFLOW.md` | Reference | Safety rules for patching Studio-owned scene/template state. |

## Current BattleArena / Polish Docs

| Doc | Status | Use |
| --- | --- | --- |
| `docs/BATTLE_ARENA_PROGRESSION_V2.md` | Current | Post-5 ArenaLevel model, branch metadata, paid revive, free respawn, future revive notes. |
| `docs/PERFORMANCE_FREEZE_AUDIT.md` | Current | Duplicate script audit, high-frequency loop notes, performance toggles, manual Studio checks. |
| `docs/PERFORMANCE_RUNTIME_DEEP_DIVE.md` | Reference | Deeper runtime analysis and follow-up profiling context. |
| `docs/ARMOR_PENETRATION_BALANCE_RU.md` | Current | Russian armor/penetration/angle balance explanation. |
| `docs/ARMORZONES_TEMPLATE_SETUP.md` | Current | BaseTankTemplate ArmorZones pre-bake state and Studio verification workflow. |
| `docs/TANK_WORLD_HEALTH_BARS.md` | Reference | Original world health bars design; verify against current smoothed implementation. |
| `docs/MOBILE_HUD_LAYOUT_PASS.md` | Reference | Mobile HUD history and layout constraints. |

## Architecture / Refactor Planning

Use these only after freezing behavior with the current state docs.

| Doc | Status | Use |
| --- | --- | --- |
| `docs/ARCHITECTURE_REFACTOR_AUDIT.md` | Reference | Architecture risks and refactor observations. |
| `docs/ARCHITECTURE_TARGET.md` | Reference | Target architecture direction. |
| `docs/ARCHITECTURE_GRAPH.md` | Reference | Dependency graph/context. |
| `docs/WOBGAMEPLAYSERVER_DECOMPOSITION_PLAN.md` | Reference | Server decomposition ideas; refresh before implementing because BattleArena responsibilities changed. |
| `docs/SERVICE_CONTRACTS.md` | Reference | Service boundaries/contracts. |
| `docs/FEEDBACK_PRESENTATION_ARCHITECTURE.md` | Reference | Presentation/VFX feedback separation. |
| `docs/PROJECTILE_WEAPON_ARCHITECTURE.md` | Reference | Projectile/weapon architecture notes. |
| `docs/WORLD_HEALTH_BARS_REFACTOR_PLAN.md` | Reference | World bars decomposition ideas. |
| `docs/BIG_REFACTOR_PLAN_OPUS.md` | Reference | Broad refactor plan; do not execute wholesale. |

## Gameplay / Design Backlog

These are idea sources, not current implementation instructions.

| Doc | Status | Use |
| --- | --- | --- |
| `docs/GDD.md` | Reference | Design north star. Verify details against current prototype. |
| `docs/GAME_DIRECTION_ROADMAP.md` | Reference | Product/design direction. |
| `docs/IDEAS_BACKLOG.md` | Reference | Backlog ideas. |
| `docs/ARENA_V2_DESIGN.md` | Historical | Earlier arena v2 plan; superseded in part by `BATTLE_ARENA_PROGRESSION_V2.md`. |
| `docs/BATTLE_ARENA_V01_PLAN.md` | Historical | Early BattleArena plan; useful history only. |
| `docs/BOT_V01.md` | Historical | Early bot plan; current bot behavior includes later spawn staggering/performance work. |
| `docs/BOT_BRAIN_PLAN.md` | Reference | Bot design notes, not an active task list. |
| `docs/COSMETIC_UNLOCKS_AND_SHOP_PLAN.md` | Reference | Future shop/progression ideas. Do not touch during arena cleanup/refactor. |
| `docs/TANK_SKIN_SYSTEM_PLAN.md` | Reference | Future cosmetics/skin system. |

## Historical / Verify Before Use

| Doc | Status | Reason |
| --- | --- | --- |
| `README_RU.md` | Historical | Describes the old upgrade HUD refactor ready pack and references root helper files. Keep until those helpers are intentionally archived. |
| `docs/START_HERE_RU.md` | Historical | Mentions older Studio-owned `WOBGameplayServer` manual patch workflow and old visible-sprint scope. Do not use as current start point. |
| `docs/PROJECT_AUDIT.md` | Historical | Early large audit with Studio snapshots and patch instructions. Useful archaeology only. |
| `docs/PROJECT_FOLDER_RECONCILIATION.md` | Historical | Folder reconciliation from an older state. |
| `docs/WOBGAMEPLAYSERVER_ROJO_MIGRATION_PLAN.md` | Historical | Migration context; Rojo-managed gameplay server is now active. |
| `docs/POSSESSION_CONTRACT_REVIEW.md` | Historical | Earlier possession and place-file audit. |
| `docs/PVP_POSSESSION_STABILITY_AUDIT.md` | Historical | Earlier PvP stability audit. |
| `docs/STABLE_FUN_DUEL_V01_AUDIT.md` | Historical | Duel audit history. Do not treat as current Duel task scope. |
| `docs/STABLE_FUN_DUEL_GAMEPLAY_ADVANCEMENT.md` | Historical | Older Duel improvement plan. |
| `docs/STABLE_FUN_DUEL_VFX_AND_MOVEMENT_PASS.md` | Historical | Older VFX/movement pass notes. |
| `docs/MOBILE_PERFORMANCE_AUDIT.md` | Historical | Earlier mobile audit; compare with current performance docs. |
| `docs/MOBILE_PERFORMANCE_PASS.md` | Historical | Earlier mobile performance pass. |
| `docs/PLAYTEST_V02_SCOPE.md` | Historical | Older playtest scope. |
| `docs/PLAYTEST_V02_TEST_SCRIPT.md` | Historical | Older playtest script. |
| `docs/PLAYTEST_POLISH_MASTER_PASS.md` | Historical | Older polish plan. |

## Manual Studio Commands

| Path | Status | Rule |
| --- | --- | --- |
| `docs/patches/*_COMMAND.lua` | Manual-only | Run only in Roblox Studio, usually outside Play Mode, after reading the command header and making a backup. |
| `docs/patches/*README*` / `*_STEPS.md` | Reference | Historical/manual Studio instructions. Verify against current Rojo-managed source first. |
| `docs/studio_scripts_snapshot/*` | Archive | Old Studio script snapshots, not runtime source of truth. |
| `docs/archive/*` | Archive | Recovery/history only. Do not restore without a clear reason. |

## Asset / Template Docs

| Doc | Status | Use |
| --- | --- | --- |
| `docs/BASE_TANK_TEMPLATE_WORKFLOW.md` | Reference | Tank template workflow. Verify against current ArmorZones pre-bake doc. |
| `docs/HUD_TEMPLATE_WORKFLOW.md` | Reference | HUD template ownership notes. |
| `docs/VFX_TEMPLATE_SETUP.md` | Reference | VFX template setup and manual Studio steps. |
| `docs/VFX_TEMPLATE_SOURCE_AUDIT.md` | Reference | VFX source audit. |
| `docs/VFX_RECOVERY_REPORT.md` | Reference | Recovery history for VFX templates. |
| `docs/VFX_ASSET_NORMALIZER_WORKFLOW.md` | Reference | Asset normalization workflow. |
| `docs/UI_TEMPLATE_DUPLICATES_AUDIT.md` | Reference | UI template duplicate history. |

## How To Use This Index

1. For current work, start with `CURRENT_PROJECT_STATE.md`.
2. For cleanup, use `CLEANUP_CANDIDATES.md`.
3. For BattleArena progression/revive decisions, use `BATTLE_ARENA_PROGRESSION_V2.md`.
4. For performance/stutter work, use `PERFORMANCE_FREEZE_AUDIT.md` first.
5. For architecture work, read current docs first, then architecture refs. Do not execute old migration plans wholesale.
6. For any Studio command, stop and confirm the live Explorer path, whether it mutates the scene, and whether it is still compatible with the current Rojo-managed code.
