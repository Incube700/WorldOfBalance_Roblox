# Audio System Plan

## Goal

Audio v0 adds a lightweight client-side sound playback layer for combat, reward, and simple UI events. It does not add final audio assets. `AudioCatalog.luau` contains allowed sound definitions with replaceable `SoundId` fields.

## Authority

Gameplay stays server-authoritative:

- server emits gameplay feedback events;
- client plays local audio only;
- client does not grant rewards;
- client does not deal damage;
- client does not request currency;
- damage, armor, ricochet, projectile, wallet, and match formulas are unchanged.

## Config

`AudioConfig.luau` controls playback settings:

- `Enabled`
- `Debug`
- `MasterVolume`
- `CombatVolume`
- `UIVolume`
- `PitchJitter`
- future playback limits such as `MaxSoundsPerSecond`.

`AudioCatalog.luau` controls allowed sound definitions:

- default sound keys per category;
- `SoundId`;
- display name;
- volume;
- playback speed;
- 2D/3D behavior;
- rolloff distance for 3D sounds.

Empty `SoundId` means that sound is disabled. The audio controller skips it without warning unless debug is enabled.

## Current Ownership Rule

Current MVP audio ownership:

- `VfxConfig` owns visual effects only: muzzle flash, smoke, sparks, explosion visuals, particles and templates.
- `AudioConfig` owns playback settings only.
- `AudioCatalog` owns allowed sound definitions and `SoundId` values.
- `WOBAudioController.client.luau` is the only client-side owner of sound playback.

Avoid duplicate sound ownership:

- Do not put `Shot` / `Ricochet` / `DeathExplosion` sounds in `VfxConfig`.
- Do not play world combat sounds through `CombatVfxService`.
- `CombatFeedbackEvent` payloads may identify an event/category, but must not send arbitrary `SoundId` values.
- The client resolves sounds locally from `AudioCatalog`.

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

## Future Player Audio Customization

Future player audio customization should store IDs only:

- `EquippedShotSoundId = "DefaultCannonShot"`
- `EquippedRicochetSoundId = "DefaultRicochet"`

Later, the server should validate ownership. The client should still resolve only allowed sounds from `AudioCatalog`.

If custom sound is public cosmetic, combat feedback payloads may include `OwnerUserId`, and clients can resolve that owner's validated loadout later. If custom sound is local-only, only the local player hears their equipped sound while others hear defaults.

The client must never accept an arbitrary `SoundId` from an untrusted RemoteEvent.

Do not use copyrighted or meme sounds. Use Roblox Creator Store or properly licensed SFX, then paste asset IDs into `AudioCatalog`.

## Manual Test

1. Leave all `AudioCatalog` `SoundId` values empty and play. There should be no errors.
2. Paste a test SoundId into `AudioCatalog.Sounds.DefaultCannonShot.SoundId` and `AudioCatalog.Sounds.DefaultBoltReward.SoundId`.
3. Start Training.
4. Shoot: `Shot` should play.
5. Kill `DummyTank`: `BoltReward` should play.
6. Ricochet: `Ricochet` should play if configured.
7. `BARREL BLOCKED`: `BarrelBlocked` should play if configured.
8. Confirm PvP still works.
9. Confirm sound objects clean up and do not accumulate forever.
