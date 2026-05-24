-- Shared performance config used by WOBPerformanceServer.

local PerformanceConfig = table.freeze({
	ActiveProfile = "MobileLow",

	Lighting = table.freeze({
		ShadowsEnabled = false,
		GlobalShadows = false,
		Brightness = 2,
		ClockTime = 14,
		FogEnd = 100000,
		Technology = "Compatibility",
	}),

	BasePart = table.freeze({
		DefaultCastShadow = false,
		FloorCastShadow = false,
		WallsCastShadow = false,
		CoverCastShadow = false,
		TanksCastShadow = false,
		RuntimeCastShadow = false,
		CharacterCastShadow = false,
	}),

	-- Diagnostic isolation switches. Defaults preserve normal gameplay/presentation behavior.
	Diagnostics = table.freeze({
		WorldHealthBarsEnabledOverride = nil,
		ProjectileVfxEnabled = true,
		MuzzleFlashEnabled = true,
		ImpactVfxEnabled = true,
		DamageFlashEnabled = true,
		FloatingCombatTextEnabled = true,
		BattleArenaBotsEnabled = true,
		BattleArenaMaxBotsOverride = nil,
		DebugRuntimeLogs = false,
	}),

	Profiles = table.freeze({
		MobileLow = table.freeze({
			Lighting = table.freeze({
				ShadowsEnabled = false,
				GlobalShadows = false,
				Brightness = 2,
				ClockTime = 14,
				FogEnd = 100000,
				Technology = "Compatibility",
			}),

			BasePart = table.freeze({
				DefaultCastShadow = false,
				FloorCastShadow = false,
				WallsCastShadow = false,
				CoverCastShadow = false,
				TanksCastShadow = false,
				RuntimeCastShadow = false,
				CharacterCastShadow = false,
			}),
		}),

		Balanced = table.freeze({
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
		}),
	}),
})

return PerformanceConfig
