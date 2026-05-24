local ArenaRewardService = {}
ArenaRewardService.__index = ArenaRewardService

function ArenaRewardService.new(config, loopConfig)
	return setmetatable({
		_config = config or {},
		_loopConfig = loopConfig or {},
		_walletService = nil,
	}, ArenaRewardService)
end

function ArenaRewardService:SetWalletService(walletService)
	self._walletService = walletService
end

function ArenaRewardService:IsLoopV02Enabled()
	return self._loopConfig.Enabled == true
end

function ArenaRewardService:GetLoopSection(sectionName)
	if not self:IsLoopV02Enabled() then
		return {}
	end

	return self._loopConfig[sectionName] or {}
end

function ArenaRewardService:GetLoopNumber(sectionName, valueName, fallback)
	local section = self:GetLoopSection(sectionName)

	return tonumber(section[valueName]) or fallback
end

function ArenaRewardService:HasProjectileRicochet(sourceProjectile)
	return sourceProjectile ~= nil and (tonumber(sourceProjectile.BounceCount) or 0) > 0
end

function ArenaRewardService:UpdateRunSummary(session)
	if session == nil or session.IsBotSession == true then
		return
	end

	session.LastSummary = ("Run: %d kills / %d deaths / +%d Bolts"):format(
		math.floor(session.Kills or 0),
		math.floor(session.Deaths or 0),
		math.floor(session.EarnedBolts or 0)
	)
end

function ArenaRewardService:GetPlayerKillScore(killerSession, victimSession, sourceProjectile)
	local defaultKillScore = math.max(0, math.floor(tonumber(self._config.KillScore) or 0))

	if killerSession == nil or killerSession.IsBotSession == true then
		return 0
	end

	if victimSession == nil or victimSession.IsBotSession ~= true or not self:IsLoopV02Enabled() then
		return defaultKillScore
	end

	local score = math.max(0, math.floor(self:GetLoopNumber("Score", "PlayerKillBot", defaultKillScore)))

	if self:HasProjectileRicochet(sourceProjectile) then
		score += math.max(0, math.floor(self:GetLoopNumber("Score", "RicochetKillBonus", 0)))
	end

	return score
end

function ArenaRewardService:GetBotKillBoltsReward(victimSession, sourceProjectile)
	if victimSession == nil or victimSession.IsBotSession ~= true or not self:IsLoopV02Enabled() then
		return 0, "BattleArenaBotKill"
	end

	local rewardAmount = math.max(0, math.floor(self:GetLoopNumber("Rewards", "BoltsPerBotKill", 0)))
	local reason = "BattleArenaBotKill"

	if self:HasProjectileRicochet(sourceProjectile) then
		rewardAmount += math.max(0, math.floor(self:GetLoopNumber("Rewards", "BoltsPerRicochetKillBonus", 0)))
		reason = "BattleArenaRicochetKill"
	end

	return rewardAmount, reason
end

function ArenaRewardService:ApplyKillRewards(killerSession, victimSession, sourceProjectile)
	if killerSession == nil or killerSession.IsBotSession == true then
		return {
			Score = 0,
			Bolts = 0,
			AwardedBolts = false,
		}
	end

	local score = self:GetPlayerKillScore(killerSession, victimSession, sourceProjectile)
	killerSession.Score += score

	if killerSession.Player == nil
		or victimSession == nil
		or victimSession.IsBotSession ~= true
		or self._walletService == nil
		or self._walletService.addBolts == nil
		or not self:IsLoopV02Enabled()
	then
		return {
			Score = score,
			Bolts = 0,
			AwardedBolts = false,
		}
	end

	local rewardAmount, reason = self:GetBotKillBoltsReward(victimSession, sourceProjectile)

	if rewardAmount <= 0 then
		return {
			Score = score,
			Bolts = 0,
			AwardedBolts = false,
			Reason = reason,
		}
	end

	local awarded = self._walletService.addBolts(killerSession.Player, rewardAmount, reason)

	if awarded then
		killerSession.EarnedBolts += rewardAmount
	end

	return {
		Score = score,
		Bolts = rewardAmount,
		AwardedBolts = awarded == true,
		Reason = reason,
	}
end

return ArenaRewardService
