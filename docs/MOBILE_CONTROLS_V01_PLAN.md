# Mobile Controls v0.1 Plan

## Current Desktop Input Flow

Desktop input is owned by `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankInputController.client.luau`.

The client resolves the locally owned tank through `TankModelResolver.findOwnedTank(root, LocalPlayer.UserId, true)`. If the player is in `Lobby`, `QueuedForDuel`, `InMatch`, or legacy `GameState=Playing`, the script samples keyboard and mouse input:

- `W`/`Up` -> `Throttle = 1`
- `S`/`Down` -> `Throttle = -1`
- `A`/`Left` -> `Steer = -1`
- `D`/`Right` -> `Steer = 1`
- mouse screen position -> camera ray -> world aim point on `CameraConfig.Input.AimPlaneY`
- left mouse button -> shoot request at the current aim point

`WOBTankInputController` sends:

- `ReplicatedStorage.Remotes.TankInputEvent:FireServer({ Throttle, Steer, AimPosition })`
- `ReplicatedStorage.Remotes.ShootRequestEvent:FireServer(aimPosition)`

Server authority remains in `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`.

`TankInputEvent.OnServerEvent` clamps `Throttle` and `Steer`, validates the player participant through `PlayerPossessionService`, and stores input only when `LobbyService.canParticipantDrive(participant)` is true. The heartbeat loop applies stored input through `TankMovementService.resolveTankPose`, and turret yaw is driven from the stored `AimPosition`.

`ShootRequestEvent.OnServerEvent` validates `LobbyService.canParticipantShoot(participant)`, then calls `ProjectileService.tryShoot`. `ProjectileService` rechecks `IsControllable`, `CanShoot`, death state, cooldown, and match/lobby shoot rules before spawning a projectile.

## RemoteEvents Used

- `TankInputEvent`: continuous drive and aim intent from client to server.
- `ShootRequestEvent`: one-shot fire intent from client to server.
- `ResetDummyRequestEvent`: training reset action from round status UI.
- `StartMatchRequestEvent`: shell UI start/training request.
- `ReturnToMenuRequestEvent`: result/shell return to lobby.
- `RematchRequestEvent`: result rematch request.
- `CombatFeedbackEvent`: server-to-client hit feedback.

Mobile controls must not add a separate movement or shooting RemoteEvent.

## Where Input Is Formed

Movement:

- Keyboard state is sampled in `WOBTankInputController.getKeyboardAxis`.
- Mobile joystick state is written by `WOBMobileControls.client.luau` into `Input/WOBClientInputState.luau`.
- `WOBTankInputController.getCombinedAxis` chooses the stronger desktop/mobile axis per component and sends raw `Throttle`/`Steer`.

Aim:

- Desktop aim uses mouse location -> camera ray -> aim plane.
- Mobile aim uses the visible right `AIM` stick.
- The right stick vector is mapped through the camera's flat screen-right/screen-up axes, then converted to `AimWorldPoint = ownedTankPosition + worldDirection * 100`.
- Mobile aim point is stored in `WOBClientInputState` and read by `WOBTankInputController`.
- If no mobile aim touch has happened yet, mobile aim falls back to the owned tank muzzle/body forward direction.

Shoot:

- Desktop left click calls the existing shoot request path.
- Mobile `FireButton` writes a pending shoot intent into `WOBClientInputState`.
- `WOBTankInputController` consumes that pending shoot intent and fires the existing `ShootRequestEvent`.

## Mobile Pipeline

`WOBMobileControls.client.luau` appears only when `UserInputService.TouchEnabled` is true, or when `MobileControlsConfig.ForceEnabledInStudio` is intentionally enabled for testing. It creates `PlayerGui.WOBMobileControls` with:

- `LeftStickBase`
- `LeftStickKnob`
- `LeftStickLabel` with `MOVE`
- `RightAimBase`
- `RightAimKnob`
- `RightAimLabel` with `AIM`
- `FireButton`
- optional `AimAreaDebugOverlay` when `MobileControlsConfig.Debug=true`

The left joystick maps directly to the same raw inputs as desktop:

- stick up -> `Throttle = 1`
- stick down -> `Throttle = -1`
- stick left -> `Steer = -1`
- stick right -> `Steer = 1`

The client does not invert steering while reversing. The server still applies `TankConfig.Movement.InvertSteeringWhenReversing`.

The right aim stick is intentionally visible. The earlier invisible right-side aim zone made mobile turret control hard to discover, so v0.1 now shows a translucent `AIM` circle and knob. Dragging it updates only `WOBClientInputState.setMobileAimWorldPoint`; `WOBTankInputController` remains the only client script that sends movement and shooting remotes.

The fire button is positioned above/right of the aim stick:

- `RightAimStick.Position = UDim2.fromScale(0.78, 0.72)`
- `FireButton.Position = UDim2.fromScale(0.9, 0.56)`

Visibility:

- visible in `Lobby`, `QueuedForDuel`, `InMatch`, `InBattleArena`, or legacy `GameState=Playing`;
- hidden in `PlayerMode=Result`;
- hidden in `ArenaRespawning` because that mode has its own death/return overlay;
- disabled and reset during `RoundEnd`, dead tank, or non-controllable tank;
- lobby controls remain usable, including no-damage shooting, when server logic allows it.

## What Not To Do

- Do not add a separate mobile movement RemoteEvent.
- Do not create a second server-side mobile movement path.
- Do not drive tanks from the client.
- Do not use Humanoid/default character controls as the basis for tank movement.
- Do not bypass `LobbyService.canParticipantDrive`, `LobbyService.canParticipantShoot`, `TankMovementService`, or `ProjectileService`.
- Do not invert reverse steering on the client.

## Studio Device Emulator Test

1. Open Roblox Studio.
2. Use `Test -> Device Emulator` or the Emulator panel.
3. Select a phone profile.
4. Press Play.
5. Confirm `WOBMobileControls` appears.
6. Test left joystick movement and turning.
7. Confirm `MOVE`, `AIM`, and `FIRE` are visible and do not overlap.
8. Drag the right `AIM` stick and confirm turret/laser aim follows.
9. Hold left `MOVE` while dragging right `AIM` and confirm drive + aim work together.
10. Tap `FIRE` and confirm the normal projectile/sound path works.
11. Switch back to desktop Play and confirm the mobile UI does not appear when `TouchEnabled=false`.

If Studio does not report `TouchEnabled=true` in the emulator, temporarily set:

```lua
ForceEnabledInStudio = true
```

in `MobileControlsConfig`. Return it to `false` before committing or publishing.

## Manual Checklist

Mobile:

- spawn lobby
- left joystick movement
- left joystick turning
- visible right `AIM` stick rotates turret/aim laser
- left `MOVE` and right `AIM` work simultaneously
- fire button
- `FIRE` shoots in the current mobile aim direction
- lobby no-damage shooting
- BattleArena controls show while alive and hide during `ArenaRespawning`
- DuelPad enter/exit
- round end disables movement/fire
- next round restores controls
- result hides controls
- return lobby restores controls

Desktop:

- mobile UI hidden when `TouchEnabled=false`
- keyboard movement still works
- mouse aim still works
- left click shooting still works
- training still works
- result/rematch/return still works
