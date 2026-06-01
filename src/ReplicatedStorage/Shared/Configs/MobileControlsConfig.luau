local MobileControlsConfig = table.freeze({
	Enabled = true,
	ForceEnabledInStudio = false,

	LeftStick = table.freeze({
		Radius = 72,
		BaseSize = 136,
		ThumbSize = 58,
		DeadZone = 0.12,
		MaxDistance = 72,
		Position = UDim2.fromScale(0.18, 0.74),
		Label = "MOVE",
	}),

	AimArea = table.freeze({
		Enabled = true,
		MinXScale = 0.45,
		AimPlaneY = 0,
	}),

	RightAimStick = table.freeze({
		Enabled = true,
		Radius = 82,
		BaseSize = 132,
		ThumbSize = 56,
		DeadZone = 0.08,
		MaxDistance = 82,
		TapMaxDuration = 0.15,
		TapMoveTolerancePixels = 6,
		AutoFireInArena = false,
		Position = UDim2.fromScale(0.78, 0.72),
		Visible = true,
		Label = "AIM",
	}),

	FireButton = table.freeze({
		Size = UDim2.fromOffset(96, 96),
		Position = UDim2.fromScale(0.9, 0.56),
		Label = "FIRE",
		CooldownVisual = true,
	}),

	ReverseButton = table.freeze({
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(1, -85, 1, -128),
		AnchorPoint = Vector2.new(1, 1),
		Label = "REV",
	}),

	SecondaryButton = table.freeze({
		Enabled = false,
	}),

	-- Joystick comfort tuning (applies to BOTH sticks, all modes; desktop unaffected).
	-- VisualScale/TouchAreaScale enlarge the stick circle and the drag range. When
	-- FloatingEnabled is true, touching anywhere in a stick's activation zone snaps that
	-- stick's base under the finger; releasing returns it to its home corner.
	-- TEMPORARILY back to defaults: no floating sticks, original size. Restores the standard
	-- mobile control feel everywhere while the scheme is reconsidered. Re-enable later by
	-- raising the scales / setting FloatingEnabled = true (code is unchanged).
	Joystick = table.freeze({
		VisualScale = 1, -- original stick size
		TouchAreaScale = 1, -- original drag range
		FloatingEnabled = false, -- fixed-position sticks (classic)
		-- Ignore touches above this fraction of the screen height when picking up a floating
		-- stick, so the top HUD / upgrade cards are never hijacked.
		FloatingActivationMinYScale = 0.32,
	}),

	-- BattleArena-only arcade mobile control preset (arcade arena pass).
	-- Left side steers FORWARD (tank body turns toward the drag and drives forward);
	-- right side steers REVERSE (body rotates toward the drag while backing away). The
	-- separate FIRE button always shoots along the tank BODY forward vector -- there is no
	-- turret and no auto-aim, so manual body aim wins (you can aim at a wall to ricochet).
	-- These settings ONLY take effect while PlayerMode == "InBattleArena". When
	-- DuelUsesClassicControls is true, Duel/PvP keeps the classic Move + Aim-stick + REV
	-- button scheme unchanged. Lobby is always unchanged.
	-- TEMPORARILY DISABLED: arcade preset is off so BattleArena uses the same classic mobile
	-- controls as everywhere else, while the control scheme is being reconsidered. Flip
	-- Enabled back to true to re-activate the BattleArena arcade preset (code is unchanged).
	BattleArenaArcade = table.freeze({
		Enabled = false, -- BattleArenaArcadeMobileControlsEnabled
		ForwardIndicatorEnabled = true, -- green forward arrow
		ReverseIndicatorEnabled = true, -- red reverse arrow
		DuelUsesClassicControls = true, -- leave Duel/PvP controls untouched
		ReverseStraightThrottle = 1, -- straight-back throttle when reverse touched without a drag direction
	}),

	Debug = false,
})

return MobileControlsConfig
