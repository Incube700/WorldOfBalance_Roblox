# Stable Fun Duel Gameplay Advancement

Date: 2026-05-14.

## What Works

- Lobby free drive works and uses no-damage shooting.
- Training starts from Lobby and uses the same round/match flow as Duel.
- DuelPad exposes `DuelQueueCount`, `DuelQueueRequired`, `DuelCountdown`, and `DuelState`.
- Duel starts only with two queued players after a cancellable countdown.
- Server owns movement, shooting, damage, death, round state, and match state.
- Movement validation uses `TankMovementService.resolveTankPose` with map/lobby obstacle includes and final overlap checks.
- Dead tank control is disabled on the server through participant alive/controllable flags.
- `RoundEnd` and `MatchEnd` are separate; full Result appears only after match end delay.
- HUD, small round overlay, Result, Stats, Rematch, and Return to Lobby are still separate presentation layers.
- Combat VFX no longer depends on Creator Store templates for baseline readability.

## Current Game Feel Risks

- Store/Toolbox VFX templates are useful as upgrades, but unstable as the primary readability path.
- First 20 seconds depend more on clear shell visibility, steering feel, camera, and feedback text than on high-end VFX.
- Duplicate reset logs can make round flow look less stable even when gameplay continues.
- If turret turn speed and shooting direction diverge, aim laser can feel dishonest.
- If projectile size/trail regress, top-down combat becomes hard to read immediately.

## Critical Bugs To Avoid

- Double reset after one death.
- Manual reset fighting the delayed `RoundEnd` reset.
- Dead tanks moving or shooting during aftermath.
- PvP starting with one player or with non-queued lobby players.
- Store template missing warnings spamming every shot.
- Result/Rematch/Return to Lobby appearing during normal `RoundEnd`.

## Stable Fun Duel v0.1 Scope

Stable Fun Duel v0.1 is:

- Lobby spawn, free drive, and no-damage shooting.
- Training match against dummy.
- Two-player DuelPad queue with countdown and cancellation.
- Server-authoritative tank movement with wall/cover/lobby containment.
- Server-authoritative shooting, ricochet, armor resolution, damage, death, and stats.
- Readable projectile, shot sound, impact/damage/no-pen/self-hit feedback, and procedural death explosion fallback.
- Round series to `MatchConfig.TargetWins`.
- Small `RoundEnd`/`MatchEnd` overlays before auto next round or full Result.
- Rematch and Return to Lobby only after full match end.

Stable Fun Duel v0.1 is not:

- Creator Store VFX integration work.
- Shop, monetization, inventory, upgrades, or cosmetics.
- Deathmatch or additional modes.
- A full rewrite of round, movement, or projectile architecture.

## Gameplay Changes In This Pass

- Shot readability remains anchored on `VfxConfig.Shot.SoundId = "rbxassetid://139771888058836"`.
- Top-down projectile readability remains anchored on `Shot.Projectile.Size = 1.2`, `LightBrightness = 2.4`, and a wide trail.
- Reverse steering is server-side and uses arcade car-style path control when throttle is below `ReverseSteeringDeadZone`.
- Turret turn speed is now also exposed in `TankConfig.Turret`, while old `TankConfig.Movement` values remain as compatibility fallbacks.
- Shooting uses the current server turret facing when `ShootUsesTurretFacing` is enabled.
- Round reset has a short reentry guard so a delayed reset/manual reset race cannot execute the reset body twice.
- Ricochet fallback has its own bright procedural sparks instead of relying only on generic wall impact or Store templates.

## Next Work After v0.1

- Manual Studio balance pass for tank speed, reload cadence, camera height, and arena scale.
- Better DuelPad visual countdown if the current text/readability is not enough.
- Optional, curated template VFX only after procedural fallback remains acceptable.
- Lightweight onboarding hints for first-time controls, if the first 20 seconds still need clarity.
