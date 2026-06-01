--!nocheck
--[[
	ApplyArenaVisualStyle.commandbar.luau

	AUTHORING UTILITY -- paste into the Roblox Studio Command Bar (View > Command Bar)
	and press Enter. It applies the dark/neon arena look (the same palette the game used
	to apply at runtime) to the CURRENTLY SELECTED objects, IN STUDIO EDIT MODE, so the
	colours/materials are baked into what you save. Because the runtime no longer recolors
	anything (see WeaponCatalog.Flags.RuntimeVisualPolishEnabled = false), Studio Edit Mode
	now matches Play Mode exactly -- what you style here is what players see.

	THIS TOOL ONLY STYLES WHAT YOU SELECT. It does not scan the Workspace, does not touch
	any container you did not select, and does not generate grid/boundary/accent geometry.
	Select the BattleArena floor/walls (or the authored layout's wall folders) and run.

	-------------------------------------------------------------------------------
	DUEL / LOBBY GUARD
	-------------------------------------------------------------------------------
	If any selected object is inside a container tagged WOBArenaRole = "Duel" or "Lobby"
	(see TagArenaRoles.commandbar.luau), the tool REFUSES to style it -- Duel and Lobby
	must stay clean. To deliberately override (rare), set ALLOW_DUEL_LOBBY = true below.

	-------------------------------------------------------------------------------
	HOW TO USE
	-------------------------------------------------------------------------------
	1. Select the arena floor / walls / cover (or the layout's CollisionWalls /
	   RicochetWalls / Cover folders) in the Explorer.
	2. Paste this whole file into the Command Bar and press Enter.
	3. Classification is by name/folder: parts named *floor*/*ground*/*baseplate* or large
	   & flat -> floor; *wall*/RicochetWall_*/in a RicochetWalls folder -> wall;
	   *cover*/Cover_Block_*/in a Cover folder -> cover. Anything else is left untouched.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

-- ===========================================================================
-- EDIT THESE TWO LINES, then paste & run.
--   STYLE        : which preset to apply ("DarkNeon" | "TeamColors" | "ArcadeBright")
--   ADD_NEON_TRIM: true = add thin neon strips along the top edge of each wall
--                  (visual-only, no collision). Set false for flat colour only.
-- ===========================================================================
local STYLE = "DarkNeon"
local ADD_NEON_TRIM = true
local ALLOW_DUEL_LOBBY = false
-- ===========================================================================

-- Each preset defines base colours/materials + a neon accent colour for the trim.
-- Add your own preset by copying a block and changing the values; then set STYLE to its key.
local PRESETS = {
	-- Dark metal/concrete with bright cyan/yellow neon edges (Tron-ish; default).
	DarkNeon = {
		Floor = { Color = Color3.fromRGB(24, 30, 40), Material = Enum.Material.Concrete, Reflectance = 0 },
		Wall = { Color = Color3.fromRGB(48, 57, 71), Material = Enum.Material.Metal, Reflectance = 0.03 },
		Cover = { Color = Color3.fromRGB(70, 75, 84), Material = Enum.Material.Metal, Reflectance = 0.02 },
		Ricochet = { Color = Color3.fromRGB(34, 120, 150), Material = Enum.Material.Metal, Reflectance = 0.05 },
		NeonWall = Color3.fromRGB(34, 198, 220), -- cyan
		NeonRicochet = Color3.fromRGB(120, 230, 255), -- bright cyan
		NeonCover = Color3.fromRGB(248, 186, 44), -- amber
	},
	-- Neutral greys with blue/red team-accent walls and matching neon.
	TeamColors = {
		Floor = { Color = Color3.fromRGB(28, 32, 38), Material = Enum.Material.Concrete, Reflectance = 0 },
		Wall = { Color = Color3.fromRGB(54, 64, 78), Material = Enum.Material.Metal, Reflectance = 0.03 },
		Cover = { Color = Color3.fromRGB(76, 80, 88), Material = Enum.Material.Metal, Reflectance = 0.02 },
		Ricochet = { Color = Color3.fromRGB(38, 132, 156), Material = Enum.Material.Metal, Reflectance = 0.05 },
		WallBlue = Color3.fromRGB(32, 116, 184),
		WallRed = Color3.fromRGB(170, 58, 50),
		NeonWall = Color3.fromRGB(90, 200, 255),
		NeonRicochet = Color3.fromRGB(120, 230, 255),
		NeonCover = Color3.fromRGB(255, 120, 90),
	},
	-- Brighter, more saturated arcade vibe.
	ArcadeBright = {
		Floor = { Color = Color3.fromRGB(44, 52, 66), Material = Enum.Material.SmoothPlastic, Reflectance = 0 },
		Wall = { Color = Color3.fromRGB(86, 98, 120), Material = Enum.Material.SmoothPlastic, Reflectance = 0.04 },
		Cover = { Color = Color3.fromRGB(120, 126, 140), Material = Enum.Material.SmoothPlastic, Reflectance = 0.02 },
		Ricochet = { Color = Color3.fromRGB(70, 170, 200), Material = Enum.Material.SmoothPlastic, Reflectance = 0.06 },
		NeonWall = Color3.fromRGB(120, 255, 200),
		NeonRicochet = Color3.fromRGB(150, 240, 255),
		NeonCover = Color3.fromRGB(255, 210, 90),
	},
}

local PALETTE = PRESETS[STYLE]
if PALETTE == nil then
	warn(("[ARENA STYLE] Unknown STYLE %q. Use one of: DarkNeon, TeamColors, ArcadeBright. Nothing was changed."):format(tostring(STYLE)))
	return
end

local NEON_TRIM_NAME = "ArenaNeonTrim" -- so re-runs replace, not stack.

local function fail(message)
	warn("[ARENA STYLE] " .. message .. " Nothing was changed.")
end

local function lower(instance)
	return string.lower(instance.Name)
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

-- Walks ancestors looking for a WOBArenaRole attribute (set by TagArenaRoles).
local function findRole(instance)
	local current = instance
	while current ~= nil and current ~= Workspace do
		local role = current:GetAttribute("WOBArenaRole")
		if typeof(role) == "string" then
			return role
		end
		current = current.Parent
	end
	return nil
end

local function isFloorPart(part)
	local name = lower(part)
	local size = part.Size
	local largeFlat = size.Y <= 4 and size.X >= 70 and size.Z >= 70
	return string.find(name, "floor", 1, true) ~= nil
		or string.find(name, "ground", 1, true) ~= nil
		or string.find(name, "baseplate", 1, true) ~= nil
		or largeFlat
end

local function isWallPart(part)
	local name = part.Name
	return string.match(name, "^Wall_") ~= nil
		or string.match(name, "^RicochetWall_") ~= nil
		or string.find(string.lower(name), "wall", 1, true) ~= nil
		or isDescendantOfFolderName(part, "RicochetWalls")
		or isDescendantOfFolderName(part, "CollisionWalls")
end

local function isCoverPart(part)
	local name = part.Name
	return string.match(name, "^Cover_Block_") ~= nil
		or string.find(string.lower(name), "cover", 1, true) ~= nil
		or isDescendantOfFolderName(part, "Cover")
end

local function smooth(part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

-- Removes any neon trim a previous run added to this part, so re-styling doesn't stack.
local function clearOldTrim(part)
	for _, child in ipairs(part:GetChildren()) do
		if child.Name == NEON_TRIM_NAME and child:IsA("BasePart") then
			child:Destroy()
		end
	end
end

-- Adds a thin neon strip along the top edge of a wall/cover part. Visual-only: no collision,
-- no query, tagged WOBVisualOnly so re-runs skip it and the runtime never treats it as a wall.
local function addNeonTrim(part, neonColor)
	if not ADD_NEON_TRIM then
		return
	end

	clearOldTrim(part)

	local size = part.Size
	local longX = size.X >= size.Z
	local trimThickness = 0.35
	local trimHeight = 0.4
	local trim = Instance.new("Part")
	trim.Name = NEON_TRIM_NAME
	trim.Anchored = true
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CanTouch = false
	trim.CastShadow = false
	trim.Material = Enum.Material.Neon
	trim.Color = neonColor
	trim:SetAttribute("WOBVisualOnly", true)

	if longX then
		trim.Size = Vector3.new(size.X * 0.96, trimHeight, trimThickness)
	else
		trim.Size = Vector3.new(trimThickness, trimHeight, size.Z * 0.96)
	end

	-- Sit it just on top of the wall, centered.
	trim.CFrame = part.CFrame * CFrame.new(0, size.Y * 0.5 + trimHeight * 0.5 - 0.05, 0)
	trim.Parent = part
end

local function styleFloor(part)
	local f = PALETTE.Floor
	part.Color = f.Color
	part.Material = f.Material
	part.Reflectance = f.Reflectance
	smooth(part)
end

local function styleWall(part, index)
	smooth(part)

	local isRicochet = string.find(lower(part), "ricochet", 1, true) ~= nil
		or isDescendantOfFolderName(part, "RicochetWalls")

	if isRicochet then
		local r = PALETTE.Ricochet
		part.Color = r.Color
		part.Material = r.Material
		part.Reflectance = r.Reflectance
		addNeonTrim(part, PALETTE.NeonRicochet)
		return
	end

	local w = PALETTE.Wall
	part.Material = w.Material
	part.Reflectance = w.Reflectance

	-- TeamColors preset alternates blue/red accent walls; other presets use the base wall colour.
	if PALETTE.WallBlue ~= nil and index % 4 == 1 then
		part.Color = PALETTE.WallBlue
	elseif PALETTE.WallRed ~= nil and index % 4 == 3 then
		part.Color = PALETTE.WallRed
	else
		part.Color = w.Color
	end

	addNeonTrim(part, PALETTE.NeonWall)
end

local function styleCover(part)
	local c = PALETTE.Cover
	part.Color = c.Color
	part.Material = c.Material
	part.Reflectance = c.Reflectance
	smooth(part)
	addNeonTrim(part, PALETTE.NeonCover)
end

local selected = Selection:Get()

if #selected == 0 then
	return fail("Selection is empty. Select the arena floor/walls/cover to style first.")
end

-- Duel/Lobby guard: refuse if anything in the selection lives under a Duel/Lobby role.
if not ALLOW_DUEL_LOBBY then
	for _, instance in ipairs(selected) do
		local role = findRole(instance)
		if role == "Duel" or role == "Lobby" then
			return fail(("Selection includes an object under a %s container (WOBArenaRole=%q). Duel/Lobby must stay clean; set ALLOW_DUEL_LOBBY=true to override."):format(
				role, role))
		end
	end
end

local floors, walls, cover, skipped = 0, 0, 0, 0
local wallIndex = 0

local function processPart(part)
	if not part:IsA("BasePart") then
		return
	end

	if part:GetAttribute("WOBVisualOnly") == true then
		skipped += 1
		return
	end

	if isFloorPart(part) then
		styleFloor(part)
		floors += 1
	elseif isWallPart(part) then
		wallIndex += 1
		styleWall(part, wallIndex)
		walls += 1
	elseif isCoverPart(part) then
		styleCover(part)
		cover += 1
	else
		skipped += 1
	end
end

for _, instance in ipairs(selected) do
	processPart(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		processPart(descendant)
	end
end

print(("[ARENA STYLE] Style=%s neonTrim=%s -> floors=%d walls=%d cover=%d (skipped %d non-arena/visual-only parts)."):format(
	STYLE, tostring(ADD_NEON_TRIM), floors, walls, cover, skipped))
