# Mobile HUD Layout Pass

## Current Problem

`WOBBattleArenaOverlay.client.luau` owns the BattleArena HUD. It creates `HealthPanel`, `ScorePanel`, and `ReturnToLobbyButton` directly under the full-screen `WOBBattleArenaOverlay` `ScreenGui`.

`WOBMobileControls.client.luau` owns touch controls separately in `PlayerGui.WOBMobileControls`:

- `LeftStickBase` and `LeftStickKnob` for MOVE in the lower-left.
- `RightAimBase` and `RightAimKnob` for AIM in the lower-right.
- `FireButton` on the right side above the aim stick.

The obstruction came from the BattleArena HUD, not from the mobile controls parent chain. The arena overlay used large desktop-sized panels and a persistent return button on mobile, so the top and middle of the battle view were occupied by status UI instead of remaining clear for combat.

## Always Visible On Mobile

- Compact HP at top-left.
- Compact arena score at top-right.
- Small `Menu` button in the top safe area.
- Respawn panel only while destroyed.

## Hidden Behind Menu

- Persistent full-size `Return to Lobby` is not shown during live mobile arena play.
- Mobile uses `Menu` -> `Resume` or `Return to Lobby`.
- Upgrade details are not shown as a long always-visible string. Mobile shows only a compact upgrade count.

## Corner Separation

- HP stays top-left, above the MOVE zone.
- Score stays top-right, above the FIRE/AIM zone.
- Menu stays small and near the top center.
- MOVE, AIM, and FIRE remain owned by `WOBMobileControls.client.luau` and keep their existing input behavior.

## Desktop vs Mobile

Desktop keeps the larger BattleArena HUD:

- HP panel at top-left.
- Arena score and full upgrade list at top-right.
- `Return to Lobby` as a direct button.

Mobile uses a separate compact layout:

- HP panel is about 170x54.
- Score panel is about 170x72.
- Mobile text is shortened to `HP`, `Score`, `K/D`, `Streak`, and `Upg`.
- `Return to Lobby` moves into a modal menu so the screen center stays available for aiming and driving.

## Parent And ZIndex Contract

- HP, score, actions, and popup are children of the full-screen BattleArena overlay, not children of mobile controls.
- Normal panels use ZIndex 10.
- Menu/actions use ZIndex 20.
- Popup dim and panel use ZIndex 30+.

## Manual Mobile Checklist

- HP visible but compact.
- Score visible but compact.
- Return to Lobby hidden behind Menu.
- Center of screen mostly free.
- Fire/AIM/MOVE not covered.
- Menu opens popup.
- Resume closes popup.
- Popup Return to Lobby uses the existing return flow.
- Arena respawn countdown still appears.
- Desktop BattleArena HUD still works.
