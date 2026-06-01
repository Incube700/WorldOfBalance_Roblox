# Update 0.2 — Pickups, Weapons, and Arena Maze (fix + layering pass)

This pass addresses two stabilization directives on top of the original Update 0.2
work: (1) pickups must not appear in the lobby and the arena must include a small
ricochet maze, and (2) temporary pickup weapons must **layer on top of** existing
run upgrades rather than replacing them. It also stabilizes the Rocket weapon.

---

## ⚠️ SUPERSEDED IN PART by Update 0.2.x (authoring + visual fix pass)

The sections below describe the original **procedural** arena (maze/pickups/breakables
generated from fraction tables in `WeaponCatalog`, plus a runtime recolor pass). That
approach has since been replaced by a **Studio-authored, template-only** workflow. Where
this document and the points below disagree, **the points below win:**

- **No procedural generation, no fraction fallbacks.** `ArenaMazeService` clones the
  authored template *only*; `ArenaPickupService` and `BreakableCoverService` read authored
  markers *only*. If the template/markers are missing, each service **no-ops with a Studio
  warning** instead of inventing geometry. `WeaponCatalog.PickupLayout` / `MazeLayout` /
  `BreakableLayout` are **deprecated and no longer read**.
- **No hidden runtime recolor.** `WOBArenaVisualPolish` is **off by default**
  (`WeaponCatalog.Flags.RuntimeVisualPolishEnabled = false`). The arena looks in Play Mode
  exactly as authored in Studio Edit Mode. When enabled it only styles containers tagged
  `WOBArenaRole` + `WOBAllowVisualPolish=true`, never Duel/Lobby/the world Baseplate, and
  fails closed on unknown roles. You style the arena in Studio with
  `tools/studio/ApplyArenaVisualStyle.commandbar.luau`.
- **Runtime objects live under `WOB_Runtime/ArenaMode`** (not under the arena container as
  the older text says). The whole subtree is purged the instant a Duel starts.
- **Explicit container roles.** Arena containers/floors are tagged with
  `tools/studio/TagArenaRoles.commandbar.luau`; `ArenaSessionLifecycle` refuses to start the
  arena layer in a container explicitly tagged `Duel`/`Lobby` or with `WOBAllowArenaMode=false`.

See `ARENA_LAYOUT_AUTHORING_GUIDE.md` for the full authoring workflow. The pickup
**behaviours** (Repair/MachineGun/Rocket, layering, ammo, reset rules) below are still
current — only *where layouts/colours come from* changed.

---

## Weapon backlog (NOT implemented — design notes only)

Current pickups: **Default Ricochet Shot** (base cannon), **Machine Gun**, **Rocket**,
**Repair** (live); **Shield** and **Phase Shot** (authored but flag-gated off). These must
not regress.

The following are **future candidates only — none are implemented.** Listed so the marker
system and catalog stay ready for them. Rough priority order, not a commitment:

1. **Shotgun / Scatter Shot** — short-range pellet cone; reuses the multishot path with a
   spread angle and short lifetime.
2. **Laser / Beam Shot** — fast/hitscan precision beam; no ricochet; needs a beam render and
   a non-projectile hit model.
3. **Mine Drop** — stationary armed mine dropped behind the tank; proximity detonation; needs
   a placed-entity lifecycle (arm delay, owner-immunity window, session-end cleanup).
4. **EMP / Shockwave** — radial pulse that briefly disables/slows nearby enemies; a control
   tool; needs a status-effect channel on participants.
5. **Bouncy Bomb** — lobbed projectile that bounces a few times then explodes; extends the
   explosive behaviour with a bounce count + timed fuse + arc.
6. **Saw Blade / Disc** — persistent high-ricochet blade dealing contact damage; long
   lifetime, contact damage instead of single-hit.
7. **Rail Shot** — charged long-range high-damage piercing line; like Phase Shot with a
   charge-up and higher damage.

**Adding one later (reference, not now):** add a frozen `Weapons`/`Pickups` entry, add a
default-off flag to `WeaponCatalog.Flags`, add the type token to
`ArenaPickupService.PICKUP_TYPE_TO_ID`, author a `PickupSpawn_<Type>_*` marker, then
implement the behaviour behind the flag — leaving the default cannon and existing weapons
untouched. The marker system already accepts arbitrary `WOBPickupType` strings: an unknown
or disabled type simply spawns nothing until its catalog entry + flag exist.

---

## Root causes from the previous pass

**Pickups appearing in the lobby.** Two compounding bugs from the previous Update
0.2 pass: the floor finder in `ArenaPickupService` (and `BreakableCoverService`)
scanned all of `Workspace/WOB_Generated` — which contains both the arena (`Map`/
`BattleArena`) **and** the `Lobby` subfolder — then picked the largest floor-like
part globally, so the lobby's floor frequently won and pickups anchored over lobby
positions. The services also called `start()` at server boot, before any arena
session existed.

**Temporary weapons erasing run progression.** The original override block in
`ProjectileService.createProjectile` replaced `MaxBounces` outright when a weapon
override was present, dropping the player's `ArenaRicochetBonus`. The Rocket also
hard-coded `MaxRicochets = 0`, which deleted the entire ricochet identity of the
weapon when picked up.

## What changed

### Arena-scoped runtime objects (new `ArenaSessionLifecycle`)

A small orchestrator now owns the maze, pickups, and breakables. It listens to two
signal sources:

- `ArenaCombatService.EnterArena` / `LeaveArena` (BattleArena loop) — wired via
  the new `arenaSessionStarted` / `arenaSessionEnded` callbacks on
  `ArenaCombatService.init`.
- `RoundMatchService.onGameStateChanged` (Training / Duel matches).

When the **first** signal fires it picks the right arena container
(`BattleArena` preferred for arena entry, `Map` preferred for matches), starts the
maze, breakables, and pickups inside that container only, and refreshes
`ProjectileService`'s map-raycast list so the runtime maze walls become real
ricochet surfaces. When the **last** signal clears, everything is torn down and the
raycast list is refreshed again. Nothing exists in the lobby at any time.

### Floor finders scoped to the arena container

All three services (`ArenaPickupService`, `BreakableCoverService`,
`ArenaMazeService`) now take the active arena container as a `start(container)`
argument and search for the largest floor-like part **inside that container only**.
They never fall back to `Workspace.Baseplate` or scan the `Lobby` subfolder.

### Arena maze (`ArenaMazeService`)

A small hand-authored layout of `RicochetWall_*` parts is spawned inside the active
arena, parented under `<arenaContainer>/RuntimeMaze`. Because the walls are named
with the standard `RicochetWall_` prefix and live inside the existing arena
container, `TankMovementService`'s obstacle detection picks them up automatically,
`WOBArenaVisualPolish` auto-styles them with neon on `DescendantAdded`, and the
projectile collection becomes bounce surfaces after the lifecycle's refresh call.

Each candidate wall is dropped if it would land within `MazeSpawnClearRadius` studs
of any arena `SpawnPoints` part, so the maze cannot block player or bot spawns. The
layout is in `WeaponCatalog.MazeLayout`; tune coordinates there.

### Layered weapon overrides

`ProjectileService.createProjectile` now composes the final shot like this:

- `FinalProjectileCount` = `getShotPattern(participant, …)` — reads the player's
  `ArenaProjectileCount`/`ArenaSpreadDegrees` attributes from upgrades unchanged.
  Weapons may set `MaxProjectilesPerTrigger` to cap multishot for safety
  (MachineGun caps at 3).
- `FinalDamage` = `PROJECTILE_DAMAGE × ArenaDamageMultiplier × weapon.DamageMultiplier`
- `FinalCooldown` = `(weapon.ShootCooldown or default) × ArenaFireRateMultiplier`
- `FinalMaxRicochets` = `PROJECTILE_MAX_BOUNCES + ArenaRicochetBonus`, then:
  - replaced by `weapon.MaxRicochets` if `weapon.OverrideMaxRicochets == true`
    (Phase Shot uses this — pierce + ricochet is unreadable);
  - or added to by `weapon.MaxRicochetsBonus` if set;
  - otherwise inherited from the upgraded base (Rocket and MachineGun use this).
- `FinalProjectileSpeed` / `Lifetime` / `Acceleration` / `MaxSpeed` are weapon-set;
  default cannon has `Acceleration == nil` and is unchanged.

**One trigger pull always consumes exactly one ammo**, no matter how many
projectiles the player's multishot upgrade spawns. So Rocket + Double Shot = 2
rockets fired, 1 ammo consumed; Triple Shot = 3 rockets, 1 ammo consumed.

Run upgrades that affect armor, tank speed, the reflect shield, level/XP, etc. are
untouched — temporary weapons only describe a projectile archetype.

## Final weapon behavior

### Default cannon (Ricochet Cannon)

Unchanged. Single shell, 110 damage, 3 ricochets (plus upgrade bonus), 1.5s reload.
Its entire code path is byte-for-byte identical to before; every override is
guarded by `participant.TempWeapon` being non-nil.

### Rocket (3 ammo)

A **ricochet** weapon. Inherits the player's ricochet count from upgrades.
- Slow start (90 studs/s), accelerates at 180 studs/s² up to a max of 240 studs/s.
- Explodes on first tank hit, on the wall hit after ricochets are exhausted, and
  on lifetime expiry. Explosion: 100 damage, 14-stud radius, owner excluded, normal
  `LobbyService.canDamageParticipant` rules respected.
- The shell itself does no penetration damage (`DamageMultiplier = 0`) — all damage
  is the explosion, so there is never a confusing "rocket hit but did almost
  nothing" outcome.
- With Double/Triple Shot, one trigger pull launches 2 or 3 rockets at the cost of
  1 ammo.
- Breaks any nearby breakable cover via `BreakableCoverService.breakNear`.

### Machine Gun (24 ammo)

Rapid pellets, 0.22s reload (~4.5 shots/s), 0.32× damage (~35/pellet). Inherits
upgrades, but caps projectile count per trigger at 3 to keep the server bounded
even with Triple Shot active. No explicit ricochet override — inherits the
upgraded ricochet count.

### Phase Shot (disabled by default this pass)

Implemented but feature-flagged off (`PhaseShotEnabled = false`) until balance is
validated in playtesting. The code path is:

- 4 ammo, 0.9s reload, ~150 damage per pierce.
- `OverrideMaxRicochets = true, MaxRicochets = 0` — does NOT ricochet (pierce +
  ricochet is unreadable on screen). Walls stop it normally.
- Pierces through exactly **one** enemy (per-tank 0.3s hit cooldown prevents
  multi-hit on the same tank while passing through), then destroys.
- Wall-pierce is intentionally NOT implemented this pass — the existing projectile
  raycast filter would need restructuring. Documented as a future option.

### Shield pickup (deferred)

`ShieldPickupEnabled = false`. The existing `ReflectShield` system grants charges
through arena-session entry and upgrade hooks; exposing it as a pickup would
require touching the upgrade flow, which the directive forbids. Code stub left out
of this pass; can be added later as a thin grant call once the shield API allows
unilateral session-state grants.

## Feature flags

All in `WeaponCatalog.Flags`:

- `PickupsEnabled` — master flag for ground pickups.
- `MazeEnabled` — runtime maze on/off.
- `BreakablesEnabled` — breakable cover props on/off.
- `RocketEnabled` — Rocket pickup spawn on/off.
- `MachineGunEnabled` — Machine Gun pickup spawn on/off.
- `PhaseShotEnabled` — Phase Shot pickup spawn on/off (default OFF this pass).
- `ShieldPickupEnabled` — reserved for a future Shield pickup (default OFF).

## Reset rules

Temporary weapons reset to the default cannon on every one of these:

- Death / respawn / paid revive / free respawn — all of these route through
  `TankSpawnResetService.applySpawnToParticipant`, which calls
  `TemporaryWeaponService.resetParticipant`.
- Run reset (`ArenaCombatService.ResetArenaSession`) — same path.
- Exit to lobby — `ArenaCombatService.LeaveArena` fires `arenaSessionEnded` which
  drives the lifecycle to clean up; the next `applySpawnToParticipant` clears the
  participant's `TempWeapon` field. No weapon state lingers in lobby.

The maze, pickups, and breakable props are all destroyed when the lifecycle goes
inactive, so a new run always sees a fresh arena.

## Files

New:
- `src/ServerScriptService/Server/Gameplay/Arena/ArenaSessionLifecycle.luau`
- `src/ServerScriptService/Server/Gameplay/Arena/ArenaMazeService.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBWeaponHud.client.luau`

Rewritten:
- `src/ReplicatedStorage/Shared/Configs/WeaponCatalog.luau`
- `src/ServerScriptService/Server/Gameplay/Pickups/ArenaPickupService.luau`
- `src/ServerScriptService/Server/Gameplay/Pickups/BreakableCoverService.luau`

Edited (guarded, additive):
- `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
- `src/ServerScriptService/Server/Gameplay/Combat/ProjectileCombatService.luau`
- `src/ServerScriptService/Server/Gameplay/Arena/ArenaCombatService.luau`
- `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`
- `src/ServerScriptService/Server/Gameplay/Tanks/TankSpawnResetService.luau`
  (from the prior pass — unchanged this pass)

## Known limitations / deferred

- **Phase Shot pickup is disabled by default** until you've playtested the limited
  pierce balance. Flip `WeaponCatalog.Flags.PhaseShotEnabled = true` to enable.
- **Wall-pierce is not implemented.** Phase Shot pierces enemies only; walls block
  it. Implementing wall-pierce would require restructuring the projectile raycast
  filter and was judged too risky for this pass.
- **Shield pickup is deferred** — coupled to the existing arena-session-driven
  shield grant; adding it as a pickup would touch the upgrade flow.
- **Maze layout is hand-authored** in `WeaponCatalog.MazeLayout` and adapts to the
  floor extents of whatever arena loads, but the geometry was authored blind (no
  Studio preview from the sandbox). Walls within 14 studs of a spawn are dropped
  so spawn-stuck is impossible; tune coordinates if any look off.

## Manual test checklist

1. Start the game in the lobby; confirm **no pickups, no maze walls, no breakable
   props** are visible there.
2. Enter Training (or BattleArena); confirm the maze, pickups, and breakables
   appear **inside the arena only**.
3. Pickups should look like items lying on the floor — small ring + small icon,
   no big floating chip.
4. Take damage, drive over a Repair pickup; HP increases (clamped to max), pickup
   disappears, respawns after ~14s.
5. Level up and take a multishot upgrade (Double Shot or Triple Shot).
6. Drive over Rocket pickup; HUD shows "Rocket x3".
7. Fire: with Double Shot active, **2 rockets** launch; with Triple Shot, **3
   rockets**. Ammo decreases by 1 per trigger pull regardless.
8. Rockets start slow, visibly accelerate. They ricochet off walls (inheriting
   your ricochet upgrade) and explode on first enemy hit, on the last wall, or on
   lifetime expiry.
9. Confirm the explosion deals 100 damage in a ~14-stud radius to enemies. Owner
   takes no self-damage.
10. Rockets near a breakable prop shatter it; it respawns after ~10s.
11. Drive over Machine Gun; HUD updates. Fire is faster, lower damage. With Triple
    Shot active, projectile count is capped at 3 per trigger (no spam).
12. Empty a weapon's ammo; HUD reverts to hidden, default cannon returns; upgrades
    are still in effect (multishot still works on the default cannon).
13. Die, then respawn; temporary weapon resets to default; upgrades persist.
14. Return to lobby; confirm pickups, maze walls, breakables are all gone.
15. Start a new run; arena objects re-spawn once (no duplicates) and ricochets
    work against the maze walls.
16. On mobile: pickup collection works by driving over the item (no precise tap
    needed); the fire button fires the current weapon; the small weapon label at
    the top of the screen does not overlap mobile controls or upgrade cards.
17. Watch Output for ~30s of play; confirm no red errors and no runtime object
    leaks.
