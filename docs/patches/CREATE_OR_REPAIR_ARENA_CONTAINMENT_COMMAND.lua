-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates/repairs lobby railings and arena containment collision.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB CONTAINMENT] Run this command outside Play Mode.")
	return
end

local GENERATED_ROOT_NAME = "WOB_Generated"
local ARENA_HALF_SIZE = 70
local ARENA_WALL_HEIGHT = 12
local ARENA_WALL_THICKNESS = 6
local LOBBY_CENTER = Vector3.new(0, 45, 155)
local LOBBY_SIZE = Vector3.new(230, 2, 190)
local LOBBY_RAILING_HEIGHT = 8
local LOBBY_RAILING_THICKNESS = 6

local changedCount = 0

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB CONTAINMENT] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	changedCount += 1
	print("[WOB CONTAINMENT] Created " .. instance:GetFullName())
	return instance, true
end

local function configureObstaclePart(part, canTouch)
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = canTouch == true
	part.CanQuery = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("WOBMovementObstacle", true)
	changedCount += 1
end

local function configureTriggerPart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	changedCount += 1
end

local function findBasePart(root, name)
	if root == nil then
		return nil
	end

	local direct = root:FindFirstChild(name)

	if direct ~= nil and direct:IsA("BasePart") then
		return direct
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local root = Workspace:FindFirstChild(GENERATED_ROOT_NAME)

if root == nil then
	root = Instance.new("Folder")
	root.Name = GENERATED_ROOT_NAME
	root.Parent = Workspace
	changedCount += 1
	print("[WOB CONTAINMENT] Created " .. root:GetFullName())
else
	print("[WOB CONTAINMENT] Kept " .. root:GetFullName())
end

local lobby = getOrCreate(root, "Folder", "Lobby")
local map = getOrCreate(root, "Folder", "Map")

if lobby ~= nil then
	local floor = lobby:FindFirstChild("Floor")
	local lobbyCenter = LOBBY_CENTER
	local lobbySize = LOBBY_SIZE
	local lobbySurfaceY = LOBBY_CENTER.Y + LOBBY_SIZE.Y * 0.5

	if floor ~= nil and floor:IsA("BasePart") then
		lobbyCenter = floor.Position
		lobbySize = floor.Size
		lobbySurfaceY = floor.Position.Y + floor.Size.Y * 0.5
		floor.Anchored = true
		floor.CanCollide = true
		floor.CanTouch = false
		floor.CanQuery = true
		print("[WOB CONTAINMENT] Checked lobby floor " .. floor:GetFullName())
	else
		warn("[WOB CONTAINMENT] Lobby/Floor missing. Run CREATE_LOBBY_COMMAND.lua if the elevated lobby needs rebuilding.")
	end

	local railings = getOrCreate(lobby, "Folder", "Railings")

	if railings ~= nil then
		local halfX = lobbySize.X * 0.5
		local halfZ = lobbySize.Z * 0.5
		local railingY = lobbySurfaceY + LOBBY_RAILING_HEIGHT * 0.5
		local railingSpecs = {
			{
				Name = "LobbyRailing_North",
				Size = Vector3.new(lobbySize.X + LOBBY_RAILING_THICKNESS * 2, LOBBY_RAILING_HEIGHT, LOBBY_RAILING_THICKNESS),
				CFrame = CFrame.new(lobbyCenter.X, railingY, lobbyCenter.Z - halfZ - LOBBY_RAILING_THICKNESS * 0.5),
			},
			{
				Name = "LobbyRailing_South",
				Size = Vector3.new(lobbySize.X + LOBBY_RAILING_THICKNESS * 2, LOBBY_RAILING_HEIGHT, LOBBY_RAILING_THICKNESS),
				CFrame = CFrame.new(lobbyCenter.X, railingY, lobbyCenter.Z + halfZ + LOBBY_RAILING_THICKNESS * 0.5),
			},
			{
				Name = "LobbyRailing_East",
				Size = Vector3.new(LOBBY_RAILING_THICKNESS, LOBBY_RAILING_HEIGHT, lobbySize.Z + LOBBY_RAILING_THICKNESS * 2),
				CFrame = CFrame.new(lobbyCenter.X + halfX + LOBBY_RAILING_THICKNESS * 0.5, railingY, lobbyCenter.Z),
			},
			{
				Name = "LobbyRailing_West",
				Size = Vector3.new(LOBBY_RAILING_THICKNESS, LOBBY_RAILING_HEIGHT, lobbySize.Z + LOBBY_RAILING_THICKNESS * 2),
				CFrame = CFrame.new(lobbyCenter.X - halfX - LOBBY_RAILING_THICKNESS * 0.5, railingY, lobbyCenter.Z),
			},
		}

		for _, spec in ipairs(railingSpecs) do
			local railing = getOrCreate(railings, "Part", spec.Name)

			if railing ~= nil then
				railing.Size = spec.Size
				railing.CFrame = spec.CFrame
				railing.Color = Color3.fromRGB(120, 210, 255)
				railing.Transparency = 0.45
				railing.Material = Enum.Material.ForceField
				configureObstaclePart(railing, false)
				print("[WOB CONTAINMENT] Repaired " .. railing:GetFullName())
			end
		end
	end

	local duelPad = lobby:FindFirstChild("DuelPad")

	if duelPad ~= nil and duelPad:IsA("BasePart") then
		configureTriggerPart(duelPad)
		print("[WOB CONTAINMENT] Checked DuelPad trigger " .. duelPad:GetFullName())
	else
		warn("[WOB CONTAINMENT] Lobby/DuelPad missing. Run CREATE_OR_REPAIR_DUELPAD_VISUAL_COMMAND.lua after recreating the lobby.")
	end
end

if map ~= nil then
	local boundaryWalls = map:FindFirstChild("BoundaryWalls")
		or map:FindFirstChild("Boundaries")
		or map:FindFirstChild("Boundary")

	if boundaryWalls == nil then
		boundaryWalls = Instance.new("Folder")
		boundaryWalls.Name = "BoundaryWalls"
		boundaryWalls.Parent = map
		changedCount += 1
		print("[WOB CONTAINMENT] Created " .. boundaryWalls:GetFullName())
	elseif not boundaryWalls:IsA("Folder") then
		warn("[WOB CONTAINMENT] " .. boundaryWalls:GetFullName() .. " is " .. boundaryWalls.ClassName .. ", expected Folder.")
		boundaryWalls = nil
	end

	local wallSpecs = {
		{
			Name = "Wall_North",
			Size = Vector3.new(ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2, ARENA_WALL_HEIGHT, ARENA_WALL_THICKNESS),
			CFrame = CFrame.new(0, ARENA_WALL_HEIGHT * 0.5, -ARENA_HALF_SIZE - ARENA_WALL_THICKNESS * 0.5),
		},
		{
			Name = "Wall_South",
			Size = Vector3.new(ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2, ARENA_WALL_HEIGHT, ARENA_WALL_THICKNESS),
			CFrame = CFrame.new(0, ARENA_WALL_HEIGHT * 0.5, ARENA_HALF_SIZE + ARENA_WALL_THICKNESS * 0.5),
		},
		{
			Name = "Wall_East",
			Size = Vector3.new(ARENA_WALL_THICKNESS, ARENA_WALL_HEIGHT, ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2),
			CFrame = CFrame.new(ARENA_HALF_SIZE + ARENA_WALL_THICKNESS * 0.5, ARENA_WALL_HEIGHT * 0.5, 0),
		},
		{
			Name = "Wall_West",
			Size = Vector3.new(ARENA_WALL_THICKNESS, ARENA_WALL_HEIGHT, ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2),
			CFrame = CFrame.new(-ARENA_HALF_SIZE - ARENA_WALL_THICKNESS * 0.5, ARENA_WALL_HEIGHT * 0.5, 0),
		},
	}

	for _, spec in ipairs(wallSpecs) do
		local wall = findBasePart(map, spec.Name)
		local created = false

		if wall == nil and boundaryWalls ~= nil then
			wall = Instance.new("Part")
			wall.Name = spec.Name
			wall.Parent = boundaryWalls
			wall.CFrame = spec.CFrame
			created = true
			changedCount += 1
			print("[WOB CONTAINMENT] Created " .. wall:GetFullName())
		end

		if wall ~= nil then
			if created then
				wall.Size = spec.Size
			elseif spec.Name == "Wall_North" or spec.Name == "Wall_South" then
				wall.Size = Vector3.new(math.max(wall.Size.X, spec.Size.X), math.max(wall.Size.Y, ARENA_WALL_HEIGHT), math.max(wall.Size.Z, ARENA_WALL_THICKNESS))
			else
				wall.Size = Vector3.new(math.max(wall.Size.X, ARENA_WALL_THICKNESS), math.max(wall.Size.Y, ARENA_WALL_HEIGHT), math.max(wall.Size.Z, spec.Size.Z))
			end

			if wall.Position.Y < ARENA_WALL_HEIGHT * 0.5 then
				wall.Position = Vector3.new(wall.Position.X, ARENA_WALL_HEIGHT * 0.5, wall.Position.Z)
			end

			wall.Material = Enum.Material.Concrete
			wall.Color = Color3.fromRGB(82, 92, 100)
			wall.Transparency = math.min(wall.Transparency, 0.2)
			configureObstaclePart(wall, false)
			print("[WOB CONTAINMENT] Repaired " .. wall:GetFullName())
		end
	end

	for _, folderName in ipairs({ "RicochetWalls", "Cover", "BoundaryWalls", "Boundaries", "Boundary" }) do
		local folder = map:FindFirstChild(folderName)

		if folder ~= nil then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					configureObstaclePart(descendant, false)
				end
			end

			print("[WOB CONTAINMENT] Checked " .. folder:GetFullName())
		else
			print("[WOB CONTAINMENT] Optional folder missing: Map/" .. folderName)
		end
	end
end

print("[WOB CONTAINMENT] Containment repair complete. Changed/checked properties: " .. tostring(changedCount) .. ". File -> Save to File.")
