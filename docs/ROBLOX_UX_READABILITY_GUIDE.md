# Roblox UX Readability Guide

## Lobby Zones

- Every lobby action needs a visible destination: `BATTLE ARENA`, `DUEL`, and `TRAINING`.
- Pads should be large enough to drive onto on mobile without precise steering.
- Pad labels should use short text, high contrast, `AlwaysOnTop = true`, and a sane `MaxDistance` around 190-260.
- Keep the main road clear. Decorative stands should not be tagged `WOBMovementObstacle`.

## Mobile-Safe HUD

- Lobby/result can show wallet progression; combat should stay minimal.
- BattleArena mobile HUD should stay in top corners, with Return hidden behind a small Menu.
- Do not place new buttons near the right-side AIM/FIRE cluster or left-side MOVE stick.
- Avoid long text in combat. Use short status labels and let world signs teach the player in lobby.

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
