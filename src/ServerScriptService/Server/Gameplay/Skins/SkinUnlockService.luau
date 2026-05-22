local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local SkinCatalog = require(configs:WaitForChild("SkinCatalog"))

local SkinUnlockService = {}

local UNLOCKED_SKINS_ATTRIBUTE = "UnlockedSkinIds"

local function getDefaultSkinId()
	return SkinCatalog.DefaultSkinId or "Default"
end

local function splitCsv(value)
	local results = {}

	if typeof(value) ~= "string" then
		return results
	end

	for token in string.gmatch(value, "[^,]+") do
		results[token] = true
	end

	return results
end

local function serializeSkinIds(unlockedById)
	local skinIds = {}

	for skinId, isUnlocked in pairs(unlockedById) do
		if isUnlocked == true then
			table.insert(skinIds, skinId)
		end
	end

	table.sort(skinIds)

	return table.concat(skinIds, ",")
end

local function getSkinDefinition(skinId)
	local skins = SkinCatalog.Skins or {}
	local skin = skins[skinId]

	if skin ~= nil and typeof(skin.AliasOf) == "string" then
		return skins[skin.AliasOf], skin.AliasOf
	end

	return skin, skinId
end

function SkinUnlockService.GetDefaultUnlockState()
	local unlocked = {}

	for skinId, skin in pairs(SkinCatalog.Skins or {}) do
		if skin.UnlockedByDefault == true or skinId == getDefaultSkinId() then
			unlocked[skinId] = true
		end
	end

	unlocked[getDefaultSkinId()] = true

	return unlocked
end

function SkinUnlockService.EnsurePlayerDefaults(player)
	if player == nil then
		return
	end

	local existingValue = player:GetAttribute(UNLOCKED_SKINS_ATTRIBUTE)

	if typeof(existingValue) == "string" and existingValue ~= "" then
		return
	end

	player:SetAttribute(UNLOCKED_SKINS_ATTRIBUTE, serializeSkinIds(SkinUnlockService.GetDefaultUnlockState()))
end

function SkinUnlockService.GetUnlockedSkinIds(player)
	local unlocked = SkinUnlockService.GetDefaultUnlockState()

	if player ~= nil then
		for skinId, isUnlocked in pairs(splitCsv(player:GetAttribute(UNLOCKED_SKINS_ATTRIBUTE))) do
			if isUnlocked == true then
				unlocked[skinId] = true
			end
		end
	end

	return unlocked
end

function SkinUnlockService.IsSkinUnlocked(player, skinId)
	local skin, resolvedSkinId = getSkinDefinition(skinId)

	if skin == nil then
		return false
	end

	return SkinUnlockService.GetUnlockedSkinIds(player)[resolvedSkinId] == true
end

function SkinUnlockService.CanUnlock(player, skinId)
	local skin, resolvedSkinId = getSkinDefinition(skinId)

	if skin == nil then
		return false, "UnknownSkin"
	end

	if SkinUnlockService.IsSkinUnlocked(player, resolvedSkinId) then
		return false, "AlreadyUnlocked"
	end

	if skin.DuelSafe ~= true then
		return false, "NotDuelSafe"
	end

	return true, "CanUnlock"
end

function SkinUnlockService.GetUnlockCost(skinId)
	local skin = getSkinDefinition(skinId)

	if skin == nil then
		return nil
	end

	return {
		Currency = skin.Currency or "Bolts",
		Price = math.max(0, math.floor(tonumber(skin.Price) or 0)),
	}
end

return SkinUnlockService
