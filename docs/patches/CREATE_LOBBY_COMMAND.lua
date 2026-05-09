-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates/updates the Lobby / Free Drive v0 scene contract.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB LOBBY] Run this command outside Play Mode.")
	return
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if existing.ClassName ~= className then
			warn("[WOB LOBBY] " .. existing:GetFullName() .. " is " .. existing.ClassName .. ", expected " .. className)
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent

	return instance, true
end

local root = Workspace:FindFirstChild("WOB_Generated")

if root == nil then
	root = Instance.new("Folder")
	root.Name = "WOB_Generated"
	root.Parent = Workspace
	print("[WOB LOBBY] Created " .. root:GetFullName())
else
	print("[WOB LOBBY] Kept existing " .. root:GetFullName())
end

local lobby = getOrCreate(root, "Folder", "Lobby")

if lobby == nil then
	return
end

local floor = getOrCreate(lobby, "Part", "Floor")

if floor ~= nil then
	floor.Size = Vector3.new(210, 1, 170)
	floor.CFrame = CFrame.new(0, -0.55, 155)
	floor.Anchored = true
	floor.CanCollide = true
	floor.CanTouch = false
	floor.CanQuery = false
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(38, 45, 46)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	print("[WOB LOBBY] Floor ready at " .. floor:GetFullName())
end

local spawnPoints = getOrCreate(lobby, "Folder", "SpawnPoints")

if spawnPoints == nil then
	return
end

local lobbySpawnSpecs = {
	{ Name = "LobbySpawn1", Position = Vector3.new(-72, 0.3, 210), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn2", Position = Vector3.new(-48, 0.3, 232), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn3", Position = Vector3.new(-18, 0.3, 238), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn4", Position = Vector3.new(18, 0.3, 238), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn5", Position = Vector3.new(48, 0.3, 232), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn6", Position = Vector3.new(72, 0.3, 210), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn7", Position = Vector3.new(-82, 0.3, 150), LookAt = Vector3.new(0, 0.3, 155) },
	{ Name = "LobbySpawn8", Position = Vector3.new(82, 0.3, 150), LookAt = Vector3.new(0, 0.3, 155) },
}

local function configureSpawn(spec)
	local spawnPart = getOrCreate(spawnPoints, "Part", spec.Name)

	if spawnPart == nil then
		return
	end

	spawnPart.Size = Vector3.new(8, 0.35, 8)
	spawnPart.CFrame = CFrame.lookAt(spec.Position, spec.LookAt, Vector3.yAxis)
	spawnPart.Anchored = true
	spawnPart.CanCollide = false
	spawnPart.CanTouch = false
	spawnPart.CanQuery = false
	spawnPart.Transparency = 0.35
	spawnPart.Material = Enum.Material.Neon
	spawnPart.Color = Color3.fromRGB(72, 190, 255)
	spawnPart.TopSurface = Enum.SurfaceType.Smooth
	spawnPart.BottomSurface = Enum.SurfaceType.Smooth
	print("[WOB LOBBY] Spawn ready: " .. spawnPart:GetFullName())
end

for _, spec in ipairs(lobbySpawnSpecs) do
	configureSpawn(spec)
end

local duelPad = getOrCreate(lobby, "Part", "DuelPad")

if duelPad ~= nil then
	duelPad.Size = Vector3.new(42, 0.45, 30)
	duelPad.CFrame = CFrame.new(0, 0.08, 92)
	duelPad.Anchored = true
	duelPad.CanCollide = false
	duelPad.CanTouch = true
	duelPad.CanQuery = false
	duelPad.Transparency = 0.28
	duelPad.Material = Enum.Material.Neon
	duelPad.Color = Color3.fromRGB(255, 210, 70)
	duelPad.TopSurface = Enum.SurfaceType.Smooth
	duelPad.BottomSurface = Enum.SurfaceType.Smooth
	print("[WOB LOBBY] DuelPad ready at " .. duelPad:GetFullName())
end

print("[WOB LOBBY] Lobby scene ready at Workspace/WOB_Generated/Lobby. Existing arena SpawnPoints were not modified. File -> Save to File.")
