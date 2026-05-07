-- Shared performance config used by WOBPerformanceServer.

local PerformanceConfig = table.freeze({
	Lighting = table.freeze({
		ShadowsEnabled = true,
		GlobalShadows = true,
		Brightness = 2,
		ClockTime = 14,
		FogEnd = 100000,
		Technology = "Compatibility",
	}),

	BasePart = table.freeze({
		DefaultCastShadow = false,
		FloorCastShadow = false,
		WallsCastShadow = true,
		CoverCastShadow = true,
		TanksCastShadow = true,
		RuntimeCastShadow = false,
		CharacterCastShadow = false,
	}),
})

return PerformanceConfig
