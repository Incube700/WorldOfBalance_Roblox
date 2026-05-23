local DebugCombatConfig = table.freeze({
	ArmorDebug = false,
	ArmorDebugVisuals = false,
	ArmorDebugThrottleSeconds = 0.25,
	ProjectileDebug = false,
	ProjectileRaycastDebug = false,
	DamageLog = false,
	SceneDebugVisuals = false,
	SpawnStartupTestTanks = false,

	-- Menu visibility and gameplay availability are intentionally separate.
	-- Hiding the Arena button from the main menu must NOT disable working
	-- Arena pad / bot gameplay. Only flip EnableArenaPadGameplay to false if a
	-- dev explicitly wants to take the in-world arena flow offline.
	ShowArenaButtonInMainMenu = false,
	EnableArenaPadGameplay = true,
	EnableArenaBots = true,

	-- Warn loudly when the modular HUD is missing. Off by default because the
	-- project intentionally uses the scripted runtime HUD now.
	WarnOnRuntimeHudFallback = false,
})

return DebugCombatConfig
