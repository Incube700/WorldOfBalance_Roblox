-- Read-only snapshot config. Do not wire without a dedicated task.

local ProjectileVisualConfig = table.freeze({
	ProjectileTypeVisuals = table.freeze({
		PrototypeRicochetShell = table.freeze({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 230, 120),

			PointLight = table.freeze({
				Brightness = 1,
				Range = 6,
			}),

			GroundGlowEnabled = true,
			GroundGlowSize = Vector3.new(3.6, 0.08, 3.6),
			GroundGlowTransparency = 0.42,
			GroundGlowHeightOffset = 0.08,
			GroundGlowColor = Color3.fromRGB(255, 180, 70),

			Trail = table.freeze({
				Name = "WOBTrail",
				Attachment0Name = "TrailAttachment0",
				Attachment0Position = Vector3.new(0, 0, -0.45),
				Attachment1Name = "TrailAttachment1",
				Attachment1Position = Vector3.new(0, 0, 0.45),
				Lifetime = 0.18,
				MinLength = 0.1,
				LightEmission = 1,
				FaceCamera = true,
				ColorStart = Color3.fromRGB(255, 230, 120),
				ColorEnd = Color3.fromRGB(255, 120, 40),
				TransparencyStart = 0.05,
				TransparencyEnd = 1,
			}),
		}),
	}),

	MuzzleFlash = table.freeze({
		Color = Color3.fromRGB(255, 220, 80),
		Size = 3.2,
		Lifetime = 0.08,
	}),

	ImpactFlash = table.freeze({
		Color = Color3.fromRGB(255, 130, 40),
		Size = 2.5,
		Lifetime = 0.12,
	}),

	RicochetSparks = table.freeze({
		Count = 3,
		Size = Vector3.new(0.25, 0.25, 1.2),
		Color = Color3.fromRGB(255, 200, 90),
		Lifetime = 0.12,
	}),

	DummyDestroyedVisual = table.freeze({
		PartColor = Color3.fromRGB(30, 30, 30),
		-- TODO: No separate death VFX exists in the snapshot; current behavior only darkens dummy parts.
	}),
})

return ProjectileVisualConfig
