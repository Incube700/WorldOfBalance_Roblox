-- Visual-only arena polish for release screenshots.
-- This script does not change collision, movement, projectile, or gameplay state.

local Workspace = game:GetService("Workspace")

local ROOT_NAME = "WOB_Generated"
local RUNTIME_ROOT_NAME = "WOB_Runtime"
local VISUAL_FOLDER_NAME = "ArenaVisualPolish"
local RESCAN_DELAY_SECONDS = 0.75

local ARENA_CONTAINER_NAMES = {
	"Map",
	"BattleArena",
}

local ARENA_CONTAINER_NAME_SET = {
	Map = true,
	BattleArena = true,
}

local GRID_SPACING = 32
local GRID_LINE_WIDTH = 0.18
local FLOOR_OVERLAY_THICKNESS = 0.08
local FLOOR_OVERLAY_MARGIN = 0.992
local FLOOR_VISUAL_LIFT = 0.045
local BOUNDARY_ACCENT_WIDTH = 0.5
local BOUNDARY_ACCENT_HEIGHT = 0.08
local MAX_GRID_LINES_PER_AXIS = 22
local MAX_ACCENT_PARTS = 96

local COLORS = {
	Floor = Color3.fromRGB(27, 34, 44),
	FloorOverlay = Color3.fromRGB(20, 27, 36),
	FloorGrid = Color3.fromRGB(46, 82, 104),
	Wall = Color3.fromRGB(54, 64, 78),
	WallBlue = Color3.fromRGB(32, 116, 184),
	WallRed = Color3.fromRGB(170, 58, 50),
	Ricochet = Color3.fromRGB(38, 132, 156),
	Cover = Color3.fromRGB(76, 80, 88),
	AccentYellow = Color3.fromRGB(248, 186, 44),
	AccentOrange = Color3.fromRGB(244, 116, 36),
	AccentCyan = Color3.fromRGB(34, 198, 220),
	Black = Color3.fromRGB(14, 16, 20),
}

local SKIP_ANCESTOR_NAMES = {
	SpawnPoints = true,
	Spawns = true,
	SpawnMarkers = true,
	Runtime = true,
	TestObjects = true,
}

local SKIP_NAME_FRAGMENTS = {
	"spawn",
	"trigger",
	"hitbox",
	"controlzone",
	"capture",
	"sensor",
}

local connectedContainers = {}
local rescanScheduled = false

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function getRuntimeRoot()
	local runtimeRoot = Workspace:FindFirstChild(RUNTIME_ROOT_NAME)

	if runtimeRoot == nil then
		runtimeRoot = Instance.new("Folder")
		runtimeRoot.Name = RUNTIME_ROOT_NAME
		runtimeRoot.Parent = Workspace
	end

	return runtimeRoot
end

local function hasAncestorNamed(instance, names)
	local current = instance.Parent

	while current ~= nil and current ~= Workspace do
		if names[current.Name] == true then
			return true
		end

		current = current.Parent
	end

	return false
end

local function lowerName(instance)
	return string.lower(instance.Name)
end

local function isWorldBaseplate(part)
	return part ~= nil
		and part:IsA("BasePart")
		and part.Name == "Baseplate"
		and part.Parent == Workspace
end

local function getBaseplateTopY()
	local baseplate = Workspace:FindFirstChild("Baseplate")

	if baseplate ~= nil and baseplate:IsA("BasePart") then
		return baseplate.Position.Y + baseplate.Size.Y * 0.5
	end

	return nil
end

local function getVisibleFloorTopY(floorPart)
	local floorTopY = floorPart.Position.Y + floorPart.Size.Y * 0.5
	local baseplateTopY = getBaseplateTopY()

	if not isWorldBaseplate(floorPart) and baseplateTopY ~= nil and floorTopY < baseplateTopY then
		return baseplateTopY
	end

	return floorTopY
end

local function shouldSkipPart(part)
	if part:GetAttribute("WOBVisualOnly") == true then
		return true
	end

	if part.Transparency >= 0.95 then
		return true
	end

	if hasAncestorNamed(part, SKIP_ANCESTOR_NAMES) then
		return true
	end

	local name = lowerName(part)

	for _, fragment in ipairs(SKIP_NAME_FRAGMENTS) do
		if string.find(name, fragment, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function isDescendantOfFolderName(instance, folderName)
	local current = instance.Parent

	while current ~= nil and current ~= Workspace do
		if current.Name == folderName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isFloorPart(part)
	local name = lowerName(part)
	local size = part.Size
	local isLargeFlatPart = size.Y <= 4 and size.X >= 70 and size.Z >= 70

	return string.find(name, "floor", 1, true) ~= nil
		or string.find(name, "baseplate", 1, true) ~= nil
		or string.find(name, "ground", 1, true) ~= nil
		or isLargeFlatPart
end

local function isWallPart(part)
	local name = part.Name
	local lname = string.lower(name)

	return string.match(name, "^Wall_") ~= nil
		or string.match(name, "^RicochetWall_") ~= nil
		or string.find(lname, "wall", 1, true) ~= nil
		or isDescendantOfFolderName(part, "RicochetWalls")
		or isDescendantOfFolderName(part, "ArenaBoundary")
		or isDescendantOfFolderName(part, "Boundaries")
end

local function isCoverPart(part)
	local name = part.Name
	local lname = string.lower(name)

	return string.match(name, "^Cover_Block_") ~= nil
		or string.find(lname, "cover", 1, true) ~= nil
		or string.find(lname, "block", 1, true) ~= nil
		or isDescendantOfFolderName(part, "Cover")
end

local function smoothVisualSurface(part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function styleFloor(part)
	part.Color = COLORS.Floor
	part.Material = Enum.Material.Concrete
	part.Reflectance = 0
	smoothVisualSurface(part)

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			child.Transparency = 1
		end
	end
end

local function styleWall(part, index)
	local name = lowerName(part)

	part.Material = Enum.Material.Metal
	part.Reflectance = 0.02
	smoothVisualSurface(part)

	if string.find(name, "ricochet", 1, true) ~= nil or isDescendantOfFolderName(part, "RicochetWalls") then
		part.Color = COLORS.Ricochet
	elseif index % 4 == 1 then
		part.Color = COLORS.WallBlue
	elseif index % 4 == 3 then
		part.Color = COLORS.WallRed
	else
		part.Color = COLORS.Wall
	end
end

local function styleCover(part)
	part.Color = COLORS.Cover
	part.Material = Enum.Material.Metal
	part.Reflectance = 0.01
	smoothVisualSurface(part)
end

local function createVisualPart(parent, name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part:SetAttribute("WOBVisualOnly", true)
	part.Parent = parent

	smoothVisualSurface(part)

	return part
end

local function getLargestFloorPart(floorParts)
	local bestPart = nil
	local bestArea = 0

	for _, part in ipairs(floorParts) do
		local area = part.Size.X * part.Size.Z

		if area > bestArea then
			bestArea = area
			bestPart = part
		end
	end

	return bestPart
end

local function buildGridOffsets(halfSize)
	local offsets = {}
	local maxIndex = math.floor(halfSize / GRID_SPACING)
	local startIndex = math.max(-MAX_GRID_LINES_PER_AXIS, -maxIndex)
	local endIndex = math.min(MAX_GRID_LINES_PER_AXIS, maxIndex)

	for index = startIndex, endIndex do
		local offset = index * GRID_SPACING

		if math.abs(offset) > 1 and math.abs(offset) < halfSize - GRID_SPACING * 0.35 then
			table.insert(offsets, offset)
		end
	end

	return offsets
end

local function addFloorGrid(visualFolder, floorPart)
	local gridFolder = getOrCreateFolder(visualFolder, "FloorGrid")
	gridFolder:ClearAllChildren()

	local floorSize = floorPart.Size
	local yOffset = (getVisibleFloorTopY(floorPart) - floorPart.Position.Y)
		+ FLOOR_OVERLAY_THICKNESS
		+ FLOOR_VISUAL_LIFT
	local xOffsets = buildGridOffsets(floorSize.X * 0.5)
	local zOffsets = buildGridOffsets(floorSize.Z * 0.5)

	for _, xOffset in ipairs(xOffsets) do
		createVisualPart(
			gridFolder,
			"GridLine_X",
			Vector3.new(GRID_LINE_WIDTH, 0.035, floorSize.Z * 0.94),
			floorPart.CFrame * CFrame.new(xOffset, yOffset, 0),
			COLORS.FloorGrid,
			Enum.Material.SmoothPlastic,
			0.28
		)
	end

	for _, zOffset in ipairs(zOffsets) do
		createVisualPart(
			gridFolder,
			"GridLine_Z",
			Vector3.new(floorSize.X * 0.94, 0.035, GRID_LINE_WIDTH),
			floorPart.CFrame * CFrame.new(0, yOffset, zOffset),
			COLORS.FloorGrid,
			Enum.Material.SmoothPlastic,
			0.28
		)
	end
end

local function addFloorOverlay(visualFolder, floorPart)
	if isWorldBaseplate(floorPart) then
		return 0
	end

	local overlayFolder = getOrCreateFolder(visualFolder, "FloorOverlay")
	local floorSize = floorPart.Size
	local yOffset = (getVisibleFloorTopY(floorPart) - floorPart.Position.Y)
		+ FLOOR_OVERLAY_THICKNESS * 0.5
		+ FLOOR_VISUAL_LIFT

	createVisualPart(
		overlayFolder,
		"FloorOverlay_" .. floorPart.Name,
		Vector3.new(floorSize.X * FLOOR_OVERLAY_MARGIN, FLOOR_OVERLAY_THICKNESS, floorSize.Z * FLOOR_OVERLAY_MARGIN),
		floorPart.CFrame * CFrame.new(0, yOffset, 0),
		COLORS.FloorOverlay,
		Enum.Material.Metal,
		0
	)

	return 1
end

local function addFloorOverlays(visualFolder, floorParts)
	local overlayFolder = getOrCreateFolder(visualFolder, "FloorOverlay")
	overlayFolder:ClearAllChildren()

	local count = 0

	for _, floorPart in ipairs(floorParts) do
		count += addFloorOverlay(visualFolder, floorPart)
	end

	return count
end

local function addFloorBoundaryAccents(visualFolder, floorPart)
	if isWorldBaseplate(floorPart) then
		return 0
	end

	local accentFolder = getOrCreateFolder(visualFolder, "BoundaryNeon")
	accentFolder:ClearAllChildren()

	local floorSize = floorPart.Size
	local yOffset = (getVisibleFloorTopY(floorPart) - floorPart.Position.Y)
		+ FLOOR_OVERLAY_THICKNESS
		+ FLOOR_VISUAL_LIFT
		+ BOUNDARY_ACCENT_HEIGHT * 0.5
	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local longX = math.max(1, floorSize.X * FLOOR_OVERLAY_MARGIN)
	local longZ = math.max(1, floorSize.Z * FLOOR_OVERLAY_MARGIN)
	local inset = BOUNDARY_ACCENT_WIDTH * 0.5 + 0.1

	createVisualPart(
		accentFolder,
		"BoundaryNeon_North",
		Vector3.new(longX, BOUNDARY_ACCENT_HEIGHT, BOUNDARY_ACCENT_WIDTH),
		floorPart.CFrame * CFrame.new(0, yOffset, halfZ - inset),
		COLORS.AccentCyan,
		Enum.Material.Neon,
		0.12
	)
	createVisualPart(
		accentFolder,
		"BoundaryNeon_South",
		Vector3.new(longX, BOUNDARY_ACCENT_HEIGHT, BOUNDARY_ACCENT_WIDTH),
		floorPart.CFrame * CFrame.new(0, yOffset, -halfZ + inset),
		COLORS.AccentCyan,
		Enum.Material.Neon,
		0.12
	)
	createVisualPart(
		accentFolder,
		"BoundaryNeon_East",
		Vector3.new(BOUNDARY_ACCENT_WIDTH, BOUNDARY_ACCENT_HEIGHT, longZ),
		floorPart.CFrame * CFrame.new(halfX - inset, yOffset, 0),
		COLORS.AccentYellow,
		Enum.Material.Neon,
		0.14
	)
	createVisualPart(
		accentFolder,
		"BoundaryNeon_West",
		Vector3.new(BOUNDARY_ACCENT_WIDTH, BOUNDARY_ACCENT_HEIGHT, longZ),
		floorPart.CFrame * CFrame.new(-halfX + inset, yOffset, 0),
		COLORS.AccentYellow,
		Enum.Material.Neon,
		0.14
	)

	return 4
end

local function addTopAccent(visualFolder, sourcePart, color)
	local sourceSize = sourcePart.Size
	local isLongX = sourceSize.X >= sourceSize.Z
	local accentSize

	if isLongX then
		accentSize = Vector3.new(math.max(2, sourceSize.X * 0.88), 0.12, math.min(0.75, math.max(0.35, sourceSize.Z * 0.22)))
	else
		accentSize = Vector3.new(math.min(0.75, math.max(0.35, sourceSize.X * 0.22)), 0.12, math.max(2, sourceSize.Z * 0.88))
	end

	createVisualPart(
		visualFolder,
		"Accent_" .. sourcePart.Name,
		accentSize,
		sourcePart.CFrame * CFrame.new(0, sourceSize.Y * 0.5 + 0.09, 0),
		color,
		Enum.Material.Neon,
		0.08
	)

	return 1
end

local function addHazardStripes(visualFolder, sourcePart)
	local sourceSize = sourcePart.Size
	local longAxisX = sourceSize.X >= sourceSize.Z
	local stripeCount = math.clamp(math.floor((longAxisX and sourceSize.X or sourceSize.Z) / 9), 2, 6)
	local longLength = longAxisX and sourceSize.X or sourceSize.Z
	local spacing = longLength / (stripeCount + 1)

	for index = 1, stripeCount do
		local localOffset = -longLength * 0.5 + spacing * index
		local localCFrame
		local stripeSize

		if longAxisX then
			localCFrame = CFrame.new(localOffset, sourceSize.Y * 0.5 + 0.16, 0) * CFrame.Angles(0, math.rad(28), 0)
			stripeSize = Vector3.new(0.35, 0.13, math.min(sourceSize.Z * 0.8, 3))
		else
			localCFrame = CFrame.new(0, sourceSize.Y * 0.5 + 0.16, localOffset) * CFrame.Angles(0, math.rad(-28), 0)
			stripeSize = Vector3.new(math.min(sourceSize.X * 0.8, 3), 0.13, 0.35)
		end

		createVisualPart(
			visualFolder,
			"HazardStripe_" .. sourcePart.Name,
			stripeSize,
			sourcePart.CFrame * localCFrame,
			COLORS.Black,
			Enum.Material.SmoothPlastic,
			0.05
		)
	end
end

local function addAccents(visualFolder, wallParts, coverParts)
	local accentsFolder = getOrCreateFolder(visualFolder, "Accents")
	accentsFolder:ClearAllChildren()

	local created = 0
	local neonAccentCount = 0

	for _, part in ipairs(wallParts) do
		if created >= MAX_ACCENT_PARTS then
			break
		end

		local color = isDescendantOfFolderName(part, "RicochetWalls") and COLORS.AccentCyan or COLORS.AccentYellow
		neonAccentCount += addTopAccent(accentsFolder, part, color)
		created += 1
	end

	for _, part in ipairs(coverParts) do
		if created >= MAX_ACCENT_PARTS then
			break
		end

		neonAccentCount += addTopAccent(accentsFolder, part, COLORS.AccentOrange)
		addHazardStripes(accentsFolder, part)
		created += 1
	end

	return neonAccentCount
end

local function getVisualFolderForContainer(visualRoot, container)
	local folder = getOrCreateFolder(visualRoot, tostring(container.Name))
	folder:ClearAllChildren()

	return folder
end

local function collectAndStyleMap(map)
	local floorParts = {}
	local wallParts = {}
	local coverParts = {}
	local wallIndex = 0

	local function processPart(part)
		if not part:IsA("BasePart") or shouldSkipPart(part) then
			return
		end

		if isFloorPart(part) then
			styleFloor(part)
			table.insert(floorParts, part)
		elseif isWallPart(part) then
			wallIndex += 1
			styleWall(part, wallIndex)
			table.insert(wallParts, part)
		elseif isCoverPart(part) then
			styleCover(part)
			table.insert(coverParts, part)
		end
	end

	if map:IsA("BasePart") then
		processPart(map)
	end

	for _, descendant in ipairs(map:GetDescendants()) do
		processPart(descendant)
	end

	return floorParts, wallParts, coverParts
end

local function applyVisualPolishToContainer(visualRoot, container)
	local visualFolder = getVisualFolderForContainer(visualRoot, container)
	local floorParts, wallParts, coverParts = collectAndStyleMap(container)
	local primaryFloor = getLargestFloorPart(floorParts)
	local floorOverlayCount = addFloorOverlays(visualFolder, floorParts)
	local neonAccentCount = 0

	if primaryFloor ~= nil and not isWorldBaseplate(primaryFloor) then
		neonAccentCount += addFloorBoundaryAccents(visualFolder, primaryFloor)
		addFloorGrid(visualFolder, primaryFloor)
	end

	neonAccentCount += addAccents(visualFolder, wallParts, coverParts)

	print(("[ARENA VISUAL] container=%s floors=%d floorOverlays=%d walls=%d cover=%d neonAccents=%d"):format(
		container:GetFullName(),
		#floorParts,
		floorOverlayCount,
		#wallParts,
		#coverParts,
		neonAccentCount
	))

	return #floorParts, #wallParts, #coverParts, floorOverlayCount, neonAccentCount
end

local function getArenaContainers(root)
	local containers = {}

	for _, containerName in ipairs(ARENA_CONTAINER_NAMES) do
		local container = root:FindFirstChild(containerName)

		if container ~= nil then
			table.insert(containers, container)
		end
	end

	local baseplate = Workspace:FindFirstChild("Baseplate")

	if baseplate ~= nil and baseplate:IsA("BasePart") then
		table.insert(containers, baseplate)
	end

	return containers
end

local function applyArenaVisualPolish(reason)
	local root = Workspace:FindFirstChild(ROOT_NAME)

	if root == nil then
		warn("[ARENA VISUAL] Workspace/" .. ROOT_NAME .. " not found; arena visual polish skipped.")
		return
	end

	local containers = getArenaContainers(root)

	if #containers == 0 then
		warn("[ARENA VISUAL] no supported arena containers found under Workspace/" .. ROOT_NAME)
		return
	end

	local runtimeRoot = getRuntimeRoot()
	local visualRoot = getOrCreateFolder(runtimeRoot, VISUAL_FOLDER_NAME)
	visualRoot:ClearAllChildren()

	local totalFloors = 0
	local totalWalls = 0
	local totalCover = 0
	local totalFloorOverlays = 0
	local totalNeonAccents = 0
	local containerNames = {}

	for _, container in ipairs(containers) do
		local floors, walls, cover, floorOverlays, neonAccents = applyVisualPolishToContainer(visualRoot, container)
		totalFloors += floors or 0
		totalWalls += walls or 0
		totalCover += cover or 0
		totalFloorOverlays += floorOverlays or 0
		totalNeonAccents += neonAccents or 0
		table.insert(containerNames, container.Name)
	end

	print(("[ARENA VISUAL] applied reason=%s supported=%s totals floors=%d floorOverlays=%d walls=%d cover=%d neonAccents=%d"):format(
		tostring(reason or "Startup"),
		table.concat(containerNames, ","),
		totalFloors,
		totalFloorOverlays,
		totalWalls,
		totalCover,
		totalNeonAccents
	))
end

local function scheduleArenaVisualPolish(reason)
	if rescanScheduled then
		return
	end

	rescanScheduled = true

	task.delay(RESCAN_DELAY_SECONDS, function()
		rescanScheduled = false
		applyArenaVisualPolish(reason)
	end)
end

local function connectContainer(container)
	if container == nil or connectedContainers[container] == true then
		return
	end

	connectedContainers[container] = true

	container.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			scheduleArenaVisualPolish("DescendantAdded:" .. container.Name)
		end
	end)
end

local function startArenaVisualPolish()
	local root = Workspace:WaitForChild(ROOT_NAME, 30)

	if root == nil then
		warn("[ARENA VISUAL] Workspace/" .. ROOT_NAME .. " not found; arena visual polish skipped.")
		return
	end

	for _, container in ipairs(getArenaContainers(root)) do
		connectContainer(container)
	end

	root.ChildAdded:Connect(function(child)
		if ARENA_CONTAINER_NAME_SET[child.Name] == true then
			connectContainer(child)
			scheduleArenaVisualPolish("ChildAdded:" .. child.Name)
		end
	end)

	applyArenaVisualPolish("Startup")
end

startArenaVisualPolish()
