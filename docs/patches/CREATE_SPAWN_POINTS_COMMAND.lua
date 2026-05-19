-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates editable spawn marker parts used by WOBGameplayServer.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB SPAWN] Run this command outside Play Mode.")
	return
end

local root = Workspace:FindFirstChild("WOB_Generated")
if root == nil then
	root = Instance.new("Folder")
	root.Name = "WOB_Generated"
	root.Parent = Workspace
	print("[WOB SPAWN] Created " .. root:GetFullName())
else
	print("[WOB SPAWN] Kept existing " .. root:GetFullName())
end

local spawnPoints = root:FindFirstChild("SpawnPoints")
if spawnPoints == nil then
	spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = root
	print("[WOB SPAWN] Created " .. spawnPoints:GetFullName())
else
	print("[WOB SPAWN] Kept existing " .. spawnPoints:GetFullName())
end

local playerPosition = Vector3.new(-42, 0.3, -42)
local player2Position = Vector3.new(42, 0.3, -42)
local dummyPosition = Vector3.new(42, 0.3, 42)

local function getOrCreateSpawnPart(name, position, lookAtPosition, color)
	local part = spawnPoints:FindFirstChild(name)
	local created = false

	if part == nil then
		part = Instance.new("Part")
		part.Name = name
		part.CFrame = CFrame.lookAt(position, lookAtPosition, Vector3.yAxis)
		part.Parent = spawnPoints
		created = true
	elseif not part:IsA("BasePart") then
		warn(name .. " already exists but is not a BasePart")
		return nil
	end

	part.Size = Vector3.new(5, 0.35, 5)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.45
	part.Material = Enum.Material.Neon
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if created then
		print("[WOB] Created " .. part:GetFullName())
	else
		print("[WOB] Updated existing " .. part:GetFullName() .. " without moving it")
	end

	return part
end

getOrCreateSpawnPart("PlayerSpawn", playerPosition, dummyPosition, Color3.fromRGB(80, 255, 120))
getOrCreateSpawnPart("Player2Spawn", player2Position, playerPosition, Color3.fromRGB(255, 100, 100))
getOrCreateSpawnPart("DummySpawn", dummyPosition, playerPosition, Color3.fromRGB(255, 110, 90))

print("[WOB] Spawn points ready at Workspace/WOB_Generated/SpawnPoints. Move/rotate PlayerSpawn, Player2Spawn and DummySpawn in Studio, then File -> Save to File.")
