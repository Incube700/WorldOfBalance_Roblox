local TankSmoothingConfig = table.freeze({
	Enabled = true,
	SmoothRemoteTanks = true,
	SmoothLocalTank = false,
	PositionLerpSpeed = 18,
	RotationLerpSpeed = 22,
	TurretRotationLerpSpeed = 28,
	MaxSnapDistance = 18,
	IgnoreDeadTanks = false,
	Debug = false,
})

return TankSmoothingConfig
