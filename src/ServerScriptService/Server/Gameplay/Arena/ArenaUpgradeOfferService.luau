local HttpService = game:GetService("HttpService")

local ArenaUpgradeOfferService = {}
ArenaUpgradeOfferService.__index = ArenaUpgradeOfferService

-- Etap 1: ReflectShield removed from the level-up pool (spawn-protection shield still exists
-- separately). Three new upgrades added: Lifesteal, Piercing, Overcharge.
local UPGRADE_ORDER = {
	"DamageUp",
	"FireRateUp",
	"MoveSpeedUp",
	"DoubleShot",
	"TripleSpread",
	"RicochetUp",
	"Lifesteal",
	"Piercing",
	"Overcharge",
}

function ArenaUpgradeOfferService.new(config, levelService)
	return setmetatable({
		_config = config or {},
		_levelService = levelService,
		_random = Random.new(),
	}, ArenaUpgradeOfferService)
end

function ArenaUpgradeOfferService:HasUpgrade(session, upgradeId)
	if session == nil then
		return false
	end

	for _, existingUpgradeId in ipairs(session.UpgradeIds) do
		if existingUpgradeId == upgradeId then
			return true
		end
	end

	return false
end

function ArenaUpgradeOfferService:CountUpgradeStacks(session, upgradeId)
	if session == nil then
		return 0
	end

	local count = 0

	for _, existingUpgradeId in ipairs(session.UpgradeIds) do
		if existingUpgradeId == upgradeId then
			count += 1
		end
	end

	return count
end

function ArenaUpgradeOfferService:GetUpgradeDefinition(upgradeId)
	local pool = self._config.UpgradePool or {}

	return pool[upgradeId]
end

function ArenaUpgradeOfferService:GetUpgradeMaxStacks(upgradeId)
	local definition = self:GetUpgradeDefinition(upgradeId)

	if definition == nil then
		return 0
	end

	if definition.Immediate == true then
		return math.huge
	end

	return math.max(1, math.floor(tonumber(definition.MaxStacks) or 1))
end

function ArenaUpgradeOfferService:IsBlockedByOwnedUpgrade(session, blockedUpgradeIds)
	if typeof(blockedUpgradeIds) == "string" then
		return self:HasUpgrade(session, blockedUpgradeIds)
	end

	if typeof(blockedUpgradeIds) ~= "table" then
		return false
	end

	for _, blockedUpgradeId in ipairs(blockedUpgradeIds) do
		if typeof(blockedUpgradeId) == "string" and self:HasUpgrade(session, blockedUpgradeId) then
			return true
		end
	end

	return false
end

function ArenaUpgradeOfferService:IsUpgradeChoiceValid(session, upgradeId)
	if session == nil or typeof(upgradeId) ~= "string" then
		return false
	end

	local definition = self:GetUpgradeDefinition(upgradeId)

	if definition == nil then
		return false
	end

	if definition.Enabled == false or definition.FutureOnly == true then
		return false
	end

	if self._levelService ~= nil
		and not self._levelService:IsUpgradeDefinitionAvailableForLevel(session.ArenaLevel, definition)
	then
		return false
	end

	if self:IsBlockedByOwnedUpgrade(session, definition.BlocksUpgrade) then
		return false
	end

	if definition.Immediate == true then
		return true
	end

	if upgradeId == "DoubleShot" and self:HasUpgrade(session, "TripleSpread") then
		return false
	end

	if upgradeId == "TripleSpread" and not self:HasUpgrade(session, "DoubleShot") then
		return false
	end

	local requiredUpgrade = definition.RequiresUpgrade

	if typeof(requiredUpgrade) == "string" and not self:HasUpgrade(session, requiredUpgrade) then
		return false
	end

	return self:CountUpgradeStacks(session, upgradeId) < self:GetUpgradeMaxStacks(upgradeId)
end

function ArenaUpgradeOfferService:GetValidUpgradeIds(session)
	local upgradeIds = {}

	for _, upgradeId in ipairs(UPGRADE_ORDER) do
		if self:IsUpgradeChoiceValid(session, upgradeId) then
			table.insert(upgradeIds, upgradeId)
		end
	end

	return upgradeIds
end

function ArenaUpgradeOfferService:MakeUpgradeChoicePayload(session, upgradeId)
	local definition = self:GetUpgradeDefinition(upgradeId) or {}
	local currentStacks = self:CountUpgradeStacks(session, upgradeId)
	local maxStacks = self:GetUpgradeMaxStacks(upgradeId)

	return {
		Id = upgradeId,
		Title = definition.Title or upgradeId,
		Description = definition.Description or "",
		Stack = definition.Immediate == true and 0 or currentStacks + 1,
		MaxStacks = maxStacks == math.huge and 0 or maxStacks,
		Immediate = definition.Immediate == true,
	}
end

function ArenaUpgradeOfferService:ClearPendingUpgradeOffer(session)
	if session == nil then
		return
	end

	session.PendingUpgradeOffer = nil
	session.PendingUpgradeOfferId = ""
	session.PendingUpgradeOfferSource = ""
end

function ArenaUpgradeOfferService:CreateUpgradeOffer(session, source)
	if session == nil or session.Player == nil or session.PendingUpgradeOffer ~= nil then
		return false, nil
	end

	local validUpgradeIds = self:GetValidUpgradeIds(session)

	if #validUpgradeIds == 0 then
		return false, nil
	end

	for index = #validUpgradeIds, 2, -1 do
		local swapIndex = self._random:NextInteger(1, index)
		validUpgradeIds[index], validUpgradeIds[swapIndex] = validUpgradeIds[swapIndex], validUpgradeIds[index]
	end

	local choiceCount = math.min(
		math.max(1, math.floor(tonumber(self._config.UpgradeChoicesPerOffer) or 3)),
		#validUpgradeIds
	)
	local choices = {}

	for index = 1, choiceCount do
		table.insert(choices, self:MakeUpgradeChoicePayload(session, validUpgradeIds[index]))
	end

	local offerId = "ArenaOffer_" .. HttpService:GenerateGUID(false)
	local offer = {
		OfferId = offerId,
		Source = source or "LevelUp",
		ArenaLevel = session.ArenaLevel,
		Choices = choices,
	}

	session.PendingUpgradeOffer = offer
	session.PendingUpgradeOfferId = offerId
	session.PendingUpgradeOfferSource = source or "LevelUp"

	return true, offer
end

function ArenaUpgradeOfferService:EnsurePendingLevelOffer(session)
	if session == nil or session.PendingUpgradeOffer ~= nil then
		return {
			Created = false,
			StateChanged = false,
		}
	end

	if (session.UnclaimedLevelUpOffers or 0) <= 0 then
		return {
			Created = false,
			StateChanged = false,
		}
	end

	local created, offer = self:CreateUpgradeOffer(session, "LevelUp")

	if not created then
		session.UnclaimedLevelUpOffers = 0

		return {
			Created = false,
			StateChanged = true,
		}
	end

	return {
		Created = true,
		StateChanged = true,
		Offer = offer,
	}
end

function ArenaUpgradeOfferService:HasOfferedChoice(session, upgradeId)
	if session == nil or session.PendingUpgradeOffer == nil then
		return false
	end

	for _, choice in ipairs(session.PendingUpgradeOffer.Choices or {}) do
		if choice.Id == upgradeId then
			return true
		end
	end

	return false
end

return ArenaUpgradeOfferService
