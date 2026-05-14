local BattleArenaConfig = table.freeze({
	Enabled = true,
	RespawnDelay = 3,
	KillScore = 1,
	SpawnPointCount = 8,
	SafeArenaCenter = Vector3.new(-340, 0, 320),
	Debug = false,
	DebugPad = false,
	DebugCollision = false,

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
})

return BattleArenaConfig
