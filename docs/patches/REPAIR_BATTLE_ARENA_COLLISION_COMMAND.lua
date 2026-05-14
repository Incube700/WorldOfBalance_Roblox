-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Repairs BattleArena collision contract while preserving the current arena position.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[ARENA REPAIR] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local BACKUP_ROOT_NAME = "WOB_EditorOnly_AssetDonors"
local BACKUP_FOLDER_NAME = "Arena_Backups"

local DEFAULT_CENTER = Vector3.new(0, 0, -360)
local DEFAULT_HALF_SIZE = 130
local FLOOR_THICKNESS = 2
local WALL_HEIGHT = 18
local WALL_THICKNESS = 8
local CENTER_CLEAR_RADIUS = 30
local STALE_SEARCH_RADIUS = 180

local changedCount = 0
local expectedParts = {}

local obstacleFolderNames = {
	Boundaries = true,
	Boundary = true,
	BoundaryWalls = true,
	Cover = true,
	MovementObstacles = true,
	Obstacles = true,
	RicochetWalls = true,
}

local allowedRootChildren = {
	BattleArena = true,
	Lobby = true,
	Map = true,
	Runtime = true,
	TestObjects = true,
	VFXPreview = true,
}

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "nil"
	end

	return ("(%.1f, %.1f, %.1f)"):format(vector.X, vector.Y, vector.Z)
end

local function getPartsBounds(parts)
	if #parts == 0 then
		return nil, nil
	end

	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5
		minX = math.min(minX, part.Position.X - halfSize.X)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)
	end

	local minVector = Vector3.new(minX, minY, minZ)
	local maxVector = Vector3.new(maxX, maxY, maxZ)

	return CFrame.new((minVector + maxVector) * 0.5), maxVector - minVector
end

local function collectBaseParts(root)
	local parts = {}

	if root:IsA("BasePart") then
		table.insert(parts, root)
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function getBackupFolder()
	local donors = Workspace:FindFirstChild(BACKUP_ROOT_NAME)

	if donors == nil then
		donors = Instance.new("Folder")
		donors.Name = BACKUP_ROOT_NAME
		donors.Parent = Workspace
		changedCount += 1
	end

	local backups = donors:FindFirstChild(BACKUP_FOLDER_NAME)

	if backups == nil then
		backups = Instance.new("Folder")
		backups.Name = BACKUP_FOLDER_NAME
		backups.Parent = donors
		changedCount += 1
	end

	return backups
end

local function backupInstance(instance, reason)
	if instance == nil or instance.Parent == nil then
		return
	end

	local backups = getBackupFolder()
	local backupName = instance.Name
		.. "_Backup_"
		.. os.date("!%Y%m%d_%H%M%S")
		.. "_"
		.. tostring(math.random(1000, 9999))
	instance.Name = backupName
	instance.Parent = backups
	changedCount += 1
	print("[ARENA REPAIR] Backed up " .. instance:GetFullName() .. " reason=" .. tostring(reason))
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			backupInstance(existing, "ClassMismatchExpected" .. className)
			existing = nil
		else
			return existing
		end
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	changedCount += 1
	print("[ARENA REPAIR] Created " .. instance:GetFullName())

	return instance
end

local function clearObstacleAttributes(part)
	part:SetAttribute("WOBMovementObstacle", nil)
	part:SetAttribute("WOBRicochetSurface", nil)
	part:SetAttribute("WOBPadTrigger", nil)
end

local function configurePart(part, size, cframe, color, transparency, material, canCollide, canTouch, canQuery)
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = canTouch == true
	part.CanQuery = canQuery == true
	part.CastShadow = false
	part.Transparency = transparency or 0
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	changedCount += 1
end

local function configureMovementObstacle(part, isRicochet)
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part:SetAttribute("WOBMovementObstacle", true)
	part:SetAttribute("WOBRicochetSurface", isRicochet == true)
	part:SetAttribute("WOBPadTrigger", nil)
	expectedParts[part] = true
	changedCount += 1
end

local function configureNonObstacle(part)
	clearObstacleAttributes(part)
	expectedParts[part] = true
	changedCount += 1
end

local function findAncestorNamed(instance, names)
	local current = instance.Parent

	while current ~= nil do
		if names[current.Name] == true then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function flatDistanceFromCenter(part, center)
	local delta = Vector3.new(part.Position.X - center.X, 0, part.Position.Z - center.Z)

	return delta.Magnitude
end

local function getAabbForPart(part)
	if part == nil or not part:IsA("BasePart") then
		return nil
	end

	local halfSize = part.Size * 0.5

	return {
		MinX = part.Position.X - halfSize.X,
		MaxX = part.Position.X + halfSize.X,
		MinZ = part.Position.Z - halfSize.Z,
		MaxZ = part.Position.Z + halfSize.Z,
	}
end

local function boundsContainsXZ(bounds, position, margin)
	if bounds == nil or typeof(position) ~= "Vector3" then
		return false
	end

	margin = margin or 0

	return position.X >= bounds.MinX - margin
		and position.X <= bounds.MaxX + margin
		and position.Z >= bounds.MinZ - margin
		and position.Z <= bounds.MaxZ + margin
end

local function isInvisibleBlocker(part)
	return part.Transparency >= 0.8
		and (part.CanCollide == true or part.CanQuery == true or part:GetAttribute("WOBMovementObstacle") == true)
end

local function isSafeNonObstacleName(name)
	return string.find(name, "Floor") ~= nil
		or string.find(name, "Trigger") ~= nil
		or string.find(name, "Pad") ~= nil
		or string.find(name, "Spawn") ~= nil
		or string.find(name, "VFX") ~= nil
		or string.find(name, "Label") ~= nil
end

local function getTopRootChild(root, instance)
	local current = instance
	local last = instance

	while current ~= nil and current ~= root do
		last = current
		current = current.Parent
	end

	if current == root then
		return last
	end

	return nil
end

local function getArenaReference(battleArena)
	local floor = battleArena:FindFirstChild("Floor")
	local center = battleArena:GetAttribute("ArenaCenter")
	local halfSize = tonumber(battleArena:GetAttribute("ArenaHalfSize"))
	local surfaceY = DEFAULT_CENTER.Y

	if floor ~= nil and floor:IsA("BasePart") then
		center = Vector3.new(floor.Position.X, floor.Position.Y + floor.Size.Y * 0.5, floor.Position.Z)
		halfSize = math.max(floor.Size.X, floor.Size.Z) * 0.5
		surfaceY = center.Y
	elseif typeof(center) == "Vector3" then
		surfaceY = center.Y
	else
		local cframe, size = getPartsBounds(collectBaseParts(battleArena))

		if cframe ~= nil then
			center = Vector3.new(cframe.Position.X, DEFAULT_CENTER.Y, cframe.Position.Z)
			halfSize = math.max(size.X, size.Z) * 0.5
		end
	end

	if typeof(center) ~= "Vector3" then
		center = DEFAULT_CENTER
	end

	if typeof(halfSize) ~= "number" or halfSize < 80 then
		halfSize = DEFAULT_HALF_SIZE
	end

	return center, halfSize, surfaceY
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[ARENA REPAIR] Workspace/" .. ROOT_NAME .. " was not found.")
	return
end

local battleArena = root:FindFirstChild("BattleArena")

if battleArena == nil then
	battleArena = Instance.new("Folder")
	battleArena.Name = "BattleArena"
	battleArena.Parent = root
	changedCount += 1
	print("[ARENA REPAIR] Created " .. battleArena:GetFullName())
elseif not battleArena:IsA("Folder") and not battleArena:IsA("Model") then
	backupInstance(battleArena, "BattleArenaWasNotFolderOrModel")
	battleArena = Instance.new("Folder")
	battleArena.Name = "BattleArena"
	battleArena.Parent = root
	changedCount += 1
	print("[ARENA REPAIR] Created " .. battleArena:GetFullName())
end

local arenaCenter, arenaHalfSize, arenaSurfaceY = getArenaReference(battleArena)

print("[ARENA REPAIR] Preserving BattleArena center=" .. formatVector3(arenaCenter) .. " halfSize=" .. tostring(math.floor(arenaHalfSize)))

battleArena:SetAttribute("WOBMode", "BattleArena")
battleArena:SetAttribute("Version", "v0.1")
battleArena:SetAttribute("ArenaCenter", arenaCenter)
battleArena:SetAttribute("ArenaHalfSize", arenaHalfSize)
battleArena:SetAttribute("SpawnPointCount", 8)

local floor = getOrCreate(battleArena, "Part", "Floor")
configurePart(
	floor,
	Vector3.new(arenaHalfSize * 2, FLOOR_THICKNESS, arenaHalfSize * 2),
	CFrame.new(arenaCenter.X, arenaSurfaceY - FLOOR_THICKNESS * 0.5, arenaCenter.Z),
	Color3.fromRGB(54, 69, 74),
	0,
	Enum.Material.Asphalt,
	true,
	false,
	false
)
floor:SetAttribute("WOBArenaFloor", true)
configureNonObstacle(floor)
print("[ARENA REPAIR] Floor repaired as non-obstacle " .. floor:GetFullName())

local boundaries = getOrCreate(battleArena, "Folder", "Boundaries")
local cover = getOrCreate(battleArena, "Folder", "Cover")
local ricochetWalls = getOrCreate(battleArena, "Folder", "RicochetWalls")
local spawnPoints = getOrCreate(battleArena, "Folder", "SpawnPoints")

local wallY = arenaSurfaceY + WALL_HEIGHT * 0.5
local total = arenaHalfSize * 2 + WALL_THICKNESS * 2
local boundarySpecs = {
	{
		Name = "BoundaryWall_North",
		Size = Vector3.new(total, WALL_HEIGHT, WALL_THICKNESS),
		CFrame = CFrame.new(arenaCenter.X, wallY, arenaCenter.Z - arenaHalfSize - WALL_THICKNESS * 0.5),
	},
	{
		Name = "BoundaryWall_South",
		Size = Vector3.new(total, WALL_HEIGHT, WALL_THICKNESS),
		CFrame = CFrame.new(arenaCenter.X, wallY, arenaCenter.Z + arenaHalfSize + WALL_THICKNESS * 0.5),
	},
	{
		Name = "BoundaryWall_East",
		Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, total),
		CFrame = CFrame.new(arenaCenter.X + arenaHalfSize + WALL_THICKNESS * 0.5, wallY, arenaCenter.Z),
	},
	{
		Name = "BoundaryWall_West",
		Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, total),
		CFrame = CFrame.new(arenaCenter.X - arenaHalfSize - WALL_THICKNESS * 0.5, wallY, arenaCenter.Z),
	},
}

for _, spec in ipairs(boundarySpecs) do
	local wall = getOrCreate(boundaries, "Part", spec.Name)
	configurePart(wall, spec.Size, spec.CFrame, Color3.fromRGB(86, 96, 105), 0.05, Enum.Material.Concrete, true, false, true)
	configureMovementObstacle(wall, false)
	print("[ARENA REPAIR] Boundary repaired " .. wall:GetFullName())
end

local coverSpecs = {
	{ Name = "Cover_Block_1", Size = Vector3.new(30, 9, 12), Offset = Vector3.new(-55, 4.5, -42), Yaw = 18 },
	{ Name = "Cover_Block_2", Size = Vector3.new(28, 9, 12), Offset = Vector3.new(58, 4.5, 36), Yaw = -22 },
	{ Name = "Cover_Block_3", Size = Vector3.new(16, 9, 34), Offset = Vector3.new(-12, 4.5, 64), Yaw = 8 },
	{ Name = "Cover_Block_4", Size = Vector3.new(16, 9, 34), Offset = Vector3.new(18, 4.5, -66), Yaw = -8 },
	{ Name = "Cover_Block_5", Size = Vector3.new(24, 9, 12), Offset = Vector3.new(-82, 4.5, 42), Yaw = 35 },
	{ Name = "Cover_Block_6", Size = Vector3.new(24, 9, 12), Offset = Vector3.new(84, 4.5, -38), Yaw = -35 },
}

for _, spec in ipairs(coverSpecs) do
	local block = getOrCreate(cover, "Part", spec.Name)
	configurePart(
		block,
		spec.Size,
		CFrame.new(arenaCenter + spec.Offset) * CFrame.Angles(0, math.rad(spec.Yaw), 0),
		Color3.fromRGB(76, 88, 82),
		0,
		Enum.Material.Metal,
		true,
		false,
		true
	)
	configureMovementObstacle(block, false)
	print("[ARENA REPAIR] Cover repaired " .. block:GetFullName())
end

local ricochetSpecs = {
	{ Name = "RicochetWall_1", Size = Vector3.new(42, 10, 5), Offset = Vector3.new(-58, 5, -18), Yaw = 35 },
	{ Name = "RicochetWall_2", Size = Vector3.new(42, 10, 5), Offset = Vector3.new(58, 5, 18), Yaw = -35 },
	{ Name = "RicochetWall_3", Size = Vector3.new(36, 10, 5), Offset = Vector3.new(-76, 5, -76), Yaw = -42 },
	{ Name = "RicochetWall_4", Size = Vector3.new(36, 10, 5), Offset = Vector3.new(76, 5, 76), Yaw = -42 },
}

for _, spec in ipairs(ricochetSpecs) do
	local wall = getOrCreate(ricochetWalls, "Part", spec.Name)
	configurePart(
		wall,
		spec.Size,
		CFrame.new(arenaCenter + spec.Offset) * CFrame.Angles(0, math.rad(spec.Yaw), 0),
		Color3.fromRGB(125, 194, 210),
		0.12,
		Enum.Material.Glass,
		true,
		false,
		true
	)
	configureMovementObstacle(wall, true)
	print("[ARENA REPAIR] Ricochet wall repaired " .. wall:GetFullName())
end

local spawnRadius = math.max(54, arenaHalfSize - 34)
local diagonalRadius = spawnRadius * 0.707
local spawnSpecs = {
	{ Name = "ArenaSpawn1", Offset = Vector3.new(0, 0, -spawnRadius) },
	{ Name = "ArenaSpawn2", Offset = Vector3.new(diagonalRadius, 0, -diagonalRadius) },
	{ Name = "ArenaSpawn3", Offset = Vector3.new(spawnRadius, 0, 0) },
	{ Name = "ArenaSpawn4", Offset = Vector3.new(diagonalRadius, 0, diagonalRadius) },
	{ Name = "ArenaSpawn5", Offset = Vector3.new(0, 0, spawnRadius) },
	{ Name = "ArenaSpawn6", Offset = Vector3.new(-diagonalRadius, 0, diagonalRadius) },
	{ Name = "ArenaSpawn7", Offset = Vector3.new(-spawnRadius, 0, 0) },
	{ Name = "ArenaSpawn8", Offset = Vector3.new(-diagonalRadius, 0, -diagonalRadius) },
}

for _, spec in ipairs(spawnSpecs) do
	local spawn = getOrCreate(spawnPoints, "Part", spec.Name)
	local position = arenaCenter + Vector3.new(spec.Offset.X, 0, spec.Offset.Z)
	configurePart(
		spawn,
		Vector3.new(9, 0.35, 9),
		CFrame.lookAt(position, arenaCenter, Vector3.yAxis),
		Color3.fromRGB(84, 235, 160),
		0.26,
		Enum.Material.Neon,
		false,
		false,
		false
	)
	spawn:SetAttribute("WOBSpawnType", "BattleArena")
	configureNonObstacle(spawn)
	print("[ARENA REPAIR] Spawn repaired " .. spawn:GetFullName())
end

for _, part in ipairs(collectBaseParts(battleArena)) do
	local shouldNeverBlock = isSafeNonObstacleName(part.Name)
	local nearCenter = flatDistanceFromCenter(part, arenaCenter) <= CENTER_CLEAR_RADIUS
	local unexpected = expectedParts[part] ~= true
	local invisibleBlocker = isInvisibleBlocker(part)

	if shouldNeverBlock then
		clearObstacleAttributes(part)
		print("[ARENA REPAIR] Cleared non-obstacle attrs " .. part:GetFullName())
	elseif unexpected and (invisibleBlocker or (nearCenter and part:GetAttribute("WOBMovementObstacle") == true)) then
		backupInstance(part, "UnexpectedBattleArenaBlocker")
	end
end

local floorBounds = getAabbForPart(floor)
local lobby = root:FindFirstChild("Lobby")

if lobby ~= nil then
	for _, lobbyPart in ipairs(collectBaseParts(lobby)) do
		local lobbyObstacle = lobbyPart:GetAttribute("WOBMovementObstacle") == true
			or string.find(lobbyPart.Name, "Railing") ~= nil
			or string.find(lobbyPart.Name, "Wall") ~= nil

		if lobbyObstacle and boundsContainsXZ(floorBounds, lobbyPart.Position, 24) then
			warn("[ARENA REPAIR] Lobby obstacle still overlaps/approaches BattleArena bounds: " .. lobbyPart:GetFullName())
		end
	end
end

for _, part in ipairs(collectBaseParts(root)) do
	local topChild = getTopRootChild(root, part)
	local nearArena = flatDistanceFromCenter(part, arenaCenter) <= STALE_SEARCH_RADIUS
	local suspiciousFolder = findAncestorNamed(part, obstacleFolderNames) ~= nil
	local suspiciousPart = nearArena
		and topChild ~= nil
		and allowedRootChildren[topChild.Name] ~= true
		and (part:GetAttribute("WOBMovementObstacle") == true or isInvisibleBlocker(part) or suspiciousFolder)

	if suspiciousPart then
		backupInstance(topChild, "StaleArenaObstacleNearPreservedCenter")
	end
end

print("[ARENA REPAIR] Complete. Changed/checked properties: " .. tostring(changedCount) .. ". File -> Save to File.")
