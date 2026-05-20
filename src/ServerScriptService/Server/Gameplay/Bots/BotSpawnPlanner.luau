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

local function makeSpawnTransform(position, yaw, source)
	return {
		Position = position,
		BodyYaw = yaw,
		TurretYaw = yaw,
		Source = source,
	}
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
			if child:IsA("BasePart") and string.match(child.Name, "^ArenaSpawn%d+$") ~= nil then
				table.insert(spawnParts, child)
			end
		end
	end

	table.sort(spawnParts, function(a, b)
		return a.Name < b.Name
	end)

	return spawnParts
end

function BotSpawnPlanner:_getFallbackTransform()
	local arena = self:_getArenaFolder()
	local arenaCenter = arena ~= nil and arena:GetAttribute("ArenaCenter") or nil
	local halfSize = arena ~= nil and arena:GetAttribute("ArenaHalfSize") or nil

	if typeof(arenaCenter) ~= "Vector3" then
		arenaCenter = BattleArenaConfig.SafeArenaCenter or Vector3.new(-340, 0, 320)
	end

	if typeof(halfSize) ~= "number" then
		halfSize = 80
	end

	local spawnCount = math.max(1, tonumber(BattleArenaConfig.SpawnPointCount) or 8)
	local index = self.NextSpawnIndex
	self.NextSpawnIndex += 1

	local angle = (math.pi * 2) * (((index - 1) % spawnCount) / spawnCount)
	local radius = math.max(30, halfSize * 0.6)
	local position = arenaCenter + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local yaw = getYawFromLookVector((arenaCenter - position).Unit)

	return makeSpawnTransform(position, yaw, "ArenaBotFallback")
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
		"ArenaBot:" .. spawnPart.Name
	)
end

return BotSpawnPlanner
