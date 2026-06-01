--!nocheck
--[[
	CreateRicochetMazeLayout.commandbar.luau

	AUTHORING UTILITY -- paste this whole file into the Roblox Studio Command Bar
	(View > Command Bar) and press Enter. It builds an editable arena layout, positioned
	RELATIVE TO THE BATTLEARENA FLOOR YOU SELECTED, under:

		Workspace
		  WOB_Authoring
		    ArenaLayouts
		      RicochetMaze_01
		        CollisionWalls      -- physical, projectile-bouncing walls (darker)
		        RicochetWalls       -- physical, projectile-bouncing walls (neon accent)
		        Cover               -- physical cover blocks
		        PickupSpawns        -- markers: where pickups appear (type by name/attr)
		        PlayerSpawns        -- markers: player tank spawn points
		        BotSpawns           -- markers: bot tank spawn points
		        BreakableSpawns     -- markers: optional breakable cover
		        Visuals             -- non-colliding decorative accents

	-------------------------------------------------------------------------------
	REQUIRES A SELECTED FLOOR (no guessing).
	-------------------------------------------------------------------------------
	Before running, SELECT exactly ONE BasePart that is the BattleArena floor, tagged:
	    WOBArenaFloor = true
	    WOBArenaRole  = "BattleArena"
	(Use tools/studio/TagArenaRoles.commandbar.luau with TARGET="Floor" ROLE="BattleArena"
	to tag it.) This tool NEVER scans the Workspace, never picks "the largest floor", and
	never uses hardcoded world coordinates. If the selection is empty, has more than one
	item, is not a BasePart, or is not tagged as the BattleArena floor, it creates NOTHING
	and tells you why. The layout is generated relative to the selected floor's CFrame and
	Size, so it lands exactly on that arena and adapts to its dimensions.

	After running, MOVE / EDIT / DELETE parts freely in Studio, then export the
	RicochetMaze_01 model:
		right-click RicochetMaze_01 > Save to File...  ->
		src/ReplicatedStorage/Assets/ArenaLayouts/RicochetMaze_01.rbxm

	This is an AUTHORING tool only. It does NOT run in production and the runtime never
	reads WOB_Authoring -- it reads the exported template from
	ReplicatedStorage/Assets/ArenaLayouts at session start. See
	docs/ARENA_LAYOUT_AUTHORING_GUIDE.md.

	Re-running is safe: it deletes and rebuilds RicochetMaze_01 only.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local LAYOUT_NAME = "RicochetMaze_01"

local WALL_HEIGHT = 7
local WALL_THICKNESS = 2

-- Colors / materials. Distinct so the author can tell wall classes apart at a glance.
local COLLISION_COLOR = Color3.fromRGB(60, 70, 84) -- darker, "solid"
local RICOCHET_COLOR = Color3.fromRGB(64, 196, 224) -- neon accent, "bouncy"
local COVER_COLOR = Color3.fromRGB(120, 150, 180)
local VISUAL_COLOR = Color3.fromRGB(90, 110, 130)

local PICKUP_COLORS = {
	Rocket = Color3.fromRGB(255, 130, 60),
	MachineGun = Color3.fromRGB(255, 215, 90),
	Repair = Color3.fromRGB(80, 235, 140),
	Shield = Color3.fromRGB(110, 170, 255),
}
local PLAYER_SPAWN_COLOR = Color3.fromRGB(120, 255, 170)
local BOT_SPAWN_COLOR = Color3.fromRGB(255, 120, 120)
local BREAKABLE_COLOR = Color3.fromRGB(150, 200, 230)

-- ---------------------------------------------------------------------------
-- Selection validation (Task E). Fail = create nothing.
-- ---------------------------------------------------------------------------
local function abort(message)
	warn("[LAYOUT GEN] " .. message .. " Nothing was created.")
end

local selected = Selection:Get()

if #selected == 0 then
	return abort("Select the BattleArena floor first (a BasePart tagged WOBArenaFloor=true, WOBArenaRole=\"BattleArena\").")
end

if #selected > 1 then
	return abort(("Select exactly ONE floor part; %d items are selected."):format(#selected))
end

local floor = selected[1]

if not floor:IsA("BasePart") then
	return abort(("Selected '%s' is a %s, not a BasePart."):format(floor.Name, floor.ClassName))
end

if floor:GetAttribute("WOBArenaFloor") ~= true then
	return abort(("Selected '%s' is not tagged WOBArenaFloor=true."):format(floor.Name))
end

if floor:GetAttribute("WOBArenaRole") ~= "BattleArena" then
	return abort(("Selected '%s' is not tagged WOBArenaRole=\"BattleArena\" (got %q)."):format(
		floor.Name, tostring(floor:GetAttribute("WOBArenaRole"))))
end

-- Floor geometry. We author in the floor's LOCAL frame: X/Z spread as fractions of the
-- floor half-extent, Y measured up from the floor's TOP surface. This adapts to the real
-- arena size and respects the floor's rotation.
local floorCFrame = floor.CFrame
local halfX = floor.Size.X * 0.5
local halfZ = floor.Size.Z * 0.5
local topLocalY = floor.Size.Y * 0.5 -- top surface, in floor-local Y.

-- Convert (fractionX, fractionZ, localYAboveTop) into a world CFrame on this floor.
local function placeOnFloor(fractionX, fractionZ, localYAboveTop, rotationY)
	local localCFrame = CFrame.new(fractionX * halfX, topLocalY + localYAboveTop, fractionZ * halfZ)
	if rotationY then
		localCFrame = localCFrame * CFrame.Angles(0, math.rad(rotationY), 0)
	end
	return floorCFrame * localCFrame
end

-- ---------------------------------------------------------------------------
-- Builders.
-- ---------------------------------------------------------------------------
local function getOrCreateFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A solid, query-able, projectile-bouncing, tank-blocking wall placed by floor fraction.
local function makeWall(parent, name, fractionX, fractionZ, size, rotationY, color, isRicochet)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = placeOnFloor(fractionX, fractionZ, size.Y * 0.5, rotationY)
	part.Anchored = true
	part.CanCollide = true -- blocks tanks.
	part.CanQuery = true -- REQUIRED: projectile + movement raycasts must hit it.
	part.CanTouch = false
	part.CastShadow = false
	part.Material = isRicochet and Enum.Material.Neon or Enum.Material.Metal
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- This attribute is what TankMovementService + the projectile map-target collector key
	-- off, independent of folder name -- so the wall works wherever it ends up.
	part:SetAttribute("WOBMovementObstacle", true)
	part:SetAttribute("WOBRicochetWall", isRicochet == true)
	part.Parent = parent
	return part
end

-- A non-colliding marker placed by floor fraction. Runtime reads only its position.
local function makeMarker(parent, name, fractionX, fractionZ, color, attributes)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 4, 4) -- flat disc lying on the floor.
	part.CFrame = placeOnFloor(fractionX, fractionZ, 0.25) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false -- never interferes with gameplay raycasts.
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.35 -- visible for editing, clearly a marker.
	if attributes then
		for key, value in pairs(attributes) do
			part:SetAttribute(key, value)
		end
	end
	part.Parent = parent
	return part
end

-- Wall length helpers: express extents as fractions of the floor so they scale with it.
local function spanX(fraction)
	return math.max(WALL_THICKNESS, fraction * (halfX * 2))
end
local function spanZ(fraction)
	return math.max(WALL_THICKNESS, fraction * (halfZ * 2))
end

-- ---------------------------------------------------------------------------
-- Build.
-- ---------------------------------------------------------------------------
local authoringRoot = getOrCreateFolder(Workspace, "WOB_Authoring")
local layoutsRoot = getOrCreateFolder(authoringRoot, "ArenaLayouts")

local oldLayout = layoutsRoot:FindFirstChild(LAYOUT_NAME)
if oldLayout then
	oldLayout:Destroy()
end

local layout = Instance.new("Model")
layout.Name = LAYOUT_NAME
layout.Parent = layoutsRoot

local collisionWalls = getOrCreateFolder(layout, "CollisionWalls")
local ricochetWalls = getOrCreateFolder(layout, "RicochetWalls")
local cover = getOrCreateFolder(layout, "Cover")
local pickupSpawns = getOrCreateFolder(layout, "PickupSpawns")
local playerSpawns = getOrCreateFolder(layout, "PlayerSpawns")
local botSpawns = getOrCreateFolder(layout, "BotSpawns")
local breakableSpawns = getOrCreateFolder(layout, "BreakableSpawns")
local visuals = getOrCreateFolder(layout, "Visuals")

-- Outer ricochet ring (four neon panels) -- generous gaps so tanks turn freely.
-- Ring sits ~0.57 of the half-extent out from center; panels span ~0.37 of full extent.
makeWall(ricochetWalls, "RicochetWall_N", 0, 0.57, Vector3.new(spanX(0.37), WALL_HEIGHT, WALL_THICKNESS), 0, RICOCHET_COLOR, true)
makeWall(ricochetWalls, "RicochetWall_S", 0, -0.57, Vector3.new(spanX(0.37), WALL_HEIGHT, WALL_THICKNESS), 0, RICOCHET_COLOR, true)
makeWall(ricochetWalls, "RicochetWall_E", 0.57, 0, Vector3.new(WALL_THICKNESS, WALL_HEIGHT, spanZ(0.37)), 0, RICOCHET_COLOR, true)
makeWall(ricochetWalls, "RicochetWall_W", -0.57, 0, Vector3.new(WALL_THICKNESS, WALL_HEIGHT, spanZ(0.37)), 0, RICOCHET_COLOR, true)

-- Four diagonal ricochet panels for rich bounce angles (~0.33 out, span ~0.13).
makeWall(ricochetWalls, "RicochetWall_NE_Diag", 0.33, 0.33, Vector3.new(spanX(0.13), WALL_HEIGHT, WALL_THICKNESS), 45, RICOCHET_COLOR, true)
makeWall(ricochetWalls, "RicochetWall_NW_Diag", -0.33, 0.33, Vector3.new(spanX(0.13), WALL_HEIGHT, WALL_THICKNESS), -45, RICOCHET_COLOR, true)
makeWall(ricochetWalls, "RicochetWall_SE_Diag", 0.33, -0.33, Vector3.new(spanX(0.13), WALL_HEIGHT, WALL_THICKNESS), -45, RICOCHET_COLOR, true)
makeWall(ricochetWalls, "RicochetWall_SW_Diag", -0.33, -0.33, Vector3.new(spanX(0.13), WALL_HEIGHT, WALL_THICKNESS), 45, RICOCHET_COLOR, true)

-- Two short solid collision walls flanking the center (darker, non-neon).
makeWall(collisionWalls, "Wall_CenterLeft", -0.13, 0, Vector3.new(WALL_THICKNESS, WALL_HEIGHT, spanZ(0.12)), 0, COLLISION_COLOR, false)
makeWall(collisionWalls, "Wall_CenterRight", 0.13, 0, Vector3.new(WALL_THICKNESS, WALL_HEIGHT, spanZ(0.12)), 0, COLLISION_COLOR, false)

-- Cover blocks (physical, named so movement also recognises them). Concrete, ~0.23 out.
local function makeCover(name, fractionX, fractionZ)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(4, 4.5, 4)
	part.CFrame = placeOnFloor(fractionX, fractionZ, 4.5 * 0.5)
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Concrete
	part.Color = COVER_COLOR
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("WOBMovementObstacle", true)
	part:SetAttribute("WOBRicochetWall", false)
	part.Parent = cover
	return part
end
makeCover("Cover_Block_NE", 0.23, 0.23)
makeCover("Cover_Block_NW", -0.23, 0.23)
makeCover("Cover_Block_SE", 0.23, -0.23)
makeCover("Cover_Block_SW", -0.23, -0.23)

-- Pickup spawn markers. Type comes from WOBPickupType (and is encoded in the name too).
makeMarker(pickupSpawns, "PickupSpawn_Repair_N", 0, 0.43, PICKUP_COLORS.Repair, { WOBPickupType = "Repair" })
makeMarker(pickupSpawns, "PickupSpawn_Repair_S", 0, -0.43, PICKUP_COLORS.Repair, { WOBPickupType = "Repair" })
makeMarker(pickupSpawns, "PickupSpawn_MachineGun_W", -0.43, 0, PICKUP_COLORS.MachineGun, { WOBPickupType = "MachineGun" })
makeMarker(pickupSpawns, "PickupSpawn_Rocket_E", 0.43, 0, PICKUP_COLORS.Rocket, { WOBPickupType = "Rocket" })
-- Shield marker is authored but only spawns when ShieldPickupEnabled flag is on.
makeMarker(pickupSpawns, "PickupSpawn_Shield_C", 0, 0, PICKUP_COLORS.Shield, { WOBPickupType = "Shield" })

-- Player spawn markers (clear of walls so tanks never spawn stuck).
makeMarker(playerSpawns, "PlayerSpawn_1", -0.73, -0.73, PLAYER_SPAWN_COLOR, {})
makeMarker(playerSpawns, "PlayerSpawn_2", 0.73, 0.73, PLAYER_SPAWN_COLOR, {})

-- Bot spawn markers.
makeMarker(botSpawns, "BotSpawn_1", 0.73, -0.73, BOT_SPAWN_COLOR, {})
makeMarker(botSpawns, "BotSpawn_2", -0.73, 0.73, BOT_SPAWN_COLOR, {})

-- Breakable cover markers (optional; feature-flagged at runtime).
makeMarker(breakableSpawns, "BreakableSpawn_1", 0.2, 0, BREAKABLE_COLOR, { WOBBreakableType = "LightCover" })
makeMarker(breakableSpawns, "BreakableSpawn_2", -0.2, 0, BREAKABLE_COLOR, { WOBBreakableType = "LightCover" })
makeMarker(breakableSpawns, "BreakableSpawn_3", 0, 0.2, BREAKABLE_COLOR, { WOBBreakableType = "LightCover" })
makeMarker(breakableSpawns, "BreakableSpawn_4", 0, -0.2, BREAKABLE_COLOR, { WOBBreakableType = "LightCover" })

-- A purely decorative, non-colliding accent ring (Visuals are never gameplay).
do
	local accent = Instance.new("Part")
	accent.Name = "Visual_CenterPad"
	accent.Shape = Enum.PartType.Cylinder
	accent.Size = Vector3.new(0.3, math.min(halfX, halfZ) * 0.6, math.min(halfX, halfZ) * 0.6)
	accent.CFrame = placeOnFloor(0, 0, 0.05) * CFrame.Angles(0, 0, math.rad(90))
	accent.Anchored = true
	accent.CanCollide = false
	accent.CanTouch = false
	accent.CanQuery = false
	accent.CastShadow = false
	accent.Material = Enum.Material.Neon
	accent.Color = VISUAL_COLOR
	accent.Transparency = 0.6
	accent:SetAttribute("WOBVisualOnly", true)
	accent.Parent = visuals
end

-- Tag the layout so the runtime can read author intent and so it's easy to spot.
layout:SetAttribute("WOBArenaLayout", true)
layout:SetAttribute("WOBLayoutName", LAYOUT_NAME)

print(("[LAYOUT GEN] Built Workspace/WOB_Authoring/ArenaLayouts/%s on floor '%s' (%.0f x %.0f). Edit it, then right-click > Save to File... -> src/ReplicatedStorage/Assets/ArenaLayouts/%s.rbxm"):format(
	LAYOUT_NAME, floor.Name, floor.Size.X, floor.Size.Z, LAYOUT_NAME))
