local CosmeticFXCatalog = {}

CosmeticFXCatalog.Version = 1

CosmeticFXCatalog.Categories = table.freeze({
	TankExplosion = "TankExplosion",
	ProjectileTrail = "ProjectileTrail",
	MuzzleFlash = "MuzzleFlash",
	ProjectileImpact = "ProjectileImpact",
	RicochetImpact = "RicochetImpact",
	Repair = "Repair",
	ReflectShield = "ReflectShield",
	UpgradeSelect = "UpgradeSelect",
	LevelUp = "LevelUp",
})

CosmeticFXCatalog.Items = table.freeze({
	TankExplosion_Default = table.freeze({
		Id = "TankExplosion_Default",
		Category = "TankExplosion",
		DisplayName = "Default Tank Explosion",
		Description = "Baseline tank destruction FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/TankExplosionFX/TankExplosion_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	TankExplosion_Fire = table.freeze({
		Id = "TankExplosion_Fire",
		Category = "TankExplosion",
		DisplayName = "Fireburst Explosion",
		Description = "A hotter cosmetic tank explosion variant.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Cosmetics/TankExplosion/TankExplosion_Fire",
		Rarity = "Rare",
		PriceBolts = 250,
		IsDefault = false,
		SortOrder = 20,
	}),

	TankExplosion_Electric = table.freeze({
		Id = "TankExplosion_Electric",
		Category = "TankExplosion",
		DisplayName = "Electric Breakdown",
		Description = "A crackling tank explosion variant.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Cosmetics/TankExplosion/TankExplosion_Electric",
		Rarity = "Epic",
		PriceBolts = 400,
		IsDefault = false,
		SortOrder = 30,
	}),

	ProjectileTrail_Default = table.freeze({
		Id = "ProjectileTrail_Default",
		Category = "ProjectileTrail",
		DisplayName = "Default Shell Trail",
		Description = "Baseline projectile trail FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/ProjectileTrailFX/ProjectileTrail_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	ProjectileTrail_Laser = table.freeze({
		Id = "ProjectileTrail_Laser",
		Category = "ProjectileTrail",
		DisplayName = "Laser Trail",
		Description = "A sharper cosmetic projectile trail.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Cosmetics/ProjectileTrail/ProjectileTrail_Laser",
		Rarity = "Rare",
		PriceBolts = 220,
		IsDefault = false,
		SortOrder = 20,
	}),

	MuzzleFlash_Default = table.freeze({
		Id = "MuzzleFlash_Default",
		Category = "MuzzleFlash",
		DisplayName = "Default Muzzle Flash",
		Description = "Baseline cannon muzzle flash FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/MuzzleFlashFX/MuzzleFlash_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	ProjectileImpact_Default = table.freeze({
		Id = "ProjectileImpact_Default",
		Category = "ProjectileImpact",
		DisplayName = "Default Impact",
		Description = "Baseline projectile impact FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/ProjectileImpactFX/ProjectileImpact_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	RicochetImpact_Default = table.freeze({
		Id = "RicochetImpact_Default",
		Category = "RicochetImpact",
		DisplayName = "Default Ricochet",
		Description = "Baseline ricochet impact FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/RicochetImpactFX/RicochetImpact_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	Repair_Default = table.freeze({
		Id = "Repair_Default",
		Category = "Repair",
		DisplayName = "Default Repair",
		Description = "Baseline repair FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/RepairFX/Repair_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	ReflectShield_Default = table.freeze({
		Id = "ReflectShield_Default",
		Category = "ReflectShield",
		DisplayName = "Default Reflect Shield",
		Description = "Baseline reflect shield FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/ReflectShieldFX/ReflectShield_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	ReflectShield_Electric = table.freeze({
		Id = "ReflectShield_Electric",
		Category = "ReflectShield",
		DisplayName = "Electric Reflect Shield",
		Description = "A charged cosmetic reflect shield variant.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Cosmetics/ReflectShield/ReflectShield_Electric",
		Rarity = "Epic",
		PriceBolts = 360,
		IsDefault = false,
		SortOrder = 20,
	}),

	UpgradeSelect_Default = table.freeze({
		Id = "UpgradeSelect_Default",
		Category = "UpgradeSelect",
		DisplayName = "Default Upgrade Select",
		Description = "Baseline upgrade selection FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/UpgradeSelectFX/UpgradeSelect_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),

	LevelUp_Default = table.freeze({
		Id = "LevelUp_Default",
		Category = "LevelUp",
		DisplayName = "Default Level Up",
		Description = "Baseline level-up FX.",
		TemplatePath = "ReplicatedStorage/Assets/FX/Gameplay/LevelUpFX/LevelUp_Default",
		Rarity = "Common",
		PriceBolts = 0,
		IsDefault = true,
		SortOrder = 10,
	}),
})

CosmeticFXCatalog.DefaultByCategory = table.freeze({
	TankExplosion = "TankExplosion_Default",
	ProjectileTrail = "ProjectileTrail_Default",
	MuzzleFlash = "MuzzleFlash_Default",
	ProjectileImpact = "ProjectileImpact_Default",
	RicochetImpact = "RicochetImpact_Default",
	Repair = "Repair_Default",
	ReflectShield = "ReflectShield_Default",
	UpgradeSelect = "UpgradeSelect_Default",
	LevelUp = "LevelUp_Default",
})

return table.freeze(CosmeticFXCatalog)
