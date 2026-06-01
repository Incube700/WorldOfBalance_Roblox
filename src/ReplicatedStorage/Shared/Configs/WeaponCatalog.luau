-- WeaponCatalog: temporary pickup weapons for Update 0.2 (Maze + Pickups + Weapons).
--
-- DESIGN MODEL — temporary weapons LAYER on top of run upgrades, they do not erase
-- progression. The final shot is composed in this order, all guarded so the default
-- cannon (no temp weapon) is byte-for-byte unchanged:
--
--   FinalProjectileCount  = ArenaProjectileCount (from upgrades), then clamped by the
--                           weapon's MaxProjectilesPerTrigger if it sets one.
--   FinalDamage           = PROJECTILE_DAMAGE * ArenaDamageMultiplier * weapon.DamageMultiplier
--   FinalCooldown         = (weapon.ShootCooldown or default) * ArenaFireRateMultiplier
--   FinalMaxRicochets     = ArenaRicochetBonus + default(3), then:
--                             * if weapon.OverrideMaxRicochets == true, replaced by
--                               weapon.MaxRicochets exactly (Phase Shot uses this);
--                             * else if weapon.MaxRicochetsBonus is set, added to.
--   FinalProjectileSpeed  = weapon.ProjectileSpeed or default speed
--   FinalProjectileLifetime = weapon.ProjectileLifetime or default lifetime
--   FinalAcceleration     = weapon.ProjectileAcceleration (nil for non-accelerating shells)
--
-- One trigger pull always consumes ONE ammo, even if multishot spawns multiple
-- projectiles. So Rocket + Double Shot = 2 rockets but still costs 1 ammo.

local WeaponCatalog = {}

-- ---------------------------------------------------------------------------
-- Feature flags. Each pickup is checked at spawn time. Disable any of these in
-- Studio to instantly turn off a system or pickup without removing code.
-- ---------------------------------------------------------------------------
WeaponCatalog.Flags = table.freeze({
	-- Update 0.2 runtime arena layer master switch. ENABLED so weapon/item pickups spawn
	-- from your authored PickupSpawns markers. NOTE: this is also the master gate for maze
	-- and breakables, but those are markers/template-only with NO procedural fallback -- with
	-- MazeEnabled/BreakablesEnabled false (below) they simply no-op, so enabling this does
	-- not invent any geometry in your hand-authored arena.
	Update02ArenaLayerEnabled = true,

	-- Per-system switches (subordinate to Update02ArenaLayerEnabled).
	-- Pickups ON; maze/breakables OFF so the manual arena layout is untouched.
	PickupsEnabled = true,
	MazeEnabled = false,
	BreakablesEnabled = false,

	-- DEPRECATED (Update 0.2.x): no longer read by any service. The runtime now ALWAYS
	-- clones the Studio-authored layout template and has NO procedural fallback — if the
	-- template/markers are missing it no-ops with a warning (prefer no spawn over a wrong
	-- spawn). Retained only to avoid breaking any external reference; toggling it does
	-- nothing.
	UseAuthoredLayout = false,

	-- Per-weapon pickup flags. Code paths stay in place either way.
	RocketEnabled = true,
	MachineGunEnabled = true,
	-- RailGun pickup: fast, long-range, high-damage line shot. Uses the existing temporary
	-- weapon grant path (Kind="Weapon"), so no new systems are needed.
	RailGunEnabled = true,
	ShotgunEnabled = true,
	-- PhaseShot is feature-flagged OFF this pass while the limited-pierce balance is
	-- validated. The code path is still present and tested by enabling this flag.
	PhaseShotEnabled = false,
	-- Shield pickup: grants ReflectShield charges on pickup (wired in ArenaPickupService).
	ShieldPickupEnabled = true,

	-- ---------------------------------------------------------------------------
	-- Runtime visual polish (Update 0.2.x authoring workflow).
	--
	-- The OLD behaviour recolored the whole map (Map + BattleArena + world Baseplate)
	-- in place at runtime and generated neon grid/boundary/accent geometry, so the
	-- arena looked different in Play Mode than in Studio Edit Mode. That defeated
	-- hand-authoring of colours and walls. These flags turn that behaviour OFF by
	-- default. Authored layouts now look in-game EXACTLY like they look in Studio.
	--
		--   RuntimeVisualPolishEnabled : switch for the runtime recolor/geometry pass.
		--                                Still requires Update02ArenaLayerEnabled. FALSE by
		--                                default. When false, WOBArenaVisualPolish does nothing
		--                                at runtime; style the arena in Studio.
	--   ApplyOnlyToTaggedArena     : when polish IS enabled, only touch containers that
	--                                carry WOBArenaRole + WOBAllowVisualPolish=true. Never
	--                                recolor the whole Workspace or an untagged container.
	--   AllowDuelVisualPolish      : hard guard. Even with polish enabled + tagging on, a
	--                                container whose WOBArenaRole=="Duel"/"Lobby" is never
	--                                styled unless this is explicitly true. Default false.
	-- ---------------------------------------------------------------------------
	RuntimeVisualPolishEnabled = false,
	ApplyOnlyToTaggedArena = true,
	AllowDuelVisualPolish = false,
})

-- Attribute schema for arena container / floor roles (Update 0.2.x). Set in Studio with
-- tools/studio/TagArenaRoles.commandbar.luau. Read by ArenaSessionLifecycle (allow/deny
-- the arena layer) and WOBArenaVisualPolish (which containers may be styled at runtime).
WeaponCatalog.RoleAttributes = table.freeze({
	Role = "WOBArenaRole", -- "BattleArena" | "Duel" | "Lobby"
	Mode = "WOBMode", -- mirrors Role; human-facing
	AllowArenaMode = "WOBAllowArenaMode",
	AllowPickups = "WOBAllowPickups",
	AllowMaze = "WOBAllowMaze",
	AllowVisualPolish = "WOBAllowVisualPolish",
	Floor = "WOBArenaFloor",
})

WeaponCatalog.Roles = table.freeze({
	BattleArena = "BattleArena",
	Duel = "Duel",
	Lobby = "Lobby",
})

WeaponCatalog.DefaultWeaponId = "DefaultCannon"
WeaponCatalog.DefaultWeaponDisplayName = "Ricochet Cannon"

-- ---------------------------------------------------------------------------
-- Temporary weapons.
-- ---------------------------------------------------------------------------
WeaponCatalog.Weapons = table.freeze({
	-- Rocket: still a RICOCHET weapon. It inherits the player's current ricochet
	-- count (no override) so it bounces off ricochet walls. It explodes when it hits
	-- a tank, when ricochets are exhausted, or when its lifetime ends. With Double
	-- Shot / Triple Shot upgrades active, one trigger pull launches multiple rockets
	-- (still costs 1 ammo).
	Rocket = table.freeze({
		Id = "Rocket",
		DisplayName = "Rocket",
		Ammo = 3,
		ShootCooldown = 1.0,
		-- Direct shell carries no penetration damage; the explosion does all damage.
		DamageMultiplier = 0,
		-- Starts slow, accelerates over its flight so it stays readable but punchy.
		ProjectileSpeed = 90,
		ProjectileAcceleration = 180, -- studs/s^2
		ProjectileMaxSpeed = 240,
		ProjectileLifetime = 5.0,
		-- INHERIT player ricochet count -- no MaxRicochetsOverride, no bonus.
		BehaviorType = "Explosive",
		ExplosionRadius = 14,
		ExplosionDamage = 100,
		ProjectileColor = Color3.fromRGB(255, 138, 60),
		ProjectileRadius = 0.85,
		NotifyText = "Rocket x3!",
	}),

	-- Machine Gun: rapid pellets, lower damage. Inherits run upgrades, but caps
	-- projectile count per trigger so multishot + machinegun cannot spawn a wall of
	-- bullets every frame.
	MachineGun = table.freeze({
		Id = "MachineGun",
		DisplayName = "Machine Gun",
		Ammo = 24,
		ShootCooldown = 0.5, -- cooldown for the whole burst
		DamageMultiplier = 0.3, -- ~33 dmg per pellet vs 110 default.
		ProjectileSpeed = 220,
		ProjectileLifetime = 2.2,
		-- BURST: one trigger fires BurstCount shells one-after-another (a stream), NOT a
		-- spread/shotgun. BurstIntervalSeconds is the gap between shells in the burst.
		BurstCount = 5,
		BurstIntervalSeconds = 0.07,
		-- Slight directional jitter so the stream isn't a perfectly straight laser.
		BurstSpreadDegrees = 5,
		-- Penetration: now pierces armor decently (so you don't grind too long). Still a bit
		-- below the front plate, but flanks/rear go through easily.
		PenetrationBonus = 5, -- 70 + 5 = 75 pen; just under Front 80, over Side/Rear
		ProjectileColor = Color3.fromRGB(255, 232, 120),
		ProjectileRadius = 0.42,
		NotifyText = "Machine Gun!",
		-- Ricochet count INHERITED from upgrades (no override, no bonus).
	}),

	-- Phase Shot: a SKILLSHOT, not a map cheat. Pierces exactly one enemy and then
	-- destroys. Walls still block it. Wall-pierce is deferred (risky with current
	-- collision filter); see PhaseShotEnabled flag above.
	PhaseShot = table.freeze({
		Id = "PhaseShot",
		DisplayName = "Phase Shot",
		Ammo = 4,
		ShootCooldown = 0.9,
		DamageMultiplier = 1.36, -- ~150 dmg per pierce vs 110 default.
		ProjectileSpeed = 220,
		ProjectileLifetime = 2.0,
		-- Phase Shot overrides ricochet count: it never bounces. (Pierce + ricochet
		-- combined makes the shot too hard to read.)
		OverrideMaxRicochets = true,
		MaxRicochets = 0,
		BehaviorType = "Piercing",
		PierceEnemies = true,
		PierceEnemyLimit = 1, -- destroys after passing through one enemy.
		PierceHitCooldownSeconds = 0.3,
		ProjectileColor = Color3.fromRGB(150, 130, 255),
		ProjectileRadius = 0.5,
		NotifyText = "Phase Shot x4!",
	}),

	-- RailGun: a heavy precision shot. Very fast and long-lived, big single-hit damage,
	-- thin bright beam-like projectile. Inherits the player's ricochet count so it still
	-- plays by the ricochet rule (no override), but rewards clean direct lines.
	RailGun = table.freeze({
		Id = "RailGun",
		DisplayName = "Rail Gun",
		Ammo = 4,
		ShootCooldown = 1.1,
		DamageMultiplier = 1.7, -- ~190 dmg vs 110 default; a punishing precision shot.
		ProjectileSpeed = 420,
		ProjectileLifetime = 2.4,
		ProjectileColor = Color3.fromRGB(120, 220, 255),
		ProjectileRadius = 0.32,
		NotifyText = "Rail Gun x4!",
		-- ARMOR-PIERCING: big penetration bonus so it crosses the front-plate threshold; armor
		-- still subtracts from damage. Pierces up to 2 enemies AND flies through walls.
		PierceEnemies = true,
		PierceEnemyLimit = 2,
		PierceHitCooldownSeconds = 0.3,
		PenetrationBonus = 40, -- 70 base + 40 = 110 pen: crosses Front armor 80 easily
		PiercesWalls = true, -- the beam ignores walls (no bounce, no stop)
		ChargeSeconds = 1.5, -- charge-up delay before the shot fires
		-- Ricochet count INHERITED from upgrades (no override).
	}),

	-- Shotgun: a tight cone of pellets, brutal up close. Like the MachineGun it has LOW
	-- penetration, so it barely dents front armor head-on but devastates flanks/rear at
	-- point blank. One trigger = one burst (slow fire rate).
	Shotgun = table.freeze({
		Id = "Shotgun",
		DisplayName = "Shotgun",
		Ammo = 6,
		ShootCooldown = 0.7,
		DamageMultiplier = 0.34, -- per pellet
		ProjectileSpeed = 230,
		ProjectileLifetime = 1.2, -- short range
		FanCount = 7,
		FanSpreadDegrees = 34,
		MaxProjectilesPerTrigger = 14,
		PenetrationBonus = 0, -- 70 pen: pens Side/Rear easily, just under Front 80
		ProjectileColor = Color3.fromRGB(255, 200, 110),
		ProjectileRadius = 0.4,
		NotifyText = "Shotgun!",
	}),
})

-- ---------------------------------------------------------------------------
-- Ground pickups. Each pickup checks its own feature flag at spawn time.
-- ---------------------------------------------------------------------------
WeaponCatalog.Pickups = table.freeze({
	Health = table.freeze({
		Id = "Health",
		Kind = "Heal",
		DisplayName = "Repair",
		HealAmount = 60,
		AccentColor = Color3.fromRGB(80, 235, 140),
		IconColor = Color3.fromRGB(160, 255, 190),
		RespawnSeconds = 14,
		NotifyText = "Repair +60!",
		ConsumeWhenFull = false,
	}),

	MachineGun = table.freeze({
		Id = "MachineGun",
		Kind = "Weapon",
		WeaponId = "MachineGun",
		FlagKey = "MachineGunEnabled",
		DisplayName = "Machine Gun",
		AccentColor = Color3.fromRGB(255, 215, 90),
		IconColor = Color3.fromRGB(255, 240, 170),
		RespawnSeconds = 18,
	}),

	Rocket = table.freeze({
		Id = "Rocket",
		Kind = "Weapon",
		WeaponId = "Rocket",
		FlagKey = "RocketEnabled",
		DisplayName = "Rocket",
		AccentColor = Color3.fromRGB(255, 130, 60),
		IconColor = Color3.fromRGB(255, 185, 130),
		RespawnSeconds = 22,
	}),

	PhaseShot = table.freeze({
		Id = "PhaseShot",
		Kind = "Weapon",
		WeaponId = "PhaseShot",
		FlagKey = "PhaseShotEnabled",
		DisplayName = "Phase Shot",
		AccentColor = Color3.fromRGB(150, 130, 255),
		IconColor = Color3.fromRGB(200, 190, 255),
		RespawnSeconds = 22,
	}),

	RailGun = table.freeze({
		Id = "RailGun",
		Kind = "Weapon",
		WeaponId = "RailGun",
		FlagKey = "RailGunEnabled",
		DisplayName = "Rail Gun",
		AccentColor = Color3.fromRGB(120, 220, 255),
		IconColor = Color3.fromRGB(190, 240, 255),
		RespawnSeconds = 24,
	}),

	Shotgun = table.freeze({
		Id = "Shotgun",
		Kind = "Weapon",
		WeaponId = "Shotgun",
		FlagKey = "ShotgunEnabled",
		DisplayName = "Shotgun",
		AccentColor = Color3.fromRGB(255, 200, 110),
		IconColor = Color3.fromRGB(255, 225, 170),
		RespawnSeconds = 20,
	}),

	-- Shield pickup: grants ReflectShield charges (reflect the next incoming shell). Fully
	-- wired via ArenaCombatService.GrantReflectShieldCharges.
	Shield = table.freeze({
		Id = "Shield",
		Kind = "Shield",
		FlagKey = "ShieldPickupEnabled",
		DisplayName = "Reflect Shield",
		ShieldCharges = 1, -- charges granted per pickup (clamped to ReflectShield.MaxCharges)
		AccentColor = Color3.fromRGB(120, 200, 255),
		IconColor = Color3.fromRGB(190, 230, 255),
		NotifyText = "Shield +1!",
		RespawnSeconds = 26,
	}),
})

-- ===========================================================================
-- DEPRECATED (Update 0.2.x): fraction-based fallback layouts.
--
-- PickupLayout / MazeLayout / BreakableLayout below are NO LONGER READ by any
-- runtime service. The arena layer is now authored-template ONLY: if the layout
-- template or its markers are missing, the services no-op with a Studio warning
-- instead of inventing geometry from these fractions. They are retained purely as
-- historical reference for the original procedural arena and may be deleted.
-- Do not wire new code to them.
-- ===========================================================================

-- DEPRECATED — not read at runtime. See banner above.
WeaponCatalog.PickupLayout = table.freeze({
	table.freeze({ "Health", 0.0, 0.55 }),
	table.freeze({ "Health", 0.0, -0.55 }),
	table.freeze({ "MachineGun", -0.55, 0.0 }),
	table.freeze({ "Rocket", 0.55, 0.0 }),
	table.freeze({ "PhaseShot", -0.42, -0.42 }),
})

-- Hand-authored maze layout: a small ricochet maze inside the active arena. Each
-- entry is { fractionX, fractionZ, lengthFracX, lengthFracZ, rotationDegrees,
-- name }. Walls are sized as fractions of the arena floor extent so the layout
-- adapts to whatever arena container is active. The layout intentionally keeps the
-- center playable and stays well clear of spawn points (validated at spawn time).
-- Walls named "RicochetWall_*" are picked up automatically by TankMovementService
-- (movement collision) and ProjectileService (bounce surfaces) -- no extra wiring.
-- DEPRECATED — not read at runtime. See banner above PickupLayout.
WeaponCatalog.MazeLayout = table.freeze({
	-- Four offset bounce panels around the center.
	table.freeze({  0.00,  0.30, 0.32, 0.02, 0,   "RicochetWall_C_N" }),
	table.freeze({  0.00, -0.30, 0.32, 0.02, 0,   "RicochetWall_C_S" }),
	table.freeze({  0.30,  0.00, 0.02, 0.32, 0,   "RicochetWall_C_E" }),
	table.freeze({ -0.30,  0.00, 0.02, 0.32, 0,   "RicochetWall_C_W" }),
	-- Diagonal angled panels (small, for rich ricochet angles).
	table.freeze({  0.45,  0.45, 0.20, 0.02, 45,  "RicochetWall_NE_Diag" }),
	table.freeze({ -0.45,  0.45, 0.20, 0.02, -45, "RicochetWall_NW_Diag" }),
	table.freeze({  0.45, -0.45, 0.20, 0.02, -45, "RicochetWall_SE_Diag" }),
	table.freeze({ -0.45, -0.45, 0.20, 0.02, 45,  "RicochetWall_SW_Diag" }),
})

WeaponCatalog.MazeWallHeight = 7
WeaponCatalog.MazeSpawnClearRadius = 14 -- walls within this many studs of a spawn are dropped.

-- ---------------------------------------------------------------------------
-- Authored layout templates (Update 0.2.x). The runtime loader looks for the active
-- template under ReplicatedStorage/Assets/ArenaLayouts/<ActiveLayoutName>. This path
-- is chosen because default.project.json maps ReplicatedStorage.Assets ->
-- src/ReplicatedStorage/Assets (so an exported .rbxm syncs straight to source), and
-- ReplicatedStorage is readable from the server where the clone happens. There is no
-- ServerStorage mapping in the Rojo project, so ServerStorage is not an option.
-- ---------------------------------------------------------------------------
WeaponCatalog.LayoutAssetsFolderName = "ArenaLayouts"
WeaponCatalog.ActiveLayoutName = "RicochetMaze_01"

-- Standard folder names inside an authored layout template. The Command Bar generator
-- (tools/studio/CreateRicochetMazeLayout.commandbar.luau) creates exactly these, and
-- the runtime services read markers out of them.
WeaponCatalog.LayoutFolders = table.freeze({
	CollisionWalls = "CollisionWalls",
	RicochetWalls = "RicochetWalls",
	Cover = "Cover",
	PickupSpawns = "PickupSpawns",
	PlayerSpawns = "PlayerSpawns",
	BotSpawns = "BotSpawns",
	BreakableSpawns = "BreakableSpawns",
	Visuals = "Visuals",
})

-- DEPRECATED — not read at runtime. See banner above PickupLayout.
WeaponCatalog.BreakableLayout = table.freeze({
	table.freeze({ 0.18,  0.18 }),
	table.freeze({ -0.18, 0.18 }),
	table.freeze({ 0.18, -0.18 }),
	table.freeze({ -0.18, -0.18 }),
})

WeaponCatalog.BreakableRespawnSeconds = 10

function WeaponCatalog.getWeapon(weaponId)
	return WeaponCatalog.Weapons[weaponId]
end

function WeaponCatalog.getPickup(pickupId)
	return WeaponCatalog.Pickups[pickupId]
end

function WeaponCatalog.isUpdate02ArenaLayerEnabled()
	return WeaponCatalog.Flags.Update02ArenaLayerEnabled == true
end

-- Returns true if this pickup should spawn (master flag + its FlagKey if any).
function WeaponCatalog.isPickupEnabled(pickupConfig)
	if not WeaponCatalog.isUpdate02ArenaLayerEnabled() then
		return false
	end

	if WeaponCatalog.Flags.PickupsEnabled ~= true then
		return false
	end

	if pickupConfig == nil then
		return false
	end

	local flagKey = pickupConfig.FlagKey

	if flagKey ~= nil and WeaponCatalog.Flags[flagKey] ~= true then
		return false
	end

	return true
end

return WeaponCatalog
