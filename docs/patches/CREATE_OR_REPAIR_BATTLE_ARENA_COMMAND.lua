-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Creates/repairs Free Drive Battle Arena v0.1 scene contract.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB BATTLE ARENA] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local BACKUP_ROOT_NAME = "WOB_EditorOnly_AssetDonors"
local BACKUP_FOLDER_NAME = "Arena_Backups"

local ARENA_CENTER = Vector3.new(0, 0, -360)
local ARENA_HALF_SIZE = 130
local ARENA_FLOOR_THICKNESS = 2
local ARENA_SURFACE_Y = 0
local ARENA_WALL_HEIGHT = 18
local ARENA_WALL_THICKNESS = 8
local ARENA_SPAWN_Y = ARENA_SURFACE_Y

local LOBBY_CENTER = Vector3.new(0, 45, 155)
local LOBBY_SIZE = Vector3.new(230, 2, 190)
local LOBBY_SURFACE_Y = LOBBY_CENTER.Y + LOBBY_SIZE.Y * 0.5
local ARENA_PAD_Y = LOBBY_SURFACE_Y + 0.14

local changedCount = 0

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB BATTLE ARENA] %s is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	changedCount += 1
	print("[WOB BATTLE ARENA] Created " .. instance:GetFullName())

	return instance, true
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
	if instance == nil then
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
	print("[WOB BATTLE ARENA] Backed up " .. backupName .. " reason=" .. tostring(reason))
end

local function getOrReplace(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil and not existing:IsA(className) then
		backupInstance(existing, "ClassMismatchExpected" .. className)
		existing = nil
	end

	return getOrCreate(parent, className, name)
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
	changedCount += 1
end

local function configurePad(part)
	part:SetAttribute("WOBPadType", "BattleArena")
	part:SetAttribute("RequiredPlayers", 1)
	part:SetAttribute("WOBPadEnabled", true)
	part:SetAttribute("WOBMovementObstacle", nil)
	part:SetAttribute("WOBRicochetSurface", nil)
	part:SetAttribute("WOBPadTrigger", nil)
	part:SetAttribute("DuelQueueCount", nil)
	part:SetAttribute("DuelState", nil)
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = Workspace
	changedCount += 1
	print("[WOB BATTLE ARENA] Created " .. root:GetFullName())
end

local battleArena = root:FindFirstChild("BattleArena")

if battleArena ~= nil and not battleArena:IsA("Folder") then
	backupInstance(battleArena, "BattleArenaWasNotFolder")
	battleArena = nil
end

if battleArena == nil then
	battleArena = Instance.new("Folder")
	battleArena.Name = "BattleArena"
	battleArena.Parent = root
	changedCount += 1
	print("[WOB BATTLE ARENA] Created " .. battleArena:GetFullName())
end

battleArena:SetAttribute("WOBMode", "BattleArena")
battleArena:SetAttribute("Version", "v0.1")
battleArena:SetAttribute("SpawnPointCount", 8)
battleArena:SetAttribute("ArenaCenter", ARENA_CENTER)
battleArena:SetAttribute("ArenaHalfSize", ARENA_HALF_SIZE)

local floor = getOrReplace(battleArena, "Part", "Floor")

if floor ~= nil then
	configurePart(
		floor,
		Vector3.new(ARENA_HALF_SIZE * 2, ARENA_FLOOR_THICKNESS, ARENA_HALF_SIZE * 2),
		CFrame.new(ARENA_CENTER.X, ARENA_SURFACE_Y - ARENA_FLOOR_THICKNESS * 0.5, ARENA_CENTER.Z),
		Color3.fromRGB(54, 69, 74),
		0,
		Enum.Material.Asphalt,
		true,
		false,
		false
	)
	floor:SetAttribute("WOBArenaFloor", true)
	floor:SetAttribute("WOBMovementObstacle", nil)
	floor:SetAttribute("WOBRicochetSurface", nil)
	floor:SetAttribute("WOBPadTrigger", nil)
end

local boundaries = getOrReplace(battleArena, "Folder", "Boundaries")
local cover = getOrReplace(battleArena, "Folder", "Cover")
local ricochetWalls = getOrReplace(battleArena, "Folder", "RicochetWalls")
local spawnPoints = getOrReplace(battleArena, "Folder", "SpawnPoints")

if boundaries ~= nil then
	local wallY = ARENA_SURFACE_Y + ARENA_WALL_HEIGHT * 0.5
	local total = ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2
	local wallSpecs = {
		{
			Name = "BoundaryWall_North",
			Size = Vector3.new(total, ARENA_WALL_HEIGHT, ARENA_WALL_THICKNESS),
			CFrame = CFrame.new(ARENA_CENTER.X, wallY, ARENA_CENTER.Z - ARENA_HALF_SIZE - ARENA_WALL_THICKNESS * 0.5),
		},
		{
			Name = "BoundaryWall_South",
			Size = Vector3.new(total, ARENA_WALL_HEIGHT, ARENA_WALL_THICKNESS),
			CFrame = CFrame.new(ARENA_CENTER.X, wallY, ARENA_CENTER.Z + ARENA_HALF_SIZE + ARENA_WALL_THICKNESS * 0.5),
		},
		{
			Name = "BoundaryWall_East",
			Size = Vector3.new(ARENA_WALL_THICKNESS, ARENA_WALL_HEIGHT, total),
			CFrame = CFrame.new(ARENA_CENTER.X + ARENA_HALF_SIZE + ARENA_WALL_THICKNESS * 0.5, wallY, ARENA_CENTER.Z),
		},
		{
			Name = "BoundaryWall_West",
			Size = Vector3.new(ARENA_WALL_THICKNESS, ARENA_WALL_HEIGHT, total),
			CFrame = CFrame.new(ARENA_CENTER.X - ARENA_HALF_SIZE - ARENA_WALL_THICKNESS * 0.5, wallY, ARENA_CENTER.Z),
		},
	}

	for _, spec in ipairs(wallSpecs) do
		local wall = getOrReplace(boundaries, "Part", spec.Name)

		if wall ~= nil then
			configurePart(
				wall,
				spec.Size,
				spec.CFrame,
				Color3.fromRGB(86, 96, 105),
				0.05,
				Enum.Material.Concrete,
				true,
				false,
				true
			)
			configureMovementObstacle(wall, false)
		end
	end
end

if cover ~= nil then
	local coverSpecs = {
		{ Name = "Cover_Block_1", Size = Vector3.new(30, 9, 12), Position = ARENA_CENTER + Vector3.new(-55, 4.5, -42), Yaw = 18 },
		{ Name = "Cover_Block_2", Size = Vector3.new(28, 9, 12), Position = ARENA_CENTER + Vector3.new(58, 4.5, 36), Yaw = -22 },
		{ Name = "Cover_Block_3", Size = Vector3.new(16, 9, 34), Position = ARENA_CENTER + Vector3.new(-12, 4.5, 64), Yaw = 8 },
		{ Name = "Cover_Block_4", Size = Vector3.new(16, 9, 34), Position = ARENA_CENTER + Vector3.new(18, 4.5, -66), Yaw = -8 },
		{ Name = "Cover_Block_5", Size = Vector3.new(24, 9, 12), Position = ARENA_CENTER + Vector3.new(-82, 4.5, 42), Yaw = 35 },
		{ Name = "Cover_Block_6", Size = Vector3.new(24, 9, 12), Position = ARENA_CENTER + Vector3.new(84, 4.5, -38), Yaw = -35 },
	}

	for _, spec in ipairs(coverSpecs) do
		local block = getOrReplace(cover, "Part", spec.Name)

		if block ~= nil then
			configurePart(
				block,
				spec.Size,
				CFrame.new(spec.Position) * CFrame.Angles(0, math.rad(spec.Yaw), 0),
				Color3.fromRGB(76, 88, 82),
				0,
				Enum.Material.Metal,
				true,
				false,
				true
			)
			configureMovementObstacle(block, false)
		end
	end
end

if ricochetWalls ~= nil then
	local ricochetSpecs = {
		{ Name = "RicochetWall_1", Size = Vector3.new(42, 10, 5), Position = ARENA_CENTER + Vector3.new(-58, 5, -18), Yaw = 35 },
		{ Name = "RicochetWall_2", Size = Vector3.new(42, 10, 5), Position = ARENA_CENTER + Vector3.new(58, 5, 18), Yaw = -35 },
		{ Name = "RicochetWall_3", Size = Vector3.new(36, 10, 5), Position = ARENA_CENTER + Vector3.new(-76, 5, -76), Yaw = -42 },
		{ Name = "RicochetWall_4", Size = Vector3.new(36, 10, 5), Position = ARENA_CENTER + Vector3.new(76, 5, 76), Yaw = -42 },
	}

	for _, spec in ipairs(ricochetSpecs) do
		local wall = getOrReplace(ricochetWalls, "Part", spec.Name)

		if wall ~= nil then
			configurePart(
				wall,
				spec.Size,
				CFrame.new(spec.Position) * CFrame.Angles(0, math.rad(spec.Yaw), 0),
				Color3.fromRGB(125, 194, 210),
				0.12,
				Enum.Material.Glass,
				true,
				false,
				true
			)
			configureMovementObstacle(wall, true)
		end
	end
end

if spawnPoints ~= nil then
	local radius = 96
	local spawnSpecs = {
		{ Name = "ArenaSpawn1", Offset = Vector3.new(0, 0, -radius) },
		{ Name = "ArenaSpawn2", Offset = Vector3.new(68, 0, -68) },
		{ Name = "ArenaSpawn3", Offset = Vector3.new(radius, 0, 0) },
		{ Name = "ArenaSpawn4", Offset = Vector3.new(68, 0, 68) },
		{ Name = "ArenaSpawn5", Offset = Vector3.new(0, 0, radius) },
		{ Name = "ArenaSpawn6", Offset = Vector3.new(-68, 0, 68) },
		{ Name = "ArenaSpawn7", Offset = Vector3.new(-radius, 0, 0) },
		{ Name = "ArenaSpawn8", Offset = Vector3.new(-68, 0, -68) },
	}

	for _, spec in ipairs(spawnSpecs) do
		local spawn = getOrReplace(spawnPoints, "Part", spec.Name)

		if spawn ~= nil then
			local position = Vector3.new(
				ARENA_CENTER.X + spec.Offset.X,
				ARENA_SPAWN_Y,
				ARENA_CENTER.Z + spec.Offset.Z
			)
			configurePart(
				spawn,
				Vector3.new(9, 0.35, 9),
				CFrame.lookAt(position, Vector3.new(ARENA_CENTER.X, ARENA_SPAWN_Y, ARENA_CENTER.Z), Vector3.yAxis),
				Color3.fromRGB(84, 235, 160),
				0.26,
				Enum.Material.Neon,
				false,
				false,
				false
			)
			spawn:SetAttribute("WOBSpawnType", "BattleArena")
			spawn:SetAttribute("WOBMovementObstacle", nil)
			spawn:SetAttribute("WOBRicochetSurface", nil)
			spawn:SetAttribute("WOBPadTrigger", nil)
		end
	end
end

local lobby = getOrReplace(root, "Folder", "Lobby")

if lobby ~= nil then
	local arenaPad, arenaPadCreated = getOrReplace(lobby, "Part", "ArenaPad")

	if arenaPad ~= nil then
		local preservedCFrame = arenaPadCreated and CFrame.new(64, ARENA_PAD_Y, 92) or arenaPad.CFrame

		configurePart(
			arenaPad,
			Vector3.new(math.max(arenaPad.Size.X, 48), 0.45, math.max(arenaPad.Size.Z, 34)),
			preservedCFrame,
			Color3.fromRGB(96, 235, 165),
			0.18,
			Enum.Material.Neon,
			false,
			true,
			false
		)
		configurePad(arenaPad)
		print("[WOB BATTLE ARENA] ArenaPad position preserved at " .. tostring(arenaPad.Position))
	end

	local arenaPadFrame = getOrReplace(lobby, "Folder", "ArenaPadFrame")

	if arenaPadFrame ~= nil and arenaPad ~= nil then
		local center = arenaPad.CFrame
		local halfX = arenaPad.Size.X * 0.5
		local halfZ = arenaPad.Size.Z * 0.5
		local rimY = arenaPad.Size.Y * 0.5 + 0.65
		local rimSpecs = {
			{ Name = "ArenaPad_Rim_North", Size = Vector3.new(arenaPad.Size.X + 4, 1.2, 2), CFrame = center * CFrame.new(0, rimY, -halfZ - 1) },
			{ Name = "ArenaPad_Rim_South", Size = Vector3.new(arenaPad.Size.X + 4, 1.2, 2), CFrame = center * CFrame.new(0, rimY, halfZ + 1) },
			{ Name = "ArenaPad_Rim_East", Size = Vector3.new(2, 1.2, arenaPad.Size.Z + 4), CFrame = center * CFrame.new(halfX + 1, rimY, 0) },
			{ Name = "ArenaPad_Rim_West", Size = Vector3.new(2, 1.2, arenaPad.Size.Z + 4), CFrame = center * CFrame.new(-halfX - 1, rimY, 0) },
		}

		for _, spec in ipairs(rimSpecs) do
			local rim = getOrReplace(arenaPadFrame, "Part", spec.Name)

			if rim ~= nil then
				configurePart(
					rim,
					spec.Size,
					spec.CFrame,
					Color3.fromRGB(162, 255, 208),
					0.08,
					Enum.Material.Neon,
					false,
					false,
					false
				)
			end
		end
	end
end

print("[WOB BATTLE ARENA] Battle Arena v0.1 scene contract ready. Changed/checked properties: " .. tostring(changedCount) .. ". File -> Save to File.")
