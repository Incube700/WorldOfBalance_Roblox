local SkinCatalog = table.freeze({
	DefaultSkinId = "Default",

	Skins = table.freeze({
		Default = table.freeze({
			DisplayName = "Default",
			BodyColor = Color3.fromRGB(55, 185, 255),
			TurretColor = Color3.fromRGB(80, 220, 160),
			BarrelColor = Color3.fromRGB(35, 40, 42),
			Material = Enum.Material.SmoothPlastic,
		}),

		RedTest = table.freeze({
			DisplayName = "Red Test",
			BodyColor = Color3.fromRGB(220, 70, 70),
			TurretColor = Color3.fromRGB(240, 120, 80),
			BarrelColor = Color3.fromRGB(45, 45, 50),
			Material = Enum.Material.SmoothPlastic,
		}),

		DesertTest = table.freeze({
			DisplayName = "Desert Test",
			BodyColor = Color3.fromRGB(185, 150, 90),
			TurretColor = Color3.fromRGB(215, 180, 110),
			BarrelColor = Color3.fromRGB(55, 50, 45),
			Material = Enum.Material.SmoothPlastic,
		}),
	}),
})

return SkinCatalog
