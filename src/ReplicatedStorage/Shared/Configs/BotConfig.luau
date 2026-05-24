local BotConfig = table.freeze({
	Enabled = true,
	Debug = false,
	Difficulty = "Easy",

	DifficultyProfiles = table.freeze({
		Easy = table.freeze({
			AimToleranceDegrees = 14,
			AimJitterDegrees = 7,
			FireChance = 0.35,
			ReactionDelay = 0.35,
			MoveJitterInterval = 1.8,
			FireCheckInterval = 0.42,
			FireCooldownMin = 0.35,
			FireCooldownMax = 0.75,
		}),

		Normal = table.freeze({
			AimToleranceDegrees = 9,
			AimJitterDegrees = 4,
			FireChance = 0.55,
			ReactionDelay = 0.2,
			MoveJitterInterval = 1.25,
			FireCheckInterval = 0.3,
			FireCooldownMin = 0.25,
			FireCooldownMax = 0.55,
		}),
	}),

	BattleArena = table.freeze({
		Enabled = true,
		MinBots = 2,
		MaxBots = 4,
		SpawnWhenPlayerCountLessThan = 2,
		RespawnDelay = 3,
		TargetBotsWhenNoPlayers = false,
	}),

	Brain = table.freeze({
		TickRate = 0.15,
		SearchRadius = 180,
		PreferredDistance = 45,
		TooCloseDistance = 18,
		AimToleranceDegrees = 14,
		AimJitterDegrees = 7,
		FireChance = 0.35,
		ReactionDelay = 0.35,
		MoveJitterInterval = 1.8,
		FireCheckInterval = 0.42,
		FireCooldownMin = 0.35,
		FireCooldownMax = 0.75,
		ReverseChanceWhenTooClose = 0.35,
		MoveThrottle = 0.75,
		ReverseThrottle = -0.55,
		AntiStuckSeconds = 1.4,
		AntiStuckDistance = 0.35,
	}),

	Safety = table.freeze({
		MaxBotsHardLimit = 6,
		CleanupOnPlayerLeave = true,
	}),

	-- BattleArena bot spawn staggering.
	-- Bots are filled in gradually (a few per tick, spaced by an interval) instead
	-- of all in one Heartbeat frame. This reduces the BattleArena entry spike
	-- described in docs/PERFORMANCE_RUNTIME_DEEP_DIVE.md. It changes only spawn
	-- *timing*: the eventual desired bot count and all post-spawn bot behavior are
	-- unchanged. Set IntervalSeconds = 0 to disable staggering (legacy behavior:
	-- fill the whole deficit immediately).
	Spawn = table.freeze({
		IntervalSeconds = 0.35,
		MaxPerTick = 1,
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
