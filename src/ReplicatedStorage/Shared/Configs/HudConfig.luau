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
		HideTopHpPanelsInTraining = true,
		HideTopHpPanelsInDuel = true,
		DeadHideDelay = 1.0,
		DiscoveryInterval = 1.0,
		MaxDistance = 120,
		-- Client-only visual smoothing for world-space HP/reload bar position.
		-- Uses a lerp toward the raw tank body position each Heartbeat so bars
		-- don't jitter when server-replicated parts update at network tick rate.
		-- Does not affect health values, damage, or any server state.
		SmoothingEnabled = true,
		PositionSmoothingSpeed = 18,
	}),

	CombatHud = table.freeze({
		CompactReload = true,
		HideLargeReloadPanelWhenWorldReloadEnabled = true,
		HideEnemyHpPanelWhenWorldBarsEnabled = true,
		HidePlayerHpPanelWhenWorldBarsEnabled = true,
		UseScriptedDuelHud = true,
		UseScriptedTrainingHud = true,
		-- Compact layout for Training: hides duplicate reload panel, bolts panel,
		-- top player/enemy HP panels, and long hint text. World bars under tanks
		-- remain active. Duel HUD is unaffected.
		TrainingCompactHud = true,
	}),

	DuelMobileScorePanel = table.freeze({
		Enabled = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(260, 46),
		TextSize = 12,
		BackgroundTransparency = 0.16,
		CornerRadius = 6,
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

	-- Presentation-only HUD layout presets per mode/device. These hold ONLY
	-- display values (anchor/position/size/text size/transparency/visibility).
	-- They must never own gameplay rules (damage, cooldowns, scoring, economy).
	-- Consumed by the overlay layout appliers; see WOBBattleArenaOverlay.
	Layouts = table.freeze({
		BattleArena = table.freeze({
			Desktop = table.freeze({
				HealthPanel = table.freeze({
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(0, 18, 0, 18),
					Size = UDim2.new(0, 260, 0, 78),
					BackgroundTransparency = 0.1,
				}),
				HealthLabel = table.freeze({
					Position = UDim2.new(0, 14, 0, 8),
					Size = UDim2.new(1, -28, 0, 28),
					TextSize = 18,
					Compact = false,
				}),
				HealthBar = table.freeze({
					Position = UDim2.new(0, 14, 0, 46),
					Size = UDim2.new(1, -28, 0, 14),
				}),
				ScorePanel = table.freeze({
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(1, -272, 0, 18),
					Size = UDim2.new(0, 250, 0, 154),
					BackgroundTransparency = 0.1,
				}),
				ScoreLabel = table.freeze({
					Position = UDim2.new(0, 14, 0, 8),
					Size = UDim2.new(1, -28, 0, 28),
					TextSize = 18,
					Compact = false,
				}),
				KillsDeathsLabel = table.freeze({
					Position = UDim2.new(0, 14, 0, 36),
					Size = UDim2.new(1, -28, 0, 24),
					TextSize = 16,
					Compact = false,
				}),
				StreakLabel = table.freeze({
					Position = UDim2.new(0, 14, 0, 62),
					Size = UDim2.new(1, -28, 0, 22),
					TextSize = 14,
					Compact = false,
				}),
				UpgradesLabel = table.freeze({
					Position = UDim2.new(0, 14, 0, 86),
					Size = UDim2.new(1, -28, 0, 34),
					TextSize = 14,
					Compact = false,
					Visible = true,
				}),
				SessionLabel = table.freeze({
					Position = UDim2.new(0, 14, 0, 120),
					Size = UDim2.new(1, -28, 0, 22),
					TextSize = 13,
					Compact = true,
					Visible = true,
				}),
				ReturnButton = table.freeze({
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -22, 1, -22),
					Size = UDim2.fromOffset(154, 42),
					Text = "Return to Lobby",
					TextSize = 16,
					Visible = true,
				}),
				MenuButtonVisible = false,
				DeathPanel = table.freeze({
					Position = UDim2.new(0.5, -150, 0.5, -92),
					Size = UDim2.new(0, 300, 0, 184),
				}),
				DestroyedLabel = table.freeze({
					Position = UDim2.new(0, 18, 0, 18),
					Size = UDim2.new(1, -36, 0, 44),
					TextSize = 30,
				}),
				RespawnLabel = table.freeze({
					Position = UDim2.new(0, 18, 0, 68),
					Size = UDim2.new(1, -36, 0, 30),
					TextSize = 20,
				}),
				DeathSummaryLabel = table.freeze({
					Position = UDim2.new(0, 18, 0, 100),
					Size = UDim2.new(1, -36, 0, 24),
					TextSize = 14,
				}),
				DeathReturnButton = table.freeze({
					Position = UDim2.new(0.18, 0, 1, -52),
					Size = UDim2.new(0.64, 0, 0, 38),
				}),
			}),
			Mobile = table.freeze({
				-- Layout anchors / responsive bounds. The overlay keeps the
				-- viewport-driven width math; these are its constant inputs.
				TopY = 18,
				SideInset = 12,
				MenuButtonWidth = 68,
				ScoreWidthCompactMin = 188,
				ScoreWidthCompactMax = 270,
				ScoreWidthFullMin = 220,
				ScoreWidthFullMax = 300,
				ShowBoltsMinWidth = 224,
				ScoreContentInset = 20,
				ScoreColumnGap = 6,
				HealthPanel = table.freeze({
					AnchorPoint = Vector2.new(0, 0),
					OffsetY = 78,
					MaxWidth = 180,
					Height = 54,
					BackgroundTransparency = 0.32,
				}),
				HealthLabel = table.freeze({
					Position = UDim2.new(0, 10, 0, 4),
					Size = UDim2.new(1, -20, 0, 24),
					TextSize = 14,
				}),
				HealthBar = table.freeze({
					Position = UDim2.new(0, 10, 0, 36),
					Size = UDim2.new(1, -20, 0, 6),
				}),
				ScorePanel = table.freeze({
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 0.32,
					HeightWithBolts = 48,
					HeightWithoutBolts = 44,
				}),
				ScoreLabel = table.freeze({
					OffsetX = 10,
					OffsetY = 3,
					Height = 18,
					TextSize = 12,
				}),
				KillsDeathsLabel = table.freeze({
					ColumnGapInset = 16,
					OffsetY = 3,
					Height = 18,
					TextSize = 12,
				}),
				StreakLabel = table.freeze({
					OffsetX = 10,
					OffsetY = 23,
					Height = 18,
					TextSize = 12,
				}),
				UpgradesLabel = table.freeze({
					ColumnGapInset = 16,
					OffsetY = 23,
					Height = 18,
					TextSize = 12,
				}),
				MenuButton = table.freeze({
					AnchorPoint = Vector2.new(1, 0),
					Height = 34,
					Text = "Menu",
					TextSize = 13,
				}),
				DeathPanel = table.freeze({
					Position = UDim2.new(0.5, -130, 0.5, -78),
					Size = UDim2.new(0, 260, 0, 156),
				}),
				DestroyedLabel = table.freeze({
					Position = UDim2.new(0, 16, 0, 14),
					Size = UDim2.new(1, -32, 0, 38),
					TextSize = 24,
				}),
				RespawnLabel = table.freeze({
					Position = UDim2.new(0, 16, 0, 58),
					Size = UDim2.new(1, -32, 0, 28),
					TextSize = 17,
				}),
				DeathSummaryLabel = table.freeze({
					Position = UDim2.new(0, 16, 0, 86),
					Size = UDim2.new(1, -32, 0, 22),
					TextSize = 12,
				}),
				DeathReturnButton = table.freeze({
					Position = UDim2.new(0.15, 0, 1, -42),
					Size = UDim2.new(0.7, 0, 0, 32),
				}),
			}),
		}),
	}),
})

return HudConfig
