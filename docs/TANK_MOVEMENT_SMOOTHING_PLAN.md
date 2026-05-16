# Tank Movement Smoothing Plan

## Diagnosis

Player-controlled tanks are still server-authoritative. `WOBGameplayServer.server.luau` reads player input from `PlayerPossessionService`, resolves the move with `TankMovementService.resolveTankPose`, writes the participant `ControlState`, and then calls `TankSpawnResetService.layoutTank` on every `Heartbeat`.

`TankSpawnResetService.layoutTank` moves the physical tank contract parts on the server:

- `Body`
- `Turret`
- `Barrel`
- `ShootPoint`
- `Hitboxes`

The Training dummy is also a normal `TankParticipant`. `TrainingBotService` writes decisions into the dummy participant control state and uses the same movement/layout services. The bot differs from a player only by decision source.

## Why Remote Tanks Can Jitter

The current tanks are kinematic Roblox models driven by server-side CFrame updates. The local player can feel smoother because their camera and controls update every frame around their own intent. Other player tanks and bot tanks arrive through replication snapshots, so the visible model can look like it moves in chunks even when FPS is fine.

This is a replication/interpolation symptom, not necessarily a rendering performance problem.

## Authority Rule

Server authority stays unchanged:

- server owns tank position, health, damage, hitboxes, projectiles, and match result;
- clients do not calculate damage;
- clients do not move bot participants;
- projectile and armor formulas stay server-side;
- match logic stays in `RoundMatchService` / mode services.

## Minimal Safe Fix

Add client-side visual smoothing for non-owned tanks only:

- owned local tank remains unsmoothed by default to avoid input lag;
- remote player tanks and bot tanks are interpolated locally on `RenderStepped`;
- smoothing reads replicated target CFrames, keeps a display CFrame, and lerps the visible parts toward the target;
- if a tank jumps too far, it snaps instead of slowly drifting;
- hitboxes remain server truth and are not part of the visual smoothing target set.

This is an MVP fallback for the current prefab contract. A future cleaner version should split visual presentation into a dedicated `Visual` folder or client-side visual proxy while leaving `Body`, `ShootPoint`, and `Hitboxes` as gameplay truth.

## Bot Movement Smoothing

`TrainingBotService` should separate thinking from acting:

- `ThinkInterval` updates desired movement, aim, and fire intent;
- movement, body rotation, turret rotation, and layout run every `Heartbeat`;
- body and turret yaw move toward desired yaw with configured angular speeds.

That keeps bot decisions imperfect while avoiding visible server-side stepping.
