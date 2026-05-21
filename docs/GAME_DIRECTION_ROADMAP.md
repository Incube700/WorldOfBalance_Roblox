# Game Direction Roadmap

This document records direction only. Do not implement bots, upgrades, third-person camera, Extraction, or new modes as part of this architecture pass.

## Core Now

- The current core is Ricochet Duel / tank arena combat.
- The main hook is ricochet skill: armor angle, hull positioning, wall reads, and trajectory prediction.
- Players should come back for short duels, funny self-hits, wall shots, and clear skill moments.
- Duel should stay a clean top-down mode with strong projectile readability.
- Visible armor zones are part of the game language, not debug-only visuals.

## Core Combat

- Ricochet is not only wall bounce.
- Tank armor angle matters.
- Player can angle hull like a diamond to increase ricochet chance.
- Direct front hits can penetrate but with reduced damage.
- Direct low-penetration front hits should no-pen rather than bounce.
- Sharp angle hits ricochet.
- Corners strongly ricochet.
- Hull angle is skill expression.
- Armor visuals must preserve meaning: front is strong, side is medium, rear is weak.

## Ricochet Readability Progression

Shell Research / Ricochet Research is a preferred progression family because it improves mastery instead of replacing skill with stats.

Future levels:

- Level 1: clearer or longer aim laser.
- Level 2: aim laser previews 1 wall ricochet.
- Level 3: aim laser previews 2 wall ricochets.
- Level 4: impact point marker after ricochet.
- Level 5: armor interaction hint with likely `Penetration`, `NoPen`, or `Ricochet` feedback.

These upgrades are appropriate for BattleArena and future Extraction. In normalized Duel, they should be disabled, equalized for both players, or reserved for a future casual/unranked ruleset.

## Competitive Balance

- Duel should be normalized.
- Permanent stat upgrades should not affect Duel by default.
- Bolts and Crystals should mostly unlock cosmetics, sidegrades, arena/extraction run content, and long-term collection goals.
- Arena and Extraction can allow progression because they are not pure competitive Duel.
- Permanent `+Damage` or `+HP` should not be the core Duel progression path. Readability, cosmetics, and sidegrades are healthier long-term rewards.

## Multiplayer Direction

- Do not hardcode Player1/Player2 beyond a bounded DuelSession.
- BattleArena supports many players.
- Bots are participants.
- Duel uses exactly 2 participants.
- Other players can stay in Lobby, BattleArena, or future Extraction while a Duel is running.

## Near Term

- Stabilize Duel, Training, and BattleArena.
- Add bot v0.1 later.
- Expand `TankFactory` from current adapter layer into the main spawn pipeline later.
- Add basic upgrades later: HP, Damage, Reload, Speed, Projectile Speed.
- Bolts are the ordinary upgrade currency.
- Crystals are rare unlock currency for skins, special weapons, VFX, and premium-feeling cosmetics.

## Camera Direction

- Duel: top-down.
- Training: top-down for now.
- Lobby can later become third-person / Roblox-style.
- BattleArena can later become third-person or a more open combat arena.
- Extraction can later be third-person.
- Future camera ownership should be explicit through `CameraModeService` and `CameraModeConfig`.
- Mapping target: `Duel -> TopDown`, `Training -> TopDown`, `Lobby -> ThirdPerson later`, `BattleArena -> TopDown now / ThirdPerson later`, `Extraction -> ThirdPerson later`.

## Future Modes

- Duel remains top-down.
- Lobby may become third-person later.
- BattleArena may become third-person later.
- Extraction later: leave lobby, collect, fight, extract to save loot; death loses unbanked run loot.

## Future Extraction Concept

- Player leaves the lobby into a larger sandbox/extraction area.
- Player can drive, fight, and collect resources.
- Death before extraction loses unbanked loot/progress from that run.
- Successful extraction banks loot/rewards.
- This can become a longer-session sandbox loop.

## Priority

- Do not mix all modes immediately.
- Current priority remains a stable playable loop built around readable ricochet combat.
