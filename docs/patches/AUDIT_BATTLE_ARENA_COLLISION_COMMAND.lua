-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Prints BattleArena collision/stuck diagnostics without changing the scene.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[ARENA AUDIT] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local ARENA_NAME = "BattleArena"
local CENTER_RADIUS = 30
local NEAR_RADIUS = 180

local obstacleFolderNames = {
	Boundaries = true,
	Boundary = true,
	BoundaryWalls = true,
	Cover = true,
	MovementObstacles = true,
	Obstacles = true,
	RicochetWalls = true,
}

local safeNonObstacleNamePatterns = {
	"Floor",
	"Trigger",
	"Pad",
	"Spawn",
	"VFX",
	"Label",
}

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "nil"
	end

	return ("(%.1f, %.1f, %.1f)"):format(vector.X, vector.Y, vector.Z)
end

local function getPartsBounds(parts)
	if #parts == 0 then
		return nil, nil
	end

	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5
		minX = math.min(minX, part.Position.X - halfSize.X)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)
	end

	local minVector = Vector3.new(minX, minY, minZ)
	local maxVector = Vector3.new(maxX, maxY, maxZ)

	return CFrame.new((minVector + maxVector) * 0.5), maxVector - minVector
end

local function collectBaseParts(root)
	local parts = {}

	if root:IsA("BasePart") then
		table.insert(parts, root)
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function findAncestorNamed(instance, names)
	local current = instance.Parent

	while current ~= nil do
		if names[current.Name] == true then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function isInsideExpectedBattleArenaObstacleFolder(part, battleArena)
	local current = part.Parent

	while current ~= nil and current ~= battleArena.Parent do
		if current == battleArena then
			return false
		end

		if current.Parent == battleArena and (
			current.Name == "Boundaries"
			or current.Name == "Cover"
			or current.Name == "RicochetWalls"
		) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isMovementObstacle(part)
	if part:GetAttribute("WOBMovementObstacle") == true then
		return true
	end

	if findAncestorNamed(part, obstacleFolderNames) ~= nil then
		return true
	end

	return string.match(part.Name, "^BoundaryWall_") ~= nil
		or string.match(part.Name, "^ArenaBoundary_") ~= nil
		or string.match(part.Name, "^Cover_Block_") ~= nil
		or string.match(part.Name, "^RicochetWall_") ~= nil
end

local function isSafeNonObstacle(part)
	for _, pattern in ipairs(safeNonObstacleNamePatterns) do
		if string.find(part.Name, pattern) ~= nil then
			return true
		end
	end

	local current = part.Parent

	while current ~= nil do
		for _, pattern in ipairs(safeNonObstacleNamePatterns) do
			if string.find(current.Name, pattern) ~= nil then
				return true
			end
		end

		current = current.Parent
	end

	return false
end

local function isInvisibleBlocker(part)
	return part.Transparency >= 0.8
		and (part.CanCollide == true or part.CanQuery == true or part:GetAttribute("WOBMovementObstacle") == true)
end

local function flatDistanceFromCenter(part, center)
	local delta = Vector3.new(part.Position.X - center.X, 0, part.Position.Z - center.Z)

	return delta.Magnitude
end

local function pointInsidePart(point, part, padding)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size * 0.5 + Vector3.new(padding, padding, padding)

	return math.abs(localPoint.X) <= halfSize.X
		and math.abs(localPoint.Y) <= halfSize.Y
		and math.abs(localPoint.Z) <= halfSize.Z
end

local function printPart(prefix, part)
	print(
		("%s path=%s name=%s pos=%s size=%s transparency=%.2f CanCollide=%s CanTouch=%s CanQuery=%s Anchored=%s WOBMovementObstacle=%s WOBRicochetSurface=%s WOBPadTrigger=%s"):format(
			prefix,
			part:GetFullName(),
			part.Name,
			formatVector3(part.Position),
			formatVector3(part.Size),
			part.Transparency,
			tostring(part.CanCollide),
			tostring(part.CanTouch),
			tostring(part.CanQuery),
			tostring(part.Anchored),
			tostring(part:GetAttribute("WOBMovementObstacle") == true),
			tostring(part:GetAttribute("WOBRicochetSurface") == true),
			tostring(part:GetAttribute("WOBPadTrigger") == true)
		)
	)
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[ARENA AUDIT] Workspace/" .. ROOT_NAME .. " was not found.")
	return
end

local battleArena = root:FindFirstChild(ARENA_NAME)

if battleArena == nil then
	warn("[ARENA AUDIT] Workspace/" .. ROOT_NAME .. "/" .. ARENA_NAME .. " was not found.")
	return
end

local arenaParts = collectBaseParts(battleArena)
local boundsCFrame, boundsSize = getPartsBounds(arenaParts)
local floor = battleArena:FindFirstChild("Floor")
local center = battleArena:GetAttribute("ArenaCenter")

if floor ~= nil and floor:IsA("BasePart") then
	center = Vector3.new(floor.Position.X, floor.Position.Y + floor.Size.Y * 0.5, floor.Position.Z)
elseif typeof(center) ~= "Vector3" and boundsCFrame ~= nil then
	center = boundsCFrame.Position
end

if typeof(center) ~= "Vector3" then
	center = Vector3.new(0, 0, 0)
end

local pivotText = "n/a"

if battleArena:IsA("Model") then
	pivotText = tostring(battleArena:GetPivot())
end

print("[ARENA AUDIT] root=" .. battleArena:GetFullName() .. " pivot=" .. pivotText .. " estimatedCenter=" .. formatVector3(center))
print("[ARENA AUDIT] boundsCenter=" .. formatVector3(boundsCFrame ~= nil and boundsCFrame.Position or nil) .. " boundsSize=" .. formatVector3(boundsSize))

if floor ~= nil and floor:IsA("BasePart") then
	printPart("[ARENA AUDIT] Floor", floor)

	if floor:GetAttribute("WOBMovementObstacle") == true then
		warn("[ARENA WARNING] Floor has WOBMovementObstacle=true")
	end
else
	warn("[ARENA WARNING] BattleArena/Floor is missing or not a BasePart")
end

local spawnFolder = battleArena:FindFirstChild("SpawnPoints")
local spawnParts = {}

if spawnFolder ~= nil then
	for _, child in ipairs(spawnFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(spawnParts, child)
		end
	end
end

table.sort(spawnParts, function(a, b)
	return a.Name < b.Name
end)

for _, spawn in ipairs(spawnParts) do
	print("[ARENA AUDIT] SpawnPoint " .. spawn:GetFullName() .. " pos=" .. formatVector3(spawn.Position) .. " size=" .. formatVector3(spawn.Size))
end

print("[ARENA AUDIT] BaseParts inside BattleArena:")

for _, part in ipairs(arenaParts) do
	printPart("[ARENA AUDIT] Part", part)

	if isSafeNonObstacle(part) and part:GetAttribute("WOBMovementObstacle") == true then
		warn("[ARENA WARNING] " .. part:GetFullName() .. " should not be a movement obstacle")
	end

	if string.find(part.Name, "Trigger") ~= nil and part:GetAttribute("WOBMovementObstacle") == true then
		warn("[ARENA WARNING] Trigger has WOBMovementObstacle=true " .. part:GetFullName())
	end

	if isInvisibleBlocker(part) then
		warn("[ARENA WARNING] Invisible part blocks movement/query " .. part:GetFullName())
	end

	if flatDistanceFromCenter(part, center) <= CENTER_RADIUS and isInvisibleBlocker(part) then
		warn("[ARENA WARNING] Center area contains blocking invisible part " .. part:GetFullName())
	end
end

local generatedParts = collectBaseParts(root)

print("[ARENA AUDIT] Parts near BattleArena center radius=" .. tostring(CENTER_RADIUS) .. ":")

for _, part in ipairs(generatedParts) do
	if flatDistanceFromCenter(part, center) <= CENTER_RADIUS then
		printPart("[ARENA AUDIT] CenterPart", part)
	end
end

print("[ARENA AUDIT] Invisible blockers in/near BattleArena:")

for _, part in ipairs(generatedParts) do
	local nearArena = part:IsDescendantOf(battleArena) or flatDistanceFromCenter(part, center) <= NEAR_RADIUS

	if nearArena and isInvisibleBlocker(part) then
		printPart("[ARENA AUDIT] InvisibleBlocker", part)
	end
end

for _, spawn in ipairs(spawnParts) do
	for _, part in ipairs(generatedParts) do
		if part ~= spawn and isMovementObstacle(part) and pointInsidePart(spawn.Position, part, 5) then
			warn("[ARENA WARNING] SpawnPoint inside obstacle spawn=" .. spawn:GetFullName() .. " obstacle=" .. part:GetFullName())
		end
	end
end

for _, descendant in ipairs(root:GetDescendants()) do
	if descendant ~= battleArena and descendant.Name == ARENA_NAME then
		warn("[ARENA WARNING] Old/duplicate BattleArena object exists at " .. descendant:GetFullName())
	end
end

for _, part in ipairs(generatedParts) do
	local nearCenter = flatDistanceFromCenter(part, center) <= NEAR_RADIUS
	local hasObstacleAttribute = part:GetAttribute("WOBMovementObstacle") == true
	local expectedArenaObstacle = part:IsDescendantOf(battleArena)
		and isInsideExpectedBattleArenaObstacleFolder(part, battleArena)

	if nearCenter and hasObstacleAttribute and not expectedArenaObstacle then
		warn("[ARENA WARNING] WOBMovementObstacle outside expected BattleArena folders " .. part:GetFullName())
	end
end

print("[ARENA AUDIT] Complete. BattleArena parts=" .. tostring(#arenaParts) .. " generatedParts=" .. tostring(#generatedParts) .. ".")
