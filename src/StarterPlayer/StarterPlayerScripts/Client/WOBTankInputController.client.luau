local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local CameraConfig = require(configs:WaitForChild("CameraConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tankInputEvent = remotes:WaitForChild("TankInputEvent")
local shootRequestEvent = remotes:WaitForChild("ShootRequestEvent")

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local camera = Workspace.CurrentCamera

local LEGACY_INPUT_CONTROLLER_NAME = "WOBClientController"
local sendInterval = CameraConfig.Input.SendInterval or 0.05
local aimPlaneY = CameraConfig.Input.AimPlaneY or 0
local pressedKeys = {}
local elapsedSinceSend = 0
local ownedTank = nil
local loggedOwnedTankId = nil

local function disableLegacyInputController(instance)
	if instance == nil then
		return
	end

	if instance == script then
		return
	end

	if instance.Name ~= LEGACY_INPUT_CONTROLLER_NAME or not instance:IsA("LocalScript") then
		return
	end

	if instance.Enabled ~= false then
		instance.Enabled = false
		print("[PVP] legacy input controller disabled: " .. instance.Name)
	end
end

local function getPlayerScriptsRoot()
	local current = script.Parent

	while current ~= nil and current.Name ~= "PlayerScripts" do
		current = current.Parent
	end

	return current
end

local function disableLegacyInputControllers()
	local parent = getPlayerScriptsRoot() or script.Parent

	if parent == nil then
		return
	end

	disableLegacyInputController(parent:FindFirstChild(LEGACY_INPUT_CONTROLLER_NAME))

	for _, descendant in ipairs(parent:GetDescendants()) do
		disableLegacyInputController(descendant)
	end
end

disableLegacyInputControllers()

local playerScriptsRoot = getPlayerScriptsRoot() or script.Parent

if playerScriptsRoot ~= nil then
	playerScriptsRoot.DescendantAdded:Connect(disableLegacyInputController)
end

local function getOwnedTank()
	for _, child in ipairs(testObjects:GetChildren()) do
		if child:IsA("Model")
			and child:GetAttribute("IsPlayerTank") == true
			and child:GetAttribute("OwnerUserId") == localPlayer.UserId
		then
			return child
		end
	end

	return nil
end

local function refreshOwnedTank()
	local nextOwnedTank = getOwnedTank()

	if ownedTank == nextOwnedTank then
		return
	end

	ownedTank = nextOwnedTank

	if ownedTank ~= nil then
		local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name

		if loggedOwnedTankId ~= tankId then
			loggedOwnedTankId = tankId
			print("[PVP] local owned tank found: " .. tostring(tankId))
		end
	end
end

local function isPlaying()
	return root:GetAttribute("GameState") == "Playing"
end

local function getKeyboardAxis()
	local throttle = 0
	local steer = 0

	if pressedKeys[Enum.KeyCode.W] or pressedKeys[Enum.KeyCode.Up] then
		throttle += 1
	end

	if pressedKeys[Enum.KeyCode.S] or pressedKeys[Enum.KeyCode.Down] then
		throttle -= 1
	end

	if pressedKeys[Enum.KeyCode.A] or pressedKeys[Enum.KeyCode.Left] then
		steer -= 1
	end

	if pressedKeys[Enum.KeyCode.D] or pressedKeys[Enum.KeyCode.Right] then
		steer += 1
	end

	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
end

local function getAimPosition()
	if camera == nil or camera.Parent == nil then
		camera = Workspace.CurrentCamera

		if camera == nil then
			return Vector3.new(0, aimPlaneY, 0)
		end
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	if math.abs(ray.Direction.Y) < 0.001 then
		return ray.Origin + ray.Direction * 100
	end

	local distance = (aimPlaneY - ray.Origin.Y) / ray.Direction.Y

	if distance < 0 then
		distance = 100
	end

	local point = ray.Origin + ray.Direction * distance

	return Vector3.new(point.X, aimPlaneY, point.Z)
end

local lastInputLogTime = 0
local lastShootLogTime = 0

local function sendTankInput()
	if not isPlaying() then
		return
	end

	refreshOwnedTank()

	if ownedTank == nil then
		return
	end

	local throttle, steer = getKeyboardAxis()
	local aimPos = getAimPosition()

	tankInputEvent:FireServer({
		Throttle = throttle,
		Steer = steer,
		AimPosition = aimPos,
	})

	local now = os.clock()
	if now - lastInputLogTime > 2 then
		lastInputLogTime = now
		local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
		print(string.format("[INPUT] client sending move for %s: T=%.1f, S=%.1f", tostring(tankId), throttle, steer))
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		pressedKeys[input.KeyCode] = true
	end

	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isPlaying() then
		refreshOwnedTank()

		if ownedTank == nil then
			return
		end

		local aimPos = getAimPosition()
		shootRequestEvent:FireServer(aimPos)

		local now = os.clock()
		if now - lastShootLogTime > 1 then
			lastShootLogTime = now
			local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
			print(string.format("[INPUT] client sending shoot for %s at %s", tostring(tankId), tostring(aimPos)))
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		pressedKeys[input.KeyCode] = nil
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	elapsedSinceSend += deltaTime

	if elapsedSinceSend < sendInterval then
		return
	end

	elapsedSinceSend = 0
	sendTankInput()
end)
