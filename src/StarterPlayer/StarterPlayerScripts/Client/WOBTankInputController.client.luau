local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local CameraConfig = require(configs:WaitForChild("CameraConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))
local WOBClientInputState = require(script.Parent:WaitForChild("Input"):WaitForChild("WOBClientInputState"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tankInputEvent = remotes:WaitForChild("TankInputEvent")
local shootRequestEvent = remotes:WaitForChild("ShootRequestEvent")

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
root:WaitForChild("TestObjects")
local camera = Workspace.CurrentCamera

local LEGACY_INPUT_CONTROLLER_NAME = "WOBClientController"
local DEBUG_INPUT = false
local sendInterval = CameraConfig.Input.SendInterval or 0.05
local aimPlaneY = CameraConfig.Input.AimPlaneY or 0
local pressedKeys = {}
local elapsedSinceSend = 0
local ownedTank = nil
local loggedOwnedTankId = nil
local stopInputSent = false

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
	return TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
end

local function refreshOwnedTank()
	local nextOwnedTank = getOwnedTank()

	if ownedTank == nextOwnedTank then
		return
	end

	ownedTank = nextOwnedTank

	if DEBUG_INPUT and ownedTank ~= nil then
		local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name

		if loggedOwnedTankId ~= tankId then
			loggedOwnedTankId = tankId
			print("[PVP] local owned tank found: " .. tostring(tankId))
		end
	end
end

local function isOwnedTankControllable(requireShoot)
	if ownedTank == nil or ownedTank.Parent == nil then
		return false
	end

	if ownedTank:GetAttribute("IsDead") == true
		or ownedTank:GetAttribute("IsControllable") == false
	then
		return false
	end

	if requireShoot then
		return ownedTank:GetAttribute("CanShoot") ~= false
	end

	return ownedTank:GetAttribute("CanMove") ~= false
end

local function isInputEnabled()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode == "Lobby" or mode == "QueuedForDuel" or mode == "InMatch" or mode == "InBattleArena" then
		return true
	end

	return mode == nil and root:GetAttribute("GameState") == "Playing"
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

local function chooseStrongerAxis(primary, secondary)
	if math.abs(secondary) > math.abs(primary) then
		return secondary
	end

	return primary
end

local function getCombinedAxis()
	local keyboardThrottle, keyboardSteer = getKeyboardAxis()
	local mobileThrottle, mobileSteer = WOBClientInputState.getMobileMovement()

	return chooseStrongerAxis(keyboardThrottle, mobileThrottle),
		chooseStrongerAxis(keyboardSteer, mobileSteer)
end

local function getForwardAimPosition()
	if ownedTank == nil or ownedTank.Parent == nil then
		return Vector3.new(0, aimPlaneY, -40)
	end

	local muzzlePart = ownedTank:FindFirstChild("ShootPoint", true)
		or ownedTank:FindFirstChild("Barrel", true)
		or ownedTank:FindFirstChild("Body", true)

	if muzzlePart ~= nil and muzzlePart:IsA("BasePart") then
		local flatLook = Vector3.new(muzzlePart.CFrame.LookVector.X, 0, muzzlePart.CFrame.LookVector.Z)

		if flatLook.Magnitude > 0.001 then
			local point = muzzlePart.Position + flatLook.Unit * 60
			return Vector3.new(point.X, aimPlaneY, point.Z)
		end

		return Vector3.new(muzzlePart.Position.X, aimPlaneY, muzzlePart.Position.Z - 60)
	end

	return Vector3.new(0, aimPlaneY, -40)
end

local function getPointerAimPosition()
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

local function getAimPosition()
	if WOBClientInputState.isMobileEnabled() then
		local mobileAimWorldPoint = WOBClientInputState.getMobileAimWorldPoint()

		if typeof(mobileAimWorldPoint) == "Vector3" then
			return mobileAimWorldPoint
		end

		return getForwardAimPosition()
	end

	return getPointerAimPosition()
end

local lastInputLogTime = 0
local lastShootLogTime = 0

local function sendTankInput()
	if not isInputEnabled() then
		if not stopInputSent then
			refreshOwnedTank()

			if ownedTank ~= nil then
				tankInputEvent:FireServer({
					Throttle = 0,
					Steer = 0,
					AimPosition = getAimPosition(),
				})
				stopInputSent = true
			end
		end

		return
	end

	refreshOwnedTank()

	if ownedTank == nil then
		return
	end

	if not isOwnedTankControllable(false) then
		if not stopInputSent then
			tankInputEvent:FireServer({
				Throttle = 0,
				Steer = 0,
				AimPosition = getAimPosition(),
			})
			stopInputSent = true
		end

		return
	end

	local throttle, steer = getCombinedAxis()
	local aimPos = getAimPosition()

	tankInputEvent:FireServer({
		Throttle = throttle,
		Steer = steer,
		AimPosition = aimPos,
	})

	local now = os.clock()
	if DEBUG_INPUT and now - lastInputLogTime > 2 then
		lastInputLogTime = now
		local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
		print(string.format("[INPUT] client sending move for %s: T=%.1f, S=%.1f", tostring(tankId), throttle, steer))
	end

	stopInputSent = throttle == 0 and steer == 0
end

local function sendShootRequest(aimPosition)
	if not isInputEnabled() then
		return
	end

	refreshOwnedTank()

	if ownedTank == nil then
		return
	end

	if not isOwnedTankControllable(true) then
		return
	end

	shootRequestEvent:FireServer(aimPosition)

	local now = os.clock()
	if DEBUG_INPUT and now - lastShootLogTime > 1 then
		lastShootLogTime = now
		local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
		print(string.format("[INPUT] client sending shoot for %s at %s", tostring(tankId), tostring(aimPosition)))
	end
end

local function processMobileShootRequest()
	local hasShootRequest, requestedAimPosition = WOBClientInputState.consumeMobileShootRequest()

	if not hasShootRequest then
		return
	end

	local aimPosition = typeof(requestedAimPosition) == "Vector3" and requestedAimPosition or getAimPosition()
	sendShootRequest(aimPosition)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		pressedKeys[input.KeyCode] = true
	end

	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isInputEnabled() then
		sendShootRequest(getAimPosition())
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		pressedKeys[input.KeyCode] = nil
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	processMobileShootRequest()

	elapsedSinceSend += deltaTime

	if elapsedSinceSend < sendInterval then
		return
	end

	elapsedSinceSend = 0
	sendTankInput()
end)
