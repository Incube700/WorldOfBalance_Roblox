-- Read-only snapshot config. Do not wire without a dedicated task.

local DummyRespawnConfig = table.freeze({
	MaxHealth = 100,
	RespawnDelay = 2.25,

	ResetColors = table.freeze({
		Body = Color3.fromRGB(160, 65, 65),
		Turret = Color3.fromRGB(45, 45, 50),
		Barrel = Color3.fromRGB(30, 30, 35),
		ShootPoint = Color3.fromRGB(255, 230, 80),
		FrontArmor = Color3.fromRGB(80, 180, 255),
		RearArmor = Color3.fromRGB(255, 150, 80),
		LeftArmor = Color3.fromRGB(180, 255, 120),
		RightArmor = Color3.fromRGB(180, 255, 120),
	}),

	AttributeNames = table.freeze({
		Health = "Health",
	}),

	-- TODO: Snapshot reset does not clear projectiles or Runtime/VFX folders.
})

return DummyRespawnConfig
