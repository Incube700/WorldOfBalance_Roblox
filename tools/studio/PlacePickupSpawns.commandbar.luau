--!nocheck
--[[
	PlacePickupSpawns.commandbar.luau

	AUTHORING UTILITY -- paste into the Roblox Studio Command Bar (View > Command Bar)
	and press Enter. It creates weapon/item PICKUP SPAWN MARKERS inside your authored arena
	layout, so ArenaPickupService spawns the matching pickups at those exact spots.

	WHAT IT MAKES
	-------------------------------------------------------------------------------
	For the chosen PICKUP_TYPE it adds one marker named  PickupSpawn_<Type>_<N>  into a
	"PickupSpawns" folder under your selected layout Model/Folder. Each marker is:
	  * a flat, semi-transparent, NON-colliding disc (CanCollide/CanQuery/CanTouch = false)
	  * tagged with attribute  WOBPickupType = <Type>  (this is what the runtime reads)
	  * tinted to match the pickup's accent colour so you can tell them apart in Edit Mode.
	The runtime reads only the marker POSITION + type; the disc itself never shows in-game.

	HOW TO USE
	-------------------------------------------------------------------------------
	1. Select ONE thing to parent the markers under -- normally your authored layout Model
	   (e.g. Workspace.WOB_Authoring.ArenaLayouts.RicochetMaze_01) or its PickupSpawns folder.
	   If you select a BasePart, markers spawn near it.
	2. Set PICKUP_TYPE and COUNT below.
	3. Paste this whole file into the Command Bar and run. Re-run with a different type to
	   add more. Move the markers wherever you want afterwards.

	VALID PICKUP TYPES (must match WeaponCatalog.Pickups + ArenaPickupService map):
	   "Rocket" | "MachineGun" | "RailGun" | "Repair" | "Shield" | "PhaseShot"
	NOTE: pickups only actually SPAWN in-game when Update02ArenaLayerEnabled = true and the
	pickup's own flag is on. Placing markers now is safe regardless of those flags.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

-- ===========================================================================
-- EDIT THESE, then paste & run.
-- ===========================================================================
local PICKUP_TYPE = "Rocket" -- Rocket | MachineGun | RailGun | Repair | Shield | PhaseShot
local COUNT = 1 -- how many markers of this type to create this run
-- ===========================================================================

local PICKUP_SPAWNS_FOLDER = "PickupSpawns"

-- Accent tints (mirror WeaponCatalog accent colours) so markers are readable in Studio.
local TINTS = {
	Rocket = Color3.fromRGB(255, 130, 60),
	MachineGun = Color3.fromRGB(255, 215, 90),
	RailGun = Color3.fromRGB(120, 220, 255),
	Repair = Color3.fromRGB(80, 235, 140),
	Shield = Color3.fromRGB(120, 200, 255),
	PhaseShot = Color3.fromRGB(150, 130, 255),
}

local function fail(message)
	warn("[PICKUP SPAWNS] " .. message .. " Nothing was created.")
end

if TINTS[PICKUP_TYPE] == nil then
	return fail(("Unknown PICKUP_TYPE %q. Use Rocket, MachineGun, RailGun, Repair, Shield, or PhaseShot."):format(tostring(PICKUP_TYPE)))
end

local count = math.clamp(math.floor(tonumber(COUNT) or 1), 1, 24)

local selected = Selection:Get()
if #selected == 0 then
	return fail("Selection is empty. Select your authored layout Model (or its PickupSpawns folder) first.")
end

local anchor = selected[1]

-- Resolve the PickupSpawns folder: if a folder named PickupSpawns is selected (or is a
-- child of the selection), use it; otherwise create one under the selected container.
local function resolveSpawnsFolder(container)
	if container.Name == PICKUP_SPAWNS_FOLDER and (container:IsA("Folder") or container:IsA("Model")) then
		return container
	end

	local existing = container:FindFirstChild(PICKUP_SPAWNS_FOLDER)
	if existing ~= nil then
		return existing
	end

	if container:IsA("BasePart") then
		-- A loose part was selected: park the folder under the part's parent.
		container = container.Parent or container
		local underParent = container:FindFirstChild(PICKUP_SPAWNS_FOLDER)
		if underParent ~= nil then
			return underParent
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = PICKUP_SPAWNS_FOLDER
	folder.Parent = container
	return folder
end

local spawnsFolder = resolveSpawnsFolder(anchor)

-- Base position to scatter new markers around (centre of the anchor, on the floor plane).
local function getAnchorPosition()
	if anchor:IsA("BasePart") then
		return anchor.Position
	end
	if anchor:IsA("Model") then
		local ok, cf = pcall(function()
			return (anchor:GetBoundingBox())
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position
		end
	end
	return Vector3.new(0, 0, 0)
end

local basePos = getAnchorPosition()

-- Next free index so re-runs don't overwrite existing markers of the same type.
local function nextIndex()
	local maxN = 0
	for _, child in ipairs(spawnsFolder:GetChildren()) do
		local n = tonumber(string.match(child.Name, "^PickupSpawn_" .. PICKUP_TYPE .. "_(%d+)$"))
		if n ~= nil and n > maxN then
			maxN = n
		end
	end
	return maxN + 1
end

local startIndex = nextIndex()
local tint = TINTS[PICKUP_TYPE]

for i = 0, count - 1 do
	local index = startIndex + i
	local marker = Instance.new("Part")
	marker.Name = ("PickupSpawn_%s_%d"):format(PICKUP_TYPE, index)
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.4, 4, 4) -- flat disc (cylinder lying on its side once rotated)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = tint
	marker.Transparency = 0.45
	marker:SetAttribute("WOBPickupType", PICKUP_TYPE)
	marker:SetAttribute("WOBVisualOnly", true)
	-- Lay the cylinder flat and scatter slightly so stacked re-runs don't overlap exactly.
	local offset = Vector3.new((i % 4) * 6, 1, math.floor(i / 4) * 6)
	marker.CFrame = CFrame.new(basePos + offset) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = spawnsFolder
end

print(("[PICKUP SPAWNS] Added %d %q marker(s) to %s (starting index %d)."):format(
	count, PICKUP_TYPE, spawnsFolder:GetFullName(), startIndex))
