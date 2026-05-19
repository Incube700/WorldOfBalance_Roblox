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

	WorldHealthBars = table.freeze({
		Enabled = true,
		ShowReloadBar = true,
		ShowOwnTank = true,
		HideTopHpPanelsOnMobile = true,
		HideTopHpPanelsInBattleArena = true,
		HideTopHpPanelsInTraining = false,
		HideTopHpPanelsInDuel = false,
		DeadHideDelay = 1.0,
		DiscoveryInterval = 1.0,
		MaxDistance = 180,
	}),

	CombatHud = table.freeze({
		CompactReload = true,
		HideLargeReloadPanelWhenWorldReloadEnabled = true,
		HideEnemyHpPanelWhenWorldBarsEnabled = true,
		HidePlayerHpPanelWhenWorldBarsEnabled = true,
	}),

	DamageFlash = table.freeze({
		Enabled = true,
		Debug = false,
		DiscoveryInterval = 0.5,
		Duration = 0.14,
		LethalDuration = 0.22,
		DepthMode = "Occluded",
		FillTransparencyStart = 0.15,
		FillTransparencyMid = 0.32,
		FillTransparencyEnd = 1,
		ColorStart = Color3.fromRGB(255, 255, 245),
		Color = Color3.fromRGB(255, 245, 180),
	}),
})

return HudConfig
