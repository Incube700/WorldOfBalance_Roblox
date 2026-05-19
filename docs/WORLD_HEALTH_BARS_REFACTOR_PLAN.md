# World Health Bars Refactor Plan

`WOBTankWorldHealthBars.client.luau` is intentionally left mostly intact in this stabilization pass.

The script currently owns too many responsibilities:

- scanning active tank models;
- cloning or building billboard UI;
- creating fallback UI;
- creating anchor parts;
- updating HP and reload bars;
- cleaning stale records;
- managing runtime folder paths;
- following tanks on heartbeat.

## Future Target Structure

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

`WOBTankWorldHealthBars.client.luau` should become a thin entry point.

## Current Pass Scope

Done now:

- keep anchors under `Workspace.WOB_Runtime.Client.HealthBarAnchors`;
- avoid moving combat/reload logic;
- avoid changing HP/reload visual behavior;
- document the future split.

Deferred:

- extracting scanner/factory/services;
- changing UI layout;
- changing reload logic;
- changing tank detection rules beyond bug fixes.
