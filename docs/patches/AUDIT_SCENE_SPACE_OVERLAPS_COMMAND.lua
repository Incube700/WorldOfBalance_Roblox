-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Audits XZ overlaps between major playable scene spaces.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[SPACE AUDIT] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local NEAR_MARGIN = 24

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "nil"
	end

	return ("(%.1f, %.1f, %.1f)"):format(vector.X, vector.Y, vector.Z)
end

local function getAabbForPart(part)
	if part == nil or not part:IsA("BasePart") then
		return nil
	end

	local halfSize = part.Size * 0.5

	return {
		MinX = part.Position.X - halfSize.X,
		MaxX = part.Position.X + halfSize.X,
		MinZ = part.Position.Z - halfSize.Z,
		MaxZ = part.Position.Z + halfSize.Z,
		Center = part.Position,
		Size = part.Size,
	}
end

local function getAabbForParts(parts)
	if #parts == 0 then
		return nil
	end

	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	local minY = math.huge
	local maxY = -math.huge

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5
		minX = math.min(minX, part.Position.X - halfSize.X)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
	end

	return {
		MinX = minX,
		MaxX = maxX,
		MinZ = minZ,
		MaxZ = maxZ,
		Center = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5),
		Size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ),
	}
end

local function collectBaseParts(root)
	local parts = {}

	if root ~= nil then
		if root:IsA("BasePart") then
			table.insert(parts, root)
		end

		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end

	return parts
end

local function findFirstFloor(container)
	if container == nil then
		return nil
	end

	local direct = container:FindFirstChild("Floor")

	if direct ~= nil and direct:IsA("BasePart") then
		return direct
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Floor" then
			return descendant
		end
	end

	return nil
end

local function boundsOverlapXZ(a, b, margin)
	if a == nil or b == nil then
		return false
	end

	margin = margin or 0

	return a.MinX <= b.MaxX + margin
		and a.MaxX >= b.MinX - margin
		and a.MinZ <= b.MaxZ + margin
		and a.MaxZ >= b.MinZ - margin
end

local function boundsContainsXZ(bounds, position, margin)
	if bounds == nil or typeof(position) ~= "Vector3" then
		return false
	end

	margin = margin or 0

	return position.X >= bounds.MinX - margin
		and position.X <= bounds.MaxX + margin
		and position.Z >= bounds.MinZ - margin
		and position.Z <= bounds.MaxZ + margin
end

local function flatDistance(a, b)
	local delta = Vector3.new(a.X - b.X, 0, a.Z - b.Z)

	return delta.Magnitude
end

local function printBounds(label, instance, bounds)
	if instance == nil then
		warn("[SPACE WARNING] " .. label .. " missing")
		return
	end

	if bounds == nil then
		warn("[SPACE WARNING] " .. label .. " has no bounds")
		return
	end

	print(
		("[SPACE AUDIT] %s path=%s pos=%s size=%s minX=%.1f maxX=%.1f minZ=%.1f maxZ=%.1f"):format(
			label,
			instance:GetFullName(),
			formatVector3(bounds.Center),
			formatVector3(bounds.Size),
			bounds.MinX,
			bounds.MaxX,
			bounds.MinZ,
			bounds.MaxZ
		)
	)
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[SPACE AUDIT] Workspace/" .. ROOT_NAME .. " was not found.")
	return
end

local lobby = root:FindFirstChild("Lobby")
local battleArena = root:FindFirstChild("BattleArena")
local duelArena = root:FindFirstChild("DuelArena") or root:FindFirstChild("Map")

local lobbyFloor = findFirstFloor(lobby)
local battleArenaFloor = findFirstFloor(battleArena)
local duelArenaFloor = findFirstFloor(duelArena)

local lobbyBounds = getAabbForPart(lobbyFloor)
local battleBounds = getAabbForPart(battleArenaFloor) or getAabbForParts(collectBaseParts(battleArena))
local duelBounds = getAabbForPart(duelArenaFloor)

printBounds("Lobby.Floor", lobbyFloor, lobbyBounds)
printBounds("BattleArena.Floor", battleArenaFloor, battleBounds)

if duelArenaFloor ~= nil then
	printBounds("DuelArenaOrMap.Floor", duelArenaFloor, duelBounds)
end

local lobbyBattleOverlap = boundsOverlapXZ(lobbyBounds, battleBounds, 0)
print("[SPACE AUDIT] Lobby/BattleArena overlap XZ = " .. tostring(lobbyBattleOverlap))

if lobbyBattleOverlap then
	warn("[SPACE WARNING] Lobby.Floor overlaps BattleArena.Floor")
end

if duelBounds ~= nil and boundsOverlapXZ(duelBounds, battleBounds, 0) then
	warn("[SPACE WARNING] DuelArena/Map floor overlaps BattleArena.Floor")
end

local battleCenter = battleBounds ~= nil and battleBounds.Center or Vector3.new(0, 0, 0)
local generatedParts = collectBaseParts(root)

for _, part in ipairs(generatedParts) do
	local isObstacle = part:GetAttribute("WOBMovementObstacle") == true
	local nearBattle = battleBounds ~= nil and boundsContainsXZ(battleBounds, part.Position, NEAR_MARGIN)
	local inBattleArena = battleArena ~= nil and part:IsDescendantOf(battleArena)

	if isObstacle and nearBattle and not inBattleArena then
		warn(
			("[SPACE WARNING] WOBMovementObstacle near BattleArena center but outside BattleArena path=%s pos=%s distance=%.1f"):format(
				part:GetFullName(),
				formatVector3(part.Position),
				flatDistance(part.Position, battleCenter)
			)
		)
	end

	if lobby ~= nil
		and part:IsDescendantOf(lobby)
		and nearBattle
		and (isObstacle or string.find(part.Name, "Railing") ~= nil or string.find(part.Name, "Wall") ~= nil)
	then
		warn("[SPACE WARNING] Lobby obstacle near/inside BattleArena bounds " .. part:GetFullName())
	end
end

print("[SPACE AUDIT] Complete.")
