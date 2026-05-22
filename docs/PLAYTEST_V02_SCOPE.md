# Playtest v0.2 Vertical Slice Scope

## Included

- BattleArena v0.2 loop foundation through `BattleArenaLoopConfig`.
- Solo BattleArena maintains two easy bots by default, capped by config.
- Player kills on arena bots grant score and small Bolts rewards through the existing wallet service.
- Ricochet bot kills can grant a small score/Bolts bonus.
- Arena HUD now explains the goal more directly and shows session Bolts/timer context.
- Bot difficulty has Easy/Normal profiles, aim jitter, reaction delay, fire pacing, and simple anti-stuck jitter.
- Armor colors and combat feedback are config-driven for `Penetration`, `NoPen`, and `Ricochet`.
- Skin catalog now has safe cosmetic-only color skins and a server-side unlock validation foundation.
- Lobby guidance command exists as disabled-by-default Studio Command Bar script.
- Playtest docs/checklists are updated for v0.2.

## Not Included

- No `.rbxl` or `.rbxlx` scene mutation from this pass.
- No automatic scene movement, arena repair, or organizer scripts.
- No third-person camera.
- No Extraction mode.
- No full shop UI or purchasing flow.
- No new weapons in gameplay.
- No pathfinding AI.
- No Duel power progression. Duel remains normalized and skill-based.
- No complex persistence migration for cosmetic inventory.

## Manual Checklist

1. Run Rojo build from repo root.
2. Open Studio and play fresh.
3. Confirm lobby loads and player tank uses `BaseTankTemplate` when present.
4. Enter DuelPad and confirm Duel HUD/rewards still work.
5. Enter ArenaPad and confirm bots spawn, move, shoot, die, and respawn.
6. Kill a bot and confirm score/kills and Bolts update.
7. Confirm Ricochet/NoPen/Penetration feedback is readable and short-lived.
8. Confirm mobile HUD does not cover MOVE/AIM/FIRE controls.
9. Confirm no duplicate `Assets`, `UI`, `VFX`, or `UX` folders appear in Workspace or ReplicatedStorage.
10. Ask testers: did you know what to do, did ricochet feel fun, and did you want another round?
