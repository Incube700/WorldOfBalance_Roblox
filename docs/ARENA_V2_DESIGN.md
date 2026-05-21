# Arena V2 Design

World of Balance: Ricochet Tanks

This document describes the BattleArena V2 progression layer. It is both a design contract and an implementation guide for the first Arena V2 foundation pass.

## Goals

BattleArena should feel alive for a solo or small-group playtest. The player should have short-term goals beyond simply driving and shooting: gain arena XP, level up, choose upgrades, fight around points of interest, grab medkits, and use supply crates.

Arena V2 must preserve the current working game:

- Duel remains skill-based and normalized.
- Training quick flow remains separate.
- Bot v0.1 remains compatible.
- TankFactory, ArmorHitResolver, ProjectileService, world HP/reload bars, and current VFX/audio flows stay intact.
- Permanent economy/progression should not leak into Duel balance.

## BattleArena V2 Core Loop

BattleArena V2 should become a run-based survival, king-of-the-hill, and semi-extraction-adjacent mode. The player is not just entering a free-fire test area; they are starting an arena run with temporary power growth and escalating danger.

Core flow:

1. Enter BattleArena from Lobby.
2. Start `ArenaRun`.
3. Fight bots and players.
4. Earn `ArenaXP` from kills, survival time, Control Zone ticks, and Supply Crates.
5. Level up `ArenaLevel` from 1 to 5.
6. Choose temporary run upgrades.
7. Difficulty escalates as the run continues.
8. Death resets the current run upgrades.
9. Player keeps session score and earned currencies according to reward rules.
10. Return to Lobby or re-enter the arena for another run.

The emotional shape should be: enter weak, survive, become dangerous, take bigger risks, eventually die or bank rewards, then try again.

## Run Reset Rules

Arena upgrades are temporary run power. They make BattleArena fun and chaotic without creating a permanent stat advantage in Duel.

Reset on death:

- current-run `ArenaXP`;
- `ArenaLevel`;
- temporary upgrades;
- temporary weapon and tank modifiers;
- active streak bonus.

Keep after death:

- `ArenaScore`;
- kills and deaths;
- already granted Bolts;
- granted Crystals;
- milestone progress if implemented later.

The exact reward timing should be server-owned. If a reward has already been granted, death should not claw it back unless the future mode explicitly marks it as unbanked.

## King Of The Hill / Control Zone

The Control Zone is the center pressure mechanic for BattleArena V2.

Control Zone intent:

- central dangerous zone;
- staying inside grants `ArenaXP` over time;
- bots are attracted to the zone;
- longer hold means better reward;
- creates high-risk/high-reward gameplay.

The zone should not be a strict capture objective in v2. It is a bonus pressure point: if several players are inside, all eligible participants can earn XP, and the danger comes from fighting over the same space.

## Semi-Extraction Future Layer

BattleArena can later grow an optional extraction-lite reward layer without becoming the full future Extraction mode.

Future optional extraction-lite:

- arena can contain extraction/save points;
- player can bank unbanked loot and rewards;
- death loses unbanked loot;
- successful extraction saves more rewards;
- do not implement this now.

This layer should remain optional and mode-specific. It must not change Duel, and it should not introduce permanent power advantages into normalized Duel.

## Points Of Interest

BattleArena V2 should use points of interest to create movement decisions instead of letting the best play be standing still and shooting.

Possible POIs:

- Control Zone;
- Supply Crates;
- Repair/Medkit areas;
- ricochet corridors;
- bot spawn camps;
- high-risk center;
- future extraction point;
- future boss/event point.

POIs should teach the arena's geometry. Ricochet corridors and visible armor zones should make players think about angle, hull positioning, and bounce shots rather than only raw aim.

## Difficulty Escalation

As the player survives and levels up, the arena should push back harder.

Escalation options:

- more bots spawn;
- bots become more aggressive;
- stronger bot variants appear later;
- arena hazards can activate later;
- reward multiplier increases.

V2 should start with simple, readable escalation. Stronger variants, hazards, and multipliers can be layered in later after the base run loop is stable.

## Minimap / Navigation

Do not implement a minimap now.

First use:

- world labels;
- arrows/signs;
- edge indicators;
- colored zones.

A minimap can become a future feature if the arena grows large enough that players cannot understand points of interest from the camera view, world labels, and arena composition alone.

## BattleArena Balance Rules

- Arena upgrades are temporary and reset on death.
- Duel remains normalized and skill-based.
- Permanent stat upgrades should not affect Duel by default.
- Arena can have chaos and progression because it is not pure competitive Duel.
- BattleArena progression should reward risk, survival, and map control without replacing the core ricochet/armor skill.

## Implementation Status

Arena V2 foundation now exists in code:

- `ArenaXP`, `ArenaLevel`, and `ArenaNextLevelXP` are published as player attributes.
- Kills award `BattleArenaConfig.XPPerKill`.
- Survival ticks award `BattleArenaConfig.XPPerSurvivalTick`.
- Supply Crates award `BattleArenaConfig.XPPerSupplyCrateUse` when an offer is created.
- Level-up creates a server-authoritative `UpgradeChoiceEvent` offer.
- Client BattleArena HUD can display level/XP and a 3-choice upgrade panel.
- Selected upgrades are validated and applied on the server.
- Death resets current-run XP, level, temporary upgrades, modifiers, and streak while keeping score/kills/deaths.
- Medkits, Supply Crates, and Control Zone are optional runtime scene hooks. If the matching scene objects are absent, the systems stay inactive without errors.
- Survival XP is intentionally small by default so fighting and Control Zone play remain the main XP sources.

## 1. Tank Level System In Arena

### Current State

`ArenaCombatService.luau` currently gives `+1 Score` for each kill and stores it in `session.Score`.

Temporary arena upgrades are currently granted automatically by score thresholds in `BattleArenaConfig.UpgradeThresholds`.

### New State

Replace the meaning of BattleArena score progression with Arena XP and Arena Level.

Implementation can either rename `Score` to `ArenaXP` or add `ArenaXP` as a separate field while keeping `Score` as a display/backward-compatibility value during migration. The preferred long-term model is:

- `ArenaXP`: accumulated XP inside the current arena session.
- `ArenaLevel`: level inside the current arena session, from 1 to 5.
- `ArenaKills`: kill count.
- `ArenaDeaths`: death count.

### XP Rules

Kill reward:

| Event | XP |
| --- | ---: |
| Kill enemy arena participant | 100 |

Level thresholds are cumulative. XP does not reset after level-up.

| Level | Required Total XP |
| --- | ---: |
| 1 | 0 |
| 2 | 100 |
| 3 | 250 |
| 4 | 450 |
| 5 | 700 |

Example:

- Player starts at `ArenaLevel = 1`, `ArenaXP = 0`.
- First kill gives `ArenaXP = 100`, player reaches level 2.
- Next kill gives `ArenaXP = 200`, still level 2.
- Next kill gives `ArenaXP = 300`, player reaches level 3.

### Level-Up Flow

When `ArenaXP` reaches the next threshold:

1. Server increments `ArenaLevel`.
2. Server creates an upgrade offer with 3 choices.
3. Server fires `UpgradeChoiceEvent` to the client with the offer.
4. Client shows a 3-choice upgrade screen.
5. Player chooses one upgrade.
6. Client sends the selected upgrade ID back through `UpgradeChoiceEvent`.
7. Server validates the choice against the active offer.
8. Server applies the selected upgrade.
9. Server marks the offer as consumed.

The choice UI must not block driving, aiming, or shooting. The player can die while the UI is open. If the player dies before choosing, the offer may remain available during respawn unless the implementation chooses to expire it; v2 should prefer keeping the offer until selected to avoid feels-bad loss.

### Upgrade Offer Rules

The server should be authoritative for upgrade offers.

The client may display the choices, but it must not decide the actual pool, validity, stack counts, or final application.

Offer rules:

- Show 3 random upgrade choices.
- Do not offer upgrades already at max stacks.
- Do not offer `DoubleShot` if the player already has `TripleSpread`.
- If the player has `DoubleShot`, `TripleSpread` may appear as the next spread upgrade.
- `Repair` can appear repeatedly because it is an immediate one-time choice, not a permanent upgrade.
- If fewer than 3 valid choices exist, show the remaining valid choices.

### Upgrade Pool

| Upgrade ID | Effect | Stack Rule |
| --- | --- | --- |
| `DamageUp` | `+20%` projectile damage | Max 2 stacks |
| `FireRateUp` | `-15%` weapon cooldown | Max 1 stack |
| `MoveSpeedUp` | `+10%` movement speed | Max 2 stacks |
| `DoubleShot` | Fire 2 projectiles | Replaced by `TripleSpread` path if already owned |
| `TripleSpread` | Fire 3 projectiles in a spread | Max 1 stack |
| `RicochetUp` | `+1` max projectile ricochet | Max 1 stack |
| `Repair` | Immediately restore 30 HP on current tank, clamped to MaxHealth | One-time choice, not stored as an upgrade |

### Shell Research / Ricochet Research

Shell Research is a readability and mastery upgrade family. It improves how clearly the player understands shots, ricochets, and armor interactions instead of directly increasing raw damage or HP.

This family fits the core identity of Ricochet Tanks:

- wall bounces should be readable;
- armor zones should be visible and meaningful;
- players should learn to angle the hull like a diamond;
- front armor should communicate strong protection;
- side armor should communicate medium protection;
- rear armor should communicate vulnerability.

Suggested progression:

| Research Level | Upgrade Effect | Gameplay Intent |
| --- | --- | --- |
| 1 | Clearer aim laser / longer aim line | Helps players aim deliberately before learning ricochets. |
| 2 | Aim laser previews 1 wall ricochet | Teaches basic bounce shots and wall geometry. |
| 3 | Aim laser previews 2 wall ricochets | Supports advanced arena shots without changing damage. |
| 4 | Impact point marker after ricochet | Shows where a bounced shot is likely to land. |
| 5 | Armor interaction hint: likely `Penetration` / `NoPen` / `Ricochet` color feedback | Helps players understand armor angle and hull positioning. |

Balance rules:

- Allowed in BattleArena and future Extraction.
- Should not create unfair permanent advantage in normalized Duel.
- In Duel, this family should be disabled, equalized for both players, or reserved for a future casual/unranked Duel mode.
- This is progression toward readability, prediction, and mastery, not raw damage.
- This is a healthier Duel-adjacent progression type than permanent `+Damage` or `+HP`, because it supports the core ricochet skill instead of replacing it with stats.

### Upgrade Ownership

Arena upgrades are session-scoped. They should reset when the player leaves BattleArena or when the arena session ends.

Suggested session data:

```text
session.ArenaXP
session.ArenaLevel
session.UpgradesById
session.PendingUpgradeOffer
session.PendingUpgradeOfferId
```

For BattleArena V2, implementation should distinguish current-run temporary power from persistent session stats. `ArenaXP`, `ArenaLevel`, and `UpgradesById` reset on death as run state. `ArenaScore`, kills, deaths, and already granted currencies remain as session or reward state.

## 2. Medkits

### Purpose

Medkits create movement goals and recovery windows in BattleArena without changing Duel balance.

### Map Placement

There should be 3 to 4 static medkit points in the arena. Exact coordinates depend on the current map and should be decided in Studio later.

Expected DataModel path:

```text
Workspace
`-- WOB_Generated
    `-- BattleArena
        `-- Medkits
            |-- Medkit1
            |-- Medkit2
            `-- ...
```

Each medkit is a `Part` or model with a trigger part.

### Behavior

- A tank touches or overlaps the medkit.
- Server checks that the tank belongs to an active BattleArena participant.
- Server checks that the tank is alive.
- Server checks that current HP is below MaxHealth.
- Server heals 40 HP, clamped to MaxHealth.
- Medkit becomes invisible and inactive.
- After 30 seconds, medkit respawns and becomes active again.

### Rules

| Rule | Value |
| --- | ---: |
| Heal amount | 40 HP |
| Respawn time | 30 seconds |
| Works at full HP | No |
| Works outside BattleArena | No |

Server validation should use or expose a helper such as `ArenaCombatService.IsParticipantInArena(participant)`.

## 3. Points Of Interest

### 3.1 Control Zone

The Control Zone gives players a reason to fight over the center without hard-locking the match into a capture mode.

Expected DataModel path:

```text
Workspace
`-- WOB_Generated
    `-- BattleArena
        `-- ControlZone
```

The zone should be a visible floor cylinder or flat trigger with a readable neutral glow. Suggested visual color: soft blue/cyan.

### Control Zone Behavior

- One control zone exists in the center of the arena.
- Every 5 seconds, the server checks which active arena tanks are inside the zone.
- Every participant inside the zone receives `+50 ArenaXP`.
- If multiple players are inside, all of them receive XP.
- The zone is not captured and has no owner.
- Bots may be eligible later, but v2 should decide explicitly whether bots gain XP. Recommended v2 default: player participants only, unless bot upgrades are intentionally tested.

### Control Zone Rules

| Rule | Value |
| --- | ---: |
| XP per tick | 50 |
| Tick interval | 5 seconds |
| Capture ownership | None |
| Multiple players | All eligible participants receive XP |

### 3.2 Supply Crates

Supply Crates create high-value pickup moments and a second route to upgrades beyond kills and control zone XP.

Expected DataModel path:

```text
Workspace
`-- WOB_Generated
    `-- BattleArena
        `-- SupplyCrates
            |-- SupplyCrate1
            `-- SupplyCrate2
```

### Supply Crate Behavior

- 2 crates exist in the arena.
- A tank touches or overlaps a crate.
- Server checks that the tank belongs to an active BattleArena participant.
- Server checks that the crate is active.
- Server checks that this same player did not already use this crate during its current active cycle.
- Server sends a 3-choice upgrade offer through the same upgrade choice flow used by level-ups.
- Crate becomes inactive after use.
- After 60 seconds, crate respawns and may be used again.

### Supply Crate Rules

| Rule | Value |
| --- | ---: |
| Crate count | 2 |
| Respawn time | 60 seconds |
| Upgrade choices | 3 random valid choices |
| Same player same crate twice before respawn | No |
| Blocks movement while choosing | No |

Supply crates should reuse the same server-side offer validation as level-up choices.

## 4. Code Changes For Future Implementation

This section lists files likely affected by the implementation. It is intentionally a list, not code.

### `src/ServerScriptService/Server/Gameplay/Arena/ArenaCombatService.luau`

Add:

- `ArenaXP` to each arena session.
- `ArenaLevel` to each arena session.
- cumulative level-up checks.
- server-side upgrade offer generation.
- server-side upgrade choice validation.
- server-side upgrade application.
- `UpgradeChoiceEvent` handling.
- Control Zone XP tick logic.
- Medkit pickup/respawn logic.
- Supply Crate pickup/respawn logic.
- helper such as `IsParticipantInArena(participant)`.

Change:

- Stop granting upgrades automatically from `UpgradeThresholds`.
- Keep kill/death stat behavior intact.
- Decide whether existing `Score` remains as kill score, display score, or is migrated to `ArenaXP`.

### `src/ReplicatedStorage/Shared/Configs/BattleArenaConfig.luau`

Add config:

```text
XPPerKill = 100
XPPerSurvivalTick = 10
SurvivalTickInterval = 10
LevelThresholds = {
    [1] = 0,
    [2] = 100,
    [3] = 250,
    [4] = 450,
    [5] = 700,
}
XPPerControlZoneTick = 50
XPPerSupplyCrateUse = 50
ControlZoneTickInterval = 5
MedkitHealAmount = 40
MedkitRespawnTime = 30
CrateRespawnTime = 60
```

Optional config:

```text
MaxArenaLevel = 5
UpgradeChoicesPerOffer = 3
MedkitFolderName = "Medkits"
SupplyCrateFolderName = "SupplyCrates"
ControlZoneName = "ControlZone"
```

### `src/StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau`

Add:

- Arena Level display.
- Arena XP display.
- Optional progress text or progress bar toward the next level.
- 3-button upgrade choice UI.
- upgrade offer state.
- client handler for server-to-client `UpgradeChoiceEvent`.
- client send-back for selected upgrade ID.

The choice UI should be readable on mobile and should not block movement input.

### New RemoteEvent: `UpgradeChoiceEvent`

Use one RemoteEvent for both directions:

Server to client:

```text
UpgradeChoiceEvent:FireClient(player, {
    OfferId = "...",
    Source = "LevelUp" | "SupplyCrate",
    ArenaLevel = number,
    Choices = {
        { Id = "DamageUp", Title = "...", Description = "..." },
        ...
    },
})
```

Client to server:

```text
UpgradeChoiceEvent:FireServer({
    OfferId = "...",
    UpgradeId = "DamageUp",
})
```

Server must validate:

- player is in BattleArena;
- offer exists;
- offer belongs to that player;
- offer is not consumed;
- selected ID is one of the offered choices;
- selected upgrade is still valid at application time.

## 5. Upgrade Application Notes

Implementation should keep current combat systems authoritative on the server.

Suggested ownership:

- Weapon cooldown and projectile count modifiers apply in the server weapon/projectile firing path.
- Damage modifiers apply in the server projectile/combat path.
- Movement modifiers apply in the server movement path.
- `Repair` applies immediately through the same health setter used by combat.

Do not duplicate upgrade effects in the client. The client may display icons/text, but the server owns actual gameplay values.

## 6. UX Notes

### Arena HUD

BattleArena HUD should show:

- Arena Level.
- Arena XP, ideally with next threshold.
- Kills / Deaths.
- Current session currencies if already displayed.
- Upgrade choice popup only when there is an active offer.

Mobile layout must stay compact and must not cover joystick, aim stick, fire button, or the central combat area.

### Upgrade Choice UI

The popup should:

- show 3 large choices;
- fit mobile width;
- have short titles and descriptions;
- allow delayed selection while the player continues playing;
- disappear after a valid choice is accepted by the server;
- show a small confirmation if possible.

## 7. Balancing Intent

Arena V2 is allowed to be more chaotic and progression-heavy than Duel.

Duel remains normalized. Arena can use run-based power because it is not the pure competitive 1v1 mode.

Permanent `+Damage` or `+HP` should not become the main Duel progression path. Upgrades such as Shell Research / Ricochet Research are better long-term progression candidates because they deepen the player's understanding of ricochets, armor zones, and angle play while preserving skill expression.

The intended loop:

1. Kill enemies for XP.
2. Fight over Control Zone for bonus XP.
3. Risk movement toward Medkits and Supply Crates.
4. Level up and choose upgrades.
5. Become stronger within the current arena run.
6. Reset temporary power when leaving the arena.

## 8. What Not To Do Now

- Do not implement Extraction mode.
- Do not add ranked matchmaking.
- Do not touch Duel mode.
- Do not change service architecture.
- Do not add permanent Duel-affecting stat upgrades.
- Do not replace Bot v0.1 behavior as part of Arena V2.
- Do not rebalance armor/projectile numbers as part of the upgrade design.
- Do not edit `.rbxl` directly from code.
