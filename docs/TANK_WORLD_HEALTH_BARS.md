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

Run this outside Play Mode:

```lua
docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua
```

It creates or repairs:

```text
ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard
```

The template is a compact `BillboardGui` with:

- `PlayerName`
- `RedBar`
- `GreenBar`
- optional `HpText`

`default.project.json` keeps `ReplicatedStorage.Shared.Assets.UI` protected with `$ignoreUnknownInstances = true`, matching the VFX template safety pattern.

## Client Runtime

`WOBTankWorldHealthBars.client.luau`:

- scans active tank models about once per second;
- clones `TankHealthBillboard` into `PlayerGui/WOBTankWorldHealthBars`;
- sets `BillboardGui.Adornee` to `Body`, `PrimaryPart`, or another tank part;
- updates bars from attributes instead of `RenderStepped`;
- removes bars when tank models are removed or deactivated;
- hides dead bars after a short grace delay.

Tank detection supports player tanks, `DummyTank`, `Player2TankPrototype`, BattleArena tanks, and future bots that expose the same attributes.

## Duplicate Check

After a round reset or BattleArena respawn:

- there should be one world HP bar per active tank;
- old bars should disappear when old tank models are removed or marked inactive;
- `PlayerGui.WOBTankWorldHealthBars` should not fill with duplicate BillboardGui clones.
