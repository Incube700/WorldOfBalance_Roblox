# Tank Entity Contract

## Purpose

This document defines the expandable tank structure for World of Balance: Ricochet Tanks. It is an architecture contract, not a gameplay refactor. The current code can keep using `PlayerTankPrototype`, `DummyTank`, `PlayerTankSpawner`, `TankSpawnResetService`, and `TankParticipantRegistry` while future prefab, skin, player tank, and bot tank work follows one stable shape.

## Five Layers

### 1. Physical Tank Model

The physical tank model is the Roblox `Model` that exists in the scene or is cloned from a template. It is the object that `TankSpawnResetService.layoutTank` positions every frame/round and that projectile raycasts hit through armor hitboxes.

Today these models live under `Workspace.WOB_Generated.TestObjects`:

- `PlayerTankPrototype`
- `Player2TankPrototype`
- `DummyTank`
- dynamic player clones named `PlayerTank_<UserId>`

`PlayerTankPrototype` is acceptable as the temporary base prefab while the MVP is still stabilizing. It should not be treated as the final asset library.

### 2. TankParticipant

`TankParticipant` is the server gameplay entity registered by `TankParticipantRegistry`. It is not a Roblox instance. It stores the current gameplay state for one tank:

- `TankId`
- `Model` / `PhysicalModel`
- `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`
- `TeamId`
- `OwnerPlayer`, `OwnerUserId`, `OwnerName`
- `ControllerType`
- `IsBot`, `IsPlayerTank`
- `ParticipantState`, `MatchId`, `OpponentTankId`
- `ControlState.Position`, `ControlState.BodyYaw`, `ControlState.TurretYaw`
- weapon state such as `WeaponTypeId`, `WeaponConfig`, `LastShotTime`, `WeaponReadyAt`
- health/death flags such as `Health`, `MaxHealth`, `IsDead`, `IsControllable`, `CanMove`, `CanShoot`

Combat, movement, death, match result, and stats should talk to `TankParticipant`, not to visual skin objects.

### 3. Controller

The controller is the source of decisions for a participant.

Current player path:

```text
Player input -> RemoteEvent -> PlayerPossessionService input map -> TankParticipant.ControlState
```

Future bot path:

```text
BotBrain -> TankParticipant.ControlState
```

Both paths must converge before movement, shooting, damage, and match logic. A bot should not create projectiles manually, write damage directly, or pretend to be a Roblox `Player`.

Current controller types:

- `Player`: player-owned tank, connected through `PlayerPossessionService`.
- `Dummy`: current server dummy participant.

Future controller types can include:

- `Bot`: AI-controlled participant using a server BotBrain.
- `Spectator` or `Disabled`: optional future non-controlling states.

### 4. Visual / Skin Layer

The visual layer is cosmetic. It can be a folder/model under the tank:

```text
TankModel
  Body
  Turret
  Barrel
  ShootPoint
  Hitboxes
    FrontArmor
    RearArmor
    LeftArmor
    RightArmor
  Visual
    HullVisual
    TurretVisual
    BarrelVisual
    Tracks
    Decorations
```

`Visual` should not be used for projectile hit ownership, armor zones, shoot origin, health, or movement collision. It may be hidden, recolored, swapped, or decorated as long as the gameplay contract remains intact.

### 5. Config / Loadout

Future player data should save IDs, not whole models:

- `EquippedTankId`
- `EquippedSkinId`
- `EquippedWeaponId`

The server should resolve those IDs into templates/configs at spawn time. Do not serialize full tank models into DataStore.

## Required Physical Model Contract

Every gameplay tank model must contain:

```text
Body
Turret
Barrel
ShootPoint
Hitboxes
  FrontArmor
  RearArmor
  LeftArmor
  RightArmor
```

Rules:

- `Body` is the hull gameplay anchor/focus part.
- `Turret` rotates independently from the body.
- `Barrel` follows turret layout.
- `ShootPoint` is the server-authoritative projectile origin.
- `Hitboxes` contains armor zone parts used by `ProjectileCombatService`.
- `FrontArmor`, `RearArmor`, `LeftArmor`, and `RightArmor` are the only current armor zones.

`PlayerTankSpawner.ensurePhysicalTankModel` may repair missing pieces today, but future prefabs should already satisfy the contract.

## Server Attributes

`TankParticipantRegistry` publishes readable attributes onto the physical model and, when applicable, the owner player. Current model attributes include:

- `TankId`
- `IsActive`
- `IsAlive`
- `IsDead`
- `IsControllable`
- `CanMove`
- `CanShoot`
- `TeamId`
- `IsBot`
- `IsPlayerTank`
- `ControllerType`
- `PhysicalModelPath`
- `ParticipantState`
- `MatchId`
- `OpponentTankId`
- `OwnerUserId`
- `OwnerName`
- `Health`
- `CurrentHealth`
- `HP`
- `MaxHealth`

These attributes are presentation/readability bridges. The server-side `TankParticipant` remains the gameplay source of truth.

## Player Connection Flow

`PlayerPossessionService` assigns a player to an available or dynamically created player participant. It sets ownership on `TankParticipantRegistry`, suppresses the default Roblox character, and stores input by player. `WOBGameplayServer` reads that input during heartbeat and applies movement/turret state to the assigned participant.

The player does not own damage, health, projectile spawning, or match state.

## Future Bot Connection Flow

A bot should be connected by assigning a non-player controller to an existing or cloned `TankParticipant`.

The future bot flow should be:

```text
TankParticipantFactory creates/registers participant
TankModelFactory clones physical model
BotBrain writes participant.ControlState
ProjectileService.tryShoot handles shooting
ProjectileCombatService handles damage and ricochet
RoundMatchService handles round/match result
```

BotBrain should differ from player input only at the decision source. It should not fork combat, damage, projectile, or match result code.

## Current PlayerTankSpawner Role

`PlayerTankSpawner.luau` is a temporary model factory/repair service. It currently:

- ensures required parts exist;
- creates missing armor hitbox folder/parts;
- assigns a primary part;
- clones player tanks for dynamic players;
- provides helper lookup for tank parts.

This is acceptable for MVP stabilization, but it should not grow into a full customization, economy, inventory, or skin system.

## What Artists / Designers Can Change

Safe visual changes:

- parts under `Visual`;
- visual colors;
- visual materials;
- meshes/decals for cosmetic parts;
- tracks/decorations;
- muzzle visual effects;
- trails/effects;
- kill effect visuals.

Safe config changes should be made in dedicated config modules and reviewed for gameplay impact.

## What Must Not Break

Skins and cosmetic work must not change:

- `Body`
- `Turret`
- `Barrel`
- `ShootPoint`
- `Hitboxes`
- armor zone names or meanings
- health values
- damage values
- projectile formulas
- match logic
- DataStore schema

Cosmetics must not move `ShootPoint`, resize armor hitboxes, or hide required gameplay parts in a way that breaks server services.

## Future Service Boundaries

### TankModelFactory

Future responsibility:

- clone a tank template by `TankTemplateId`;
- validate the physical model contract;
- place the model under the right runtime/scene folder;
- avoid adding gameplay logic.

### TankParticipantFactory

Future responsibility:

- create a `TankParticipant` table from model/config/loadout;
- register it through `TankParticipantRegistry`;
- set `ControllerType`, team, weapon config, and initial health.

### TankCustomizationService

Future responsibility:

- apply visual skins under `Visual`;
- apply cosmetic colors/materials/meshes;
- never modify gameplay hitboxes, shoot points, armor, or damage.

### PlayerLoadoutService

Future responsibility:

- read selected IDs such as `EquippedTankId`, `EquippedSkinId`, and `EquippedWeaponId`;
- validate IDs against server-owned configs;
- hand IDs to factory/customization services.

It should not store or clone whole models from DataStore.

## Why No DI Container Now

The project already uses small service modules plus explicit `init(options)` callbacks. That is enough for the current scale. A DI container would add vocabulary, startup order risk, and debugging cost before the game needs it.

Use direct requires for stable leaf modules and `init(options)` for service boundaries that need callbacks. Extract factories when there is real duplication or feature pressure.

## Future Template Location

When templates are ready to persist outside the scene, move them into a server-owned asset area such as:

```text
ServerStorage
  WOBAssets
    TankTemplates
      PrototypeTank
      HeavyTank
      ScoutTank
```

Rojo persistence should use `.rbxmx` template files. The scene should not be the only copy of production tank templates.

## Near-Term Safe Steps

- Keep the current `PlayerTankPrototype`.
- Add/use a `Visual` folder inside tank models for cosmetic parts.
- Do not break `Body`, `Turret`, `Barrel`, `ShootPoint`, or `Hitboxes`.
- Do not add shop, economy, inventory, or monetization now.
- Do not add a DI container now.
- Later extract `TankParticipantFactory`.
- Later extract `TankModelFactory`.
- Keep `TrainingBotService` as the simple v0 BotBrain; later split richer BotBrain modules if needed.
