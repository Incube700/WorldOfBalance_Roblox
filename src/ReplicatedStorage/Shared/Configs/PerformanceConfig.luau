-- Read-only snapshot config. Do not wire without a dedicated task.

local PerformanceConfig = table.freeze({
	Lighting = table.freeze({
		GlobalShadows = false,
		Brightness = 2,
		ClockTime = 14,
		FogEnd = 100000,
		Technology = "Compatibility",
	}),

	BasePart = table.freeze({
		CastShadow = false,
	}),
})

return PerformanceConfig
