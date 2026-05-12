local VfxConfig = table.freeze({
	Shot = table.freeze({
		-- Put Roblox asset ids here later, for example: "rbxassetid://123456789".
		-- Empty ids keep the current procedural fallback visuals.
		SoundId = "",
		SoundVolume = 0.7,
		SoundPlaybackSpeed = 1,
		SoundRollOffMaxDistance = 180,

		MuzzleFlash = table.freeze({
			Enabled = true,
			Color = Color3.fromRGB(255, 225, 90),
			Size = 4.1,
			Lifetime = 0.06,
		}),

		MuzzleBlast = table.freeze({
			Enabled = true,
			Color = Color3.fromRGB(255, 180, 55),
			Size = Vector3.new(1.7, 1.7, 6),
			Transparency = 0.12,
			ForwardOffset = 2.6,
			Lifetime = 0.075,
			LightBrightness = 4,
			LightRange = 15,
			LightColor = Color3.fromRGB(255, 205, 95),
		}),

		Smoke = table.freeze({
			Enabled = true,
			Color = Color3.fromRGB(115, 115, 105),
			Size = Vector3.new(3.2, 1.2, 3.2),
			Transparency = 0.55,
			BackwardOffset = 0.8,
			UpOffset = 0.3,
			Lifetime = 0.16,
		}),

		Projectile = table.freeze({
			Size = 1.35,
			Color = Color3.fromRGB(255, 235, 125),
			LightBrightness = 2.4,
			LightRange = 10,
			LightColor = Color3.fromRGB(255, 220, 120),
			TrailFrontOffset = -0.65,
			TrailBackOffset = 0.65,
			TrailColorStart = Color3.fromRGB(255, 245, 150),
			TrailColorEnd = Color3.fromRGB(255, 100, 35),
			TrailLifetime = 0.18,
			TrailWidthStart = 1.6,
			TrailWidthMid = 0.85,
		}),

		ImpactFlash = table.freeze({
			Enabled = true,
			Color = Color3.fromRGB(255, 130, 40),
			Size = 2.5,
			Lifetime = 0.12,
		}),

		ImpactSparks = table.freeze({
			Enabled = true,
			Count = 3,
			Color = Color3.fromRGB(255, 200, 90),
			Size = Vector3.new(0.25, 0.25, 1.2),
			Lifetime = 0.12,
		}),
	}),
})

return VfxConfig
