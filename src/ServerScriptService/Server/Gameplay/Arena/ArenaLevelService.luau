local ArenaLevelService = {}
ArenaLevelService.__index = ArenaLevelService

function ArenaLevelService.new(config)
	return setmetatable({
		_config = config or {},
	}, ArenaLevelService)
end

function ArenaLevelService:GetLevelThreshold(level)
	local thresholds = self._config.LevelThresholds or {}
	local numericLevel = math.max(1, math.floor(tonumber(level) or 1))
	local explicitThreshold = tonumber(thresholds[numericLevel])

	if explicitThreshold ~= nil then
		return explicitThreshold
	end

	local highestLevel = 1
	local highestThreshold = 0

	for thresholdLevel, threshold in pairs(thresholds) do
		local parsedLevel = tonumber(thresholdLevel)
		local parsedThreshold = tonumber(threshold)

		if parsedLevel ~= nil
			and parsedThreshold ~= nil
			and parsedLevel > highestLevel
		then
			highestLevel = parsedLevel
			highestThreshold = parsedThreshold
		end
	end

	if numericLevel <= highestLevel then
		return nil
	end

	local postMaxLevelXPStep = math.max(1, math.floor(tonumber(self._config.PostMaxLevelXPStep) or 350))

	return highestThreshold + (numericLevel - highestLevel) * postMaxLevelXPStep
end

function ArenaLevelService:GetNextLevelThreshold(level)
	return self:GetLevelThreshold((tonumber(level) or 1) + 1)
end

function ArenaLevelService:GetMaxArenaLevel()
	local maxArenaLevel = tonumber(self._config.MaxArenaLevel)

	if maxArenaLevel == nil or maxArenaLevel <= 0 then
		return math.huge
	end

	return math.max(1, math.floor(maxArenaLevel))
end

function ArenaLevelService:GetMaxUpgradeLevel()
	local maxUpgradeLevel = tonumber(self._config.MaxUpgradeLevel)
		or tonumber(self._config.CoreBuildLevel)
		or 5

	return math.max(1, math.floor(maxUpgradeLevel))
end

function ArenaLevelService:ShouldGrantLevelUpgradeOffer(arenaLevel)
	return (tonumber(arenaLevel) or 1) <= self:GetMaxUpgradeLevel()
end

function ArenaLevelService:IsUpgradeDefinitionAvailableForLevel(arenaLevel, definition)
	if typeof(definition) ~= "table" then
		return false
	end

	local numericArenaLevel = tonumber(arenaLevel) or 1
	local minArenaLevel = tonumber(definition.MinArenaLevel)

	if minArenaLevel ~= nil and numericArenaLevel < minArenaLevel then
		return false
	end

	local maxOfferLevel = tonumber(definition.MaxOfferLevel)

	if maxOfferLevel ~= nil and numericArenaLevel > maxOfferLevel then
		return false
	end

	local offerAfterLevel = tonumber(definition.OfferAfterLevel)

	if offerAfterLevel ~= nil and numericArenaLevel <= offerAfterLevel then
		return false
	end

	return true
end

function ArenaLevelService:UpdateNextLevelXP(session)
	if session == nil then
		return
	end

	if session.ArenaLevel >= self:GetMaxArenaLevel() then
		session.NextLevelXP = nil
	else
		session.NextLevelXP = self:GetNextLevelThreshold(session.ArenaLevel)
	end
end

function ArenaLevelService:ResetRunProgress(session)
	if session == nil then
		return
	end

	session.ArenaXP = 0
	session.ArenaLevel = 1
	self:UpdateNextLevelXP(session)
	session.UnclaimedLevelUpOffers = 0
end

function ArenaLevelService:AddXP(session, amount)
	if session == nil or session.IsBotSession == true then
		return {
			Added = false,
			Amount = 0,
		}
	end

	local xpAmount = math.max(0, math.floor(tonumber(amount) or 0))

	if xpAmount <= 0 then
		return {
			Added = false,
			Amount = xpAmount,
		}
	end

	local previousLevel = session.ArenaLevel
	local levelUps = 0
	local grantedUpgradeOffers = 0
	session.ArenaXP += xpAmount

	local maxLevel = self:GetMaxArenaLevel()

	while session.ArenaLevel < maxLevel do
		local nextThreshold = self:GetNextLevelThreshold(session.ArenaLevel)

		if nextThreshold == nil or session.ArenaXP < nextThreshold then
			break
		end

		session.ArenaLevel += 1
		levelUps += 1

		if self:ShouldGrantLevelUpgradeOffer(session.ArenaLevel) then
			session.UnclaimedLevelUpOffers += 1
			grantedUpgradeOffers += 1
		end
	end

	self:UpdateNextLevelXP(session)

	return {
		Added = true,
		Amount = xpAmount,
		PreviousLevel = previousLevel,
		ArenaLevel = session.ArenaLevel,
		LevelUps = levelUps,
		GrantedUpgradeOffers = grantedUpgradeOffers,
	}
end

return ArenaLevelService
