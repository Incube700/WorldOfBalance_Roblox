local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local BattleArenaConfig = require(configs:WaitForChild("BattleArenaConfig"))

local BotSpawnPlanner = {}
BotSpawnPlanner.__index = BotSpawnPlanner

local function getYawFromLookVector(lookVector)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLook.Magnitude < 0.001 then
		return 0
	end

	local unit = flatLook.Unit
	return math.atan2(-unit.X, -unit.Z)
end

local function makeSpawnTransform(position, yaw, source, sourcePath)
	return {
		Position = position,
		BodyYaw = yaw,
		TurretYaw = yaw,
		Source = source,
		SourcePath = sourcePath,
	}
end

-- A part is a valid BattleArena bot spawn ONLY if it lives in BattleArena/SpawnPoints and
-- matches an explicit arena spawn name. ArenaSpawn* is the established name; BotSpawn* /
-- ArenaBotSpawn* are accepted so a dedicated bot spawn can be authored without code changes.
local function isArenaSpawnName(name)
	return string.match(name, "^ArenaSpawn%d+$") ~= nil
		or string.match(name, "^BotSpawn%d+$") ~= nil
		or string.match(name, "^ArenaBotSpawn%d+$") ~= nil
end

function BotSpawnPlanner.new(root)
	return setmetatable({
		Root = root,
		NextSpawnIndex = 1,
	}, BotSpawnPlanner)
end

function BotSpawnPlanner:_getArenaFolder()
	return self.Root ~= nil and self.Root:FindFirstChild("BattleArena") or nil
end

function BotSpawnPlanner:_getArenaSpawnParts()
	local arena = self:_getArenaFolder()
	local spawnFolder = arena ~= nil and arena:FindFirstChild("SpawnPoints") or nil
	local spawnParts = {}

	if spawnFolder ~= nil then
		for _, child in ipairs(spawnFolder:GetChildren()) do
			if child:IsA("BasePart") and isArenaSpawnName(child.Name) then
				table.insert(spawnParts, child)
			end
		end
	end

	table.sort(spawnParts, function(a, b)
		return a.Name < b.Name
	end)

	return spawnParts
end

-- Last-resort fallback ONLY: the centre of the BattleArena floor. Never the Duel area,
-- never SafeArenaCenter guesswork. Used solely when no BattleArena spawn parts exist.
function BotSpawnPlanner:_getFallbackTransform()
	local arena = self:_getArenaFolder()
	local floor = arena ~= nil and arena:FindFirstChild("Floor") or nil

	local center
	if floor ~= nil and floor:IsA("BasePart") then
		center = Vector3.new(floor.Position.X, floor.Position.Y + floor.Size.Y * 0.5 + 3, floor.Position.Z)
		warn(("[ARENA SPAWN] No BattleArena spawn parts found in %s; using BattleArena floor centre %s as last-resort fallback."):format(
			arena ~= nil and arena:GetFullName() or "Workspace.WOB_Generated.BattleArena (missing)",
			tostring(center)))
	else
		-- No arena floor either: refuse to guess near Duel. Park at origin and warn loudly.
		center = Vector3.new(0, 5, 0)
		warn("[ARENA SPAWN] No BattleArena spawn parts AND no BattleArena/Floor found; cannot place arena bot safely. Parking at origin. Author Workspace.WOB_Generated.BattleArena.SpawnPoints.ArenaSpawn1.")
	end

	return makeSpawnTransform(center, 0, "ArenaBotFloorCentreFallback", "<fallback: BattleArena floor centre>")
end

function BotSpawnPlanner:GetNextSpawnTransform()
	local spawnParts = self:_getArenaSpawnParts()

	if #spawnParts == 0 then
		return self:_getFallbackTransform()
	end

	local spawnPart = spawnParts[((self.NextSpawnIndex - 1) % #spawnParts) + 1]
	self.NextSpawnIndex += 1

	return makeSpawnTransform(
		spawnPart.Position,
		getYawFromLookVector(spawnPart.CFrame.LookVector),
		"ArenaBot:" .. spawnPart.Name,
		spawnPart:GetFullName()
	)
end

return BotSpawnPlanner
