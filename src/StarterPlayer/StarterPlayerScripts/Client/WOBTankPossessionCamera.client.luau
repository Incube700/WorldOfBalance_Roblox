local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local CameraConfig = require(configs:WaitForChild("CameraConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
root:WaitForChild("TestObjects")

local topDownConfig = CameraConfig.TopDown
local cameraHeight = topDownConfig.Height or 95
local fieldOfView = topDownConfig.FieldOfView or 42
local lookAtOffset = topDownConfig.LookAtOffset or Vector3.new(0, 0, 0)
local upVector = topDownConfig.UpVector or Vector3.new(0, 0, -1)

local DEBUG_CAMERA = false
local ownedTank = nil
local isFollowing = false
local lastFollowedTankId = nil

local function findOwnedTank()
	return TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
		or TankModelResolver.findOwnedTank(root, localPlayer.UserId, false)
end

local function getTankFocusPart(tank)
	local physicalTank = TankModelResolver.resolvePhysicalModel(root, tank) or tank

	return TankModelResolver.findFocusPart(physicalTank)
end

local function printTankDiagnostics(tank)
	if not tank then return end
	
	print("--- TANK DIAGNOSTICS ---")
	print("FullName: " .. tank:GetFullName())
	print("ClassName: " .. tank.ClassName)
	print("BaseParts: " .. tostring(TankModelResolver.countBaseParts(tank)))
	
	local attrs = {"OwnerUserId", "TankId", "ControllerType", "IsPlayerTank"}
	for _, attr in ipairs(attrs) do
		print("Attribute " .. attr .. ": " .. tostring(tank:GetAttribute(attr)))
	end
	
	print("First 20 descendants:")
	local descendants = tank:GetDescendants()
	for i = 1, math.min(20, #descendants) do
		local d = descendants[i]
		print(string.format("  [%d] %s (%s)", i, d.Name, d.ClassName))
	end
	print("------------------------")
end

local lastErrorTime = 0
local diagnosedTanks = {}

local function isCameraFollowEnabled()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode == "Lobby" or mode == "QueuedForDuel" or mode == "InMatch" then
		return true
	end

	return mode == nil and root:GetAttribute("GameState") == "Playing"
end

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	if not isCameraFollowEnabled() then
		if isFollowing then
			isFollowing = false
			lastFollowedTankId = nil
			if DEBUG_CAMERA then
				print("[PVP] camera follow stopped")
			end
		end
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		-- В других состояниях не форсируем камеру, позволяя работать меню/результатам
		return
	end

	-- В состоянии Playing ищем или обновляем ownedTank
	if not ownedTank or ownedTank.Parent == nil or ownedTank:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		ownedTank = findOwnedTank()
		if ownedTank then
			local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
			if DEBUG_CAMERA then
				print("[PVP] camera owned tank found: " .. tostring(tankId))
			end
		end
	end

	local focusPart = getTankFocusPart(ownedTank)
	if not focusPart then
		if isFollowing then
			isFollowing = false
			lastFollowedTankId = nil
			if DEBUG_CAMERA then
				print("[PVP] camera follow stopped (tank lost)")
			end
		end
		
		-- Добавляем throttled лог ошибки поиска частей
		if ownedTank and os.clock() - lastErrorTime > 5 then
			lastErrorTime = os.clock()
			local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
			print("[PVP] camera cannot follow: no BasePart for " .. tostring(tankId))
			
			if DEBUG_CAMERA and not diagnosedTanks[ownedTank] then
				diagnosedTanks[ownedTank] = true
				printTankDiagnostics(ownedTank)
			end
		end
		
		return
	end

	local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name

	if not isFollowing or lastFollowedTankId ~= tankId then
		isFollowing = true
		lastFollowedTankId = tankId
		print("[PVP] camera follow started: " .. tostring(tankId) .. " part=" .. tostring(focusPart.Name))
	end

	-- Форсируем Scriptable каждый кадр в режиме Playing
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fieldOfView
	
	-- Убеждаемся, что фокус установлен
	camera.CameraSubject = focusPart

	local lookAt = focusPart.Position + lookAtOffset
	local cameraPosition = lookAt + Vector3.new(0, cameraHeight, 0)
	camera.CFrame = CFrame.lookAt(cameraPosition, lookAt, upVector)
end

-- Следим за добавлением потомков, чтобы быстрее найти танк при спавне/ремонте модели
root.DescendantAdded:Connect(function()
	if isCameraFollowEnabled() and not ownedTank then
		ownedTank = findOwnedTank()
	end
end)

RunService:BindToRenderStep(
	"WOBTankPossessionCamera",
	Enum.RenderPriority.Camera.Value + 10,
	updateCamera
)
