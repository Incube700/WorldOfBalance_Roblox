-- Shared projectile mechanics config. Visual-only values live in ProjectileVisualConfig.

local DEFAULT_RICOCHET_SHELL = table.freeze({
	Id = "DefaultRicochetShell",
	BehaviorType = "Ricochet",
	Speed = 160,
	Radius = 0.6,
	BaseDamage = 110,
	Damage = 110,
	MaxDamage = 110,
	PenetrationPower = 70,
	Penetration = 45,
	MaxRicochets = 3,
	BounceSpeedMultiplier = 0.78,
	DamageMultiplierPerBounce = 0.75,
	MinProjectileSpeed = 5,
	Lifetime = 4,

	Raycast = table.freeze({
		FilterType = "Exclude",
		IgnoreWater = true,
		ExcludedRuntimeGroups = table.freeze({
			"Projectiles",
			"VFX",
		}),
		-- Active server excludes the owner tank before first bounce, then allows ricochet self-hit.
	}),
})

local ProjectileCatalog = table.freeze({
	BehaviorTypes = table.freeze({
		Ricochet = "Ricochet",
		Piercing = "Piercing",
		Explosive = "Explosive",
		Heavy = "Heavy",
		NoRicochet = "NoRicochet",
	}),

	DefaultProjectileTypeId = "DefaultRicochetShell",

	Projectiles = table.freeze({
		DefaultRicochetShell = DEFAULT_RICOCHET_SHELL,
		-- Legacy alias for older notes/scripts that still mention PrototypeRicochetShell.
		PrototypeRicochetShell = DEFAULT_RICOCHET_SHELL,
	}),
})

return ProjectileCatalog
