local BotConfig = table.freeze({
	Enabled = true,
	Debug = false,

	BattleArena = table.freeze({
		Enabled = true,
		MinBots = 1,
		MaxBots = 3,
		SpawnWhenPlayerCountLessThan = 2,
		RespawnDelay = 3,
		TargetBotsWhenNoPlayers = false,
	}),

	Brain = table.freeze({
		TickRate = 0.15,
		SearchRadius = 180,
		PreferredDistance = 45,
		TooCloseDistance = 18,
		AimToleranceDegrees = 10,
		FireChance = 0.55,
		MoveJitterInterval = 1.25,
		ReverseChanceWhenTooClose = 0.35,
		MoveThrottle = 0.75,
		ReverseThrottle = -0.55,
	}),

	Safety = table.freeze({
		MaxBotsHardLimit = 6,
		CleanupOnPlayerLeave = true,
	}),

	ThinkInterval = 0.12,
	PreferredDistance = 55,
	MinDistance = 28,
	MaxDistance = 85,
	MoveThrottle = 0.75,
	ReverseThrottle = -0.55,
	BodyTurnSpeedRadians = 2.0,
	TurretTurnSpeedRadians = 5.5,
	StrafeSwitchMinTime = 1.0,
	StrafeSwitchMaxTime = 2.2,
	AimErrorDegrees = 4,
	FireCheckInterval = 0.25,
	FireChance = 0.55,
	LineOfSightEnabled = true,
	ArenaBoundsEnabled = true,
	ArenaMinX = -96,
	ArenaMaxX = 96,
	ArenaMinZ = -96,
	ArenaMaxZ = 96,
	ReturnToCenterDistance = 12,
})

return BotConfig
