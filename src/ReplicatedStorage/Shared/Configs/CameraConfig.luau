-- Read-only snapshot config. Do not wire without a dedicated task.

local CameraConfig = table.freeze({
	TopDown = table.freeze({
		Height = 113,
		FieldOfView = 50,
		LookAtOffset = Vector3.new(0, 0, 0),
		UpVector = Vector3.new(0, 0, -1),
	}),

	-- BattleArena-only higher camera (arcade arena pass). Applied by
	-- WOBTankPossessionCamera ONLY when PlayerMode == "InBattleArena" and
	-- HigherCameraEnabled == true. Duel/PvP, Training, and Lobby keep TopDown unchanged.
	-- Height is derived as TopDown.Height * HeightMultiplier so it tracks the base preset.
	BattleArena = table.freeze({
		HigherCameraEnabled = true,
		HeightMultiplier = 1.3, -- 113 -> ~147 studs (+30%): more arena visible, tanks slightly smaller.
		FieldOfView = 53, -- small widen from 50 for extra visibility; still readable.
		LookAtOffset = Vector3.new(0, 0, 0),
		UpVector = Vector3.new(0, 0, -1),
	}),

	Input = table.freeze({
		SendInterval = 0.05,
		AimPlaneY = 0,
	}),
})

return CameraConfig
