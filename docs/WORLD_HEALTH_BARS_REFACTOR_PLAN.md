# World Health Bars Refactor Plan

`WOBTankWorldHealthBars.client.luau` has been split into small client modules. The refactor is intended to preserve the existing HP/reload world bar behavior while making future changes safer.

The script currently owns too many responsibilities:

- scanning active tank models;
- cloning or building billboard UI;
- creating fallback UI;
- creating anchor parts;
- updating HP and reload bars;
- cleaning stale records;
- managing runtime folder paths;
- following tanks on heartbeat.

## Implemented Structure

```text
src/StarterPlayer/StarterPlayerScripts/Client/WorldHealthBars/
├── WorldHealthBarsConfig.luau
├── TankModelScanner.luau
├── HealthBarBillboardFactory.luau
├── HealthBarAnchorService.luau
├── TankHealthBarRecord.luau
├── WorldHealthBarsController.luau
└── WOBTankWorldHealthBars.client.luau
```

`WOBTankWorldHealthBars.client.luau` is now a thin entry point:

- gets `Players.LocalPlayer`;
- requires `WorldHealthBarsController`;
- creates the controller;
- calls `controller:Start()`.

## Module Ownership

| Module | Responsibility |
| --- | --- |
| `WorldHealthBarsConfig.luau` | Runtime constants, folder names, billboard size, offsets, max distance, discovery interval, watched attributes. |
| `TankModelScanner.luau` | Tank model detection and scanning `Workspace.WOB_Generated.TestObjects` / `Workspace.WOB_Generated.BattleArena`. |
| `HealthBarBillboardFactory.luau` | Resolve `ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard`, clone/configure it, build fallback UI, hide optional text labels. |
| `HealthBarAnchorService.luau` | Own `Workspace.WOB_Runtime.Client.HealthBarAnchors`, create/update/cleanup transparent anchor parts. |
| `TankHealthBarRecord.luau` | Own one tank model's billboard, anchor, bars, attribute connections, HP/reload updates, cleanup. |
| `WorldHealthBarsController.luau` | Own discovery loop, records map, Heartbeat anchor/reload updates, missing model cleanup. |

## Where To Change Things

- Size, offsets, max distance, folder names: `WorldHealthBarsConfig.luau`.
- Tank detection / active model roots: `TankModelScanner.luau`.
- Template lookup, fallback UI, bar hierarchy repair: `HealthBarBillboardFactory.luau`.
- Anchor folder path and anchor placement: `HealthBarAnchorService.luau`.
- HP/reload fill behavior and attribute listeners: `TankHealthBarRecord.luau`.
- Discovery cadence and record lifecycle: `WorldHealthBarsController.luau`.

## Anchor Placement

`HealthBarAnchorService.luau` should anchor bars from a stable hull part, not from full model bounds:

1. `Body`
2. `Hull`
3. `PrimaryPart`
4. `Model:GetBoundingBox()` only as a fallback

This prevents rotating turret/barrel parts from moving the HP/reload bar around the tank.

## Current Pass Scope

Done now:

- keep anchors under `Workspace.WOB_Runtime.Client.HealthBarAnchors`;
- anchor bars from `Body`/`Hull` before falling back to full model bounds;
- avoid moving combat/reload logic;
- avoid changing HP/reload visual behavior;
- keep discovery at the existing interval;
- keep Heartbeat limited to anchor movement and reload fill updates;
- keep fallback billboard support when the template is missing;
- implement the module split.

Deferred:

- changing UI layout;
- changing reload logic;
- changing tank detection rules beyond bug fixes.
