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

	Debug = false,
})

return MobileControlsConfig
