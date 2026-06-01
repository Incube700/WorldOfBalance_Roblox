# Arena Layout Authoring Guide

How to design, edit, and ship arena layouts (maze walls, pickups, breakables, spawns)
as **Studio-authored templates** instead of hidden runtime generation.

This system was introduced in Update 0.2.x. It does **not** change gameplay balance,
the wallet/DataStore, the remotes protocol, XP/level-up upgrades, or any temporary
weapon behaviour. It only moves *where the arena layout comes from*: from procedural
code into an editable model you can touch in Studio.

---

## TL;DR workflow

1. In Studio, open the **Command Bar** (`View > Command Bar`).
2. **Tag your arena first.** Select the BattleArena container (and its floor part), paste
   `tools/studio/TagArenaRoles.commandbar.luau` (with `ROLE = "BattleArena"`) and run it.
   Repeat with `ROLE = "Duel"` / `"Lobby"` on those containers so they're explicitly
   marked off-limits. Nothing is created or guessed — only your selection is tagged.
3. **Select the tagged BattleArena floor** (exactly one BasePart with
   `WOBArenaFloor = true` and `WOBArenaRole = "BattleArena"`), paste
   `tools/studio/CreateRicochetMazeLayout.commandbar.luau` and run it. The layout is built
   *relative to that floor*. With no valid floor selected it creates nothing and warns.
4. A folder appears: `Workspace/WOB_Authoring/ArenaLayouts/RicochetMaze_01`.
5. Move / rotate / resize / delete walls and markers freely. To restyle them in Edit Mode,
   select them and run `tools/studio/ApplyArenaVisualStyle.commandbar.luau` (refuses
   Duel/Lobby unless explicitly overridden).
6. Right-click `RicochetMaze_01` → **Save to File...** →
   `src/ReplicatedStorage/Assets/ArenaLayouts/RicochetMaze_01.rbxm`.
7. `rojo build` / sync. At the next Training or BattleArena session the runtime clones
   your template **verbatim** into the live arena. Lobby and Duel stay completely clean.

> **Edit Mode = Play Mode.** As of Update 0.2.x the runtime no longer recolors the map or
> generates geometry on its own. What you author and style in Studio is exactly what ships.

---

## Where things live

### Authoring side (you edit this, in Studio)

```
Workspace
  WOB_Authoring
    ArenaLayouts
      RicochetMaze_01            <- a Model; this is what you Save to File
        CollisionWalls           <- solid walls (darker), block tanks + bounce shots
        RicochetWalls            <- neon walls, block tanks + bounce shots
        Cover                    <- physical cover blocks
        PickupSpawns             <- markers: where pickups appear
        PlayerSpawns             <- markers: player tank spawn points
        BotSpawns                <- markers: bot tank spawn points
        BreakableSpawns          <- markers: optional breakable cover
        Visuals                  <- decorative, non-colliding accents
```

`WOB_Authoring` is **authoring scratch space only**. The runtime never reads it. You can
delete it in a live game with no effect.

### Source side (what gets committed)

```
src/ReplicatedStorage/Assets/ArenaLayouts/RicochetMaze_01.rbxm
```

**Why this path:** `default.project.json` maps `ReplicatedStorage.Assets` →
`src/ReplicatedStorage/Assets`, so an exported `.rbxm` syncs straight into source. The
runtime clone happens on the server, and `ReplicatedStorage` is readable from the server.
There is no `ServerStorage` mapping in the Rojo project, so `ServerStorage` is not an
option. (We never touch the `.rbxlx` place file directly.)

### Runtime side (created/destroyed automatically — do not hand-edit)

```
Workspace
  WOB_Runtime
    ArenaMode                    <- single subtree for ALL Update 0.2.x runtime objects
      ActiveArenaLayout          <- a clone of your template, dropped onto the arena floor
      ArenaPickups               <- live pickup models
      ArenaBreakables            <- live breakable props
```

`WOB_Runtime/ArenaMode` exists only while a Training/BattleArena session is active and is
destroyed on exit/reset/end. Keeping everything under one `ArenaMode` folder means the
lifecycle can purge the whole arena layer in a single destroy — which is exactly what it
does the instant a **Duel (PvP)** starts, so a Duel can never inherit leftover Training
objects. **Duel never creates or populates `ArenaMode`.**

---

## Editing the layout

### Walls (`CollisionWalls`, `RicochetWalls`, `Cover`)

These are real, anchored Parts. Drag them anywhere, resize, rotate. Rules:

- **CanCollide = true** and **CanQuery = true** — required so tanks collide and
  projectiles bounce. The generator sets these; keep them.
- Each wall carries the attribute **`WOBMovementObstacle = true`**. This is what makes it
  a tank obstacle *and* a projectile bounce surface, independent of its folder or name.
  If you build a new wall by hand, set this attribute (or name it `RicochetWall_*` /
  `Cover_Block_*`, or place it in a `RicochetWalls` / `Cover` folder).
- `RicochetWalls` use the neon accent so you can tell bounce panels from solid walls at a
  glance. Functionally both bounce projectiles (this is a ricochet game).
- **Main maze walls are not destructible.** Only `BreakableSpawns` markers create
  breakables.

### Markers (`PickupSpawns`, `BreakableSpawns`, `PlayerSpawns`, `BotSpawns`)

Markers are flat, semi-transparent, **non-colliding** discs (CanCollide/CanTouch/CanQuery
= false). The runtime reads only their **position** — the marker part itself is never
shown in-game. Move them to decide where things spawn.

**Naming + attributes:**

| Folder            | Name pattern                    | Attribute               | Notes |
|-------------------|---------------------------------|-------------------------|-------|
| `PickupSpawns`    | `PickupSpawn_Rocket_*`          | `WOBPickupType="Rocket"`     | Rocket pickup |
| `PickupSpawns`    | `PickupSpawn_MachineGun_*`      | `WOBPickupType="MachineGun"` | Machine Gun pickup |
| `PickupSpawns`    | `PickupSpawn_Repair_*`          | `WOBPickupType="Repair"`     | Repair / heal |
| `PickupSpawns`    | `PickupSpawn_Shield_*`          | `WOBPickupType="Shield"`     | Only if Shield flag on |
| `BreakableSpawns` | `BreakableSpawn_*`              | `WOBBreakableType="LightCover"` | Optional, flag-gated |
| `PlayerSpawns`    | `PlayerSpawn_*`                 | —                       | Player spawn point |
| `BotSpawns`       | `BotSpawn_*`                    | —                       | Bot spawn point |

The attribute wins; the name token is a fallback. Pickups are still filtered by their
feature flags in `WeaponCatalog.Flags` — e.g. a `Shield` marker spawns nothing while
`ShieldPickupEnabled = false`, and a `Rocket` marker spawns nothing while
`RocketEnabled = false`.

### Collision rules summary

- **Walls / cover:** `CanCollide = true`, `CanQuery = true`, `WOBMovementObstacle = true`.
- **Markers:** `CanCollide = false`, `CanTouch = false`, `CanQuery = false`.
- **Visual accents (`Visuals`):** `CanCollide = false`, `CanTouch = false`,
  `CanQuery = false`, `WOBVisualOnly = true`.

Leave plenty of room (the generator uses generous gaps) so tanks can turn, and keep
`PlayerSpawns` / `BotSpawns` clear of walls so nothing spawns stuck.

---

## How the runtime loads a layout

On an active **Training** or **BattleArena** session, `ArenaSessionLifecycle` starts the
arena layer, and `ArenaMazeService`:

1. Finds `ReplicatedStorage/Assets/ArenaLayouts/<ActiveLayoutName>`
   (`WeaponCatalog.ActiveLayoutName`, default `RicochetMaze_01`).
2. Clones it into `Workspace/WOB_Runtime/ArenaMode/ActiveArenaLayout`.
3. **Positions** it: centers the layout footprint on the arena floor in X/Z and rests its
   lowest part on the floor surface — so you can author around the world origin and it
   drops onto whatever arena is active.
4. Re-asserts `WOBMovementObstacle` / `CanQuery` on the wall folders (defensive).
5. `ArenaSessionLifecycle` then refreshes the projectile raycast target list so the new
   walls become live bounce surfaces, and `TankMovementService` (which now also scans
   `WOB_Runtime`) treats them as collision.

`ArenaPickupService` reads `PickupSpawns`; `BreakableCoverService` reads
`BreakableSpawns`. Both snap their spawns onto the floor surface.

On session exit/reset/end, the whole `WOB_Runtime/ArenaMode` subtree
(`ActiveArenaLayout`, `ArenaPickups`, `ArenaBreakables`) is destroyed and projectile
targets refresh again.

### If the template or markers are missing

There is **no procedural fallback.** The runtime never invents a maze, pickups, or
breakables. If the input is absent it logs a Studio **warning** and spawns nothing:

- No template at `ReplicatedStorage/Assets/ArenaLayouts/<ActiveLayoutName>` →
  `ArenaMazeService` warns *"Arena layout template missing; no runtime maze spawned."* and
  the arena loads no walls.
- No `PickupSpawns` markers in the active layout → `ArenaPickupService` warns *"No
  PickupSpawns markers in active layout; no pickups spawned."*
- No `BreakableSpawns` markers → `BreakableCoverService` warns *"No BreakableSpawns markers
  in active layout; no breakable cover spawned."*

The fix is always to author the missing template/markers and re-save — never to rely on a
fallback. This is the deliberate **prefer no spawn over a wrong spawn** rule.

---

## Why Lobby and Duel stay clean

The lifecycle is built on the rule **prefer no spawn over a wrong spawn**, enforced by
three independent guards:

- **Allowlist (mode).** `RoundMatchService` drives both Training and Duel through the
  same `"Playing"` game state, so `"Playing"` alone is **not** enough. The match mode is
  mandatory: `ArenaSessionLifecycle.onGameStateChanged(gameState, matchMode)` activates
  the arena layer **only when `matchMode == "Training"`**. `"PvP"` (Duel), `nil`, and any
  unknown mode are forbidden → no-op. (Actual mode strings:
  `RoundMatchService.MATCH_MODE_TRAINING = "Training"`,
  `RoundMatchService.MATCH_MODE_PVP = "PvP"`.)
- **Explicit container (where).** Runtime objects are cloned only into a specifically
  named container under `WOB_Generated` — Training → `Map`, BattleArena → `BattleArena`.
  There is **no** "largest floor anywhere" inference and **no** Lobby/Duel fallback. If
  the named container is absent, nothing spawns.
- **Hard cleanup (Duel/PvP).** When a forbidden mode reaches `"Playing"`, the lifecycle
  destroys the whole `WOB_Runtime/ArenaMode` subtree, so a Duel can never inherit objects
  left over from a previous Training session.

- **Lobby:** the runtime layer is only started for an *active arena session*. All floor
  searches are scoped to the explicitly resolved arena container, never the Lobby or
  world Baseplate.
- **BattleArena** is unaffected by the match-mode path — it activates through its own
  `onBattleArenaEnter` / `onBattleArenaLeave` signals and uses the `BattleArena`
  container.

---

## Visual polish

**Runtime visual polish is OFF by default** (`WeaponCatalog.Flags.RuntimeVisualPolishEnabled
= false`). This is the key fix that makes Edit Mode match Play Mode: `WOBArenaVisualPolish`
no longer recolors the map, blacks out walls, or generates neon geometry at startup. The
colours and materials you author in Studio are exactly what you see at runtime.

If you ever opt back in (set `RuntimeVisualPolishEnabled = true`), it still fails closed:

- `ApplyOnlyToTaggedArena = true` (default) → it only touches containers explicitly tagged
  `WOBArenaRole` with `WOBAllowVisualPolish = true`. Untagged containers are skipped.
- `AllowDuelVisualPolish = false` (default) → Duel and Lobby are refused even if tagged.
- The world Baseplate is never styled.

To style your arena, do it in **Edit Mode** instead, with
`tools/studio/ApplyArenaVisualStyle.commandbar.luau` on a selection. That applies the
dark/neon palette to the selected BattleArena/layout objects, skips `WOBVisualOnly` parts,
refuses Duel/Lobby unless explicitly overridden, and prints what it changed.

---

## Feature flags (`WeaponCatalog.Flags`)

| Flag | Effect |
|------|--------|
| `RuntimeVisualPolishEnabled` | **Default `false`.** Master switch for runtime recolor/polish. Off = Edit Mode matches Play Mode |
| `ApplyOnlyToTaggedArena` | **Default `true`.** When polish is on, only style containers tagged `WOBArenaRole` + `WOBAllowVisualPolish = true` |
| `AllowDuelVisualPolish` | **Default `false`.** Even with polish on, never style Duel/Lobby |
| `MazeEnabled` | Master switch for the maze/layout |
| `PickupsEnabled` | Master switch for pickups |
| `BreakablesEnabled` | Master switch for breakables |
| `RocketEnabled` / `MachineGunEnabled` | Per-weapon pickup toggles |
| `PhaseShotEnabled` | Phase Shot pickup (off by default) |
| `ShieldPickupEnabled` | Shield pickup (off by default) |

`WeaponCatalog.ActiveLayoutName` selects which template under `ArenaLayouts` to load.

> The old `UseAuthoredLayout` flag is gone — there is no procedural alternative to toggle
> to anymore. The authored template is the only source of the layout.

## Arena role attributes

Containers and floors carry explicit role attributes (set via
`tools/studio/TagArenaRoles.commandbar.luau`). The runtime reads these as a defense-in-depth
guard on top of the mode/signal allowlist.

| Attribute | On | Meaning |
|-----------|-----|---------|
| `WOBArenaRole` | container + floor | `"BattleArena"`, `"Duel"`, or `"Lobby"` |
| `WOBMode` | container | mirrors the role |
| `WOBAllowArenaMode` | container | may the arena layer start here (BattleArena → true, Duel/Lobby → false) |
| `WOBAllowPickups` / `WOBAllowMaze` / `WOBAllowVisualPolish` | container | per-feature opt-in (all true for BattleArena, all false for Duel/Lobby) |
| `WOBArenaFloor` | floor part | marks the floor BasePart the generator builds relative to |

A container tagged `WOBArenaRole = "Duel"` / `"Lobby"`, or with `WOBAllowArenaMode = false`,
is refused by `ArenaSessionLifecycle` even if a signal somehow resolves to it. Untagged
containers stay allowed for backward compatibility, since the mode/signal allowlist already
guarantees only `Map` (Training) and `BattleArena` reach the start path.

---

## Manual test checklist

1. Start in **Lobby**: no pickups, no maze, no breakables.
2. Start a **Duel**: clean duel arena — no pickups, maze, or breakables.
3. Start **Training / BattleArena**: the layout loads into `WOB_Runtime/ArenaMode/ActiveArenaLayout`.
4. Pickups appear **only** in the active arena (never the lobby).
5. Rocket / Machine Gun / Repair pickups grant their effect on pickup.
6. Maze walls are physical obstacles (tanks cannot pass through).
7. `RicochetWall_*` parts bounce projectiles.
8. Exit to Lobby: `ActiveArenaLayout`, `ArenaPickups`, `ArenaBreakables` are all cleaned up.
9. Start Training again: the layout appears exactly once (no duplicates).
10. Move one wall in the authoring layout, re-save/rebuild, restart the session, and
    confirm the runtime uses the new position.

---

## File map

| File | Role |
|------|------|
| `tools/studio/TagArenaRoles.commandbar.luau` | Tag selected container/floor with arena role attributes (selection only) |
| `tools/studio/CreateRicochetMazeLayout.commandbar.luau` | Command Bar generator; builds relative to the selected tagged BattleArena floor |
| `tools/studio/ApplyArenaVisualStyle.commandbar.luau` | Edit-Mode styling of a selection; refuses Duel/Lobby |
| `src/ReplicatedStorage/Assets/ArenaLayouts/RicochetMaze_01.rbxm` | Exported template (you create via Save to File) |
| `ArenaMazeService.luau` | Clones/positions the authored layout (no fallback); marker accessors |
| `ArenaPickupService.luau` | Spawns pickups from `PickupSpawns` markers only (no fallback) |
| `BreakableCoverService.luau` | Spawns breakables from `BreakableSpawns` markers only (no fallback) |
| `ArenaSessionLifecycle.luau` | Starts/stops the arena layer; mode allowlist + role guard + hard Duel cleanup |
| `WOBArenaVisualPolish.server.luau` | Runtime polish, **off by default**, fail-closed when enabled |
| `TankMovementService.luau` | Scans `WOB_Runtime` so cloned walls are obstacles |
| `WeaponCatalog.luau` | Flags, role attribute names, `ActiveLayoutName`, layout folder names |
