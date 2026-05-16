local WeaponSafetyConfig = table.freeze({
	MuzzleObstructionCheckEnabled = true,
	MuzzleClearancePadding = 0.35,
	MuzzleCheckRadius = 0.4,
	BlockedShotFeedbackEnabled = true,
	BlockedShotFeedbackText = "BARREL BLOCKED",
	Debug = false,
})

return WeaponSafetyConfig
