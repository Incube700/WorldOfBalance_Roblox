# Battle Arena Progression v2

## Current Problems

- Battle Arena progression effectively ends at `ArenaLevel = 5` because `BattleArenaConfig.MaxArenaLevel` also acted as the level cap.
- Levels 1-5 are doing useful core build work, but there is no post-5 record/reward layer.
- `ReflectShield` and `Repair` currently share the same random offer pool as core damage/reload/speed upgrades, so defense can feel like a wasted combat-build choice instead of a branch.
- On player death, `ArenaCombatService.OnParticipantKilled` calls `resetArenaRun(victimSession)` immediately, which clears XP, level, upgrades, forced upgrades, shields, and modifiers before the delayed respawn.
- The death panel is built in `WOBBattleArenaOverlay.client.luau` and currently has a prominent `DeathReturnToLobbyButton`.
- Revive-for-Bolts needs to apply only to Battle Arena and must not touch Duel flow.
- The aim laser reads the raw `ShootPoint` every `RenderStepped`; when tank visuals/camera update on their own render order, the beam anchors can visibly jitter.

## ArenaLevel Model

`ArenaLevel` should continue beyond level 5 for records, session score, future rewards, and longer-run identity.

Current prepared config:

- `MaxArenaLevel = 20`: record/progression ceiling for now.
- `CoreBuildLevel = 5`: intended end of the main combat-build phase.
- `MaxUpgradeLevel = 5`: level-up offers are granted only through level 5.
- `PostMaxLevelXPStep = 350`: generated XP step for levels beyond the explicit threshold table.
- `PostLevelRewards.Enabled = false`: placeholder for later rewards.

Levels 2-5 remain the core upgrade path. Levels 6+ can now exist, but they do not grant infinite level-up upgrade offers by default.

## Build Branches

| Branch | Fantasy / Playstyle | Upgrade List | Tags | Synergies | Risks | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| Movement | Agile tank that survives by repositioning, circling, and controlling pickups. | `MoveSpeedUp`; future dash/traction/rotation perks. | `speed`, `positioning`, `survival` | Ricochet angles, medkit control, control-zone pressure. | Too much speed can make tank combat feel floaty and weaken armor-angle gameplay. | High after core stability. |
| Shooting | Direct cannon power, reload control, and multi-shot pressure. | `DamageUp`, `FireRateUp`, `DoubleShot`, `TripleSpread`. | `damage`, `reload`, `multishot`, `cannon` | Ricochet, Vampire on penetration, Defense for riskier close play. | Can become the only correct branch if damage/reload scales too hard. | Already active; needs branch weighting later. |
| Defense | Survive burst, reflect key shots, and recover during long runs. | `Repair`, `ReflectShield`; future armor/temporary plating. | `repair`, `shield`, `reflect`, `survival` | Movement for disengage, Vampire for sustain, Ricochet for defensive counterplay. | If offered randomly as a normal build choice, it feels like lost DPS; if too strong, it stalls fights. | High, because shields need a real branch. |
| Vampire | Aggressive sustain through confirmed hits, ideally penetration-based. | Future `VampireShells`, disabled and not active. | `future`, `lifesteal`, `penetration` | Shooting damage, armor piercing, close-range pressure. | Too much healing erases punishment; healing on non-penetrating hits would undermine armor. | Design only until penetration branch is ready. |
| Ricochet | Map mastery: angles, bounces, and indirect shots around cover. | `RicochetUp`; future bounce damage/angle control. | `bounce`, `angles`, `map-control` | Shooting, Vampire on pen after bounce, Movement for angle setup. | Too many bounces can make hits unreadable and increase projectile/VFX load. | Medium-high; keep readable. |

## Shield / Defense Rule

Shields should be a coherent Defense branch, not a random tax on normal upgrade offers.

Recommended next rules:

- Keep `ReflectShield` in the active pool for now.
- Use the new `Branch = "Defense"` and `Tags = { "shield", "reflect", "survival" }` metadata for future offer weighting.
- Later, offer at least one branch-consistent choice per offer instead of fully random picks.
- Consider separate defensive offer slots after a death, low HP, or shield depletion.
- Avoid presenting `Repair` as the only valid level-up choice after the core build phase.

## Revive-for-Bolts Design

### Target UX

- On Battle Arena death, show two clear paths: paid `Revive` and free `Respawn`.
- Move `Return to Lobby` into the arena menu, not the main death action.
- `Revive` spends Bolts, respawns inside Battle Arena, and preserves the current run build.
- `Respawn - Free` spends no Bolts, stays inside Battle Arena, and resets the current run powers.
- Revive restores partial HP, for example `ReviveHpPercent = 0.5`.
- Revive cost grows per death or revive count.
- Applies only when `PlayerMode == "ArenaRespawning"` or the arena session is in a revive-pending state.
- Never applies to Duel, Training result, or normal lobby death.

### MVP Implemented

The first revive MVP is active for Battle Arena only.

```lua
Revive = {
	Enabled = true,
	CostBase = 5,
	CostPerRevive = 0,
	MaxRevivesPerRun = 3,
	RestoreHpPercent = 0.5,
	FreeRespawnEnabled = true,
	FreeRespawnRestoreHpPercent = 1.0,
	FreeRespawnResetsRun = true,
}
```

What it does:

- On Battle Arena death, the run is held in a death-pending state when paid revive or free respawn is available.
- `ArenaLevel`, `ArenaXP`, selected upgrades, score/session stats, and arena modifiers are preserved while pending.
- The client death panel shows `REVIVE - 5 BOLTS`.
- The client death panel also shows `RESPAWN - FREE`.
- The server validates the player is in a Battle Arena revive-pending session.
- The server checks and spends Bolts through `PlayerWalletService.trySpendBolts`.
- Successful revive respawns in the Arena, reapplies existing session upgrades, grants spawn shield as before, and restores 50% HP.
- If the player cannot afford the revive, the paid button is disabled and free respawn remains available.
- Free respawn does not spend Bolts, resets `ArenaLevel`, `ArenaXP`, selected upgrades, current modifiers, shield state, and revive count through the normal arena run reset path, then respawns in the Arena.
- `Return to Lobby` still uses the existing return-to-menu path.

What it intentionally does not do yet:

- No Duel revive.
- No Training revive.
- No revive VFX.
- No revive perks, rarity, or branch interactions.
- No automatic post-5 reward payout.
- No King/Pedestal/Vampire gameplay activation.

Future cost-scaling option:

```text
cost = floor((CostBase + CostPerRevive * reviveCount) * CostMultiplier ^ reviveCount)
```

### Integration Points

- Death handling: `src/ServerScriptService/Server/Gameplay/Arena/ArenaCombatService.luau`
  - `OnParticipantKilled` now splits into two paths:
    - free/normal respawn resets the run;
    - paid revive preserves `ArenaXP`, `ArenaLevel`, `UpgradeIds`, score/session stats, and modifiers.
- Respawn with same build: `ArenaCombatService.RespawnPlayer`
  - Restores tank visibility, spawn, mode, input, session upgrades, and spawn shield.
  - Revive passes `RestoreHpPercent = 0.5`.
- Wallet check/spend: `src/ServerScriptService/Server/Gameplay/Economy/PlayerWalletService.luau`
  - Supports `addBolts`, `getBoltsBalance`, and now `trySpendBolts`.
- UI death panel: `src/StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau`
  - `DeathPanel`, `RespawnLabel`, `DeathSummaryLabel`, `DeathReviveButton`, `DeathFreeRespawnButton`, and `DeathReturnToLobbyButton` are created here.
  - `DeathReviveButton` fires `ArenaReviveRequestEvent`.
  - `DeathFreeRespawnButton` fires `ArenaFreeRespawnRequestEvent`.
- Return to lobby: `ReturnToMenuRequestEvent` -> `LobbyService.handleReturnToLobbyRequest`
  - Existing path should remain the way to leave Battle Arena.
- Session state/upgrades: `sessionsByPlayer`, `sessionsByParticipant`, and session fields in `ArenaCombatService`
  - Current build lives in `session.UpgradeIds`, `ArenaLevel`, `ArenaXP`, `ReflectShieldCharges`, `SpawnShieldUntil`, and the arena modifier attributes.

Future improvements:

- Add visible revive VFX/audio.
- Add cost scaling after the flat-cost MVP is tested.
- Make revive limits/perks part of a future Defense branch.
- Connect post-5 reward milestones after economy tuning.

## Future Upgrade Config Shape

Prepared/proposed fields:

| Field | Purpose |
| --- | --- |
| `Id` | Stable upgrade id, matching icon/config/effect paths. |
| `Title` | UI title. |
| `Description` | UI description. |
| `Tags` | Selection, branch, filtering, analytics, and future synergy metadata. |
| `Branch` | One of `Movement`, `Shooting`, `Defense`, `Vampire`, `Ricochet`. |
| `Rarity` | Future weighting: `Common`, `Uncommon`, `Rare`, etc. |
| `MaxStacks` | Stack limit for non-immediate upgrades. |
| `RequiresUpgrade` | Upgrade id required before this one can be offered. |
| `BlocksUpgrade` | Upgrade id/list that conflicts with this one. |
| `MinArenaLevel` | Earliest arena level for offer eligibility. |
| `MaxOfferLevel` | Latest arena level for offer eligibility. |
| `OfferAfterLevel` | Offer only after this level. |
| `FutureOnly` | Design/config entry only; never offered. |
| `Enabled` | Explicit active flag. |

The server now respects `Enabled=false`, `FutureOnly=true`, `MinArenaLevel`, `MaxOfferLevel`, `OfferAfterLevel`, and `BlocksUpgrade` in the active offer validation path. Existing active upgrades are still enabled and keep their current effects.

## Vampire Status

`VampireShells` is prepared only in `FutureUpgradePool`, disabled and future-only.

It is not in the active `UpgradePool`, not in `UPGRADE_ORDER`, and has no gameplay effect.

## MVP Implementation Phases

1. Progression foundation
   - Keep level-up upgrade choices through level 5.
   - Let `ArenaLevel` continue past 5.
   - Track post-5 records without adding reward payouts yet.

2. Branch metadata and offers
   - Use `Branch`, `Tags`, and `Rarity` to make choices less random.
   - Ensure Defense appears intentionally instead of replacing core build choices unpredictably.

3. Revive MVP
   - Implemented wallet `trySpendBolts`.
   - Implemented arena-only `ArenaReviveRequestEvent`.
   - Implemented death panel `Revive` button.
   - Preserves run state only when revive succeeds.
   - Keep Duel untouched.

4. Post-5 rewards
   - Add safe reward milestones after levels 6+.
   - Start with small Bolts/session records.
   - Avoid permanent progression changes until the economy pass is explicit.

5. Vampire branch
   - Activate only after penetration/armor balance is stable.
   - Prefer healing on penetrating hits, not every hit.

## Laser Jitter Audit

### Current Path

- File: `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau`
- The laser runs in `RunService.RenderStepped`.
- It finds the local player tank, then reads `ShootPoint` or `Barrel`.
- It uses `muzzlePart.Position` and `muzzlePart.CFrame.LookVector`.
- It raycasts from the current raw muzzle direction.
- It moves two invisible parts, `WOBAimLaserStart` and `WOBAimLaserEnd`, and a `Beam` renders between them.

### Smoothing Relationship

- `WOBTankVisualSmoothing.client.luau` also runs in `RenderStepped` and mutates tank part `CFrame` for presentation smoothing.
- `WOBTankPossessionCamera.client.luau` uses `BindToRenderStep` after camera priority.
- The laser did not have its own visual smoothing, so render order and small tank part corrections could show as beam jitter.

### Prepared Fix

`AimAssistConfig` now has visual-only smoothing:

```lua
AimLaserVisualSmoothingEnabled = true
AimLaserVisualSmoothingSpeed = 30
AimLaserVisualSnapDistance = 120
```

`WOBAimLaser` now smooths only the beam anchor positions. It still computes the ray from the real current muzzle transform, and it does not change shooting input, server aim, projectile direction, cooldown, damage, or controls.

## What This Pass Did Not Change

- No Duel rules.
- No King/Pedestal mechanics.
- No active Vampire gameplay.
- No upgrade effects changed.
- No damage, shooting, movement, projectile collision, or Reflect Shield logic changed.
- No remotes changed.
- No `UpgradeIconConfig.luau` asset ids changed.
- No shop, DataStore design, monetization, or permanent progression changes.
