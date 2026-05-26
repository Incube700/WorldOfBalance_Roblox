local GameplayFXCatalog = {}

GameplayFXCatalog.Version = 1
GameplayFXCatalog.Debug = false

GameplayFXCatalog.Effects = table.freeze({
	MuzzleFlash = table.freeze({
		Key = "MuzzleFlash",
		FolderName = "MuzzleFlashFX",
		TemplateName = "MuzzleFlash_Default",
		EmitCount = 12,
		Lifetime = 0.35,
		YOffset = 0,
		ScaleMultiplier = 0.65,
		DebugName = "Muzzle Flash",
	}),

	ProjectileTrail = table.freeze({
		Key = "ProjectileTrail",
		FolderName = "ProjectileTrailFX",
		TemplateName = "ProjectileTrail_Default",
		AttachMode = "Projectile",
		EmitCount = 1,
		Lifetime = 4,
		YOffset = 0,
		ScaleMultiplier = 0.75,
		DebugName = "Projectile Trail",
	}),

	ProjectileVisual = table.freeze({
		Key = "ProjectileVisual",
		FolderName = "ProjectileVisualFX",
		TemplateName = "ProjectileVisual_Default",
		AttachMode = "ProjectileVisual",
		EmitCount = 1,
		Lifetime = 4,
		YOffset = 0,
		ScaleMultiplier = 0.75,
		DebugName = "Projectile Visual",
	}),

	ProjectileImpact = table.freeze({
		Key = "ProjectileImpact",
		FolderName = "ProjectileImpactFX",
		TemplateName = "ProjectileImpact_Default",
		EmitCount = 20,
		Lifetime = 1,
		YOffset = 0,
		ScaleMultiplier = 0.85,
		DebugName = "Projectile Impact",
	}),

	RicochetImpact = table.freeze({
		Key = "RicochetImpact",
		FolderName = "RicochetImpactFX",
		TemplateName = "RicochetImpact_Default",
		EmitCount = 16,
		Lifetime = 0.8,
		YOffset = 0,
		ScaleMultiplier = 0.75,
		DebugName = "Ricochet Impact",
	}),

	TankExplosion = table.freeze({
		Key = "TankExplosion",
		FolderName = "TankExplosionFX",
		TemplateName = "TankExplosion_Default",
		EmitCount = 60,
		Lifetime = 3.5,
		YOffset = 1.2,
		ScaleMultiplier = 1.25,
		DebugName = "Tank Explosion",
	}),

	Repair = table.freeze({
		Key = "Repair",
		FolderName = "RepairFX",
		TemplateName = "Repair_Default",
		EmitCount = 30,
		Lifetime = 2,
		YOffset = 1,
		ScaleMultiplier = 1,
		DebugName = "Repair",
	}),

	ReflectShield = table.freeze({
		Key = "ReflectShield",
		FolderName = "ReflectShieldFX",
		TemplateName = "ReflectShield_Default",
		EmitCount = 14,
		Lifetime = 1,
		YOffset = 0.25,
		ScaleMultiplier = 0.08,
		DebugName = "Reflect Shield",
	}),

	UpgradeSelect = table.freeze({
		Key = "UpgradeSelect",
		FolderName = "UpgradeSelectFX",
		TemplateName = "UpgradeSelect_Default",
		EmitCount = 24,
		Lifetime = 1.5,
		YOffset = 1,
		ScaleMultiplier = 1,
		DebugName = "Upgrade Select",
	}),

	LevelUp = table.freeze({
		Key = "LevelUp",
		FolderName = "LevelUpFX",
		TemplateName = "LevelUp_Default",
		EmitCount = 32,
		Lifetime = 2,
		YOffset = 1.2,
		ScaleMultiplier = 1.1,
		DebugName = "Level Up",
	}),
})

return table.freeze(GameplayFXCatalog)
