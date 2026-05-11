-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates/updates the Lobby / Free Drive v0 scene contract.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB LOBBY] Run this command outside Play Mode.")
	return
end

local LOBBY_CENTER = Vector3.new(0, 45, 155)
local LOBBY_SIZE = Vector3.new(230, 2, 190)
local LOBBY_SURFACE_Y = LOBBY_CENTER.Y + LOBBY_SIZE.Y * 0.5
local LOBBY_SPAWN_Y = LOBBY_SURFACE_Y + 0.35
local DUEL_PAD_Y = LOBBY_SURFACE_Y + 0.12
local RAILING_Y = LOBBY_SURFACE_Y + 3.2

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

local function configurePart(part, size, cframe, color, transparency, material, canCollide, canTouch, canQuery)
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanTouch = canTouch
	part.CanQuery = canQuery
	part.Transparency = transparency
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
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

lobby:SetAttribute("LobbyCenterY", LOBBY_CENTER.Y)
lobby:SetAttribute("LobbySurfaceY", LOBBY_SURFACE_Y)
lobby:SetAttribute("LobbySpawnY", LOBBY_SPAWN_Y)

local floor = getOrCreate(lobby, "Part", "Floor")

if floor ~= nil then
	configurePart(
		floor,
		LOBBY_SIZE,
		CFrame.new(LOBBY_CENTER),
		Color3.fromRGB(70, 110, 120),
		0.42,
		Enum.Material.Glass,
		true,
		false,
		true
	)
	print("[WOB LOBBY] Elevated transparent Floor ready at " .. floor:GetFullName())
end

local railings = getOrCreate(lobby, "Folder", "Railings")

if railings ~= nil then
	local halfX = LOBBY_SIZE.X * 0.5
	local halfZ = LOBBY_SIZE.Z * 0.5
	local railingSpecs = {
		{
			Name = "LobbyRailing_North",
			Size = Vector3.new(LOBBY_SIZE.X + 8, 6, 4),
			CFrame = CFrame.new(LOBBY_CENTER.X, RAILING_Y, LOBBY_CENTER.Z - halfZ - 2),
		},
		{
			Name = "LobbyRailing_South",
			Size = Vector3.new(LOBBY_SIZE.X + 8, 6, 4),
			CFrame = CFrame.new(LOBBY_CENTER.X, RAILING_Y, LOBBY_CENTER.Z + halfZ + 2),
		},
		{
			Name = "LobbyRailing_East",
			Size = Vector3.new(4, 6, LOBBY_SIZE.Z + 8),
			CFrame = CFrame.new(LOBBY_CENTER.X + halfX + 2, RAILING_Y, LOBBY_CENTER.Z),
		},
		{
			Name = "LobbyRailing_West",
			Size = Vector3.new(4, 6, LOBBY_SIZE.Z + 8),
			CFrame = CFrame.new(LOBBY_CENTER.X - halfX - 2, RAILING_Y, LOBBY_CENTER.Z),
		},
	}

	for _, spec in ipairs(railingSpecs) do
		local railing = getOrCreate(railings, "Part", spec.Name)

		if railing ~= nil then
			configurePart(
				railing,
				spec.Size,
				spec.CFrame,
				Color3.fromRGB(120, 210, 255),
				0.55,
				Enum.Material.ForceField,
				true,
				false,
				true
			)
		end
	end

	print("[WOB LOBBY] Elevated lobby railings ready at " .. railings:GetFullName())
end

local spawnPoints = getOrCreate(lobby, "Folder", "SpawnPoints")

if spawnPoints == nil then
	return
end

local lobbySpawnSpecs = {
	{ Name = "LobbySpawn1", Position = Vector3.new(-82, LOBBY_SPAWN_Y, 210), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn2", Position = Vector3.new(-56, LOBBY_SPAWN_Y, 232), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn3", Position = Vector3.new(-22, LOBBY_SPAWN_Y, 238), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn4", Position = Vector3.new(22, LOBBY_SPAWN_Y, 238), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn5", Position = Vector3.new(56, LOBBY_SPAWN_Y, 232), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn6", Position = Vector3.new(82, LOBBY_SPAWN_Y, 210), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn7", Position = Vector3.new(-92, LOBBY_SPAWN_Y, 150), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
	{ Name = "LobbySpawn8", Position = Vector3.new(92, LOBBY_SPAWN_Y, 150), LookAt = Vector3.new(0, LOBBY_SPAWN_Y, 155) },
}

local function configureSpawn(spec)
	local spawnPart = getOrCreate(spawnPoints, "Part", spec.Name)

	if spawnPart == nil then
		return
	end

	configurePart(
		spawnPart,
		Vector3.new(8, 0.35, 8),
		CFrame.lookAt(spec.Position, spec.LookAt, Vector3.yAxis),
		Color3.fromRGB(72, 190, 255),
		0.35,
		Enum.Material.Neon,
		false,
		false,
		false
	)
	print("[WOB LOBBY] Elevated spawn ready: " .. spawnPart:GetFullName())
end

for _, spec in ipairs(lobbySpawnSpecs) do
	configureSpawn(spec)
end

local duelPad = getOrCreate(lobby, "Part", "DuelPad")

if duelPad ~= nil then
	configurePart(
		duelPad,
		Vector3.new(48, 0.45, 34),
		CFrame.new(0, DUEL_PAD_Y, 92),
		Color3.fromRGB(255, 210, 70),
		0.28,
		Enum.Material.Neon,
		false,
		true,
		false
	)
	print("[WOB LOBBY] Elevated DuelPad ready at " .. duelPad:GetFullName())
end

print("[WOB LOBBY] Elevated transparent lobby scene ready at Workspace/WOB_Generated/Lobby.")
print("[WOB LOBBY] Lobby surface Y=" .. tostring(LOBBY_SURFACE_Y) .. ", spawn Y=" .. tostring(LOBBY_SPAWN_Y) .. ". Existing arena SpawnPoints were not modified. File -> Save to File.")
