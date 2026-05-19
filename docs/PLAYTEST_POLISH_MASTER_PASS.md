# Playtest Polish Master Pass

## Что сейчас работает

- Lobby free drive: игрок появляется в лобби, ездит, стреляет без урона и может выбрать режим через pads.
- Training: одиночный матч против dummy остается отдельным от Duel rewards.
- DuelPad: очередь 2 игроков, countdown, best-of series, RoundEnd, MatchEnd, Result, Rematch и Return to Lobby.
- BattleArena: отдельный free battle режим с respawn, score, session upgrades и компактным mobile HUD.
- Mobile controls: MOVE, AIM и FIRE остаются отдельным клиентским вводом через `WOBClientInputState`.
- VFX: runtime fallback работает без обязательных Studio templates; Rojo guard сохраняет unknown VFX templates в `ReplicatedStorage.Shared.Assets.VFX`.
- Wallet: Bolts остаются soft currency за kills; Crystals добавлены как внутренняя валюта за победы в Duel.

## Что мешало playtest

- На телефоне дорого обходились тени, частые UI refresh и потенциальные runtime leftovers.
- `TankBurningTemplate` мог содержать looped Sound или donor script, из-за чего после смерти танка слышался постоянный fire/campfire loop.
- Игроку в лобби было недостаточно понятно, куда ехать: Arena, Duel, Training и будущие cosmetics не читались как Roblox-style zones.
- В HUD не было второй валюты и явного `+1 Crystal` после победы в Duel.

## Что сделано в этом проходе

- Добавлен `RewardConfig` и `MatchRewardService`: финальная победа в Duel дает `+1 Crystal`.
- `PlayerWalletService` теперь хранит `Bolts` и `Crystals` в одном wallet DataStore с graceful fallback в Studio.
- Добавлены player attributes: `Crystals`, `PersistentCrystals`, `SessionCrystalsEarned`, `UnsavedCrystals`, `LastCrystalsReward*`.
- Wallet HUD показывает Bolts и Crystals в lobby/result, а combat HUD остается компактным.
- Duel MatchEnd overlay показывает `+1 Crystal` победителю текущего матча.
- `PerformanceConfig` получил `MobileLow` profile по умолчанию; runtime shadows выключены для mobile playtest.
- Runtime `Projectiles` и `VFX` folders очищаются на server startup.
- `CombatVfxService` санитизирует runtime clones: гасит template sounds unless explicitly enabled, снимает looped sounds и удаляет donor scripts/click detectors на клоне.
- `VfxConfig.BurningTank` по умолчанию mute: `PlayTemplateSounds = false`, `SoundVolume = 0`, `AllowLoopedSounds = false`.
- Добавлены Studio command scripts:
  - `docs/patches/MUTE_BURNING_VFX_SOUNDS_COMMAND.lua`
  - `docs/patches/CREATE_OR_REPAIR_LOBBY_SHOWCASES_COMMAND.lua`
  - `docs/patches/CREATE_OR_REPAIR_LOBBY_GUIDANCE_COMMAND.lua`
- Добавлены docs для mobile performance и UX/readability.

## Что сознательно не делаем сейчас

- Не добавляем Robux, IAP, Marketplace purchases, paid shop, gambling или ставки.
- Не делаем полноценный inventory/store/equip flow.
- Не переписываем `BattleArena`, `DuelPad`, `Training` или `RoundMatchService`.
- Не трогаем `.rbxl` напрямую; scene changes идут только через `docs/patches/*_COMMAND.lua`.
- Не удаляем VFX templates и не меняем Rojo VFX mapping.
- Не выдаем Crystals за Training, BattleArena kills или round wins.

## Manual Checklist Before Publish to Roblox

- `default.project.json` still has `$ignoreUnknownInstances = true` under `ReplicatedStorage.Shared.Assets.VFX`.
- Run `MUTE_BURNING_VFX_SOUNDS_COMMAND.lua` outside Play Mode if `TankBurningTemplate` exists in Studio.
- Run `CREATE_OR_REPAIR_LOBBY_SHOWCASES_COMMAND.lua` outside Play Mode.
- Run `CREATE_OR_REPAIR_LOBBY_GUIDANCE_COMMAND.lua` outside Play Mode.
- Run existing pad/collision audit scripts if pads or arena were manually moved.
- Spawn in lobby and confirm Arena/Duel/Training signs are readable.
- Confirm showcases are visible, non-blocking, and marked coming soon.
- Confirm DuelPad queue/countdown still works with 2 players.
- Win a Duel and confirm `Crystals +1`, HUD update, and `[REWARD] Duel win crystal +1 ...` log.
- Confirm Training win gives no Crystal.
- Confirm BattleArena kill gives no Crystal.
- Confirm no constant fire/campfire sound after tank death.
- Confirm shot sound and explosion visual still work.
- Confirm mobile MOVE/AIM/FIRE work and HUD does not cover controls.
- Confirm performance feels acceptable on a phone or mobile emulator.
- Publish to the same Roblox experience after Studio checks pass.
