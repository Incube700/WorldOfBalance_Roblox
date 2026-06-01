-- Shared visual/input assist config. Does not own projectile damage or armor rules.

local AimAssistConfig = table.freeze({
	AimLaserEnabled = true,
	AimLaserWidth = 0.16,
	AimLaserTransparency = 0.15,
	AimLaserColor = Color3.fromRGB(255, 70, 70), -- red aim laser
	AimLaserMaxDistance = 90, -- shorter than before
	-- Ricochet aim preview: how many wall bounces the laser shows (0 = straight line only).
	AimLaserMaxBounces = 2,
	AimLaserHeightOffset = 0,
	AimLaserVisualSmoothingEnabled = true,
	AimLaserVisualSmoothingSpeed = 30,
	AimLaserVisualSnapDistance = 120,
})

return AimAssistConfig
