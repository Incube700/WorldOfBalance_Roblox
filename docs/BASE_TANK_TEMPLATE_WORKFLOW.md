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

## Known Limitations (this pass)

- `BaseTankTemplate` must be placed manually in Studio; it is not auto-created.
- Only `SkinId = "Default"` is implemented in `TankSkinApplier`.
- The legacy `PlayerTankPrototype` / `Player2TankPrototype` / `DummyTank` prototypes remain in scene as fallbacks and are not deleted.
- `Visuals` folder parts must be manually created and welded in Studio; TankSkinApplier only configures them, does not create them.
- Skin shop / cosmetic unlock system is out of scope for this pass.
