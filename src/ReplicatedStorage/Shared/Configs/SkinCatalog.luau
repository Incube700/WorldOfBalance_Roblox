local SkinCatalog = table.freeze({
	DefaultSkinId = "Default",

	Skins = table.freeze({
		Default = table.freeze({
			DisplayName = "Default",
			BodyColor = Color3.fromRGB(55, 185, 255),
			TurretColor = Color3.fromRGB(80, 220, 160),
			BarrelColor = Color3.fromRGB(35, 40, 42),
			Material = Enum.Material.SmoothPlastic,
			UnlockedByDefault = true,
			DuelSafe = true,
		}),

		Red = table.freeze({
			DisplayName = "Red",
			BodyColor = Color3.fromRGB(220, 70, 70),
			TurretColor = Color3.fromRGB(240, 120, 80),
			BarrelColor = Color3.fromRGB(45, 45, 50),
			Material = Enum.Material.SmoothPlastic,
			Price = 25,
			Currency = "Bolts",
			DuelSafe = true,
		}),

		Blue = table.freeze({
			DisplayName = "Blue",
			BodyColor = Color3.fromRGB(45, 110, 245),
			TurretColor = Color3.fromRGB(85, 185, 255),
			BarrelColor = Color3.fromRGB(35, 40, 48),
			Material = Enum.Material.SmoothPlastic,
			Price = 25,
			Currency = "Bolts",
			DuelSafe = true,
		}),

		Green = table.freeze({
			DisplayName = "Green",
			BodyColor = Color3.fromRGB(70, 185, 95),
			TurretColor = Color3.fromRGB(120, 230, 130),
			BarrelColor = Color3.fromRGB(35, 45, 38),
			Material = Enum.Material.SmoothPlastic,
			Price = 25,
			Currency = "Bolts",
			DuelSafe = true,
		}),

		BlackGold = table.freeze({
			DisplayName = "Black / Gold",
			BodyColor = Color3.fromRGB(30, 30, 34),
			TurretColor = Color3.fromRGB(225, 170, 65),
			BarrelColor = Color3.fromRGB(15, 16, 18),
			Material = Enum.Material.SmoothPlastic,
			Price = 3,
			Currency = "Crystals",
			DuelSafe = true,
			FeaturedLocked = true,
		}),

		RedTest = table.freeze({
			DisplayName = "Red Test",
			AliasOf = "Red",
			BodyColor = Color3.fromRGB(220, 70, 70),
			TurretColor = Color3.fromRGB(240, 120, 80),
			BarrelColor = Color3.fromRGB(45, 45, 50),
			Material = Enum.Material.SmoothPlastic,
			DuelSafe = true,
		}),

		DesertTest = table.freeze({
			DisplayName = "Desert Test",
			BodyColor = Color3.fromRGB(185, 150, 90),
			TurretColor = Color3.fromRGB(215, 180, 110),
			BarrelColor = Color3.fromRGB(55, 50, 45),
			Material = Enum.Material.SmoothPlastic,
			DuelSafe = true,
		}),
	}),
})

return SkinCatalog
