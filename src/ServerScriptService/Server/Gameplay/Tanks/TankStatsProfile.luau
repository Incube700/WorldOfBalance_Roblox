local TankStatsProfile = {
	DuelNormalized = "DuelNormalized",
	ArenaDefault = "ArenaDefault",
	TrainingPlayer = "TrainingPlayer",
	TrainingDummy = "TrainingDummy",
	BotDefault = "BotDefault",
}

local validProfiles = {}

for _, profileId in pairs(TankStatsProfile) do
	validProfiles[profileId] = true
end

function TankStatsProfile.IsValid(profileId)
	return validProfiles[profileId] == true
end

return table.freeze(TankStatsProfile)
