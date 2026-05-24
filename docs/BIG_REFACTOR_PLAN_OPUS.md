# Big Refactor Plan (Opus)

Date: 2026-05-24

This document is the Phase 0 audit + plan for the architecture refactor described in
`OPUS_BIG_REFACTOR_PROMPT_WOB.md`. It records the current "god scripts", the desired
ownership boundaries, the exact first extraction target, and a rollback/validation
checklist. It does not change gameplay behavior.

It builds on (does not replace) the existing analysis in:

- `ARCHITECTURE_TARGET.md`
- `ARCHITECTURE_REFACTOR_AUDIT.md`
- `CONFIG_EXTRACTION_PLAN.md`
- `MOBILE_HUD_LAYOUT_PASS.md`
- `SOURCE_OF_TRUTH_CLEANUP.md`
- `SERVICE_CONTRACTS.md`
- `PROJECT_FOLDER_RECONCILIATION.md`
- `WOBGAMEPLAYSERVER_DECOMPOSITION_PLAN.md`

## Current god scripts (line counts at audit time)

Client:

- `WOBDuelHudOverlay.client.luau` — large; mixes UI construction, HP/reload display,
  result overlay, reward animation, combat feedback, training menu, visibility.
- `WOBPlayableShell.client.luau` — large; main shell/menu flow.
- `WOBRoundStatusOverlay.client.luau` — round/result/HUD binding mixed.
- `WOBBattleArenaOverlay.client.luau` — **864 lines**; UI construction + desktop/mobile
  layout + stats binding + death panel + return/menu flow + upgrade offer wiring.
- `WOBMobileControls.client.luau` — sensitive input UI; **do not change behavior**.

Server (planning only — not touched in this slice):

- `WOBGameplayServer.server.luau` — composition root that still owns helpers.
- `ArenaCombatService.luau` — arena session + score + respawn + upgrades + bots.
- `ProjectileService.luau` — spawn + simulation + muzzle safety + VFX dispatch.
- `LobbyService.luau` — modes + pad polling + queue + lobby spawn/return.

Already-extracted helper boundaries (reuse, do not duplicate):

- `Client/Hud/HudDeviceUtils.luau`, `Client/Hud/HudVisibilityRules.luau`,
  `Client/Hud/CompactStatsFormatter.luau`, `Client/Hud/BattleArenaUpgradeHud.luau`
- `Client/WorldHealthBars/*`
- `Server/Gameplay/Lobby/LobbyPadResolver.luau`
- `Server/Gameplay/Projectiles/ProjectileCollisionService.luau`,
  `ProjectileHitResult.luau`
- `Server/Gameplay/Combat/ArmorHitResolver.luau`
- `Server/Gameplay/Tanks/TankFactory.luau`

## Desired boundaries (HUD focus for this slice)

Per `ARCHITECTURE_TARGET.md` the overlay scripts should become display-only and split
into: a **Factory/Builder** (creates instances), a **Layout config/resolver** (decides
positions/sizes/visibility for desktop/mobile/mode), a **Presenter/Binder** (reads
attributes and updates the view), and **View/Widget records**.

This slice delivers the first two pieces for one overlay only:

1. A reusable, gameplay-free **`Client/Hud/HudWidgetFactory.luau`** holding the shared
   UI primitives (`addCorner`, `addStroke`, `createPanel`, `createLabel`, `createBar`,
   `styleButton`, `createButton`). These primitives currently live as local functions
   inside `WOBBattleArenaOverlay` (and similar copies in other overlays).
2. **`HudConfig.Layouts.BattleArena.Desktop` / `.Mobile`** — presentation-only layout
   tables (anchor/position/size/text size/transparency/corner radius/visibility) that
   the overlay reads when applying desktop vs mobile layout.

## Exact first extraction target

`WOBBattleArenaOverlay.client.luau`, because:

- it is the overlay most tied to future arena growth (multi-arena, HUD presets);
- it contains obvious, self-contained primitive builders (`makePanel`, `makeLabel`,
  `makeBar`, `styleButton`);
- its layout already cleanly separates into `applyDesktopLayout` /
  `applyMobileLayout`, which makes a presentation-config extraction low-risk.

`WOBDuelHudOverlay` primitive extraction is deferred to a later slice (its result/reward
flow is sensitive). Server/Arena splits (Phase 3/4) are planning-only here.

## What is intentionally NOT touched

- No gameplay rules, remotes, root attributes, or attribute names change.
- No `.rbxl` / `.rbxlx` / `default.project.json` change.
- No mobile-controls behavior change (`WOBMobileControls`, `MobileControlsConfig` —
  note these already have unrelated uncommitted local edits, left as-is).
- No scene mutation, no `docs/patches` scripts run.
- Responsive math in `applyMobileLayout` (viewport-driven width clamps) stays in the
  overlay; only static presentation constants move into config.

## Rollback / validation checklist

Reversibility: changes are limited to one new client module, the existing overlay, and
an additive `HudConfig.Layouts` table. Each can be reverted independently with `git`.

Automated (run in the repo):

```bash
git diff --check
grep -R "<<<<<<<\|=======\|>>>>>>>" -n src docs --exclude-dir=.git
rojo build default.project.json --output /tmp/wob-big-refactor-check.rbxm
```

Manual Studio checks after sync:

1. Main menu opens; Training starts.
2. Duel HUD appears only in Duel/Training contexts as before.
3. BattleArena HUD appears in arena mode (HP top-left, score top-right).
4. Mobile: MOVE/AIM/FIRE not covered; compact HP/score/Menu layout intact.
5. Desktop: larger panels and Return-to-Lobby button intact.
6. Reload / world health bars still update.
7. Damage / death / respawn / reward feedback still appears.
8. Return to Lobby from BattleArena works (button + Menu popup).
9. No duplicate HUD ScreenGuis after respawn / mode switch.
