local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local utils = shared:WaitForChild("Utils")
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")

local FRIENDLY_BODY_COLOR = Color3.fromRGB(55, 185, 255)
local FRIENDLY_TURRET_COLOR = Color3.fromRGB(80, 220, 160)
local ENEMY_BODY_COLOR = Color3.fromRGB(230, 65, 70)
local ENEMY_TURRET_COLOR = Color3.fromRGB(255, 105, 80)
local DEAD_COLOR = Color3.fromRGB(30, 30, 30)
local DEBUG_VISUALS = false

local VISUAL_PART_NAMES = {
	Body = true,
	Turret = true,
	Barrel = true,
}

local ARMOR_HITBOX_NAMES = {
	FrontArmor = true,
	RearArmor = true,
	LeftArmor = true,
	RightArmor = true,
}

local loggedOwnedTankId = nil
local elapsedSinceRefresh = 0

local function isVisualTankModel(model)
	if not model:IsA("Model") then
		return false
	end

	return model:GetAttribute("IsPlayerTank") == true or model.Name == "DummyTank"
end

local function getTankColors(model)
	if model:GetAttribute("IsDead") == true then
		return DEAD_COLOR, DEAD_COLOR
	end

	if model:GetAttribute("IsPlayerTank") == true
		and model:GetAttribute("OwnerUserId") == localPlayer.UserId
	then
		local tankId = model:GetAttribute("TankId") or model.Name

		if DEBUG_VISUALS and loggedOwnedTankId ~= tankId then
			loggedOwnedTankId = tankId
			print("[PVP] local owned tank found: " .. tostring(tankId))
		end

		return FRIENDLY_BODY_COLOR, FRIENDLY_TURRET_COLOR
	end

	return ENEMY_BODY_COLOR, ENEMY_TURRET_COLOR
end

local function colorTank(model)
	if not isVisualTankModel(model) then
		return
	end

	local bodyColor, turretColor = getTankColors(model)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart")
			and VISUAL_PART_NAMES[descendant.Name] == true
			and ARMOR_HITBOX_NAMES[descendant.Name] ~= true
		then
			if descendant.Name == "Body" then
				descendant.Color = bodyColor
			else
				descendant.Color = turretColor
			end
		end
	end
end

local function colorAllTanks()
	local colored = {}

	for _, descendant in ipairs(testObjects:GetDescendants()) do
		if descendant:IsA("Model") then
			local tankModel = TankModelResolver.resolvePhysicalModel(root, descendant) or descendant

			if colored[tankModel] ~= true then
				colored[tankModel] = true
				colorTank(tankModel)
			end
		end
	end
end

root.DescendantAdded:Connect(function(child)
	if child:IsA("Model") then
		child:GetAttributeChangedSignal("OwnerUserId"):Connect(colorAllTanks)
		child:GetAttributeChangedSignal("IsActive"):Connect(colorAllTanks)
		child:GetAttributeChangedSignal("IsDead"):Connect(colorAllTanks)
	end

	colorAllTanks()
end)

for _, child in ipairs(testObjects:GetDescendants()) do
	if child:IsA("Model") then
		child:GetAttributeChangedSignal("OwnerUserId"):Connect(colorAllTanks)
		child:GetAttributeChangedSignal("IsActive"):Connect(colorAllTanks)
		child:GetAttributeChangedSignal("IsDead"):Connect(colorAllTanks)
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	elapsedSinceRefresh += deltaTime

	if elapsedSinceRefresh < 0.25 then
		return
	end

	elapsedSinceRefresh = 0
	colorAllTanks()
end)

colorAllTanks()
