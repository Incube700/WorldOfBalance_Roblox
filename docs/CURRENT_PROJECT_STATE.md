# Current Project State

This checkpoint documents the playable state before the next architecture refactor. It is intentionally descriptive only. No gameplay changes are part of this cleanup note.

## Current Playable Loop

### Lobby

- Players spawn into the lobby/free-drive flow.
- Lobby UI can start Training, Duel, or Battle Arena through the existing menu/pad paths.
- Return to Lobby still uses the existing `ReturnToMenuRequestEvent` path.

### Training

- Training remains the lightweight practice mode against the dummy/training target.
- This checkpoint does not intentionally change Training death, scoring, controls, or bot behavior.

### Duel

- Duel remains the separate PvP/training duel flow.
- Duel balance, round rules, death flow, and HUD are not part of the current Battle Arena revive work.

### BattleArena

- Battle Arena starts from the lobby flow and keeps the player inside the arena loop.
- Bots spawn gradually to reduce entry stutter.
- Arena HUD shows score, kills/deaths, level/XP, session Bolts, upgrades, shield state, health, and reload.
- World HP/reload bars and aim laser presentation have been smoothed for readability.

### Upgrade Choice

- Battle Arena upgrade cards use `UpgradeIconConfig` and `ImageLabel` icon slots.
- Desktop and mobile upgrade cards should both use configured image assets.
- The fallback star is only for missing or empty icon ids.
- Existing upgrade effects are preserved.

### Post-5 ArenaLevel

- `ArenaLevel` is prepared to continue past level 5.
- `MaxUpgradeLevel` / `CoreBuildLevel` keep the main combat build phase at level 5.
- Post-5 levels are prepared for records and future rewards, but do not grant infinite full-power upgrade offers by default.

### Paid Revive

- Paid revive is BattleArena-only.
- Cost is currently 5 Bolts.
- Paid revive preserves current run powers: level, XP, selected upgrades, current modifiers, score/session stats, and run state.
- Paid revive restores partial HP using the revive config.

### Free Respawn

- Free respawn is BattleArena-only.
- It costs 0 Bolts and keeps the player in BattleArena.
- It resets the current run powers/progression through the arena run reset path.
- It is the fallback when the player has too few Bolts or has exhausted paid revives.

### Exit To Lobby

- Exit/Return to Lobby remains available through the arena menu/fallback button.
- Exit to Lobby should not be the main death action.

## Recently Completed Work

- Upgrade icon config and `ImageLabel` pipeline for BattleArena upgrade cards.
- Mobile upgrade icon binding so configured assets show instead of fallback stars.
- Bot spawn staggering to reduce BattleArena entry stutter.
- BaseTankTemplate ArmorZones pre-bake for stable armor hitbox ownership.
- Aim laser smoothing as a visual-only fix.
- World HP/reload bar smoothing and performance toggles.
- BattleArena progression v2 config preparation: post-5 levels, branch metadata, future-only Vampire config.
- Paid revive for Bolts preserving run powers.
- Free respawn that resets run powers while staying in BattleArena.
- Performance audit docs and diagnostic toggles for bots, world bars, VFX, and combat feedback.

## Known Working Behaviors

- BattleArena starts and remains playable.
- Bots spawn gradually instead of all at once.
- Paid revive spends Bolts through the wallet spend path.
- Paid revive preserves the current run build.
- Free respawn resets current run powers and respawns in BattleArena.
- Upgrade icons use configured image assets.
- Mobile upgrade cards should use the same icon path as desktop.
- Duel and Training were not intentionally changed by the BattleArena revive/free-respawn work.

## Known Issues / Polish Debts

- Death panel needs final UX polish for text hierarchy, button states, and mobile spacing.
- Post-5 HUD messaging needs clearer language so players understand records/rewards versus core upgrade levels.
- VFX/projectile object churn is still not deeply optimized; the current pass added isolation toggles, not pooling.
- Studio can show DataStore warnings without API access enabled; this is expected in local Studio fallback cases.
- `ArenaCombatService` and `WOBGameplayServer` are growing too large and should be decomposed deliberately.
- Full upgrade branches are not implemented yet.
- Vampire gameplay is not active.
- King/Pedestal/record-holder systems are not implemented.

## Files Changed In Recent Checkpoint

### Configs

- `BattleArenaConfig.luau`: post-5 level prep, branch metadata, revive/free respawn config.
- `PerformanceConfig.luau`: diagnostic toggles for performance isolation.
- `AimAssistConfig.luau`: visual aim-laser smoothing config.
- `BotConfig.luau`: bot spawn/performance tuning.
- `HudConfig.luau`: world bar/HUD presentation tuning.
- `UpgradeIconConfig.luau`: existing icon asset ids must be preserved exactly.

### Arena And Economy

- `ArenaCombatService.luau`: ArenaLevel progression, upgrade validation metadata, paid revive, free respawn, revive pending state.
- `PlayerWalletService.luau`: `TrySpendBolts` and signed pending delta save behavior.
- `WOBGameplayServer.server.luau`: remote creation/wiring and arena service orchestration.

### Client Presentation

- `WOBBattleArenaOverlay.client.luau`: upgrade/death HUD presentation, revive button, free respawn button.
- `WOBAimLaser.client.luau`: visual-only laser smoothing.
- `WorldHealthBarsController.luau` and related world bar modules: smoother bars and safer update behavior.
- Combat feedback, impact feedback, projectile readability, and damage flash overlays: performance diagnostic toggles.

### Bots And Projectiles

- `BotService.luau`: staggered BattleArena spawn/performance controls.
- `ProjectileService.luau`: presentation VFX diagnostic gates; projectile gameplay should remain unchanged.

### Docs

- `BATTLE_ARENA_PROGRESSION_V2.md`
- `PERFORMANCE_FREEZE_AUDIT.md`
- `PERFORMANCE_RUNTIME_DEEP_DIVE.md`
- `ARMOR_PENETRATION_BALANCE_RU.md`
- `ARMORZONES_TEMPLATE_SETUP.md`

### Place / Template

- `RicochetTanksPrototype.rbxlx`: serialized Studio place/template state, including BaseTankTemplate ArmorZones and disabled legacy scripts.

## What Must Not Be Touched Casually

- `UpgradeIconConfig.luau` asset ids.
- Duel balance, Duel death flow, and Duel HUD behavior.
- Tank movement, shooting input, projectile collision, armor/damage, and reflect shield gameplay.
- Wallet spend/save path, especially signed pending Bolt deltas.
- BaseTankTemplate ArmorZones and their naming/ownership.
- Revive pending and free respawn flow.
- Existing remotes and upgrade protocol.
- Mobile controls layout and behavior.

## Recommended Next Phase

### A. Small Polish

- Finalize death panel text states: enough Bolts, not enough Bolts, max paid revives, free respawn, exit.
- Improve post-5 HUD messaging so players understand that levels continue while core upgrades stop at level 5.

### B. Architecture Audit

- Split `ArenaCombatService` responsibilities into focused services after behavior is locked:
  - `ArenaRunService`
  - `ArenaLevelService`
  - `ArenaUpgradeService`
  - `ArenaReviveService`
  - `ArenaRewardService`
- Keep the first refactor audit-only, then migrate one service at a time.

### C. Later Gameplay

- Implement Movement, Shooting, Defense, Vampire, and Ricochet branches after the architecture pass.
- Add VFX pooling once gameplay behavior is stable.
- Add record, pedestal, and king systems later, not during cleanup.
