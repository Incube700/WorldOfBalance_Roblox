# Hit Flash Debug

The hit flash is driven by tank model attributes, not by projectile visuals.

## Expected Server Attributes

On real damage, the server should update the damaged active tank model:

- `LastDamageSerial`
- `LastDamageAmount`
- `LastDamageWasLethal`

`LastDamageSerial` should increment only for real HP damage. Ricochet/no-penetration events should not increment it.

## Expected Client Watch Roots

`WOBTankDamageFlash.client.luau` watches active tank models under:

- `Workspace.WOB_Generated.TestObjects`
- `Workspace.WOB_Generated.BattleArena`

The local `Highlight` instances live under:

```text
Workspace.WOB_Runtime.Client.Visuals.DamageFlash
```

## Debug Switch

Enable:

```lua
HudConfig.DamageFlash.Debug = true
```

Expected log on real damage:

```text
[HIT FLASH] detected model=... serial=... amount=...
```

Default is `false`, so normal play should not spam output.

## Manual Check

1. Play Training.
2. Damage `DummyTank`; it should pulse white/yellow.
3. Damage the player tank through self-hit/damage; it should pulse.
4. Cause ricochet/no-damage; there should be no pulse.
5. Confirm death explosion and burning VFX still appear.
