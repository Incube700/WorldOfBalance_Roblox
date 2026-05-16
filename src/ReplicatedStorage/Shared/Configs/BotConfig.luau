local BotConfig = table.freeze({
	Enabled = true,
	ThinkInterval = 0.12,
	PreferredDistance = 55,
	MinDistance = 28,
	MaxDistance = 85,
	MoveThrottle = 0.75,
	ReverseThrottle = -0.55,
	StrafeSwitchMinTime = 1.0,
	StrafeSwitchMaxTime = 2.2,
	AimErrorDegrees = 4,
	FireCheckInterval = 0.25,
	FireChance = 0.55,
	LineOfSightEnabled = true,
})

return BotConfig
