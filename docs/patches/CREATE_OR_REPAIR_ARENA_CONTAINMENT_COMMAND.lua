-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates/repairs arena containment collision only.
-- Use REPAIR_LOBBY_VERTICAL_CONTAINMENT_COMMAND.lua for elevated lobby railings/walls.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


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
local ARENA_FLOOR_FALLBACK_TOP_Y = 0

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

local function isDescendantOf(instance, ancestor)
	local current = instance

	while current ~= nil do
		if current == ancestor then
			return true
		end

		current = current.Parent
	end

	return false
end

local function findArenaFloor(root, map)
	local floorNames = {
		"ArenaFloor",
		"MapFloor",
		"Floor",
		"Ground",
		"ArenaGround",
	}
	local lobby = root ~= nil and root:FindFirstChild("Lobby") or nil

	if map ~= nil then
		for _, floorName in ipairs(floorNames) do
			local floor = findBasePart(map, floorName)

			if floor ~= nil then
				return floor
			end
		end
	end

	if root ~= nil then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") and not isDescendantOf(descendant, lobby) then
				for _, floorName in ipairs(floorNames) do
					if descendant.Name == floorName then
						return descendant
					end
				end
			end
		end
	end

	return nil
end

local function getArenaFloorTopY(root, map)
	local floor = findArenaFloor(root, map)

	if floor ~= nil then
		return floor.Position.Y + floor.Size.Y * 0.5, floor
	end

	warn("[WOB CONTAINMENT] Arena floor not found. Using world Y=0 as arena floor top fallback.")
	return ARENA_FLOOR_FALLBACK_TOP_Y, nil
end

local function movePartBottomToY(part, floorTopY)
	local oldY = part.Position.Y
	local newY = floorTopY + part.Size.Y * 0.5
	local deltaY = newY - oldY

	if math.abs(deltaY) > 0.001 then
		part.CFrame = part.CFrame + Vector3.new(0, deltaY, 0)
		changedCount += 1
		print(("[WOB CONTAINMENT] Repaired %s Y %.2f -> %.2f"):format(part:GetFullName(), oldY, part.Position.Y))
	end
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

local map = getOrCreate(root, "Folder", "Map")

if map ~= nil then
	local arenaFloorTopY, arenaFloor = getArenaFloorTopY(root, map)

	if arenaFloor ~= nil then
		arenaFloor.Anchored = true
		arenaFloor.CanCollide = true
		arenaFloor.CanTouch = false
		arenaFloor.CanQuery = true
		print(("[WOB CONTAINMENT] Using arena floor %s topY=%.2f"):format(arenaFloor:GetFullName(), arenaFloorTopY))
	else
		print(("[WOB CONTAINMENT] Using arena floor fallback topY=%.2f"):format(arenaFloorTopY))
	end

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
			CFrame = CFrame.new(0, arenaFloorTopY + ARENA_WALL_HEIGHT * 0.5, -ARENA_HALF_SIZE - ARENA_WALL_THICKNESS * 0.5),
		},
		{
			Name = "Wall_South",
			Size = Vector3.new(ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2, ARENA_WALL_HEIGHT, ARENA_WALL_THICKNESS),
			CFrame = CFrame.new(0, arenaFloorTopY + ARENA_WALL_HEIGHT * 0.5, ARENA_HALF_SIZE + ARENA_WALL_THICKNESS * 0.5),
		},
		{
			Name = "Wall_East",
			Size = Vector3.new(ARENA_WALL_THICKNESS, ARENA_WALL_HEIGHT, ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2),
			CFrame = CFrame.new(ARENA_HALF_SIZE + ARENA_WALL_THICKNESS * 0.5, arenaFloorTopY + ARENA_WALL_HEIGHT * 0.5, 0),
		},
		{
			Name = "Wall_West",
			Size = Vector3.new(ARENA_WALL_THICKNESS, ARENA_WALL_HEIGHT, ARENA_HALF_SIZE * 2 + ARENA_WALL_THICKNESS * 2),
			CFrame = CFrame.new(-ARENA_HALF_SIZE - ARENA_WALL_THICKNESS * 0.5, arenaFloorTopY + ARENA_WALL_HEIGHT * 0.5, 0),
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

			wall.Material = Enum.Material.Concrete
			wall.Color = Color3.fromRGB(82, 92, 100)
			wall.Transparency = math.min(wall.Transparency, 0.2)
			configureObstaclePart(wall, false)
			movePartBottomToY(wall, arenaFloorTopY)
		end
	end

	for _, folderName in ipairs({ "RicochetWalls", "Cover", "BoundaryWalls", "Boundaries", "Boundary" }) do
		local folder = map:FindFirstChild(folderName)

		if folder ~= nil then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					configureObstaclePart(descendant, false)
					movePartBottomToY(descendant, arenaFloorTopY)
				end
			end

			print("[WOB CONTAINMENT] Checked " .. folder:GetFullName())
		else
			print("[WOB CONTAINMENT] Optional folder missing: Map/" .. folderName)
		end
	end
end

print("[WOB CONTAINMENT] Containment repair complete. Changed/checked properties: " .. tostring(changedCount) .. ". File -> Save to File.")
