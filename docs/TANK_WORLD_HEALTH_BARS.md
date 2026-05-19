# Tank World Health Bars

## Goal

Combat readability now uses small world-space HP bars above active tank models. The bar is client-side UI driven by replicated tank attributes; combat and damage authority stay on the server.

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
- `Root.PlayerName`
- `Root.BarBack`
- `Root.BarBack.RedBar`
- `Root.BarBack.GreenBar`
- `Root.BarBack.HpText`

`default.project.json` keeps `ReplicatedStorage.Shared.Assets.UI` protected with `$ignoreUnknownInstances = true`, matching the VFX template safety pattern.

`BillboardGui.Size` controls the screen-space size of the HP bar. Current target is `UDim2.fromOffset(130, 42)`, small enough for mobile while still readable.

`BillboardGui.StudsOffset` controls where the bar appears above the adornee part. The template uses `Vector3.new(0, 4.5, 0)` for preview/editing, while the runtime client recalculates the Y offset from each tank model bounding box so the bar sits above taller or shorter tanks.

`GreenBar` must be a child of `BarBack`, not a loose sibling elsewhere. `BarBack.ClipsDescendants = true` keeps the green fill clipped inside the bar frame.

The fill changes by width:

```lua
GreenBar.Size = UDim2.new(ratio, 0, 1, 0)
```

The red bar stays full width behind it. Do not represent HP loss by only changing `GreenBar.BackgroundColor3`; the width has to shrink from left to right.

## Client Runtime

`WOBTankWorldHealthBars.client.luau`:

- scans active tank models about once per second;
- clones `TankHealthBillboard` into `PlayerGui/WOBTankWorldHealthBars`;
- sets `BillboardGui.Adornee` to `Body`, then `PrimaryPart`, then a fallback part;
- sets `BillboardGui.StudsOffset` from `model:GetBoundingBox()`;
- updates bars from attributes instead of `RenderStepped`;
- removes bars when tank models are removed or deactivated;
- hides dead bars after a short grace delay.

Tank detection supports player tanks, `DummyTank`, `Player2TankPrototype`, BattleArena tanks, and future bots that expose the same attributes.

## Duplicate Check

After a round reset or BattleArena respawn:

- there should be one world HP bar per active tank;
- old bars should disappear when old tank models are removed or marked inactive;
- `PlayerGui.WOBTankWorldHealthBars` should not fill with duplicate BillboardGui clones.
