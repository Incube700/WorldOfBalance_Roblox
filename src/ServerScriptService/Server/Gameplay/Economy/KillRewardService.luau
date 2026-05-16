local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local CurrencyConfig = require(configs:WaitForChild("CurrencyConfig"))

local KillRewardService = {}

local MATCH_MODE_TRAINING = "Training"
local MATCH_MODE_PVP = "PvP"

local playerWalletService = nil
local roundMatchService = nil

local function participantIsInMatch(participant, activeMatch)
	for _, activeParticipant in ipairs(activeMatch.Participants or {}) do
		if activeParticipant == participant then
			return true
		end
	end

	return false
end

local function getDeathKey(victimParticipant, activeMatch, roundNumber)
	return tostring(activeMatch.MatchId)
		.. ":"
		.. tostring(roundNumber or 0)
		.. ":"
		.. tostring(victimParticipant.TankId)
end

local function getRewardForMatchMode(matchMode)
	if matchMode == MATCH_MODE_TRAINING then
		return CurrencyConfig.Rewards.TrainingKill or 0, "TrainingKill"
	elseif matchMode == MATCH_MODE_PVP then
		return CurrencyConfig.Rewards.PvPKill or 0, "PvPKill"
	end

	return 0, "NoReward"
end

function KillRewardService.init(options)
	options = options or {}
	playerWalletService = options.playerWalletService
	roundMatchService = options.roundMatchService
end

function KillRewardService.awardTankKill(killerParticipant, victimParticipant, context)
	context = context or {}

	if playerWalletService == nil or roundMatchService == nil then
		return false, "NoReward", 0
	end

	if killerParticipant == nil or victimParticipant == nil then
		return false, "NoReward", 0
	end

	local activeMatch = roundMatchService.getActiveMatch ~= nil and roundMatchService.getActiveMatch() or nil

	if activeMatch == nil or activeMatch.IsFinished == true then
		return false, "NoReward", 0
	end

	if not participantIsInMatch(killerParticipant, activeMatch)
		or not participantIsInMatch(victimParticipant, activeMatch)
	then
		return false, "NoReward", 0
	end

	local roundState = roundMatchService.getRoundState ~= nil and roundMatchService.getRoundState() or nil

	if roundState ~= nil and roundState.Ended == true then
		return false, "NoReward", 0
	end

	local deathKey = getDeathKey(victimParticipant, activeMatch, context.RoundNumber)

	if victimParticipant.LastRewardedDeathKey == deathKey then
		return false, "NoReward", 0
	end

	victimParticipant.LastRewardedDeathKey = deathKey

	if context.Projectile ~= nil and context.Projectile.NoDamage == true then
		return false, "NoReward", 0
	end

	if context.NoDamage == true then
		return false, "NoReward", 0
	end

	if killerParticipant == victimParticipant then
		return false, "SelfKill", CurrencyConfig.Rewards.SelfKill or 0
	end

	local ownerPlayer = killerParticipant.OwnerPlayer

	if ownerPlayer == nil then
		return false, "NoReward", 0
	end

	local rewardAmount, reason = getRewardForMatchMode(activeMatch.MatchMode)

	if rewardAmount <= 0 then
		return false, reason, 0
	end

	return playerWalletService.addBolts(ownerPlayer, rewardAmount, reason), reason, rewardAmount
end

return KillRewardService
