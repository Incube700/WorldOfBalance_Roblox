# Combat Hit Flash

## Goal

Tanks briefly flash white-yellow when they take real damage. The flash is client-side only, so it does not change combat, colors, materials, movement, projectiles, or VFX.

## Trigger

The server increments `LastDamageSerial` on the damaged tank model after successful damage:

```text
LastDamageSerial += 1
LastDamageAmount = damage
LastDamageWasLethal = true/false
```

The client listens for `LastDamageSerial`. No serial change means no flash, so ricochets and no-damage hits do not trigger the effect.

## Runtime

`WOBTankDamageFlash.client.luau`:

- scans active tank models once per second;
- listens to `LastDamageSerial`;
- creates a local `Highlight` per watched tank only when needed;
- tweens `FillTransparency` from readable to invisible;
- uses a slightly longer duration for lethal damage.

The `Highlight` lives under `Workspace.WOBLocalDamageFlash` on the local client. It is destroyed when the tank model is removed or deactivated.

## Config

`HudConfig.DamageFlash` controls:

- `Enabled`
- `Duration`
- `LethalDuration`
- `FillTransparencyStart`
- `FillTransparencyEnd`
- `Color`

Current color is a warm white-yellow to read against arena walls and explosion VFX.

## Manual Check

- Shoot `DummyTank`: HP bar drops and the dummy flashes.
- Kill `DummyTank`: lethal flash is visible, then death VFX still plays.
- Shoot a ricochet/no-penetration angle: no damage flash.
- Self-hit damage flashes the owner tank.
- Round reset and BattleArena respawn do not leave old highlights behind.
