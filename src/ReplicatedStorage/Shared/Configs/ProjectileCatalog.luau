-- Read-only snapshot config. Do not wire without a dedicated task.

local ProjectileCatalog = table.freeze({
	BehaviorTypes = table.freeze({
		Ricochet = "Ricochet",
		Piercing = "Piercing",
		Explosive = "Explosive",
		Heavy = "Heavy",
		NoRicochet = "NoRicochet",
	}),

	DefaultProjectileTypeId = "PrototypeRicochetShell",

	Projectiles = table.freeze({
		PrototypeRicochetShell = table.freeze({
			Id = "PrototypeRicochetShell",
			BehaviorType = "Ricochet",
			Speed = 160,
			Damage = 35,
			MaxRicochets = 3,
			DamageMultiplierPerRicochet = 0.75,
			Lifetime = 4,

			Raycast = table.freeze({
				FilterType = "Exclude",
				IgnoreWater = true,
				ExcludedRuntimeGroups = table.freeze({
					"Projectiles",
					"VFX",
					"PlayerTankPrototype",
				}),
				-- TODO: Current snapshot excludes PlayerTankPrototype, so self-hit is not active yet.
			}),
		}),
	}),
})

return ProjectileCatalog
