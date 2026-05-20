local TankArmorConfig = table.freeze({
	Default = table.freeze({
		ModelForwardAxis = "-Z",
		CornerThreshold = 0.82,
		NoPenAngleBelowRicochet = true,
		EffectiveArmorMinCos = 0.25,
		GlancingAngleDegrees = 45,
		DefaultRicochetAngleDegrees = 60,
		MinPenetrationDamage = 1,
		NoPenDamage = 0,

		Zones = table.freeze({
			Front = table.freeze({
				Armor = 80,
				DamageMultiplier = 0.65,
				RicochetAngleDegrees = 60,
			}),
			Side = table.freeze({
				Armor = 55,
				DamageMultiplier = 0.9,
				RicochetAngleDegrees = 62,
			}),
			Rear = table.freeze({
				Armor = 35,
				DamageMultiplier = 1.15,
				RicochetAngleDegrees = 65,
			}),
			Corner = table.freeze({
				Armor = 90,
				DamageMultiplier = 0.5,
				RicochetAngleDegrees = 45,
				ForceRicochetBias = true,
			}),
		}),
	}),

	Projectile = table.freeze({
		DefaultPenetrationPower = 70,
	}),
})

return TankArmorConfig
