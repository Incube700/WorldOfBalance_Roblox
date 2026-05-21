# Base Tank Template Workflow

## Purpose

`BaseTankTemplate` is the editable, in-Studio master template for the default tank.
It separates gameplay structure (physics, armor, query) from visual skin (decoration, color).
TankFactory reads this template at runtime and never mutates it.

---

## Target Hierarchy

```
BaseTankTemplate  (Model)
├── Body           (Part)          -- stable physics hull, PrimaryPart
├── Turret         (Part)          -- rotates on Y for aiming
├── Barrel         (Part)          -- elevates for pitch
├── ShootPoint     (Part)          -- invisible origin for projectiles
├── ArmorZones     (Folder)        -- gameplay query zones, visible by default
│   ├── FrontArmor (Part)
│   ├── RearArmor  (Part)
│   ├── LeftArmor  (Part)
│   └── RightArmor (Part)
└── Visuals        (Folder)        -- decoration only, no collision/query
    ├── BodyVisual  (Part | MeshPart | SpecialMesh)
    ├── TurretVisual
    ├── BarrelVisual
    └── Decorations (Folder, optional)
```

---

## Part Rules

### Body / Hull
- `Anchored = false`
- `CanCollide = true`
- `CanQuery = true`
- `CanTouch = true`
- Must be set as `PrimaryPart` of the model.
- All other parts should be welded (WeldConstraint) to Body or to Turret where appropriate.

### ArmorZones (FrontArmor / RearArmor / LeftArmor / RightArmor)
- `CanCollide = false`
- `CanTouch = false`
- `CanQuery = true`         ← projectile raycasts hit these
- `Massless = true`
- `Anchored = false`
- Welded to Body via `WOBArmorBodyWeld` WeldConstraint.
- Color and transparency are set by `TankArmorPartsService` from `TankArmorConfig.Visuals`.
- Visible by default (`Transparency` from config, not 1).
- Attribute `WOBArmorHitbox = true` is set at runtime.
- Attribute `ArmorZone = "Front" | "Side" | "Rear"` is set at runtime.
- **Do not** use these as decoration — they are gameplay zones.

### Visuals folder parts (BodyVisual / TurretVisual / BarrelVisual / Decorations)
- `CanCollide = false`
- `CanTouch = false`
- `CanQuery = false`        ← projectiles ignore these
- `Massless = true`
- `Anchored = false`
- Welded to the appropriate parent part (BodyVisual → Body, TurretVisual → Turret, etc.).
- Color / material / mesh is set by `TankSkinApplier`.
- Safe to edit freely: changing these does not affect combat, physics, or armor.

---

## Template Lookup Priority (TankTemplateProvider)

1. `Workspace.WOB_Generated.TestObjects.BaseTankTemplate` — if present, used for **all roles**.
2. Role-specific legacy fallback:
   - Player / ArenaPlayer → `PlayerTankPrototype`
   - DuelOpponent / Bot / ArenaBot → `Player2TankPrototype`, then `PlayerTankPrototype`
   - Dummy → `DummyTank`, then `PlayerTankPrototype`
3. `PlayerTankPrototype` as final catch-all.

**BaseTankTemplate is never created by code.** The user places it in Studio.

### Startup Participants

Three static participants (`Startup_Player`, `Startup_Dummy`, `Startup_Player2`) are created at server start with `IsActive = false`. They use `TankFactoryConfig.StartupParticipantIds` keys whose names do not match any legacy prototype model, so `TankFactory` always resolves them through `GetTemplateForRole` — picking `BaseTankTemplate` when available.

**Startup tanks must not appear as visible active tanks in the lobby.**
`TankSpawnResetService.configureActiveParticipants` controls visibility. The rule is:
- Player-role tanks are visible only when `participant.OwnerPlayer ~= nil` (i.e., a real player was assigned).
- DuelOpponent-role tanks are visible only when `matchMode == "PvP"` and a second player has joined.
- Dummy-role tanks are visible only during Training mode.

`Startup_Player` has no owner at server start and must stay hidden. If you see an extra visible large tank in the lobby that you did not expect, check `configureActiveParticipants` — it must not call `setParticipantModelVisible(participant, true)` for unowned player-role tanks.

### Hitbox Folder Contract

`participant.Hitboxes` must always point to the armor hitbox folder — either `ArmorZones` (BaseTankTemplate) or `Hitboxes` (legacy prototypes).

`PlayerTankSpawner.ensurePhysicalTankModel` skips creating a `Hitboxes` folder when the model already has an `ArmorZones` folder. This prevents creating unwelded ghost armor parts at the initial spawn position that would stay in place while the tank moves.

**Do not rename `ArmorZones` to `Hitboxes` in BaseTankTemplate.** The runtime systems prefer `ArmorZones` and the hitbox folder lookup is order-sensitive: ArmorZones wins.

---

## Runtime Attributes (set by TankFactory on each spawned model)

| Attribute           | Type   | Meaning                                                    |
|---------------------|--------|------------------------------------------------------------|
| `TemplateSourceName`| string | Name of the cloned template (`"BaseTankTemplate"`, `"PlayerTankPrototype"`, …) or `"reused"` when an existing model was returned without cloning. |
| `TemplateSourcePath`| string | Full Roblox path of the source template at spawn time. |
| `TankRole`          | string | Role string (Player, Dummy, ArenaBot, …). |
| `SkinId`            | string | Active skin identifier. |

To verify which template a runtime tank used, select the model in Studio Explorer (during Play Mode) → Properties → Attributes.

---

## Skin / Visual Contract

`TankSkinApplier.Apply(tankModel, loadout)` is called by `TankFactory` after every clone or reuse.

Current supported SkinIds:
- `"Default"` — applies base colors to Visuals folder; does not touch ArmorZones or stats.

Future skins add new SkinIds without changing gameplay parts.

---

## Manual Editing Workflow

1. **Stop Play Mode** in Studio (if running).
2. In the Explorer, navigate to `Workspace > WOB_Generated > TestObjects`.
3. Locate `PlayerTankPrototype` — this is the current legacy template.
4. **Duplicate** it as a backup: right-click → Duplicate. Rename copy to `PlayerTankPrototype_BACKUP`.
5. Duplicate again and rename to `BaseTankTemplate`.
6. Inside `BaseTankTemplate`:
   - Create a `Folder` named `ArmorZones`. Move or create `FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor` inside it.
   - Create a `Folder` named `Visuals`. Move or create visual decoration parts inside it.
   - Set armor part properties per the rules above.
   - Set `BaseTankTemplate.PrimaryPart = Body`.
7. **Do not edit** a runtime `PlayerTank_<UserId>` model — those are live clones.
8. Enter Play Mode and verify:
   - Tank spawns and moves.
   - Armor zones are visible with correct colors.
   - Projectiles register hits on ArmorZones.
   - Bot and Duel still function.
9. If everything works: **File → Save to File** (saves the .rbxl).
10. Commit the .rbxl as a separate commit from Luau source changes.

---

## What TankSkinApplier Does vs What TankArmorPartsService Does

| Responsibility                          | Module                  |
|-----------------------------------------|-------------------------|
| Resize + position armor zone parts      | TankArmorPartsService   |
| Set CanQuery/CanCollide/Massless        | TankArmorPartsService   |
| Set armor zone color/transparency       | TankArmorPartsService   |
| Weld armor zones to Body               | TankArmorPartsService   |
| Apply skin color to Visuals parts       | TankSkinApplier         |
| Set CanQuery=false on Visuals parts     | TankSkinApplier         |
| Apply mesh / material to Visuals        | TankSkinApplier         |
| Armor stat tuning                       | TankArmorConfig (never touched by skin) |

---

## Debugging Projectile Pass-Through

If shells pass through a tank, check in this order:

1. **IsActive** — is the tank `IsActive=true`? Inactive tanks are excluded from projectile targets.
2. **Hitbox folder** — does the tank have `ArmorZones` (preferred) or `Hitboxes`? Run `AUDIT_TANK_TEMPLATE_RIG_COMMAND.lua` to verify.
3. **CanQuery** — are all four armor zone parts (`FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor`) `CanQuery=true`?
4. **Welding** — are armor zone parts welded to Body via `WOBArmorBodyWeld`? Unwelded parts fall to the ground.
5. **TemplateSourceName** — is it `"BaseTankTemplate"`? Legacy fallback tanks use `"Hitboxes"`, not `"ArmorZones"`.
6. **Enable debug**: set `DebugCombatConfig.ProjectileDebug = true` in Studio and watch the Output panel for `[PROJECTILE COLLISION]` and `[PROJECTILE HIT]` logs.

**Root cause that was fixed (2025)**: `PlayerTankSpawner.ensurePhysicalTankModel` was creating a `Hitboxes` folder with unanchored, unwelded armor parts when `BaseTankTemplate` already had an `ArmorZones` folder. The unwelded parts fell to the ground; projectile raycasts targeted them instead of the welded ArmorZones parts, causing shells to hit the ground instead of the tank. Fixed by skipping Hitboxes creation when ArmorZones already exists.

## Known Limitations (this pass)

- `BaseTankTemplate` must be placed manually in Studio; it is not auto-created.
- Only `SkinId = "Default"` is implemented in `TankSkinApplier`.
- The legacy `PlayerTankPrototype` / `Player2TankPrototype` / `DummyTank` prototypes remain in scene as fallbacks and are not deleted until BaseTankTemplate is verified across Player/Duel/Bot/Dummy modes.
- `Visuals` folder parts must be manually created and welded in Studio; TankSkinApplier only configures them, does not create them.
- Skin shop / cosmetic unlock system is out of scope for this pass.
