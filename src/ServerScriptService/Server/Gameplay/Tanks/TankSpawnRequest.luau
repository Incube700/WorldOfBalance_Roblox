local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TankFactoryConfig = require(configs:WaitForChild("TankFactoryConfig"))

local TankRole = require(script.Parent:WaitForChild("TankRole"))
local TankStatsProfile = require(script.Parent:WaitForChild("TankStatsProfile"))

local TankSpawnRequest = {}

local DEFAULT_PROFILE_BY_ROLE = table.freeze({
	[TankRole.Player] = TankStatsProfile.DuelNormalized,
	[TankRole.DuelOpponent] = TankStatsProfile.DuelNormalized,
	[TankRole.Dummy] = TankStatsProfile.TrainingDummy,
	[TankRole.Bot] = TankStatsProfile.BotDefault,
	[TankRole.ArenaPlayer] = TankStatsProfile.ArenaDefault,
	[TankRole.ArenaBot] = TankStatsProfile.BotDefault,
})

local function copyUpgradeLevels(upgradeLevels)
	local copy = {}

	if typeof(upgradeLevels) == "table" then
		for key, value in pairs(upgradeLevels) do
			copy[key] = value
		end
	end

	return copy
end

local function normalizeLoadout(loadout)
	loadout = loadout or {}

	return {
		SkinId = loadout.SkinId or TankFactoryConfig.DefaultLoadout.SkinId,
		WeaponId = loadout.WeaponId or TankFactoryConfig.DefaultLoadout.WeaponId,
		UpgradeLevels = copyUpgradeLevels(loadout.UpgradeLevels),
	}
end

function TankSpawnRequest.Normalize(request)
	request = request or {}

	local role = request.Role or TankRole.Player

	if not TankRole.IsValid(role) then
		error("[TANK SPAWN REQUEST] Invalid Role: " .. tostring(role), 2)
	end

	local statsProfileId = request.StatsProfileId or DEFAULT_PROFILE_BY_ROLE[role] or TankStatsProfile.DuelNormalized

	if not TankStatsProfile.IsValid(statsProfileId) then
		error("[TANK SPAWN REQUEST] Invalid StatsProfileId: " .. tostring(statsProfileId), 2)
	end

	local normalized = {}

	for key, value in pairs(request) do
		normalized[key] = value
	end

	normalized.Role = role
	normalized.StatsProfileId = statsProfileId
	normalized.Loadout = normalizeLoadout(request.Loadout)

	return normalized
end

return TankSpawnRequest
