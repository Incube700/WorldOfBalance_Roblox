local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tankInputEvent = remotes:WaitForChild("TankInputEvent")
local shootRequestEvent = remotes:WaitForChild("ShootRequestEvent")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local playerTank = testObjects:WaitForChild("PlayerTankPrototype")
local tankBody = playerTank:WaitForChild("Body")

local CAMERA_HEIGHT = 95
local CAMERA_FIELD_OF_VIEW = 42
local INPUT_SEND_INTERVAL = 0.05

local keys = {
	W = false,
	A = false,
	S = false,
	D = false,
}

local sendTimer = 0

local function getThrottle()
	local throttle = 0

	if keys.W then
		throttle += 1
	end

	if keys.S then
		throttle -= 1
	end

	return throttle
end

local function getSteer()
	local steer = 0

	if keys.A then
		steer -= 1
	end

	if keys.D then
		steer += 1
	end

	return steer
end

local function getMouseWorldPosition()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	if math.abs(ray.Direction.Y) < 0.001 then
		return tankBody.Position + Vector3.new(0, 0, -20)
	end

	local distanceToGround = (0 - ray.Origin.Y) / ray.Direction.Y
	local worldPosition = ray.Origin + ray.Direction * distanceToGround

	return Vector3.new(worldPosition.X, 0, worldPosition.Z)
end

local function updateCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FIELD_OF_VIEW

	local targetPosition = tankBody.Position
	local cameraPosition = targetPosition + Vector3.new(0, CAMERA_HEIGHT, 0)

	camera.CFrame = CFrame.lookAt(
		cameraPosition,
		targetPosition,
		Vector3.new(0, 0, -1)
	)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.W then
		keys.W = true
	elseif input.KeyCode == Enum.KeyCode.A then
		keys.A = true
	elseif input.KeyCode == Enum.KeyCode.S then
		keys.S = true
	elseif input.KeyCode == Enum.KeyCode.D then
		keys.D = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		shootRequestEvent:FireServer(getMouseWorldPosition())
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then
		keys.W = false
	elseif input.KeyCode == Enum.KeyCode.A then
		keys.A = false
	elseif input.KeyCode == Enum.KeyCode.S then
		keys.S = false
	elseif input.KeyCode == Enum.KeyCode.D then
		keys.D = false
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	updateCamera()

	sendTimer += deltaTime

	if sendTimer >= INPUT_SEND_INTERVAL then
		sendTimer = 0

		tankInputEvent:FireServer({
			Throttle = getThrottle(),
			Steer = getSteer(),
			AimPosition = getMouseWorldPosition(),
		})
	end
end)

print("[WOB] Client controller started")
