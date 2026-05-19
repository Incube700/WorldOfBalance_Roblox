# Tank World Health Bars

## Goal

Combat readability now uses small world-space bars above active tank models. The top green bar shows HP, and the thin blue bar below it shows reload progress. Both bars are client-side UI driven by replicated tank attributes; combat, cooldown, and damage authority stay on the server.

## Server Attributes

Tank models expose:

- `CurrentHealth`, `Health`, and `HP`
- `MaxHealth`
- `IsDead` and `IsAlive`
- `OwnerName` and `OwnerUserId`
- `TankId` and `TankParticipantId`

Damage events also update:

- `LastDamageSerial`
- `LastDamageAmount`
- `LastDamageAt`
- `LastDamageAtServerTime`
- `LastDamageWasLethal`

`LastDamageSerial` only increments after real damage is applied. Ricochets and no-penetration hits should not move the serial.

Accepted shots also publish presentation-only reload attributes:

- `LastShotAtServerTime`
- `ReloadDuration`
- `ReloadProgress`
- `ReloadReady`

These attributes are written after the server accepts a shot in `ProjectileService`. They only drive UI fill state and must not be used as client-side shooting authority.

## Template

Run this outside Play Mode to rebuild the real editable template:

```lua
docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua
```

It creates or repairs:

```text
ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard
```

Then run this outside Play Mode to create a disposable world preview:

```lua
docs/patches/CREATE_TANK_HEALTH_BAR_PREVIEW_COMMAND.lua
```

The real editable template lives here:

```text
ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard
```

The preview clone lives under:

```text
Workspace.WOB_Debug.UiPreview.HPBarPreviewPart
```

Edit the template in `ReplicatedStorage`, then rerun the preview command. Do not edit the runtime clone in `PlayerGui`; that clone is created during Play and will be recreated.

The template is a compact `BillboardGui` with this clean hierarchy:

- `Root`
- `Root.PlayerName` hidden
- `Root.BarsRoot`
- `Root.BarsRoot.BarBack`
- `Root.BarsRoot.BarBack.RedBar`
- `Root.BarsRoot.BarBack.GreenBar`
- `Root.BarsRoot.BarBack.HpText` hidden
- `Root.BarsRoot.ReloadBack`
- `Root.BarsRoot.ReloadBack.ReloadBar`

`default.project.json` keeps `ReplicatedStorage.Shared.Assets.UI` protected with `$ignoreUnknownInstances = true`, matching the VFX template safety pattern.

`BillboardGui.Size` controls the screen-space size of the HP/reload bar. Current target is `UDim2.fromOffset(68, 14)`, compact enough for mobile while still readable above a tank.

`BillboardGui.StudsOffset` is kept at `Vector3.zero`; the runtime client uses a transparent anchor part and recalculates the Y offset from each tank model bounding box so the bar sits above taller or shorter tanks.

`GreenBar` must be a child of `BarBack`, not a loose sibling elsewhere. `BarBack.ClipsDescendants = true` keeps the green fill clipped inside the bar frame.

`ReloadBar` must be a child of `ReloadBack`. It is blue/cyan and clips inside the reload frame just like HP.

The fill changes by width:

```lua
GreenBar.Size = UDim2.new(ratio, 0, 1, 0)
ReloadBar.Size = UDim2.new(reloadRatio, 0, 1, 0)
```

The red HP bar stays full width behind `GreenBar`. The dark reload background stays full width behind `ReloadBar`. Do not represent HP loss or reload progress by only changing color; the width has to shrink/fill from left to right.

Sizing/color tuning lives in:

- `docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua` for the editable Studio template.
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankWorldHealthBars.client.luau` for runtime fallback/layout repair.
- `src/ReplicatedStorage/Shared/Configs/HudConfig.luau` for enabling world bars and hiding duplicate top HP/reload HUD panels.

## Top HUD Cleanup

World bars are the primary combat HP readout. The old modular top HUD should not duplicate large `Player HP` and `Enemy HP` blocks in BattleArena or on mobile.

Current rules:

- BattleArena hides its large top HP panel when `HudConfig.WorldHealthBars.HideTopHpPanelsInBattleArena = true`.
- Mobile Duel/Training hides the modular `PlayerStatusPanel` and `EnemyStatusPanel` when `HideTopHpPanelsOnMobile = true`.
- Desktop Training/Duel can still keep top HP panels while the layout is being tuned, because `HideTopHpPanelsInTraining` and `HideTopHpPanelsInDuel` default to `false`.
- Large top Reload is temporary. On mobile, it is hidden when `HudConfig.CombatHud.CompactReload = true`; the thin blue world reload bar remains.
- `WOBHudBootstrap` keeps the base `HUD` disabled by default outside `InMatch`, so stale Studio HUD panels do not sit behind lobby/BattleArena UI.

## Client Runtime

`WOBTankWorldHealthBars.client.luau`:

- scans active tank models about once per second;
- clones `TankHealthBillboard` into `PlayerGui/WOBTankWorldHealthBars`;
- sets `BillboardGui.Adornee` to a lightweight client anchor part above the tank bounds;
- updates HP from health attributes;
- updates reload fill from server-published reload attributes on `Heartbeat`;
- removes bars when tank models are removed or deactivated;
- hides dead bars after a short grace delay.

If a tank has no reload attributes yet, the reload bar displays full/ready. This keeps enemy or dummy tanks readable without adding fake client authority.

Tank detection supports player tanks, `DummyTank`, `Player2TankPrototype`, BattleArena tanks, and future bots that expose the same attributes.

## Duplicate Check

After a round reset or BattleArena respawn:

- there should be one world HP bar per active tank;
- each bar should contain one green HP fill and one blue reload fill;
- old bars should disappear when old tank models are removed or marked inactive;
- `PlayerGui.WOBTankWorldHealthBars` should not fill with duplicate BillboardGui clones.
