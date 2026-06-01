# Ricochet Tanks — Update 0.2: Maze + Pickups + Weapons (Vertical Slice)

This pass adds ground pickups, three temporary pickup weapons, a rocket explosion
system, and optional breakable cover, while keeping the published game stable. The
maze layout was intentionally deferred to Update 0.3 (see "Deferred" below).

The guiding constraint was *additive and reversible*: the default cannon's ricochet
behavior is untouched, no remotes were changed, no DataStore/wallet logic was
modified, and the authored arena geometry in the `.rbxlx` place file was not edited.
Every new visual lives under `Workspace/WOB_Runtime` and is non-colliding.

## Feature flags

All new systems are gated in `WeaponCatalog.Flags` so they can be disabled instantly
in Studio without removing code:

- `PickupsEnabled` (default `true`) — ground pickups + temporary weapons.
- `BreakableCoverEnabled` (default `true`) — decorative breakable props.
- `MazeEnabled` (default `false`) — reserved for the deferred 0.3 maze builder.

## Implemented pickups

Pickups lie flat on the arena floor as a small neon ring plus a slowly spinning glow
icon and a point light. There is **no** large floating billboard/chip above them.
Collection is **server-authoritative**: a throttled proximity check (every 0.2s,
7-stud radius) runs on the server — it does **not** use `.Touched` (tanks here are
CFrame-moved and would not reliably raise touch events) and never trusts a client
claim. Pickups are only collectible by player-owned, living tanks while the game
state is `Playing`.

- **Repair** (`Health`) — heals +60 HP, clamped to max HP. If the tank is already at
  full HP the pickup is left in place (not consumed); this is controlled by
  `ConsumeWhenFull`. Respawns 14s after collection.
- **Machine Gun** — grants the Machine Gun weapon. Respawns 18s after collection.
- **Rocket** — grants the Rocket weapon. Respawns 22s after collection.
- **Phase Shot** — grants the Phase Shot weapon. Respawns 22s after collection.

Pickup spawn positions are expressed as fractions of the live arena floor's
half-extent (`WeaponCatalog.PickupLayout`), so the layout adapts to whatever arena
loads and stays clear of the center and edges. Because pickups are non-colliding,
their placement cannot cause spawn-stuck or block movement in any case.

## Implemented weapons

All temporary weapons are **ammo-based** (no ticking timer). When ammo reaches zero
the tank reverts to the default cannon. Weapons also reset to default on respawn, run
reset, and lobby exit (hooked into `TankSpawnResetService.applySpawnToParticipant`,
the universal reset path). Bots never receive pickups, so they always use the default
cannon.

- **Default Cannon (Ricochet Cannon)** — unchanged. Single ricochet shell, 110 base
  damage, 3 ricochets, 1.5s reload. Its code path is byte-for-byte identical to
  before: all overrides below are guarded by `participant.TempWeapon` being non-nil.

- **Machine Gun** — 24 rapid pellets, 0.22s reload (~4.5 shots/s), ~0.32× damage,
  1 ricochet, bright yellow tracer. Projectile count is bounded by the existing
  cooldown gate and the ammo count, so there is no projectile spam even if the player
  also has the multi-shot upgrades.

- **Rocket** — 4 shells, 1.0s reload, slow (120 studs/s), explodes on first contact
  (0 ricochets). The shell itself carries no penetration damage; **all** damage is
  the explosion: 80 HP to live enemies within a 13-stud radius. The owner is excluded
  and normal damage rules (`LobbyService.canDamageParticipant`) are respected.
  Explosion FX reuses the existing death-explosion VFX. Rockets that time out midair
  also explode.

- **Phase Shot** — 6 shells, 0.9s reload, fast (220 studs/s), ~0.7× damage. Passes
  **through enemies** but is **blocked by walls** (0 ricochets). A short per-tank hit
  cooldown (0.3s) prevents a single shell from multi-hitting the same tank while it
  passes through. Phase Shot applies flat damage and bypasses armor-zone resolution
  (the "phase" fantasy), unlike the default cannon which respects armor zones.

## Breakable cover (optional, included)

A few decorative breakable props (`WeaponCatalog.BreakableLayout`) are scattered on
the floor. They are **visual-only**: anchored, `CanCollide = false`, `CanQuery =
false`, so they never block tanks, projectiles, spawns, or arena boundaries. They
"break" only when a rocket explodes within its blast radius (the explosion handler
calls `BreakableCoverService.breakNear`), then respawn after 10s. No physics debris
is ever created.

## Deferred to Update 0.3 (skipped this pass)

- **Maze layout (Task B)** — the arena geometry lives in the `.rbxlx` place file,
  which this pass does not modify, so a maze would have to be spawned at runtime and
  could not be visually verified outside Studio. Deferred by design decision. The
  integration path is already proven: any anchored `CanCollide` part named
  `RicochetWall_*` (or placed in a `RicochetWalls` / `MovementObstacles` folder under
  `Workspace/WOB_Generated/Map`) is automatically picked up as both a tank-movement
  obstacle and a projectile bounce surface, and is auto-styled with neon by
  `WOBArenaVisualPolish`. A future `MazeBuilder` can use the `MazeEnabled` flag.
- **Shield pickup (optional)** — not implemented this pass; a `ReflectShield`
  mechanic already exists in combat and could be exposed as a pickup later.

## How to add a new weapon

1. Add an entry to `WeaponCatalog.Weapons` (`Shared/Configs/WeaponCatalog.luau`).
   Supported fields: `Id`, `DisplayName`, `Ammo`, `ShootCooldown`,
   `DamageMultiplier`, `ProjectileSpeed`, `ProjectileLifetime`, `MaxRicochets`,
   `BehaviorType`, `ProjectileColor`, `ProjectileRadius`, and optionally
   `ExplosionRadius` + `ExplosionDamage` (for explosive weapons) or `PierceEnemies` +
   `PierceHitCooldownSeconds` (for piercing weapons), plus `NotifyText`.
2. Add a matching pickup to `WeaponCatalog.Pickups` with `Kind = "Weapon"` and
   `WeaponId = "<your weapon id>"`, plus `AccentColor`, `IconColor`, `RespawnSeconds`.
3. Add the pickup to `WeaponCatalog.PickupLayout` (`{ pickupId, fractionX, fractionZ }`).

No code changes are required for simple speed/damage/ricochet/explosive/piercing
variants — `ProjectileService` reads the override and `TemporaryWeaponService` tracks
the ammo automatically.

## How to add a pickup spawn

Append a row to `WeaponCatalog.PickupLayout`: `{ "<PickupId>", fractionX, fractionZ }`,
where the fractions are in `[-1, 1]` of the floor half-extent (0,0 is the center).
Keep within roughly ±0.6 to stay clear of the boundaries.

## Files

New:
- `src/ReplicatedStorage/Shared/Configs/WeaponCatalog.luau`
- `src/ServerScriptService/Server/Gameplay/Weapons/TemporaryWeaponService.luau`
- `src/ServerScriptService/Server/Gameplay/Pickups/ArenaPickupService.luau`
- `src/ServerScriptService/Server/Gameplay/Pickups/BreakableCoverService.luau`

Edited (guarded, additive):
- `src/ServerScriptService/Server/Gameplay/Projectiles/ProjectileService.luau`
- `src/ServerScriptService/Server/Gameplay/Combat/ProjectileCombatService.luau`
- `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`
- `src/ServerScriptService/Server/Gameplay/Tanks/TankSpawnResetService.luau`

## Manual test checklist

1. Start Training, then BattleArena.
2. Confirm player and bots spawn safely (no maze added this pass, so spawns are
   unchanged).
3. Drive around; confirm tanks turn normally.
4. Fire the default weapon; confirm ricochets still work exactly as before.
5. Take damage, then drive over a Repair pickup; confirm HP increases (clamped to max)
   and that a full-HP tank does not consume it.
6. Drive over Machine Gun; confirm the weapon changes (yellow tracer, rapid fire) and
   that fire is throttled (no projectile spam).
7. Drive over Rocket; confirm slow shell, explosion on impact, modest AoE damage, and
   that nearby breakable cover shatters and respawns.
8. Drive over Phase Shot; confirm it passes through an enemy tank (damaging it) but is
   stopped by walls.
9. Empty a weapon's ammo; confirm it reverts to the default cannon with an
   "Out of ammo" notice.
10. Die / reset / return to lobby; confirm the weapon resets to default.
11. Confirm pickup notifications ("Machine Gun!", "Rocket x4!", "Repair +60!") appear
    as small floating world text and do not clutter the screen.
12. On mobile, confirm driving over a pickup collects it (no precise tap needed) and
    that the fire button fires the current weapon.
13. Watch Output for ~30s of play; confirm no red errors and no runtime object leaks
    (projectiles, pickups, and breakables all clean up / respawn).
