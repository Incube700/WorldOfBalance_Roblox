local BattleArenaConfig = table.freeze({
	Enabled = true,
	RespawnDelay = 3,
	KillScore = 1,
	XPPerKill = 100,
	XPPerSurvivalTick = 10,
	SurvivalTickInterval = 10,
	MaxArenaLevel = 30,
	CoreBuildLevel = 5,
	-- Upgrades are now offered for much longer (was 5). With multi-stack stats (Etap 1) you
	-- keep getting meaningful choices deep into a run instead of "done at level 5".
	MaxUpgradeLevel = 15,
	PostMaxLevelXPStep = 700,
	UpgradeChoicesPerOffer = 3,
	-- Slower, longer curve: each level needs more XP than before so reaching high levels is
	-- an achievement, not a 2-minute formality.
	LevelThresholds = table.freeze({
		[1] = 0,
		[2] = 150,
		[3] = 380,
		[4] = 700,
		[5] = 1120,
		[6] = 1650,
		[7] = 2300,
		[8] = 3080,
		[9] = 4000,
		[10] = 5080,
		[11] = 6330,
		[12] = 7770,
		[13] = 9410,
		[14] = 11270,
		[15] = 13360,
	}),
	XPPerControlZoneTick = 50,
	XPPerSupplyCrateUse = 50,
	ControlZoneTickInterval = 5,
	MedkitHealAmount = 40,
	MedkitRespawnTime = 30,
	CrateRespawnTime = 60,
	PickupCheckInterval = 0.25,
	MedkitFolderName = "Medkits",
	SupplyCrateFolderName = "SupplyCrates",
	ControlZoneName = "ControlZone",
	SpawnPointCount = 8,
	SafeArenaCenter = Vector3.new(-340, 0, 320),
	Debug = false,
	DebugPad = false,
	DebugCollision = false,

	MobileHud = table.freeze({
		Compact = true,
		ShowUpgradeList = false,
		UseMenuForReturn = true,
	}),

	PostLevelRewards = table.freeze({
		Enabled = false,
		BoltsPerLevel = 0,
		RewardEveryLevels = 0,
	}),

	Revive = table.freeze({
		Enabled = true,
		CostBase = 5,
		CostPerRevive = 0,
		MaxRevivesPerRun = 3,
		RestoreHpPercent = 0.5,
		FreeRespawnEnabled = true,
		FreeRespawnRestoreHpPercent = 1.0,
		FreeRespawnResetsRun = true,
		-- Legacy aliases kept during the MVP rollout.
		CostBaseBolts = 5,
		CostAdditiveBolts = 0,
		CostMultiplier = 1,
		ReviveHpPercent = 0.5,
	}),

	UpgradeSchema = table.freeze({
		"Id",
		"Title",
		"Description",
		"Tags",
		"Branch",
		"Rarity",
		"MaxStacks",
		"RequiresUpgrade",
		"BlocksUpgrade",
		"MinArenaLevel",
		"MaxOfferLevel",
		"OfferAfterLevel",
		"FutureOnly",
		"Enabled",
	}),

	UpgradeBranches = table.freeze({
		Movement = table.freeze({
			Title = "Movement",
			Tags = table.freeze({ "speed", "positioning", "survival" }),
		}),
		Shooting = table.freeze({
			Title = "Shooting",
			Tags = table.freeze({ "damage", "reload", "multishot" }),
		}),
		Defense = table.freeze({
			Title = "Defense",
			Tags = table.freeze({ "shield", "repair", "survival" }),
		}),
		Vampire = table.freeze({
			Title = "Vampire",
			Tags = table.freeze({ "future", "lifesteal", "penetration" }),
			FutureOnly = true,
		}),
		Ricochet = table.freeze({
			Title = "Ricochet",
			Tags = table.freeze({ "bounce", "angles", "map-control" }),
		}),
	}),

	UpgradeThresholds = table.freeze({
		DamageUp = 2,
		FireRateUp = 4,
		DoubleShot = 6,
		MoveSpeedUp = 8,
		TripleSpread = 10,
	}),

	DamageUpMultiplier = 1.2, -- +20% damage per DamageUp stack
	FireRateMultiplier = 0.88, -- -12% cooldown per FireRateUp stack (now multi-stack)
	MoveSpeedMultiplier = 1.1, -- +10% move speed per MoveSpeedUp stack
	MultiShotSpreadDegrees = 8,
	DoubleShotLateralOffset = 1.1,
	RicochetUpBonus = 1, -- +1 ricochet per RicochetUp stack (now up to 3)
	RepairHealAmount = 30,

	-- Etap 1 new upgrades tuning.
	-- Lifesteal: heal LifestealHealPerKill HP on each confirmed kill, per stack.
	LifestealHealPerKill = 18,
	-- Overcharge: per stack -> +damage, but slower fire rate (risk/reward).
	OverchargeDamageBonus = 0.18, -- +18% damage per stack (additive on top of DamageUp)
	OverchargeFireRatePenalty = 0.12, -- +12% cooldown per stack (slower)
	-- Piercing: passive shells pass through this many enemies (per stack).
	PiercingEnemiesPerStack = 1,

	ReflectShield = table.freeze({
		SpawnDurationSeconds = 3.0,
		UpgradeGrantCharges = 1,
		MaxCharges = 3,
		ReflectText = "REFLECT",
		MaxReflectsPerProjectile = 1,
	}),

	UpgradePool = table.freeze({
		DamageUp = table.freeze({
			Id = "DamageUp",
			Title = "Damage Up",
			Description = "+20% projectile damage. Stacks up to 5x.",
			Tags = table.freeze({ "damage", "cannon", "core" }),
			Branch = "Shooting",
			Rarity = "Common",
			MaxStacks = 5,
			Enabled = true,
		}),
		FireRateUp = table.freeze({
			Id = "FireRateUp",
			Title = "Fire Rate Up",
			Description = "-12% cannon cooldown. Stacks up to 5x.",
			Tags = table.freeze({ "reload", "cannon", "core" }),
			Branch = "Shooting",
			Rarity = "Common",
			MaxStacks = 5,
			Enabled = true,
		}),
		MoveSpeedUp = table.freeze({
			Id = "MoveSpeedUp",
			Title = "Move Speed Up",
			Description = "+10% tank speed. Stacks up to 5x.",
			Tags = table.freeze({ "speed", "positioning", "core" }),
			Branch = "Movement",
			Rarity = "Common",
			MaxStacks = 5,
			Enabled = true,
		}),
		DoubleShot = table.freeze({
			Id = "DoubleShot",
			Title = "Double Shot",
			Description = "Fire two shells side by side.",
			Tags = table.freeze({ "multishot", "cannon", "core" }),
			Branch = "Shooting",
			Rarity = "Rare",
			MaxStacks = 1,
			Enabled = true,
		}),
		TripleSpread = table.freeze({
			Id = "TripleSpread",
			Title = "Triple Spread",
			Description = "Upgrade Double Shot into a 3-shell spread.",
			Tags = table.freeze({ "multishot", "spread", "core" }),
			Branch = "Shooting",
			Rarity = "Rare",
			MaxStacks = 1,
			RequiresUpgrade = "DoubleShot",
			Enabled = true,
		}),
		RicochetUp = table.freeze({
			Id = "RicochetUp",
			Title = "Ricochet Research",
			Description = "+1 max wall ricochet. Stacks up to 3x.",
			Tags = table.freeze({ "bounce", "angles", "core" }),
			Branch = "Ricochet",
			Rarity = "Uncommon",
			MaxStacks = 3,
			Enabled = true,
		}),
		Repair = table.freeze({
			Id = "Repair",
			Title = "Repair",
			Description = "Restore 30 HP immediately.",
			Tags = table.freeze({ "repair", "survival", "instant" }),
			Branch = "Defense",
			Rarity = "Common",
			Immediate = true,
			Enabled = true,
		}),
		-- Etap 1: ReflectShield removed from the level-up pool. Three new upgrades below.
		Lifesteal = table.freeze({
			Id = "Lifesteal",
			Title = "Lifesteal",
			Description = "Heal +18 HP on each kill. Stacks up to 3x.",
			Tags = table.freeze({ "lifesteal", "survival", "core" }),
			Branch = "Defense",
			Rarity = "Uncommon",
			MaxStacks = 3,
			Enabled = true,
		}),
		Piercing = table.freeze({
			Id = "Piercing",
			Title = "Piercing Rounds",
			Description = "Shells pass through +1 enemy. Stacks up to 2x.",
			Tags = table.freeze({ "pierce", "cannon", "core" }),
			Branch = "Shooting",
			Rarity = "Rare",
			MaxStacks = 2,
			Enabled = true,
		}),
		Overcharge = table.freeze({
			Id = "Overcharge",
			Title = "Overcharge",
			Description = "+18% damage but -12% fire rate. Stacks up to 3x.",
			Tags = table.freeze({ "damage", "risk", "core" }),
			Branch = "Shooting",
			Rarity = "Rare",
			MaxStacks = 3,
			Enabled = true,
		}),
	}),

	FutureUpgradePool = table.freeze({
		VampireShells = table.freeze({
			Id = "VampireShells",
			Title = "Vampire Shells",
			Description = "Future: heal after confirmed penetrating hits.",
			Tags = table.freeze({ "future", "lifesteal", "penetration" }),
			Branch = "Vampire",
			Rarity = "Rare",
			MaxStacks = 3,
			MinArenaLevel = 6,
			FutureOnly = true,
			Enabled = false,
		}),
	}),
})

return BattleArenaConfig
