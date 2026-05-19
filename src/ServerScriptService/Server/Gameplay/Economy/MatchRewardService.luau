local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local CurrencyConfig = require(configs:WaitForChild("CurrencyConfig"))
local RewardConfig = require(configs:WaitForChild("RewardConfig"))

local MatchRewardService = {}

local playerWalletService = nil

local function getCrystalAttributes()
	return CurrencyConfig.Crystals.Attributes
end

local function getParticipantByTankId(participants, tankId)
	if typeof(tankId) ~= "string" or tankId == "" then
		return nil
	end

	for _, participant in ipairs(participants or {}) do
		if participant.TankId == tankId then
			return participant
		end
	end

	return nil
end

local function hasDistinctPlayerOwners(winnerParticipant, loserParticipant)
	if winnerParticipant == nil
		or loserParticipant == nil
		or winnerParticipant.OwnerPlayer == nil
		or loserParticipant.OwnerPlayer == nil
	then
		return false
	end

	return winnerParticipant.OwnerUserId ~= nil
		and loserParticipant.OwnerUserId ~= nil
		and winnerParticipant.OwnerUserId ~= loserParticipant.OwnerUserId
end

local function isValidDuelReward(activeMatch, matchState)
	if playerWalletService == nil or activeMatch == nil or matchState == nil then
		return false
	end

	if activeMatch.IsDuel ~= true or activeMatch.MatchMode ~= "PvP" then
		return false
	end

	if activeMatch.CrystalRewardIssued == true then
		return false
	end

	if matchState.MatchEnded ~= true then
		return false
	end

	if matchState.MatchWinnerTankId == "" or matchState.MatchWinnerTankId == matchState.MatchLoserTankId then
		return false
	end

	return true
end

function MatchRewardService.init(options)
	options = options or {}
	playerWalletService = options.playerWalletService
end

function MatchRewardService.awardFinalMatchRewards(activeMatch, matchState)
	if not isValidDuelReward(activeMatch, matchState) then
		return false
	end

	local rewardAmount = math.max(0, math.floor(tonumber(RewardConfig.DuelWinCrystals) or 0))

	if rewardAmount <= 0 then
		return false
	end

	local winnerParticipant = getParticipantByTankId(activeMatch.Participants, matchState.MatchWinnerTankId)
	local loserParticipant = getParticipantByTankId(activeMatch.Participants, matchState.MatchLoserTankId)

	if not hasDistinctPlayerOwners(winnerParticipant, loserParticipant) then
		return false
	end

	activeMatch.CrystalRewardIssued = true

	local winnerPlayer = winnerParticipant.OwnerPlayer
	local awarded, total = playerWalletService.addCrystals(winnerPlayer, rewardAmount, "DuelWin")

	if not awarded then
		return false
	end

	winnerPlayer:SetAttribute(getCrystalAttributes().LastRewardMatchId, tostring(activeMatch.MatchId or ""))
	print(("[REWARD] Duel win crystal +%d player=%s total=%d"):format(rewardAmount, winnerPlayer.Name, total))

	if playerWalletService.savePlayer ~= nil then
		task.spawn(function()
			playerWalletService.savePlayer(winnerPlayer)
		end)
	end

	if RewardConfig.DebugRewards == true then
		print(
			("[REWARD DEBUG] matchId=%s winnerTank=%s loserTank=%s"):format(
				tostring(activeMatch.MatchId),
				tostring(matchState.MatchWinnerTankId),
				tostring(matchState.MatchLoserTankId)
			)
		)
	end

	return true
end

return MatchRewardService
