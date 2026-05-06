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

local function applyLightingProfile()
	local lightingConfig = PerformanceConfig.Lighting

	Lighting.GlobalShadows = lightingConfig.GlobalShadows
	Lighting.Brightness = lightingConfig.Brightness
	Lighting.ClockTime = lightingConfig.ClockTime
	Lighting.FogEnd = lightingConfig.FogEnd

	pcall(function()
		if lightingConfig.Technology == "Compatibility" then
			Lighting.Technology = Enum.Technology.Compatibility
		end
	end)
end

local function optimizePart(part)
	if not part:IsA("BasePart") then
		return
	end

	part.CastShadow = PerformanceConfig.BasePart.CastShadow
end

local function optimizeModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		optimizePart(descendant)
	end
end

local function optimizeCharacter(character)
	optimizeModel(character)
end

applyLightingProfile()
optimizeModel(root)

root.DescendantAdded:Connect(function(descendant)
	optimizePart(descendant)
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

print("[WOB] Performance profile applied: shadows disabled, generated parts optimized.")
