-- ArenaMazeService (Update 0.2.x): loads the active arena LAYOUT.
--
-- AUTHORED-TEMPLATE ONLY. This service clones a Studio-authored layout template
--   ReplicatedStorage/Assets/ArenaLayouts/<WeaponCatalog.ActiveLayoutName>
-- into Workspace/WOB_Runtime/ArenaMode/ActiveArenaLayout, positioned over the active
-- arena floor. The template carries hand-placed CollisionWalls / RicochetWalls / Cover,
-- plus PickupSpawns / BreakableSpawns / PlayerSpawns / BotSpawns markers that the pickup
-- and breakable services read. Authoring/editing happens entirely in Studio -- see
-- tools/studio/CreateRicochetMazeLayout.commandbar.luau and
-- docs/ARENA_LAYOUT_AUTHORING_GUIDE.md.
--
-- THERE IS NO PROCEDURAL FALLBACK. The runtime never invents geometry. If the template
-- (or its floor target) is missing, the service NO-OPS with a Studio warning rather than
-- generating a different arena -- "prefer no spawn over a wrong spawn". The arena you see
-- in-game is exactly the model you authored and saved; nothing is recolored or generated.
--
-- Walls are made movement obstacles + projectile bounce surfaces via the
-- WOBMovementObstacle attribute. Because the cloned layout lives under WOB_Runtime
-- (outside WOB_Generated), TankMovementService is given WOB_Runtime as an extra search
-- root and ArenaSessionLifecycle calls refreshProjectileTargets() after start()/stop()
-- so the walls become live bounce surfaces.
--
-- NOTHING here ever touches the Lobby or runs in Duel: ArenaSessionLifecycle only calls
-- start() for active Training / BattleArena sessions.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local WeaponCatalog = require(configs:WaitForChild("WeaponCatalog"))

local ArenaMazeService = {}

local RUNTIME_ROOT_NAME = "WOB_Runtime"
-- All Update 0.2.x runtime objects live under WOB_Runtime/ArenaMode so the whole arena
-- layer is a single subtree (ArenaSessionLifecycle purges it on Duel/PvP start).
local ARENA_MODE_FOLDER = "ArenaMode"
local ACTIVE_LAYOUT_NAME = "ActiveArenaLayout"

local activeLayout = nil
local activeContainer = nil

-- ---------------------------------------------------------------------------
-- Runtime root / floor discovery (arena-container-scoped).
-- ---------------------------------------------------------------------------
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
	local runtime = getOrCreateFolder(Workspace, RUNTIME_ROOT_NAME)
	return getOrCreateFolder(runtime, ARENA_MODE_FOLDER)
end

local function isFloorLike(part)
	if not part:IsA("BasePart") then
		return false
	end

	local name = string.lower(part.Name)
	local size = part.Size

	return string.find(name, "floor", 1, true) ~= nil
		or string.find(name, "ground", 1, true) ~= nil
		or string.find(name, "baseplate", 1, true) ~= nil
		or (size.Y <= 4 and size.X >= 40 and size.Z >= 40)
end

local function findContainerFloor(container)
	local best = nil
	local bestArea = 0

	for _, descendant in ipairs(container:GetDescendants()) do
		if isFloorLike(descendant) then
			local area = descendant.Size.X * descendant.Size.Z
			if area > bestArea then
				bestArea = area
				best = descendant
			end
		end
	end

	if best == nil then
		return nil
	end

	return {
		Center = best.Position,
		HalfX = best.Size.X * 0.5,
		HalfZ = best.Size.Z * 0.5,
		TopY = best.Position.Y + best.Size.Y * 0.5,
	}
end

-- ---------------------------------------------------------------------------
-- Template resolution + placement.
-- ---------------------------------------------------------------------------
local function findLayoutTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end

	local layoutsFolder = assets:FindFirstChild(WeaponCatalog.LayoutAssetsFolderName or "ArenaLayouts")
	if layoutsFolder == nil then
		return nil
	end

	return layoutsFolder:FindFirstChild(WeaponCatalog.ActiveLayoutName or "RicochetMaze_01")
end

-- Bounding box (XZ center + min Y) over every BasePart in the instance.
local function measureBounds(instance)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge
	local found = false

	for _, part in ipairs(instance:GetDescendants()) do
		if part:IsA("BasePart") then
			found = true
			local p = part.Position
			local half = part.Size * 0.5
			minX = math.min(minX, p.X - half.X)
			maxX = math.max(maxX, p.X + half.X)
			minZ = math.min(minZ, p.Z - half.Z)
			maxZ = math.max(maxZ, p.Z + half.Z)
			minY = math.min(minY, p.Y - half.Y)
		end
	end

	if not found then
		return nil
	end

	return {
		CenterX = (minX + maxX) * 0.5,
		CenterZ = (minZ + maxZ) * 0.5,
		MinY = minY,
	}
end

-- Translate every BasePart in the layout so the layout's footprint centers on the arena
-- floor in XZ and rests its lowest part on the floor surface.
local function placeLayoutOnFloor(layout, floorInfo)
	local bounds = measureBounds(layout)
	if bounds == nil then
		return
	end

	local offset = Vector3.new(
		floorInfo.Center.X - bounds.CenterX,
		floorInfo.TopY - bounds.MinY,
		floorInfo.Center.Z - bounds.CenterZ
	)

	for _, part in ipairs(layout:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + offset
		end
	end
end

-- Guarantee walls/cover are detected as obstacles + bounce surfaces regardless of how
-- the author saved them (defensive: the Command Bar already sets these).
local function enforceWallAttributes(layout)
	local folders = WeaponCatalog.LayoutFolders or {}

	local function tagFolder(folderName, isRicochet)
		local folder = layout:FindFirstChild(folderName)
		if folder == nil then
			return
		end
		for _, part in ipairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				part:SetAttribute("WOBMovementObstacle", true)
				if isRicochet then
					part:SetAttribute("WOBRicochetWall", true)
				end
				part.CanQuery = true -- required for movement + projectile raycasts.
			end
		end
	end

	tagFolder(folders.CollisionWalls or "CollisionWalls", false)
	tagFolder(folders.RicochetWalls or "RicochetWalls", true)
	tagFolder(folders.Cover or "Cover", false)
end

-- ---------------------------------------------------------------------------
-- Public: marker access for ArenaPickupService / BreakableCoverService.
-- ---------------------------------------------------------------------------
function ArenaMazeService.getActiveLayout()
	if activeLayout ~= nil and activeLayout.Parent ~= nil then
		return activeLayout
	end
	return nil
end

-- Returns the BaseParts inside a named folder of the active layout (or empty list).
function ArenaMazeService.getLayoutMarkers(folderName)
	local markers = {}
	local layout = ArenaMazeService.getActiveLayout()
	if layout == nil then
		return markers
	end

	local folder = layout:FindFirstChild(folderName)
	if folder == nil then
		return markers
	end

	for _, child in ipairs(folder:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(markers, child)
		end
	end

	return markers
end

-- ---------------------------------------------------------------------------
-- Lifecycle.
-- ---------------------------------------------------------------------------
function ArenaMazeService.start(arenaContainer)
	if activeContainer == arenaContainer and activeLayout ~= nil and activeLayout.Parent ~= nil then
		return
	end

	ArenaMazeService.stop()

	if not WeaponCatalog.isUpdate02ArenaLayerEnabled() then
		warn("[MAZE] Update02ArenaLayerEnabled=false; authored arena layout not loaded.")
		return
	end

	if WeaponCatalog.Flags.MazeEnabled ~= true then
		print("[MAZE] Disabled via WeaponCatalog.Flags.MazeEnabled.")
		return
	end

	if arenaContainer == nil then
		warn("[MAZE] start() called without an arena container; skipping.")
		return
	end

	local floorInfo = findContainerFloor(arenaContainer)

	if floorInfo == nil then
		warn(("[MAZE] No floor found inside arena container '%s'; layout not loaded."):format(arenaContainer:GetFullName()))
		return
	end

	activeContainer = arenaContainer

	-- AUTHORED-TEMPLATE ONLY. No procedural fallback: if the template is missing we spawn
	-- nothing and warn, rather than inventing a different arena.
	local template = findLayoutTemplate()

	if template == nil then
		activeContainer = nil
		warn("[MAZE] Arena layout template missing; no runtime maze spawned.")
		return
	end

	local clone = template:Clone()
	clone.Name = ACTIVE_LAYOUT_NAME
	placeLayoutOnFloor(clone, floorInfo)
	enforceWallAttributes(clone)
	clone.Parent = getRuntimeRoot()
	activeLayout = clone
	print(("[MAZE] Loaded authored layout '%s' into '%s/%s/%s'."):format(
		tostring(WeaponCatalog.ActiveLayoutName), RUNTIME_ROOT_NAME, ARENA_MODE_FOLDER, ACTIVE_LAYOUT_NAME))
end

function ArenaMazeService.stop()
	if activeLayout ~= nil and activeLayout.Parent ~= nil then
		activeLayout:Destroy()
	end

	activeLayout = nil
	activeContainer = nil
end

return ArenaMazeService
