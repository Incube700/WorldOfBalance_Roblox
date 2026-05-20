# Roblox UX Readability Guide

## Lobby Zones

- Every lobby action needs a visible destination: `BATTLE ARENA`, `DUEL`, and `TRAINING`.
- Pads should be large enough to drive onto on mobile without precise steering.
- Pad labels should use short text, high contrast, `AlwaysOnTop = true`, and a sane `MaxDistance` around 190-260.
- Keep the main road clear. Decorative stands should not be tagged `WOBMovementObstacle`.

## Mobile-Safe HUD

- Lobby/result can show wallet progression; combat should stay minimal.
- BattleArena mobile HUD should stay in top corners, with Return hidden behind a small Menu.
- World tank HP/reload bars are preferred over large duplicate top HP/reload panels on mobile combat screens.
- Top HP panels can be hidden in BattleArena and on mobile Duel/Training when `HudConfig.WorldHealthBars` is enabled.
- The large top Reload panel should be hidden in BattleArena/mobile when `HudConfig.WorldHealthBars.ShowReloadBar` is enabled.
- The base modular `HUD` should be disabled outside active `InMatch` play so old HP/reload panels do not appear in lobby, result, or BattleArena.
- Desktop Training/Duel may temporarily keep top HP panels for comparison, but mobile should trust the world bars first.
- Do not place new buttons near the right-side AIM/FIRE cluster or left-side MOVE stick.
- Avoid long text in combat. Use short status labels and let world signs teach the player in lobby.
- Mobile BattleArena stats should fit in a small top strip: Score, K/D, Crystals, and Bolts if space allows. Hide long upgrade lists during combat.
- Keep world HP/reload `BillboardGui.MaxDistance` in the 80-120 range for mobile combat unless a visual review shows it is too short.
- World HP/reload anchors should follow the tank body/hull, not the full model bounding box, so turret/barrel rotation cannot move the bar.
- Avoid non-debug startup prints from client overlays; repeated output noise can hide real mobile regressions during Studio tests.

## Mobile Performance Readability

- Prefer short-lived runtime VFX with Debris cleanup over persistent scene effects.
- Runtime visual parts should use `CanCollide=false`, `CanTouch=false`, `CanQuery=false`, and `CastShadow=false`.
- Do not run full-Workspace `GetDescendants` scans on `RenderStepped`; cache or throttle discovery.
- Keep aim/readability helpers visually useful, but avoid creating new objects every frame.
- Leave joystick controls unchanged unless a dedicated controls pass is requested.

## Combat Readability

- Active tanks should expose `CurrentHealth`, `MaxHealth`, `IsDead`, `OwnerName`, and `TankParticipantId`.
- Tank HP/reload bars should be compact world-space `BillboardGui` objects, not Roblox Humanoid healthbars.
- The green bar is health; the blue bar below it is reload progress.
- HP/reload bars should be readable at normal camera distance without covering the tank or aim line.
- Dead tank bars should hit zero, then hide after a short grace delay so round outcomes remain readable.
- Damage flash should be client-side `Highlight` feedback triggered by `LastDamageSerial`, not by mutating tank part colors.
- Ricochets and no-penetration hits should not flash unless real damage was applied.

## Rewards

- Bolts remain soft currency for kills.
- Crystals are rare internal progression currency.
- Current rule: final Duel win gives `+1 Crystal`.
- Do not show Crystals as Robux, premium purchase, gambling, or paid shop.

## Showcases

- Showcases are decorative and informational for now.
- Use labels like `TANK SKINS`, `WEAPON SKINS`, `CRYSTAL SHOP`, and `COMING SOON`.
- Mark showcases with attributes:
  - `WOBShowcase = true`
  - `ShowcaseType = ...`
  - `Locked = true`
  - `ComingSoon = true`
- Do not add purchase prompts or equip logic until inventory/shop design is explicit.

## Floating Text And Arrows

- Floating tips should be world-space BillboardGui objects, not extra mobile screen UI.
- Tips should teach one idea at a time:
  - Earn Crystals by winning Duels
  - Battle Arena: fight, respawn, upgrade
  - Use ricochets to hit enemies
- Floor arrows should be non-colliding, non-querying, and not movement obstacles.

## What To Test

- A new player can identify Arena, Duel, Training, Crystals, and coming soon showcases without explanation.
- Labels are readable from normal lobby camera distance but do not fill the whole screen.
- Showcases do not block driving routes or pad triggers.
- HUD text fits on mobile and desktop.
- Result screen and wallet make Duel rewards understandable.
- Player and enemy tanks have one HP bar each during Training/Duel/BattleArena.
- Damage lowers the world HP bar and creates one short white-yellow flash.
- Shooting resets the blue reload bar, then it fills left-to-right until ready.
- BattleArena/mobile does not duplicate HP or reload in large top HUD blocks.
- Round reset, death, and respawn do not create duplicate HP bars or stale highlights.
