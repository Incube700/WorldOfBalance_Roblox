-- Read-only snapshot config. Do not wire without a dedicated task.

local CameraConfig = table.freeze({
	TopDown = table.freeze({
		Height = 113,
		FieldOfView = 50,
		LookAtOffset = Vector3.new(0, 0, 0),
		UpVector = Vector3.new(0, 0, -1),
	}),

	Input = table.freeze({
		SendInterval = 0.05,
		AimPlaneY = 0,
	}),
})

return CameraConfig
