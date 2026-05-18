# Feedback / Presentation Architecture

## Главный принцип

World of Balance должен держать простое разделение:

```text
Gameplay services produce facts.
Presentation controllers produce feelings.
```

Или короче:

- Gameplay = правда игры.
- Presentation = звук, VFX, UI и UX-реакция.

Gameplay services решают, что произошло: выстрел, рикошет, пробитие, урон, смерть, награда, победа. Presentation layer решает, как это почувствует игрок: вспышка, искры, звук, текст, HUD, reward popup.

Это разделение особенно важно для Roblox-прототипа, потому что сервер остаётся источником истины, а клиент отвечает за читаемость и ощущение боя.

## Ответственность

| Компонент | Отвечает за | Не отвечает за |
| --- | --- | --- |
| `ProjectileService` | создание и обновление projectile state, raycast movement, wall hit, bounce, projectile lifecycle | выбор `SoundId`, UI text, popup, конкретный VFX template |
| `ProjectileCombatService` | armor penetration, armor ricochet, damage, no penetration, self-hit, death trigger | звук, UI, popup, visual style |
| `RoundMatchService` | round/match state, score, win/lose, match lifecycle | анимацию результата, result panel beauty, sounds |
| `KillRewardService` | решение, кому дать Bolts и за какой kill | отображение `+1 Bolt`, reward sound, wallet UI |
| `PlayerWalletService` | баланс, DataStore save/load, player currency attributes | shop UI, visual reward feedback, purchase UX |
| `CombatFeedbackService` | целевой server-side мост для отправки gameplay facts клиентам | подсчёт урона, проигрывание звука, создание VFX, изменение UI |
| `WOBAudioController` | client-side audio playback по feedback/reward events | gameplay, damage, Bolts grant, projectile rules |
| `WOBCombatVfxController` | будущий client-side VFX controller для muzzle flash, sparks, explosion, impact visuals | damage/projectile/match logic |
| `WOBCombatFeedbackOverlay` | боевой текст: `RICOCHET`, `NO PEN`, damage numbers, `BARREL BLOCKED` | combat calculations |
| `WOBWalletOverlay` | отображение Bolts, total balance и `+1 Bolt` | начисление валюты |
| `WOBHud` / `WOBRoundStatusOverlay` | HP, reload, score, round/match state display | управление матчем, damage, rewards |

## Целевая Схема Событий

Целевая цепочка:

```text
Server gameplay service
  -> CombatFeedbackService
  -> CombatFeedbackEvent
  -> Client presentation controllers
```

Пример payload:

```lua
{
    Type = "Ricochet",
    Position = hitPosition,
    Text = "RICOCHET",
    AudioOnly = false,
    VisualOnly = false,
}
```

Базовые event types:

- `Shot`
- `Ricochet`
- `ArmorRicochet`
- `Damage`
- `NoPenetration`
- `SelfHit`
- `TankDestroyed`
- `BarrelBlocked`
- `BoltReward`
- `RoundWin`
- `RoundLose`
- `MatchWin`
- `MatchLose`

`CombatFeedbackService` не должен считать damage, выбирать звук или создавать VFX. Его работа - принять уже случившийся gameplay fact и отправить совместимый payload клиентам.

## UX-Реакции

Одно gameplay событие может иметь несколько presentation reactions:

- Visual feedback
- Audio feedback
- UI/Text feedback

| Gameplay event | Visual | Audio | UI/Text |
| --- | --- | --- | --- |
| `Shot` | muzzle flash, shell trail start | shot sound | обычно нет |
| `Ricochet` от стены | sparks at hit point | ricochet sound | optional |
| `ArmorRicochet` | armor sparks | metal clang | `RICOCHET` |
| `NoPenetration` | small sparks | clang/no-pen sound | `NO PEN` |
| `Damage` | impact flash | hit sound | damage number |
| `TankDestroyed` | explosion/burning | explosion sound | win/kill feedback |
| `BarrelBlocked` | обычно без VFX | blocked click | `BARREL BLOCKED` |
| `BoltReward` | optional sparkle | reward sound | `+1 Bolt` |
| `RoundWin` / `RoundLose` | result transition | win/lose sound | result panel |

Gameplay событие не обязано иметь все три реакции. Например, `Shot` может не иметь текста, а `BarrelBlocked` может быть только текстом и коротким UI-звуком.

## Разделение Конфигов

Gameplay configs:

- `TankConfig`
- `WeaponConfig`
- `ProjectileCatalog`
- `CurrencyConfig`
- `MatchConfig`
- `BotConfig`

Presentation configs:

- `VfxConfig`
- `AudioConfig`
- `AudioCatalog`
- `HudConfig`
- `ProjectileVisualConfig`
- `SkinCatalog`

`SkinCatalog` относится к presentation/customization layer, пока скины меняют только visual parts and colors. Он не должен менять armor zones, hitboxes, health, projectile rules or match logic.

## Текущее Ownership-Правило

Текущее целевое ownership-правило:

```text
VfxConfig = visual effects only.
AudioConfig = playback settings.
AudioCatalog = allowed sound definitions / SoundIds.
WOBAudioController = client-side audio playback.
```

`VfxConfig` больше не должен быть владельцем звуков. Он отвечает за muzzle flash, smoke, sparks, explosion visuals, particles and templates.

`AudioConfig` больше не должен хранить сами sound definitions. Он отвечает за общие настройки воспроизведения: enabled/debug, master volume, combat/UI volume, pitch jitter and future rate limits.

`AudioCatalog` хранит разрешённые sound definitions:

- `Shot`
- `Ricochet`
- `Hit`
- `NoPenetration`
- `TankDestroyed`
- `BarrelBlocked`
- `BoltReward`
- `ButtonClick`
- `Win`
- `Lose`

`WOBAudioController` слушает gameplay/reward feedback, выбирает категорию, резолвит allowed sound из `AudioCatalog` и проигрывает 2D/3D sound на клиенте.

Главное правило: `CombatFeedbackEvent` может отправить event type или sound category, но не произвольный `SoundId`.

## Целевая Архитектура

После стабилизации ownership должен стать чище:

- `VfxConfig` = только визуальные эффекты.
- `AudioConfig` = только настройки воспроизведения.
- `AudioCatalog` = только разрешённые звуки и `SoundId`.
- `ProjectileService` = только gameplay/projectile facts.
- `CombatFeedbackService` = отправка событий.
- client VFX/Audio/UI controllers = presentation.

Целевая структура:

```text
ServerScriptService
  Server
    Gameplay
      Projectiles
        ProjectileService.luau
      Combat
        ProjectileCombatService.luau
        CombatFeedbackService.luau
      Economy
        KillRewardService.luau
        PlayerWalletService.luau

StarterPlayer
  StarterPlayerScripts
    Client
      WOBCombatVfxController.client.luau
      WOBAudioController.client.luau
      WOBCombatFeedbackOverlay.client.luau
      WOBWalletOverlay.client.luau
      WOBHudBootstrap.client.luau
```

## Выстрел В Целевой Версии

Целевой flow:

```text
Player presses shoot
  -> Server validates shoot
  -> ProjectileService creates projectile state
  -> CombatFeedbackService.fireShot(muzzlePosition)
  -> Client:
       WOBCombatVfxController -> muzzle flash
       WOBAudioController -> shot sound
```

`ProjectileService` не знает, какой `SoundId` используется и какой template отвечает за muzzle flash.

## Рикошет В Целевой Версии

Целевой flow:

```text
ProjectileService detects wall bounce
  -> ProjectileService updates projectile direction/speed
  -> CombatFeedbackService.fireRicochet(hitPosition, normal)
  -> Client:
       WOBCombatVfxController -> sparks
       WOBAudioController -> ricochet sound
       WOBCombatFeedbackOverlay -> optional "RICOCHET"
```

Рикошетная математика остаётся в gameplay. Красота рикошета остаётся в presentation.

## Bolts В Целевой Версии

Целевой flow:

```text
Tank destroyed
  -> KillRewardService validates reward
  -> PlayerWalletService.addBolts(player, amount, reason)
  -> Player attributes update:
       PersistentBolts
       SessionBoltsEarned
       LastBoltsRewardAmount
       LastBoltsRewardReason
  -> Client:
       WOBWalletOverlay shows +1 Bolt
       WOBAudioController plays BoltReward
```

Client никогда не просит `GiveMeBolts`. Client только отображает то, что сервер уже выдал.

## UX Priority Для Ближайшего Прототипа

Минимальные события, которые должны быть читаемыми:

- `Shot` -> звук + вспышка.
- `Ricochet` -> звук + искры.
- `NoPenetration` -> clang + `NO PEN`.
- `Damage` -> hit sound + damage number.
- `TankDestroyed` -> explosion + result.
- `BoltReward` -> `+1 Bolt` + reward sound.
- `BarrelBlocked` -> `BARREL BLOCKED`.

Mobile UX:

- не ставить важный текст под пальцы;
- не делать мелкие кнопки;
- не перекрывать центр боя;
- Bolts держать сверху/сбоку;
- combat feedback делать коротким и крупным.

## Что Нельзя Делать Сейчас

Сейчас нельзя:

- делать большой refactor `ProjectileService`;
- переносить все VFX/Audio одним махом;
- возвращать combat sounds в `VfxConfig`;
- дублировать `Shot` / `Ricochet` между VFX and audio configs;
- добавлять магазин;
- добавлять сложную инвентаризацию;
- добавлять paid currency;
- менять управление одновременно с feedback refactor;
- трогать damage/armor/ricochet formulas без отдельной задачи.

## Safe Migration Plan

### Phase 0 - Current MVP

Сделано:

- `VfxConfig` отвечает за combat visuals.
- `AudioConfig` отвечает за playback settings.
- `AudioCatalog` отвечает за allowed sound definitions.
- `WOBAudioController` проигрывает sounds client-side.
- `ProjectileService` отправляет feedback facts for shot/ricochet/destroyed/block events.

Цель: игра работает.

### Phase 1 - Document Ownership

Зафиксировать:

- `VfxConfig` = combat visuals only.
- `AudioConfig` = playback settings only.
- `AudioCatalog` = allowed sounds only.
- No duplicate sound ownership.

Цель: не путаться.

### Phase 2 - CombatFeedbackService

Добавить server-side сервис:

- `CombatFeedbackService.fireShot(...)`
- `CombatFeedbackService.fireRicochet(...)`
- `CombatFeedbackService.fireDamage(...)`
- `CombatFeedbackService.fireDestroyed(...)`
- `CombatFeedbackService.fireBlockedShot(...)`

Он только отправляет `CombatFeedbackEvent`.

Цель: убрать прямое знание `RemoteEvent` из разных сервисов.

### Phase 3 - Client VFX Controller

Добавить:

- `WOBCombatVfxController.client.luau`

Он слушает `CombatFeedbackEvent` и показывает VFX.

Цель: VFX переезжают из `ProjectileService` в presentation layer.

### Phase 4 - Player Audio Customization

Будущая кастомизация звука должна хранить IDs:

- `EquippedShotSoundId = "DefaultCannonShot"`
- `EquippedRicochetSoundId = "DefaultRicochet"`

Server later validates ownership. Client resolves allowed sounds from `AudioCatalog`.

Если custom sound публичный cosmetic, `CombatFeedbackEvent` может позже включать `OwnerUserId`, а клиент сможет резолвить validated owner loadout. Если custom sound local-only, только локальный игрок слышит свой equipped sound, а остальные слышат default.

Цель: customization without arbitrary client sound ids.

### Phase 5 - ProjectileService Cleanup

`ProjectileService` должен остаться с задачами:

- create projectile;
- update projectile;
- raycast movement;
- wall bounce;
- call combat service;
- emit feedback facts.

`ProjectileService` не должен:

- выбирать звук;
- выбирать VFX template;
- показывать текст;
- решать UX.

## Формула Для Запоминания

```text
ProjectileService = что случилось.
CombatFeedbackService = сообщить.
VFX Controller = показать.
Audio Controller = озвучить.
Overlay/HUD = объяснить.
```
