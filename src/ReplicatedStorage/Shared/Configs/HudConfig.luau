-- Read-only snapshot config. Do not wire without a dedicated task.

local HudConfig = table.freeze({
	DummyHealth = table.freeze({
		MaxHealthDisplay = 100,
		LabelPrefix = "Dummy HP: ",
		Separator = " / ",
		-- TODO: This display value mirrors DummyRespawnConfig.MaxHealth but is not wired yet.
	}),

	Reload = table.freeze({
		DisplayCooldown = 0.45,
		ReadyText = "Reload: READY",
		Prefix = "Reload: ",
		Suffix = "%",
		-- TODO: This display cooldown mirrors WeaponConfig.PrimaryWeapon.ShootCooldown but is not wired yet.
	}),

	Feedback = table.freeze({
		Time = 0.8,
		Messages = table.freeze({
			HitPrefix = "HIT -",
			Destroyed = "TARGET DESTROYED",
			Reset = "TARGET RESET",
		}),
		Colors = table.freeze({
			Hit = Color3.fromRGB(255, 220, 90),
			Destroyed = Color3.fromRGB(255, 80, 80),
			Reset = Color3.fromRGB(120, 255, 150),
		}),
	}),
})

return HudConfig
