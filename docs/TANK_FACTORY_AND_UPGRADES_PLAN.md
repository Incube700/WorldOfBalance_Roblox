# Tank Factory And Upgrades Plan

Current prototypes are temporary template sources and should not be deleted:

- `PlayerTankPrototype`
- `Player2TankPrototype`
- `DummyTank`

They exist because the current saved scene still stores the physical tank template sources there.

## Current Migration State

`TankFactory` is now the main server spawn path for player/dummy/duel-compatible tank creation.

Current behavior:

- `TankTemplateProvider` is the only code layer that resolves legacy template names.
- `TankSpawnRequest` normalizes role/profile/loadout requests.
- `TankStatsProvider` owns initial health/profile defaults.
- `TankFactory` reuses existing participants/models when present, clones templates when needed, applies attributes, and registers with `TankParticipantRegistry`.
- `WOBGameplayServer.server.luau` requests tanks by role/profile instead of cloning or selecting prototypes directly.
- Per-player lobby tanks use dynamic ids like `PlayerTank_<UserId>` through `TankFactoryConfig`.
- BattleArena currently reuses the already assigned factory-created player participant and does not spawn separate arena-only tanks yet.
- BattleArena Bot v0.1 spawns `ArenaBot_*` participants through `TankFactory` with `Role = ArenaBot` and `StatsProfileId = BotDefault`.

## Staged Migration

Stage 0:

- `TankFactory` adapter exists. Complete.

Stage 1:

- Player/dummy/duel-compatible tank creation goes through `TankFactory`. Complete.
- Legacy prototypes remain template sources only.

Stage 2:

- Bot v0.1 requests `Role = ArenaBot` with `BotDefault`. Complete for BattleArena filler bots.
- Bots are participants, not special-case scene objects.

Stage 3: **Editable BaseTankTemplate workflow — complete.**

- `TankTemplateProvider` now checks for `BaseTankTemplate` (priority 1) before role-specific legacy fallbacks.
- `BaseTankTemplateName = "BaseTankTemplate"` is defined in `TankFactoryConfig`.
- `TankArmorPartsService` supports both `ArmorZones` folder (new contract) and `Hitboxes` folder (legacy).
- `TankSkinApplier` module created: applies visual skin to the `Visuals` folder without touching armor or stats.
- `TankFactory` calls `TankSkinApplier.Apply` after clone.
- `docs/BASE_TANK_TEMPLATE_WORKFLOW.md` documents the structure, rules, and manual Studio workflow.
- `docs/patches/CREATE_BASE_TANK_TEMPLATE_PREVIEW_COMMAND.lua` provides a disabled-by-default Studio command to create the template from `PlayerTankPrototype`.
- Legacy prototypes (`PlayerTankPrototype` / `Player2TankPrototype` / `DummyTank`) remain as fallback sources and are not deleted.

Stage 4:

- Add loadout/stats/skin/upgrade application through factory dependencies.
- Duel ignores permanent stat upgrades by default.

Stage 5:

- More bot participants and session-based spawning use the same factory path as players.

Rule: do not delete legacy prototypes until all active spawn flows use `TankFactory`.

## Future Direction

Move toward a server-owned factory:

```text
ServerStorage.TankTemplates.BaseTankTemplate
TankFactory
TankRole
TankLoadout
TankStatsProvider
TankTemplateProvider
UpgradeConfig
```

## Future Data Model

`TankRole` examples:

- `Player`
- `DuelOpponent`
- `Dummy`
- `Bot`
- `ArenaPlayer`
- `ArenaBot`

`TankStatsProfile` examples:

- `DuelNormalized`
- `ArenaDefault`
- `TrainingPlayer`
- `TrainingDummy`
- `BotDefault`

`TankLoadout` examples:

- `SkinId`
- `WeaponId`
- `UpgradeLevels`

## Upgrade Currencies

Bolts can cover basic upgrades outside normalized Duel:

- HP
- Damage
- Reload
- Speed
- Projectile Speed

Crystals can cover rarer unlocks:

- skins;
- special weapons;
- VFX;
- sidegrades;
- premium cosmetics.

## Duel Normalization

Duel should stay skill-based and normalized by default. Permanent stat upgrades should not apply to Duel unless a separate non-ranked/fun mode explicitly allows it.

BattleArena and future Extraction can use progression because they are not pure competitive Duel.

## Not In This Pass

Do not delete prototypes, migrate the scene, create `ServerStorage.TankTemplates`, add a shop UI, add advanced bot AI, or make permanent upgrades active in Duel in the current factory/bot passes.
