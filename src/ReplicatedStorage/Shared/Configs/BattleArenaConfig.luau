local BattleArenaConfig = table.freeze({
	Enabled = true,
	RespawnDelay = 3,
	KillScore = 1,
	XPPerKill = 100,
	XPPerSurvivalTick = 10,
	SurvivalTickInterval = 10,
	MaxArenaLevel = 5,
	UpgradeChoicesPerOffer = 3,
	LevelThresholds = table.freeze({
		[1] = 0,
		[2] = 100,
		[3] = 250,
		[4] = 450,
		[5] = 700,
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

	UpgradeThresholds = table.freeze({
		DamageUp = 2,
		FireRateUp = 4,
		DoubleShot = 6,
		MoveSpeedUp = 8,
		TripleSpread = 10,
	}),

	DamageUpMultiplier = 1.2,
	FireRateMultiplier = 0.85,
	MoveSpeedMultiplier = 1.1,
	MultiShotSpreadDegrees = 8,
	DoubleShotLateralOffset = 1.1,
	RicochetUpBonus = 1,
	RepairHealAmount = 30,

	UpgradePool = table.freeze({
		DamageUp = table.freeze({
			Title = "Damage Up",
			Description = "+20% projectile damage.",
			MaxStacks = 2,
		}),
		FireRateUp = table.freeze({
			Title = "Fire Rate Up",
			Description = "-15% cannon cooldown.",
			MaxStacks = 1,
		}),
		MoveSpeedUp = table.freeze({
			Title = "Move Speed Up",
			Description = "+10% tank speed.",
			MaxStacks = 2,
		}),
		DoubleShot = table.freeze({
			Title = "Double Shot",
			Description = "Fire two shells side by side.",
			MaxStacks = 1,
		}),
		TripleSpread = table.freeze({
			Title = "Triple Spread",
			Description = "Upgrade Double Shot into a 3-shell spread.",
			MaxStacks = 1,
			RequiresUpgrade = "DoubleShot",
		}),
		RicochetUp = table.freeze({
			Title = "Ricochet Research",
			Description = "+1 max wall ricochet.",
			MaxStacks = 1,
		}),
		Repair = table.freeze({
			Title = "Repair",
			Description = "Restore 30 HP immediately.",
			Immediate = true,
		}),
	}),
})

return BattleArenaConfig
