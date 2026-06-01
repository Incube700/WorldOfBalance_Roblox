-- BreakableCoverService (Update 0.2, optional): visual-only breakable cover props
-- inside the active arena. NOT colliding, NOT in the projectile filter -- they only
-- "break" when a rocket explosion happens nearby (BreakableCoverService.breakNear).
--
-- Arena-scoped: start(container) places props inside the given arena container's
-- floor extent. stop() destroys them. This is gated by ArenaSessionLifecycle so no
-- props ever appear in the lobby.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local WeaponCatalog = require(configs:WaitForChild("WeaponCatalog"))

local BreakableCoverService = {}

local RUNTIME_ROOT_NAME = "WOB_Runtime"
local ARENA_MODE_FOLDER = "ArenaMode" -- all runtime arena objects nest under WOB_Runtime/ArenaMode.
local FOLDER_NAME = "ArenaBreakables"
local ACTIVE_LAYOUT_NAME = "ActiveArenaLayout"
local BREAKABLE_SPAWNS_FOLDER = "BreakableSpawns"

local records = {}
local activeFolder = nil
local activeContainer = nil

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
	if container == nil then
		return nil
	end

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

-- Returns BreakableSpawns marker positions from the active authored layout, or empty.
local function collectMarkerPositions()
	local positions = {}
	local runtimeRoot = Workspace:FindFirstChild(RUNTIME_ROOT_NAME)
	if runtimeRoot == nil then
		return positions
	end

	local arenaMode = runtimeRoot:FindFirstChild(ARENA_MODE_FOLDER)
	if arenaMode == nil then
		return positions
	end

	local layout = arenaMode:FindFirstChild(ACTIVE_LAYOUT_NAME)
	if layout == nil then
		return positions
	end

	local markersFolder = layout:FindFirstChild(BREAKABLE_SPAWNS_FOLDER)
	if markersFolder == nil then
		return positions
	end

	for _, marker in ipairs(markersFolder:GetDescendants()) do
		if marker:IsA("BasePart") then
			table.insert(positions, marker.Position)
		end
	end

	return positions
end

local function buildProp(parent, position)
	local part = Instance.new("Part")
	part.Name = "BreakableCover"
	part.Size = Vector3.new(3.2, 4.5, 3.2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 4.5 * 0.5, 0))
	part.Anchored = true
	part.CanCollide = false -- visual-only: never blocks movement or projectiles.
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Glass
	part.Color = Color3.fromRGB(120, 150, 180)
	part.Transparency = 0.25
	part:SetAttribute("WOBVisualOnly", true)
	part.Parent = parent

	local edge = Instance.new("SelectionBox")
	edge.Adornee = part
	edge.Color3 = Color3.fromRGB(90, 200, 240)
	edge.LineThickness = 0.05
	edge.Transparency = 0.2
	edge.Parent = part

	return part
end

local function setRecordVisible(record, visible)
	if record.Part ~= nil and record.Part.Parent ~= nil then
		record.Part.Transparency = visible and 0.25 or 1
		local edge = record.Part:FindFirstChildOfClass("SelectionBox")
		if edge ~= nil then
			edge.Transparency = visible and 0.2 or 1
		end
	end

	record.Intact = visible
end

-- Called by the rocket explosion handler. Breaks any intact prop within radius.
function BreakableCoverService.breakNear(position, radius)
	if not WeaponCatalog.isUpdate02ArenaLayerEnabled() or typeof(position) ~= "Vector3" or activeFolder == nil then
		return 0
	end

	local effectiveRadius = math.max(1, tonumber(radius) or 0)
	local broken = 0
	local respawnSeconds = math.max(2, tonumber(WeaponCatalog.BreakableRespawnSeconds) or 10)

	for _, record in ipairs(records) do
		if record.Intact then
			local delta = record.Position - position

			if delta.Magnitude <= effectiveRadius then
				setRecordVisible(record, false)
				broken += 1

				-- Capture record so the closure works even if records is cleared on
				-- stop(). setRecordVisible silently no-ops if the part is gone.
				local capturedRecord = record
				task.delay(respawnSeconds, function()
					setRecordVisible(capturedRecord, true)
				end)
			end
		end
	end

	return broken
end

function BreakableCoverService.start(arenaContainer)
	if activeContainer == arenaContainer and #records > 0 then
		return
	end

	BreakableCoverService.stop()

	if not WeaponCatalog.isUpdate02ArenaLayerEnabled() then
		warn("[BREAKABLE] Update02ArenaLayerEnabled=false; breakable cover not spawned.")
		return
	end

	if WeaponCatalog.Flags.BreakablesEnabled ~= true then
		print("[BREAKABLE] Disabled via WeaponCatalog.Flags.BreakablesEnabled.")
		return
	end

	if arenaContainer == nil then
		warn("[BREAKABLE] start() called without an arena container; skipping.")
		return
	end

	local floorInfo = findContainerFloor(arenaContainer)

	if floorInfo == nil then
		warn(("[BREAKABLE] No floor found inside arena container '%s'; not spawned."):format(arenaContainer:GetFullName()))
		return
	end

	activeContainer = arenaContainer

	-- MARKERS ONLY. Breakable positions come exclusively from the authored layout's
	-- BreakableSpawns markers. No fraction fallback: no markers -> no breakables + warn.
	local markerPositions = collectMarkerPositions()

	if #markerPositions == 0 then
		activeContainer = nil
		warn("[BREAKABLE] No BreakableSpawns markers in active layout; no breakable cover spawned.")
		return
	end

	activeFolder = getOrCreateFolder(getRuntimeRoot(), FOLDER_NAME)
	activeFolder:ClearAllChildren()
	records = {}

	local positions = {}
	for _, markerPos in ipairs(markerPositions) do
		table.insert(positions, Vector3.new(markerPos.X, floorInfo.TopY, markerPos.Z))
	end
	print(("[BREAKABLE] Using %d authored layout BreakableSpawns markers."):format(#markerPositions))

	for _, position in ipairs(positions) do
		local part = buildProp(activeFolder, position)

		table.insert(records, {
			Part = part,
			Position = position,
			Intact = true,
		})
	end

	print(("[BREAKABLE] Spawned %d breakable cover props in arena '%s'."):format(#records, arenaContainer.Name))
end

function BreakableCoverService.stop()
	if activeFolder ~= nil and activeFolder.Parent ~= nil then
		activeFolder:Destroy()
	end

	activeFolder = nil
	activeContainer = nil
	records = {}
end

return BreakableCoverService
