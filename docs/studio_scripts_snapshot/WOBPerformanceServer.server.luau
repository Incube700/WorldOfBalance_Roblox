local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local root = Workspace:WaitForChild("WOB_Generated")

local function applyLightingProfile()
	Lighting.GlobalShadows = false
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000

	pcall(function()
		Lighting.Technology = Enum.Technology.Compatibility
	end)
end

local function optimizePart(part)
	if not part:IsA("BasePart") then
		return
	end

	part.CastShadow = false
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
