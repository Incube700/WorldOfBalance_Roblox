# Audio System Plan

## Goal

Audio v0 adds a lightweight client-side sound playback layer for combat, reward, and simple UI events. It does not add final audio assets. `AudioConfig.luau` contains placeholder `SoundId` fields that can be replaced manually later.

## Authority

Gameplay stays server-authoritative:

- server emits gameplay feedback events;
- client plays local audio only;
- client does not grant rewards;
- client does not deal damage;
- client does not request currency;
- damage, armor, ricochet, projectile, wallet, and match formulas are unchanged.

## Config

`AudioConfig.luau` controls:

- `Enabled`
- `Debug`
- `MasterVolume`
- `CombatVolume`
- `UIVolume`
- per-sound `SoundId`, `Volume`, `PlaybackSpeed`, and optional `RollOffMaxDistance` / `Is2D`.

Empty `SoundId` means that sound is disabled. The audio controller skips it without warning unless debug is enabled.

## Client Controller

`WOBAudioController.client.luau` listens to:

- `CombatFeedbackEvent`;
- local player reward attributes such as `LastBoltsRewardAmount` and `LastBoltsRewardSequence`;
- optional local round result attributes if they are later exposed.

It supports:

- 3D sounds at world positions;
- 2D sounds for UI/reward events;
- automatic cleanup via `Sound.Ended` and `Debris`;
- small pitch variation for repeated combat sounds.

## Feedback Mapping

First priority sounds:

- `Shot`
- `Ricochet`
- `Hit`
- `NoPenetration`
- `TankDestroyed`
- `BarrelBlocked`
- `BoltReward`

Existing combat feedback drives:

- `Damage` -> `Hit`
- `ArmorRicochet` / `Ricochet` -> `Ricochet`
- `NoPenetration` -> `NoPenetration`
- `BlockedShot` -> `BarrelBlocked`
- `TankDestroyed` -> `TankDestroyed`
- `Shot` -> `Shot`

`Shot`, wall `Ricochet`, and `TankDestroyed` can be sent as `AudioOnly = true`, so the combat text overlay ignores them while the audio controller still plays them.

## Future

Safe next audio work:

- UI button click hooks;
- win/lose result sounds with correct local-player perspective;
- countdown sounds;
- mute/audio settings toggle;
- engine loop only after careful performance and annoyance testing.

Do not use copyrighted or meme sounds. Use Roblox Creator Store or properly licensed SFX, then paste asset IDs into `AudioConfig`.

## Manual Test

1. Leave all `SoundId` values empty and play. There should be no errors.
2. Paste a test SoundId into `Shot` and `BoltReward`.
3. Start Training.
4. Shoot: `Shot` should play.
5. Kill `DummyTank`: `BoltReward` should play.
6. Ricochet: `Ricochet` should play if configured.
7. `BARREL BLOCKED`: `BarrelBlocked` should play if configured.
8. Confirm PvP still works.
9. Confirm sound objects clean up and do not accumulate forever.
