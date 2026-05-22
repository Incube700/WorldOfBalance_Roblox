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

	Visuals = table.freeze({
		ArmorZonesVisible = false,
		Material = "SmoothPlastic",
		FrontColor = Color3.fromRGB(75, 240, 180),
		SideColor = Color3.fromRGB(255, 210, 70),
		RearColor = Color3.fromRGB(255, 90, 85),
		CornerColor = Color3.fromRGB(135, 210, 255),
		FrontTransparency = 0.32,
		SideTransparency = 0.42,
		RearTransparency = 0.42,
		CornerTransparency = 0.45,
	}),

	Feedback = table.freeze({
		DamageColor = Color3.fromRGB(255, 105, 75),
		NoPenText = "NO PEN",
		NoPenColor = Color3.fromRGB(185, 225, 255),
		RicochetText = "RICOCHET",
		RicochetColor = Color3.fromRGB(255, 220, 70),
		Lifetime = 0.6,
		RiseDistance = 2.1,
		MaxActiveFeedback = 6,
	}),
})

return TankArmorConfig
