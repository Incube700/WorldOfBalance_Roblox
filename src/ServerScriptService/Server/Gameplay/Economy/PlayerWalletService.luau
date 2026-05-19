local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local CurrencyConfig = require(configs:WaitForChild("CurrencyConfig"))

local PlayerWalletService = {}

local STORE_NAME = "WOBPlayerWalletV1"
local KEY_PREFIX = "Player_"

local walletStore = nil
local loadedBoltsByUserId = {}
local sessionBoltsByUserId = {}
local unsavedBoltsByUserId = {}
local loadedCrystalsByUserId = {}
local sessionCrystalsByUserId = {}
local unsavedCrystalsByUserId = {}

local attributes = CurrencyConfig.Attributes
local crystalAttributes = CurrencyConfig.Crystals.Attributes

local function sanitizeCurrencyValue(value)
	local numberValue = tonumber(value)

	if numberValue == nil then
		return 0
	end

	return math.max(0, math.floor(numberValue))
end

local function sanitizeBolts(value)
	return sanitizeCurrencyValue(value)
end

local function sanitizeCrystals(value)
	return sanitizeCurrencyValue(value)
end

local function sanitizeWalletData(value)
	if typeof(value) ~= "table" then
		return {
			Bolts = 0,
			Crystals = 0,
		}
	end

	return {
		Bolts = sanitizeBolts(value.Bolts),
		Crystals = sanitizeCrystals(value.Crystals),
	}
end

local function getPlayerKey(player)
	return KEY_PREFIX .. tostring(player.UserId)
end

local function getDataStore()
	if walletStore ~= nil then
		return walletStore, nil
	end

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)

	if not success then
		return nil, result
	end

	walletStore = result
	return walletStore, nil
end

local function getLoadedBolts(player)
	return loadedBoltsByUserId[player.UserId] or 0
end

local function getSessionBolts(player)
	return sessionBoltsByUserId[player.UserId] or 0
end

local function getUnsavedBolts(player)
	return unsavedBoltsByUserId[player.UserId] or 0
end

local function getVisibleBolts(player)
	return getLoadedBolts(player) + getUnsavedBolts(player)
end

local function getLoadedCrystals(player)
	return loadedCrystalsByUserId[player.UserId] or 0
end

local function getSessionCrystals(player)
	return sessionCrystalsByUserId[player.UserId] or 0
end

local function getUnsavedCrystals(player)
	return unsavedCrystalsByUserId[player.UserId] or 0
end

local function getVisibleCrystals(player)
	return getLoadedCrystals(player) + getUnsavedCrystals(player)
end

local function setWalletAttributes(player)
	if player == nil then
		return
	end

	player:SetAttribute(attributes.PersistentBalance, getVisibleBolts(player))
	player:SetAttribute(attributes.SessionEarned, getSessionBolts(player))
	player:SetAttribute(attributes.UnsavedBalance, getUnsavedBolts(player))
	player:SetAttribute(crystalAttributes.Balance, getVisibleCrystals(player))
	player:SetAttribute(crystalAttributes.PersistentBalance, getVisibleCrystals(player))
	player:SetAttribute(crystalAttributes.SessionEarned, getSessionCrystals(player))
	player:SetAttribute(crystalAttributes.UnsavedBalance, getUnsavedCrystals(player))
end

local REWARD_SEQUENCE_ATTRIBUTE = "LastBoltsRewardSequence"

local function setFallbackAttributes(player, preservedUnsavedBolts, preservedUnsavedCrystals)
	loadedBoltsByUserId[player.UserId] = 0
	sessionBoltsByUserId[player.UserId] = 0
	unsavedBoltsByUserId[player.UserId] = sanitizeBolts(preservedUnsavedBolts)
	loadedCrystalsByUserId[player.UserId] = 0
	sessionCrystalsByUserId[player.UserId] = 0
	unsavedCrystalsByUserId[player.UserId] = sanitizeCrystals(preservedUnsavedCrystals)

	setWalletAttributes(player)
	player:SetAttribute(attributes.LastRewardAmount, 0)
	player:SetAttribute(attributes.LastRewardReason, "")
	player:SetAttribute(REWARD_SEQUENCE_ATTRIBUTE, player:GetAttribute(REWARD_SEQUENCE_ATTRIBUTE) or 0)
	player:SetAttribute(crystalAttributes.LastRewardAmount, 0)
	player:SetAttribute(crystalAttributes.LastRewardReason, "")
	player:SetAttribute(crystalAttributes.LastRewardSequence, player:GetAttribute(crystalAttributes.LastRewardSequence) or 0)
	player:SetAttribute(crystalAttributes.LastRewardMatchId, "")
	player:SetAttribute("WalletLoaded", false)
	player:SetAttribute("WalletLastSaveSucceeded", false)
end

function PlayerWalletService.loadPlayer(player)
	if player == nil then
		return {
			Bolts = 0,
			Crystals = 0,
		}, false
	end

	local preservedUnsavedBolts = getUnsavedBolts(player)
	local preservedUnsavedCrystals = getUnsavedCrystals(player)

	setFallbackAttributes(player, preservedUnsavedBolts, preservedUnsavedCrystals)

	local store, storeError = getDataStore()

	if store == nil then
		warn("[WALLET] DataStore unavailable for " .. player.Name .. ": " .. tostring(storeError))
		return {
			Bolts = 0,
			Crystals = 0,
		}, false
	end

	local success, result = pcall(function()
		return store:GetAsync(getPlayerKey(player))
	end)

	if not success then
		warn("[WALLET] Failed to load wallet for " .. player.Name .. ": " .. tostring(result))
		return {
			Bolts = 0,
			Crystals = 0,
		}, false
	end

	local walletData = sanitizeWalletData(result)
	local currentSessionBolts = getSessionBolts(player)
	local currentUnsavedBolts = getUnsavedBolts(player)
	local currentSessionCrystals = getSessionCrystals(player)
	local currentUnsavedCrystals = getUnsavedCrystals(player)

	loadedBoltsByUserId[player.UserId] = walletData.Bolts
	sessionBoltsByUserId[player.UserId] = currentSessionBolts
	unsavedBoltsByUserId[player.UserId] = currentUnsavedBolts
	loadedCrystalsByUserId[player.UserId] = walletData.Crystals
	sessionCrystalsByUserId[player.UserId] = currentSessionCrystals
	unsavedCrystalsByUserId[player.UserId] = currentUnsavedCrystals

	setWalletAttributes(player)
	player:SetAttribute("WalletLoaded", true)
	player:SetAttribute("WalletLastSaveSucceeded", currentUnsavedBolts <= 0 and currentUnsavedCrystals <= 0)

	return walletData, true
end

function PlayerWalletService.addBolts(player, amount, reason)
	if player == nil then
		return false, 0
	end

	local rewardAmount = sanitizeBolts(amount)

	if rewardAmount <= 0 then
		return false, PlayerWalletService.getBoltsBalance(player)
	end

	local userId = player.UserId
	sessionBoltsByUserId[userId] = getSessionBolts(player) + rewardAmount
	unsavedBoltsByUserId[userId] = getUnsavedBolts(player) + rewardAmount

	setWalletAttributes(player)
	player:SetAttribute(attributes.LastRewardAmount, rewardAmount)
	player:SetAttribute(attributes.LastRewardReason, tostring(reason or "Reward"))
	player:SetAttribute(REWARD_SEQUENCE_ATTRIBUTE, (tonumber(player:GetAttribute(REWARD_SEQUENCE_ATTRIBUTE)) or 0) + 1)
	player:SetAttribute("WalletLastSaveSucceeded", false)

	print(
		("[WALLET] %s +%d %s reason=%s total=%d"):format(
			player.Name,
			rewardAmount,
			CurrencyConfig.DisplayName,
			tostring(reason or "Reward"),
			PlayerWalletService.getBoltsBalance(player)
		)
	)

	return true, PlayerWalletService.getBoltsBalance(player)
end

function PlayerWalletService.addCrystals(player, amount, reason)
	if player == nil then
		return false, 0
	end

	local rewardAmount = sanitizeCrystals(amount)

	if rewardAmount <= 0 then
		return false, PlayerWalletService.getCrystalsBalance(player)
	end

	local userId = player.UserId
	sessionCrystalsByUserId[userId] = getSessionCrystals(player) + rewardAmount
	unsavedCrystalsByUserId[userId] = getUnsavedCrystals(player) + rewardAmount

	setWalletAttributes(player)
	player:SetAttribute(crystalAttributes.LastRewardAmount, rewardAmount)
	player:SetAttribute(crystalAttributes.LastRewardReason, tostring(reason or "Reward"))
	player:SetAttribute(
		crystalAttributes.LastRewardSequence,
		(tonumber(player:GetAttribute(crystalAttributes.LastRewardSequence)) or 0) + 1
	)
	player:SetAttribute("WalletLastSaveSucceeded", false)

	print(
		("[WALLET] %s +%d %s reason=%s total=%d"):format(
			player.Name,
			rewardAmount,
			CurrencyConfig.Crystals.DisplayName,
			tostring(reason or "Reward"),
			PlayerWalletService.getCrystalsBalance(player)
		)
	)

	return true, PlayerWalletService.getCrystalsBalance(player)
end

function PlayerWalletService.getBoltsBalance(player)
	if player == nil then
		return 0
	end

	return getVisibleBolts(player)
end

function PlayerWalletService.getCrystalsBalance(player)
	if player == nil then
		return 0
	end

	return getVisibleCrystals(player)
end

function PlayerWalletService.savePlayer(player)
	if player == nil then
		return false
	end

	local pendingBoltsDelta = getUnsavedBolts(player)
	local pendingCrystalsDelta = getUnsavedCrystals(player)

	if pendingBoltsDelta <= 0 and pendingCrystalsDelta <= 0 then
		player:SetAttribute("WalletLastSaveSucceeded", true)
		return true
	end

	local store, storeError = getDataStore()

	if store == nil then
		warn("[WALLET] DataStore unavailable while saving " .. player.Name .. ": " .. tostring(storeError))
		player:SetAttribute("WalletLastSaveSucceeded", false)
		return false
	end

	local savedWalletData = nil
	local success, result = pcall(function()
		savedWalletData = store:UpdateAsync(getPlayerKey(player), function(oldValue)
			local walletData = sanitizeWalletData(oldValue)
			walletData.Bolts += pendingBoltsDelta
			walletData.Crystals += pendingCrystalsDelta
			return walletData
		end)
	end)

	if not success then
		warn("[WALLET] Failed to save wallet for " .. player.Name .. ": " .. tostring(result))
		player:SetAttribute("WalletLastSaveSucceeded", false)
		return false
	end

	savedWalletData = sanitizeWalletData(savedWalletData)

	local currentUnsavedBolts = getUnsavedBolts(player)
	local currentUnsavedCrystals = getUnsavedCrystals(player)
	local remainingUnsavedBolts = math.max(0, currentUnsavedBolts - pendingBoltsDelta)
	local remainingUnsavedCrystals = math.max(0, currentUnsavedCrystals - pendingCrystalsDelta)

	loadedBoltsByUserId[player.UserId] = savedWalletData.Bolts
	unsavedBoltsByUserId[player.UserId] = remainingUnsavedBolts
	loadedCrystalsByUserId[player.UserId] = savedWalletData.Crystals
	unsavedCrystalsByUserId[player.UserId] = remainingUnsavedCrystals

	setWalletAttributes(player)
	player:SetAttribute("WalletLoaded", true)
	player:SetAttribute("WalletLastSaveSucceeded", true)

	return true
end

function PlayerWalletService.removePlayer(player)
	if player == nil then
		return
	end

	if getUnsavedBolts(player) > 0 or getUnsavedCrystals(player) > 0 then
		PlayerWalletService.savePlayer(player)
	end

	if getUnsavedBolts(player) > 0 or getUnsavedCrystals(player) > 0 then
		warn("[WALLET] Keeping unsaved wallet delta in memory for " .. player.Name)
		return
	end

	loadedBoltsByUserId[player.UserId] = nil
	sessionBoltsByUserId[player.UserId] = nil
	unsavedBoltsByUserId[player.UserId] = nil
	loadedCrystalsByUserId[player.UserId] = nil
	sessionCrystalsByUserId[player.UserId] = nil
	unsavedCrystalsByUserId[player.UserId] = nil
end

return PlayerWalletService
