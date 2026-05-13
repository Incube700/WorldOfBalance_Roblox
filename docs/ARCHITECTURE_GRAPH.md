# Architecture Graph

Graphify note: локальный `graphify` бинарь найден, но pipeline не запускался в этом sprint, чтобы не создавать новый `graphify-out` и не раздувать изменения. Архитектурная карта ниже сделана вручную по текущим Rojo/Luau файлам.

## Server Bootstrap Flow

```mermaid
flowchart TD
    A["WOBGameplayServer.server.luau"] --> B["Players.CharacterAutoLoads = false"]
    A --> C["Resolve ReplicatedStorage/Shared configs"]
    A --> D["Resolve Workspace/WOB_Generated folders"]
    A --> E["Create Runtime/Projectiles and Runtime/VFX"]
    A --> F["Register tank participants"]
    F --> G["TankParticipantRegistry"]
    A --> H["Init services"]
    H --> I["MatchStatsService"]
    H --> J["TankMovementService"]
    H --> K["TankSpawnResetService"]
    H --> L["ProjectileService"]
    H --> M["ProjectileCombatService"]
    H --> N["RoundMatchService"]
    H --> O["LobbyService"]
    H --> P["PlayerPossessionService"]
```

## Lobby Flow

```mermaid
flowchart TD
    A["PlayerAdded"] --> B["PlayerPossessionService.assignPlayer"]
    B --> C["Dynamic PlayerTank_<UserId>"]
    C --> D["LobbyService.playerAssigned"]
    D --> E["PlayerMode = Lobby"]
    E --> F["Spawn on LobbySpawnN with elevated Y"]
    F --> G["Free drive and no-damage shooting"]
    G --> H["StartMatchRequest"]
    H --> I["Training match"]
    G --> J["DuelPad queue"]
    J --> K["DuelQueueCount attributes"]
    K --> L["3 second countdown"]
    L --> M["PvP Duel"]
```

## Tank Participant Flow

```mermaid
flowchart TD
    A["Physical tank model"] --> B["registerTankParticipant"]
    B --> C["TankId / TeamId / Owner attrs"]
    B --> D["Body Turret Barrel ShootPoint Hitboxes"]
    D --> E["TankSpawnResetService.layoutTank"]
    C --> F["Client TankModelResolver"]
    F --> G["Camera/Input/AimLaser own tank lookup"]
```

## Movement Flow

```mermaid
flowchart TD
    A["Client TankInputEvent"] --> B["Server validates player participant"]
    B --> C["Heartbeat movement"]
    C --> D["BodyYaw + desiredMove"]
    D --> E["TankMovementService.resolveTankMovement"]
    E --> F["collect movement obstacle parts"]
    F --> G["Map walls/cover/boundaries"]
    F --> H["Lobby railings"]
    F --> I["WOBMovementObstacle parts"]
    E --> J["Blockcast include obstacles"]
    E --> K["Overlap fallback"]
    J --> L["Full move, then X, then Z"]
    K --> L
    L --> M["layoutTank preserves current Y"]
```

## Projectile And VFX Flow

```mermaid
flowchart TD
    A["ShootRequestEvent"] --> B["Server uses current turret facing"]
    B --> C["ProjectileService.tryShoot"]
    C --> D["create projectile part and trail"]
    C --> E["CombatVfxService template attempt"]
    E --> F["ReplicatedStorage/Shared/Assets/VFX"]
    E --> G["Particle Emit and Sound Play"]
    E --> H["TextureId/procedural fallback"]
    D --> I["Projectile raycast"]
    I --> J["Map/lobby obstacle hit"]
    I --> K["Tank hitbox hit"]
    J --> L["Impact VFX and ricochet"]
    K --> M["ProjectileCombatService armor result"]
    M --> N["CombatFeedbackEvent"]
```

## Client Camera Input HUD Flow

```mermaid
flowchart TD
    A["TankModelResolver"] --> B["Owned tank by OwnerUserId"]
    B --> C["WOBTankPossessionCamera"]
    B --> D["WOBTankInputController"]
    B --> E["WOBAimLaser"]
    F["Root/Player attributes"] --> G["WOBRoundStatusOverlay"]
    H["CombatFeedbackEvent"] --> I["WOBCombatFeedbackOverlay"]
    J["Runtime/VFX"] --> K["WOBImpactFeedbackOverlay"]
    L["Runtime/Projectiles"] --> M["WOBProjectileReadabilityOverlay"]
    N["DuelPad attributes"] --> O["WOBDuelPadVisual"]
```

## Config Dependencies

- `TankConfig`: movement speed, body turn speed, turret turn speed, shoot facing rule, armor/hitbox layout.
- `WeaponConfig`: primary weapon id, cooldown, projectile type id.
- `ProjectileCatalog`: projectile speed, damage, penetration, ricochet count and lifetime.
- `VfxConfig`: shot sound, projectile visuals, procedural VFX, template names/lifetimes/emit counts.
- `MatchConfig`: series target wins.
- `CameraConfig`, `AimAssistConfig`, `HudConfig`, `ProjectileVisualConfig`: client presentation.

## Scene Contract

- `Workspace/WOB_Generated/Runtime`: runtime projectiles and VFX only.
- `Workspace/WOB_Generated/TestObjects`: physical tank models.
- `Workspace/WOB_Generated/Map`: arena walls, cover, ricochet walls, spawn points.
- `Workspace/WOB_Generated/Lobby`: elevated lobby floor, railings, spawn points, DuelPad.
- `ReplicatedStorage/Shared/Assets/VFX`: source templates for cloned VFX.
- `docs/patches/*_COMMAND.lua`: manual Studio scene repair, always outside Play Mode.
