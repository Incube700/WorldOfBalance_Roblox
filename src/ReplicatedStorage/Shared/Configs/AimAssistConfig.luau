-- Shared visual/input assist config. Does not own projectile damage or armor rules.

local AimAssistConfig = table.freeze({
	AimLaserEnabled = true,
	AimLaserWidth = 0.22,
	AimLaserTransparency = 0.28,
	AimLaserColor = Color3.fromRGB(95, 245, 165),
	AimLaserMaxDistance = 140,
	AimLaserHeightOffset = 0,
	AimLaserVisualSmoothingEnabled = true,
	AimLaserVisualSmoothingSpeed = 30,
	AimLaserVisualSnapDistance = 120,
})

return AimAssistConfig
