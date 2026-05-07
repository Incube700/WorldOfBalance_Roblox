-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates editable spawn marker parts used by WOBGameplayServer.

local Workspace = game:GetService("Workspace")

local root = Workspace:FindFirstChild("WOB_Generated")
if root == nil then
	error("Workspace/WOB_Generated not found")
end

local map = root:FindFirstChild("Map")
if map == nil then
	error("Workspace/WOB_Generated/Map not found")
end

local spawnPoints = map:FindFirstChild("SpawnPoints")
if spawnPoints == nil then
	spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = map
end

local playerPosition = Vector3.new(-42, 0.3, -42)
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
getOrCreateSpawnPart("DummySpawn", dummyPosition, playerPosition, Color3.fromRGB(255, 110, 90))

print("[WOB] Spawn points ready. Move/rotate PlayerSpawn and DummySpawn in Studio, then File -> Save to File.")
