local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TankFactoryConfig = require(configs:WaitForChild("TankFactoryConfig"))

local TankStatsProfile = require(script.Parent:WaitForChild("TankStatsProfile"))

local TankStatsProvider = {}
TankStatsProvider.__index = TankStatsProvider

local DEFAULT_STATS_BY_PROFILE = table.freeze({
	[TankStatsProfile.DuelNormalized] = table.freeze({}),
	[TankStatsProfile.ArenaDefault] = table.freeze({}),
	[TankStatsProfile.TrainingPlayer] = table.freeze({}),
	[TankStatsProfile.TrainingDummy] = table.freeze({}),
	[TankStatsProfile.BotDefault] = table.freeze({}),
})

local function getNumberAttribute(model, attributeName)
	if model == nil then
		return nil
	end

	local value = model:GetAttribute(attributeName)

	return typeof(value) == "number" and value or nil
end

function TankStatsProvider.new()
	return setmetatable({}, TankStatsProvider)
end

function TankStatsProvider:GetStats(statsProfileId, request, model)
	request = request or {}

	local profileDefaults = DEFAULT_STATS_BY_PROFILE[statsProfileId] or DEFAULT_STATS_BY_PROFILE[TankStatsProfile.DuelNormalized]
	local maxHealth = tonumber(request.MaxHealth)
		or getNumberAttribute(model, "MaxHealth")
		or profileDefaults.MaxHealth
		or TankFactoryConfig.DefaultStats.MaxHealth
	local health = tonumber(request.Health)
		or tonumber(request.CurrentHealth)
		or getNumberAttribute(model, "CurrentHealth")
		or getNumberAttribute(model, "HP")
		or getNumberAttribute(model, "Health")
		or profileDefaults.Health
		or maxHealth

	maxHealth = math.max(1, maxHealth)
	health = math.clamp(health, 0, maxHealth)

	return {
		MaxHealth = maxHealth,
		Health = health,
		WeaponId = request.WeaponId
			or (request.Loadout ~= nil and request.Loadout.WeaponId)
			or TankFactoryConfig.DefaultLoadout.WeaponId,
	}
end

return TankStatsProvider
