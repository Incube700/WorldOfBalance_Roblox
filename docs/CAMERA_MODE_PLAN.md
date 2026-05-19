# Camera Mode Plan

Current cleanup pass rule: do not implement third-person camera yet.

## Current Modes

- `DuelCameraMode = TopDown`
- `TrainingCameraMode = TopDown`
- `BattleArenaCameraMode = TopDown`
- `OpenWorldCameraMode = Unimplemented`

`Duel` should stay strict top-down because aiming, ricochet readability, HP world bars, and reload bars are tuned around that view.

`BattleArena` stays top-down for the current published playtest loop. A future BattleArena/OpenWorld pass can switch to a Roblox-style third-person camera when the larger-space movement and combat readability are ready for it.

## Future Controller

Future camera ownership should move into a client controller:

```text
WOBTankCameraController
```

Responsibilities:

- Resolve camera mode from player state, for example `PlayerMode` and future mode attributes.
- Keep `Duel` and `Training` in top-down mode.
- Allow `BattleArena` and `OpenWorld` to opt into third-person later.
- Keep camera behavior separate from combat, reload, health bars, mobile controls, and scene repair scripts.

## Deferred Third-Person Work

When third-person is implemented later, it should be a dedicated pass with manual Studio validation:

- camera collision and zoom limits;
- turret aim mapping from screen/camera direction;
- mobile right-stick aim feel;
- HP world bar readability;
- projectile, ricochet, and death VFX framing;
- BattleArena HUD overlap checks.

No current camera code is changed by this cleanup pass.
