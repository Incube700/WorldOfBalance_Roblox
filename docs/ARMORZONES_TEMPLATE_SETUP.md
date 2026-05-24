# ArmorZones Template Setup (pre-bake to remove runtime armor creation)

## Why this exists

On every tank spawn, `PlayerTankSpawner.ensurePhysicalTankModel` →
`ensureHitboxes` checks the cloned tank model for an armor-zone folder and the four
named armor parts. If they are missing, it **creates them at runtime** (a Folder +
four `Part`s) and logs lines like:

```
[TANK] created missing <model>.Hitboxes
[TANK] created missing <model>.ArmorZones.FrontArmor
```

`TankArmorPartsService.Configure` then sizes, colours, and welds those parts to the
tank Body. Doing this for every fresh bot/player clone adds instance-creation +
weld + descendant-scan work to the BattleArena entry frame (see
`docs/PERFORMANCE_RUNTIME_DEEP_DIVE.md` §5).

If the **template** already contains a correct `ArmorZones` folder with the four
parts, `ensureHitboxes` finds them and creates nothing — the entry frame gets
cheaper and the "created missing" logs stop.

> This is a **template/asset** change only. It does not touch gameplay numbers,
> armor values, ricochet rules, damage, or `TankArmorConfig`. `Configure` still runs
> at spawn and remains the source of truth for size/colour/weld, so authored geometry
> does not need to be exact — only the folder and part **names/classes** matter.

## Verified current state (inspected 2026-05-24, in `RicochetTanksPrototype.rbxlx`)

A read-only inspection of the place file confirms exactly what to fix:

- **`BaseTankTemplate` is the only tank template present.** The legacy prototypes
  (`PlayerTankPrototype`, `Player2TankPrototype`, `DummyTank`) do **not** exist in the
  place. Because `BaseTankTemplate` is priority 1 in `TankTemplateProvider`, it is the
  template used for **every** role — both **Player** and **ArenaBot**. Fixing this one
  model fixes all spawns.
- **Location:** `ServerStorage › TankTemplates › BaseTankTemplate` (the preferred home;
  matches `TankFactoryConfig.TemplateStorageFolderName = "TankTemplates"`).
- **Children today:** `Body`, `Turret`, `Barrel`, `ShootPoint`, `ArmorZones`, `Visuals`.
- **`ArmorZones` already exists but is EMPTY** — it contains none of `FrontArmor`,
  `RearArmor`, `LeftArmor`, `RightArmor`. That is exactly why spawns log
  `[TANK] created missing ...ArmorZones.FrontArmor` (×4) but **not** the `...Hitboxes`
  line (the folder is found; only the parts are missing).
- **`Body` size** is ≈ `(7.73, 2.90, 10.63)` — useful for rough placement, though
  `TankArmorPartsService.Configure` recomputes the exact size/position at spawn.

**So the remaining work is minimal:** add the four named `Part`s **inside the existing
`ArmorZones` folder**. You do not need to create the folder or touch `Body`.

## Why it is not auto-edited here

The tank templates are **not** Rojo-managed. `TankTemplateProvider` resolves them at
runtime from, in priority order:

1. `ServerStorage.TankTemplates.BaseTankTemplate` (preferred home), then
2. `Workspace.WOB_Generated.TestObjects.BaseTankTemplate`, then
3. legacy per-role prototypes by name: `PlayerTankPrototype`,
   `Player2TankPrototype`, `DummyTank`.

None of these models exist as files under `src/` — they live only inside the Studio
place (`RicochetTanksPrototype.rbxlx`). Editing a 2.4 MB serialized `.rbxlx` by hand
to insert parts is error-prone and risky, so it is **not** done automatically. Follow
the manual Studio steps below instead.

## Required hierarchy (what the code looks for)

`ensureHitboxes` / `TankArmorPartsService.findArmorZonesFolder` accept a folder named
**`ArmorZones`** (preferred) or legacy **`Hitboxes`**, found directly under the tank
Model (a deep descendant search is also done). Use `ArmorZones`. Inside it, exactly
these four parts must exist:

```
<TankTemplate Model>
├── Body            (existing BasePart — required so armor can be sized/welded;
│                    "Hull" is also accepted as the body part)
├── Turret, Barrel, ShootPoint  (existing — unchanged)
└── ArmorZones      (Folder)              <-- add this
    ├── FrontArmor  (Part / BasePart)     <-- add these four
    ├── RearArmor   (Part / BasePart)
    ├── LeftArmor   (Part / BasePart)
    └── RightArmor  (Part / BasePart)
```

Names are case-sensitive and must match exactly: `ArmorZones`, `FrontArmor`,
`RearArmor`, `LeftArmor`, `RightArmor`.

### Part properties to author

`TankArmorPartsService.configureArmorPart` overrides Size, CFrame, Material, Color,
Transparency, and the body weld at spawn, and sets the gameplay attributes. So the
authored values only need to be **valid and queryable**. Set each of the four parts to:

| Property | Value | Why |
| --- | --- | --- |
| ClassName | `Part` | Must be a `BasePart`; `ensureHitboxes` rejects non-BasePart and warns. |
| `Anchored` | `false` | Welded to Body at runtime; matches `Configure`. |
| `Massless` | `true` | So armor doesn't affect tank physics. |
| `CanCollide` | `false` | Armor must not block movement. |
| `CanTouch` | `false` | No Touched events. |
| `CanQuery` | **`true`** | **Required** — projectile raycasts must hit armor parts. |
| `CastShadow` | `false` | Matches performance profile. |
| `Transparency` | ~0.35 (front) / ~0.45 (others) | Cosmetic; re-applied by `Configure`. |
| `Color` | front green / rear red / sides yellow | Cosmetic; re-applied from `TankArmorConfig.Visuals`. |

Sensible starting Size/Offset (relative to Body, taken from `PlayerTankSpawner`
`HITBOX_SPECS`; `Configure` will recompute exact values from the Body size):

| Part | Size (X,Y,Z) | Offset from model pivot |
| --- | --- | --- |
| FrontArmor | `8.7, 5.4, 0.25` | `(0, 3.4, -5.7)` |
| RearArmor | `8.7, 5.4, 0.25` | `(0, 3.4, 5.7)` |
| LeftArmor | `0.25, 5.4, 11.7` | `(-4.2, 3.4, 0)` |
| RightArmor | `0.25, 5.4, 11.7` | `(4.2, 3.4, 0)` |

> The colour-coded, visible armor zones are an **intentional readability design
> decision**, not debug clutter. Keep them visible and colour-coded; do not set them
> black or fully transparent. `Configure` enforces the colours from
> `TankArmorConfig.Visuals` at spawn.

Do **not** author the weld — `TankArmorPartsService.getOrCreateBodyWeld` creates a
`WeldConstraint` named `WOBArmorBodyWeld` at spawn. Authoring one is harmless (it is
validated/replaced) but unnecessary.

## Manual Studio steps (for this place — `ArmorZones` folder already exists)

Because the inspection above shows the `ArmorZones` folder is already present and only
its four parts are missing, the steps reduce to "add four parts into the existing
folder."

1. **Open** `RicochetTanksPrototype.rbxlx` in Studio.
2. **Select the folder.** In Explorer, expand
   `ServerStorage › TankTemplates › BaseTankTemplate › ArmorZones` and click the
   (currently empty) `ArmorZones` folder.
3. **Add four parts.** With `ArmorZones` selected, Insert Object → `Part` four times
   (or duplicate one). Rename them **exactly**: `FrontArmor`, `RearArmor`, `LeftArmor`,
   `RightArmor`. They must be direct children of `ArmorZones`.
4. **Set properties** on each of the four per the property table above — especially
   `CanQuery = true`, `Anchored = false`, `Massless = true`, `CanCollide = false`,
   `CastShadow = false`. Size/position only need to be roughly tank-sized; `Configure`
   recomputes the exact `Size`/`CFrame` from `Body` (≈ `7.73 × 2.90 × 10.63`) at spawn,
   and re-applies the zone colours from `TankArmorConfig.Visuals`.
   - Quick fastest path: set one part up correctly, then copy/paste it three times and
     just rename each — Studio assigns valid serialization on save.
5. **Do not add a weld.** `TankArmorPartsService.getOrCreateBodyWeld` creates the
   `WOBArmorBodyWeld` `WeldConstraint` at spawn.
6. **(N/A here) Legacy `Hitboxes`:** there is no `Hitboxes` folder in this template, so
   nothing to remove. (At runtime, a coexisting `Hitboxes` folder is auto-removed when
   `ArmorZones` is active, but that does not apply here.)
7. **Save** the place (and Publish, if testing on a live server). The folder name
   already matches `TankFactoryConfig.TemplateStorageFolderName = "TankTemplates"`.

> Note: there are no legacy prototype templates (`PlayerTankPrototype`,
> `Player2TankPrototype`, `DummyTank`) in this place, so `BaseTankTemplate` is the only
> model you need to fix. If you ever add those prototypes back, give each its own
> `ArmorZones` folder with the same four parts.

## How to verify

Do a **baseline-then-fix** comparison so the difference is unambiguous.

1. **Baseline (before adding parts):** Play, open **Output**, and clear it. Enter
   **Training**, then enter **BattleArena**. You should see, on tank spawns:
   ```
   [TANK] created missing <model>.ArmorZones.FrontArmor   (and Rear/Left/Right)
   ```
   Note them so you know what should disappear. (`[TANK FACTORY] spawn role=...` is a
   normal, throttled spawn log — that one is *not* the armor log and will remain.)
2. **Apply the fix** (add the four parts to `ArmorZones`, save).
3. **After:** Play again with a cleared Output.
   - **Enter Training.** Confirm **no** `[TANK] created missing ... ArmorZones` lines
     appear for the player/dummy tank.
   - **Enter BattleArena** so bots spawn (staggered). Confirm **no**
     `[TANK] created missing ... ArmorZones` lines appear for any bot or the player tank.
   - There should also be no `[TANK] created missing ...Hitboxes` line (there wasn't one
     before, since the folder already existed).
4. **Confirm armor still works** (nothing about damage changed): shoot a tank's coloured
   zones and verify front/side/rear damage and ricochet behave exactly as before — armor
   values live in `TankArmorConfig` and were not touched.
5. **Confirm the coloured plates are still visible** (green front, yellow sides, red
   rear); `TankArmorPartsService.Configure` re-applies colour/size/weld at spawn, so the
   pre-baked parts look identical to the runtime-created ones.

## Runtime fallback is intact

`ensureHitboxes` is **not** removed or weakened. If a template still lacks
`ArmorZones`, the old creation path runs exactly as before and the tank is fully
functional — it just pays the per-spawn creation cost (and logs the "created missing"
lines). Pre-baking is an optimization, not a hard requirement.
