-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It restores only the elevated lobby vertical scene contract.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB LOBBY Y] Run this command outside Play Mode.")
	return
end

local GENERATED_ROOT_NAME = "WOB_Generated"
local LOBBY_CENTER = Vector3.new(0, 45, 155)
local LOBBY_SIZE = Vector3.new(230, 2, 190)
local LOBBY_SURFACE_Y = LOBBY_CENTER.Y + LOBBY_SIZE.Y * 0.5
local LOBBY_SPAWN_Y = LOBBY_SURFACE_Y + 0.35
local DUEL_PAD_Y = LOBBY_SURFACE_Y + 0.12
local LOBBY_RAILING_HEIGHT = 8
local LOBBY_RAILING_THICKNESS = 6

local containmentFolderNames = {
	Boundary = true,
	BoundaryWalls = true,
	Containment = true,
	ContainmentWalls = true,
	LobbyWalls = true,
	MovementObstacles = true,
	Railings = true,
	Walls = true,
}

local excludedFolderNames = {
	DuelPadVisuals = true,
	SpawnPoints = true,
}

local changedCount = 0
local processedParts = {}

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB LOBBY Y] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	changedCount += 1
	print("[WOB LOBBY Y] Created " .. instance:GetFullName())
	return instance, true
end

local function isDescendantOfNamedFolder(instance, folderNames)
	local current = instance.Parent

	while current ~= nil do
		if folderNames[current.Name] == true then
			return true
		end

		current = current.Parent
	end

	return false
end

local function findBasePartByNames(root, names)
	if root == nil then
		return nil
	end

	for _, name in ipairs(names) do
		local direct = root:FindFirstChild(name)

		if direct ~= nil and direct:IsA("BasePart") then
			return direct
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, name in ipairs(names) do
				if descendant.Name == name then
					return descendant
				end
			end
		end
	end

	return nil
end

local function configureBasePart(part, canCollide, canTouch, canQuery)
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = canTouch == true
	part.CanQuery = canQuery == true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function setPartCFrame(part, cframe, reason)
	local oldPosition = part.Position
	part.CFrame = cframe
	changedCount += 1
	print(("[WOB LOBBY Y] %s %s pos %.2f,%.2f,%.2f -> %.2f,%.2f,%.2f"):format(
		reason,
		part:GetFullName(),
		oldPosition.X,
		oldPosition.Y,
		oldPosition.Z,
		part.Position.X,
		part.Position.Y,
		part.Position.Z
	))
end

local function findLobby(root)
	local lobby = root ~= nil and root:FindFirstChild("Lobby") or nil

	if lobby ~= nil and lobby:IsA("Folder") then
		return lobby
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Folder") and descendant.Name == "Lobby" then
			return descendant
		end
	end

	return nil
end

local function getLobbyFloor(lobby)
	local floor = findBasePartByNames(lobby, {
		"Floor",
		"LobbyFloor",
		"LobbyPlatform",
		"Platform",
	})

	if floor ~= nil then
		return floor
	end

	return nil
end

local function configureLobbyFloor(lobby)
	local floor = getLobbyFloor(lobby)

	if floor == nil then
		floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Parent = lobby
		changedCount += 1
		print("[WOB LOBBY Y] Created " .. floor:GetFullName())
	end

	floor.Size = LOBBY_SIZE
	setPartCFrame(floor, CFrame.new(LOBBY_CENTER), "Restored floor")
	configureBasePart(floor, true, false, true)
	floor.Transparency = 0.42
	floor.Material = Enum.Material.Glass
	floor.Color = Color3.fromRGB(70, 110, 120)

	return floor
end

local function configureLobbyObstacle(part)
	configureBasePart(part, true, true, true)
	part:SetAttribute("WOBMovementObstacle", true)
end

local function movePartBottomToSurface(part, surfaceY)
	local oldY = part.Position.Y
	local newY = surfaceY + part.Size.Y * 0.5
	local deltaY = newY - oldY

	if math.abs(deltaY) > 0.001 then
		part.CFrame = part.CFrame + Vector3.new(0, deltaY, 0)
		changedCount += 1
		print(("[WOB LOBBY Y] Repaired %s Y %.2f -> %.2f"):format(part:GetFullName(), oldY, part.Position.Y))
	end

	configureLobbyObstacle(part)
end

local function isLobbyContainmentPart(part)
	if part.Name == "Floor" or part.Name == "DuelPad" then
		return false
	end

	if isDescendantOfNamedFolder(part, excludedFolderNames) then
		return false
	end

	if part:GetAttribute("WOBMovementObstacle") == true then
		return true
	end

	if containmentFolderNames[part.Parent.Name] == true or isDescendantOfNamedFolder(part, containmentFolderNames) then
		return true
	end

	return string.match(part.Name, "^LobbyRailing_") ~= nil
		or string.match(part.Name, "^LobbyWall_") ~= nil
		or string.match(part.Name, "^LobbyBoundary_") ~= nil
		or string.match(part.Name, "^Railing_") ~= nil
		or string.match(part.Name, "^Wall_") ~= nil
end

local function collectLobbyContainmentParts(lobby)
	local parts = {}
	local seen = {}

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BasePart")
			and isLobbyContainmentPart(descendant)
			and seen[descendant] ~= true
		then
			seen[descendant] = true
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function repairLobbySpawnPoints(lobby)
	local spawnPoints = lobby:FindFirstChild("SpawnPoints")

	if spawnPoints == nil then
		return
	end

	local lookAt = Vector3.new(LOBBY_CENTER.X, LOBBY_SPAWN_Y, LOBBY_CENTER.Z)

	for _, child in ipairs(spawnPoints:GetChildren()) do
		if child:IsA("BasePart") and string.match(child.Name, "^LobbySpawn%d+$") ~= nil then
			local oldPosition = child.Position
			local newPosition = Vector3.new(oldPosition.X, LOBBY_SPAWN_Y, oldPosition.Z)
			child.Size = Vector3.new(math.max(child.Size.X, 8), 0.35, math.max(child.Size.Z, 8))
			setPartCFrame(child, CFrame.lookAt(newPosition, lookAt, Vector3.yAxis), "Restored spawn")
			configureBasePart(child, false, false, false)
			child.Transparency = math.min(child.Transparency, 0.45)
			child.Material = Enum.Material.Neon
		end
	end
end

local function repairDuelPad(lobby)
	local duelPad = lobby:FindFirstChild("DuelPad")

	if duelPad == nil or not duelPad:IsA("BasePart") then
		return
	end

	duelPad.Size = Vector3.new(math.max(duelPad.Size.X, 48), 0.45, math.max(duelPad.Size.Z, 34))
	setPartCFrame(duelPad, CFrame.new(0, DUEL_PAD_Y, 92), "Restored DuelPad")
	configureBasePart(duelPad, false, true, false)
	duelPad.Transparency = math.max(duelPad.Transparency, 0.82)
end

local root = Workspace:FindFirstChild(GENERATED_ROOT_NAME)

if root == nil then
	warn("[WOB LOBBY Y] Workspace/WOB_Generated was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local lobby = findLobby(root)

if lobby == nil then
	warn("[WOB LOBBY Y] Lobby folder was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local floor = configureLobbyFloor(lobby)

lobby:SetAttribute("LobbyCenterY", LOBBY_CENTER.Y)
lobby:SetAttribute("LobbySurfaceY", LOBBY_SURFACE_Y)
lobby:SetAttribute("LobbySpawnY", LOBBY_SPAWN_Y)

local railings = getOrCreate(lobby, "Folder", "Railings")

if railings ~= nil and floor ~= nil then
	local halfX = LOBBY_SIZE.X * 0.5
	local halfZ = LOBBY_SIZE.Z * 0.5
	local railingSpecs = {
		{
			Name = "LobbyRailing_North",
			Size = Vector3.new(LOBBY_SIZE.X + LOBBY_RAILING_THICKNESS * 2, LOBBY_RAILING_HEIGHT, LOBBY_RAILING_THICKNESS),
			CFrame = CFrame.new(LOBBY_CENTER.X, LOBBY_SURFACE_Y + LOBBY_RAILING_HEIGHT * 0.5, LOBBY_CENTER.Z - halfZ - LOBBY_RAILING_THICKNESS * 0.5),
		},
		{
			Name = "LobbyRailing_South",
			Size = Vector3.new(LOBBY_SIZE.X + LOBBY_RAILING_THICKNESS * 2, LOBBY_RAILING_HEIGHT, LOBBY_RAILING_THICKNESS),
			CFrame = CFrame.new(LOBBY_CENTER.X, LOBBY_SURFACE_Y + LOBBY_RAILING_HEIGHT * 0.5, LOBBY_CENTER.Z + halfZ + LOBBY_RAILING_THICKNESS * 0.5),
		},
		{
			Name = "LobbyRailing_East",
			Size = Vector3.new(LOBBY_RAILING_THICKNESS, LOBBY_RAILING_HEIGHT, LOBBY_SIZE.Z + LOBBY_RAILING_THICKNESS * 2),
			CFrame = CFrame.new(LOBBY_CENTER.X + halfX + LOBBY_RAILING_THICKNESS * 0.5, LOBBY_SURFACE_Y + LOBBY_RAILING_HEIGHT * 0.5, LOBBY_CENTER.Z),
		},
		{
			Name = "LobbyRailing_West",
			Size = Vector3.new(LOBBY_RAILING_THICKNESS, LOBBY_RAILING_HEIGHT, LOBBY_SIZE.Z + LOBBY_RAILING_THICKNESS * 2),
			CFrame = CFrame.new(LOBBY_CENTER.X - halfX - LOBBY_RAILING_THICKNESS * 0.5, LOBBY_SURFACE_Y + LOBBY_RAILING_HEIGHT * 0.5, LOBBY_CENTER.Z),
		},
	}

	for _, spec in ipairs(railingSpecs) do
		local railing = getOrCreate(railings, "Part", spec.Name)

		if railing ~= nil then
			local oldY = railing.Position.Y
			railing.Size = spec.Size
			railing.CFrame = spec.CFrame
			railing.Color = Color3.fromRGB(120, 210, 255)
			railing.Transparency = math.min(railing.Transparency, 0.55)
			railing.Material = Enum.Material.ForceField
			configureLobbyObstacle(railing)
			processedParts[railing] = true
			changedCount += 1
			print(("[WOB LOBBY Y] Repaired %s Y %.2f -> %.2f"):format(railing:GetFullName(), oldY, railing.Position.Y))
		end
	end
end

repairLobbySpawnPoints(lobby)
repairDuelPad(lobby)

local containmentParts = collectLobbyContainmentParts(lobby)

for _, part in ipairs(containmentParts) do
	if processedParts[part] ~= true then
		movePartBottomToSurface(part, LOBBY_SURFACE_Y)
	end
end

print("[WOB LOBBY Y] Restored elevated lobby at centerY=" .. tostring(LOBBY_CENTER.Y) .. ", surfaceY=" .. tostring(LOBBY_SURFACE_Y) .. ", spawnY=" .. tostring(LOBBY_SPAWN_Y) .. ". File -> Save to File.")
