-- Rojo-managed replacement for Studio WOBPerformanceServer.
-- This lives under ServerScriptService/Server/Services to avoid Rojo ownership of the Studio Services folder.
-- Before Play testing this, disable/remove the old Studio-owned ServerScriptService/Services/WOBPerformanceServer.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerformanceConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("PerformanceConfig")
)

local root = Workspace:WaitForChild("WOB_Generated")
local map = root:FindFirstChild("Map")
local runtime = root:FindFirstChild("Runtime")
local testObjects = root:FindFirstChild("TestObjects")
local activeProfileName = tostring(PerformanceConfig.ActiveProfile or "Default")

local function getActiveProfile()
	local profiles = PerformanceConfig.Profiles

	if typeof(profiles) == "table" then
		local profile = profiles[activeProfileName]

		if typeof(profile) == "table" then
			return profile
		end
	end

	return PerformanceConfig
end

local activeProfile = getActiveProfile()

local function getLightingConfig()
	return activeProfile.Lighting or PerformanceConfig.Lighting
end

local function getBasePartConfig()
	return activeProfile.BasePart or PerformanceConfig.BasePart
end

local function applyLightingProfile()
	local lightingConfig = getLightingConfig()

	Lighting.GlobalShadows = lightingConfig.ShadowsEnabled == true and lightingConfig.GlobalShadows ~= false
	Lighting.Brightness = lightingConfig.Brightness
	Lighting.ClockTime = lightingConfig.ClockTime
	Lighting.FogEnd = lightingConfig.FogEnd

	pcall(function()
		if lightingConfig.Technology == "Compatibility" then
			Lighting.Technology = Enum.Technology.Compatibility
		end
	end)
end

local function isFloorPart(part)
	local lowerName = string.lower(part.Name)

	return lowerName == "arenafloor"
		or lowerName == "floor"
		or string.find(lowerName, "floor") ~= nil
end

local function isWallPart(part)
	if map == nil then
		map = root:FindFirstChild("Map")
	end

	local ricochetWalls = map ~= nil and map:FindFirstChild("RicochetWalls") or nil

	return string.match(part.Name, "^Wall_") ~= nil
		or string.match(part.Name, "^RicochetWall_") ~= nil
		or (ricochetWalls ~= nil and part:IsDescendantOf(ricochetWalls))
end

local function isCoverPart(part)
	if map == nil then
		map = root:FindFirstChild("Map")
	end

	local cover = map ~= nil and map:FindFirstChild("Cover") or nil

	return string.match(part.Name, "^Cover_Block_") ~= nil
		or (cover ~= nil and part:IsDescendantOf(cover))
end

local function isTankPart(part)
	if testObjects == nil then
		testObjects = root:FindFirstChild("TestObjects")
	end

	if testObjects == nil then
		return false
	end

	local playerTank = testObjects:FindFirstChild("PlayerTankPrototype")
	local dummyTank = testObjects:FindFirstChild("DummyTank")

	return (playerTank ~= nil and part:IsDescendantOf(playerTank))
		or (dummyTank ~= nil and part:IsDescendantOf(dummyTank))
end

local function shouldCastShadow(part)
	local shadowConfig = getBasePartConfig()
	local lightingConfig = getLightingConfig()

	if lightingConfig.ShadowsEnabled ~= true then
		return false
	end

	if runtime ~= nil and part:IsDescendantOf(runtime) then
		return shadowConfig.RuntimeCastShadow == true
	end

	if isFloorPart(part) then
		return shadowConfig.FloorCastShadow == true
	end

	if isWallPart(part) then
		return shadowConfig.WallsCastShadow == true
	end

	if isCoverPart(part) then
		return shadowConfig.CoverCastShadow == true
	end

	if isTankPart(part) then
		return shadowConfig.TanksCastShadow == true
	end

	return shadowConfig.DefaultCastShadow == true
end

local function applyShadowProfile(part)
	if not part:IsA("BasePart") then
		return
	end

	part.CastShadow = shouldCastShadow(part)
end

local function optimizeModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		applyShadowProfile(descendant)
	end
end

local function optimizeCharacter(character)
	local shadowConfig = getBasePartConfig()

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CastShadow = shadowConfig.CharacterCastShadow == true
		end
	end
end

applyLightingProfile()
optimizeModel(root)

root.DescendantAdded:Connect(function(descendant)
	applyShadowProfile(descendant)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(optimizeCharacter)

	if player.Character ~= nil then
		optimizeCharacter(player.Character)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character ~= nil then
		optimizeCharacter(player.Character)
	end
end

print("[WOB] Performance profile applied: " .. activeProfileName)
