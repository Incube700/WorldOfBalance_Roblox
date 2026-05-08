local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local CameraConfig = require(configs:WaitForChild("CameraConfig"))

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")

local topDownConfig = CameraConfig.TopDown
local cameraHeight = topDownConfig.Height or 95
local fieldOfView = topDownConfig.FieldOfView or 42
local lookAtOffset = topDownConfig.LookAtOffset or Vector3.new(0, 0, 0)
local upVector = topDownConfig.UpVector or Vector3.new(0, 0, -1)

local ownedTank = nil
local isFollowing = false
local lastFollowedTankId = nil

local function findOwnedTank()
	for _, child in ipairs(testObjects:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == localPlayer.UserId then
			return child
		end
	end
	return nil
end

local function getTankFocusPart(tank)
	if not tank then
		return nil
	end
	
	-- Если tank сам является BasePart, возвращаем его
	if tank:IsA("BasePart") then
		return tank
	end
	
	-- Сначала ищем PrimaryPart
	if tank:IsA("Model") and tank.PrimaryPart then
		return tank.PrimaryPart
	end
	
	-- Затем ищем Body, Hull или Root (могут быть глубоко)
	local possibleNames = {"Body", "Hull", "Root"}
	for _, name in ipairs(possibleNames) do
		local part = tank:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	
	-- Затем любой BasePart
	for _, descendant in ipairs(tank:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	
	-- Если всё еще не нашли, пробуем найти физическую модель в TestObjects по TankId
	local tankId = tank:GetAttribute("TankId")
	if tankId and tank.Parent ~= testObjects then
		local physicalModel = testObjects:FindFirstChild(tostring(tankId))
		if physicalModel and physicalModel ~= tank then
			return getTankFocusPart(physicalModel)
		end
	end
	
	return nil
end

local function printTankDiagnostics(tank)
	if not tank then return end
	
	print("--- TANK DIAGNOSTICS ---")
	print("FullName: " .. tank:GetFullName())
	print("ClassName: " .. tank.ClassName)
	
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

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local gameState = root:GetAttribute("GameState")

	if gameState ~= "Playing" then
		if isFollowing then
			isFollowing = false
			lastFollowedTankId = nil
			print("[PVP] camera follow stopped")
		end
		-- В других состояниях не форсируем камеру, позволяя работать меню/результатам
		return
	end

	-- В состоянии Playing ищем или обновляем ownedTank
	if not ownedTank or ownedTank.Parent ~= testObjects then
		ownedTank = findOwnedTank()
		if ownedTank then
			local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
			print("[PVP] camera owned tank found: " .. tostring(tankId))
		end
	end

	local focusPart = getTankFocusPart(ownedTank)
	if not focusPart then
		if isFollowing then
			isFollowing = false
			lastFollowedTankId = nil
			print("[PVP] camera follow stopped (tank lost)")
		end
		
		-- Добавляем throttled лог ошибки поиска частей
		if ownedTank and os.clock() - lastErrorTime > 5 then
			lastErrorTime = os.clock()
			local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name
			print("[PVP] camera cannot follow: no BasePart for " .. tostring(tankId))
			
			if not diagnosedTanks[ownedTank] then
				diagnosedTanks[ownedTank] = true
				printTankDiagnostics(ownedTank)
			end
		end
		
		return
	end

	local tankId = ownedTank:GetAttribute("TankId") or ownedTank.Name

	if not isFollowing then
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

-- Следим за добавлением детей, чтобы быстрее найти танк при спавне
testObjects.ChildAdded:Connect(function()
	if root:GetAttribute("GameState") == "Playing" and not ownedTank then
		ownedTank = findOwnedTank()
	end
end)

RunService:BindToRenderStep(
	"WOBTankPossessionCamera",
	Enum.RenderPriority.Camera.Value + 10,
	updateCamera
)
