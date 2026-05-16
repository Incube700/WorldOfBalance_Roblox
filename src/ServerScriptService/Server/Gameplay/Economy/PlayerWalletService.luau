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

local attributes = CurrencyConfig.Attributes

local function sanitizeBolts(value)
	local numberValue = tonumber(value)

	if numberValue == nil then
		return 0
	end

	return math.max(0, math.floor(numberValue))
end

local function sanitizeWalletData(value)
	if typeof(value) ~= "table" then
		return {
			Bolts = 0,
		}
	end

	return {
		Bolts = sanitizeBolts(value.Bolts),
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

local function setWalletAttributes(player)
	if player == nil then
		return
	end

	player:SetAttribute(attributes.PersistentBalance, getVisibleBolts(player))
	player:SetAttribute(attributes.SessionEarned, getSessionBolts(player))
	player:SetAttribute(attributes.UnsavedBalance, getUnsavedBolts(player))
end

local REWARD_SEQUENCE_ATTRIBUTE = "LastBoltsRewardSequence"

local function setFallbackAttributes(player, preservedUnsavedBolts)
	loadedBoltsByUserId[player.UserId] = 0
	sessionBoltsByUserId[player.UserId] = 0
	unsavedBoltsByUserId[player.UserId] = sanitizeBolts(preservedUnsavedBolts)

	setWalletAttributes(player)
	player:SetAttribute(attributes.LastRewardAmount, 0)
	player:SetAttribute(attributes.LastRewardReason, "")
	player:SetAttribute(REWARD_SEQUENCE_ATTRIBUTE, player:GetAttribute(REWARD_SEQUENCE_ATTRIBUTE) or 0)
	player:SetAttribute("WalletLoaded", false)
	player:SetAttribute("WalletLastSaveSucceeded", false)
end

function PlayerWalletService.loadPlayer(player)
	if player == nil then
		return {
			Bolts = 0,
		}, false
	end

	local preservedUnsavedBolts = getUnsavedBolts(player)

	setFallbackAttributes(player, preservedUnsavedBolts)

	local store, storeError = getDataStore()

	if store == nil then
		warn("[WALLET] DataStore unavailable for " .. player.Name .. ": " .. tostring(storeError))
		return {
			Bolts = 0,
		}, false
	end

	local success, result = pcall(function()
		return store:GetAsync(getPlayerKey(player))
	end)

	if not success then
		warn("[WALLET] Failed to load wallet for " .. player.Name .. ": " .. tostring(result))
		return {
			Bolts = 0,
		}, false
	end

	local walletData = sanitizeWalletData(result)
	local currentSessionBolts = getSessionBolts(player)
	local currentUnsavedBolts = getUnsavedBolts(player)

	loadedBoltsByUserId[player.UserId] = walletData.Bolts
	sessionBoltsByUserId[player.UserId] = currentSessionBolts
	unsavedBoltsByUserId[player.UserId] = currentUnsavedBolts

	setWalletAttributes(player)
	player:SetAttribute("WalletLoaded", true)
	player:SetAttribute("WalletLastSaveSucceeded", currentUnsavedBolts <= 0)

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

function PlayerWalletService.getBoltsBalance(player)
	if player == nil then
		return 0
	end

	return getVisibleBolts(player)
end

function PlayerWalletService.savePlayer(player)
	if player == nil then
		return false
	end

	local pendingDelta = getUnsavedBolts(player)

	if pendingDelta <= 0 then
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
			walletData.Bolts += pendingDelta
			return walletData
		end)
	end)

	if not success then
		warn("[WALLET] Failed to save wallet for " .. player.Name .. ": " .. tostring(result))
		player:SetAttribute("WalletLastSaveSucceeded", false)
		return false
	end

	savedWalletData = sanitizeWalletData(savedWalletData)

	local currentUnsaved = getUnsavedBolts(player)
	local remainingUnsaved = math.max(0, currentUnsaved - pendingDelta)

	loadedBoltsByUserId[player.UserId] = savedWalletData.Bolts
	unsavedBoltsByUserId[player.UserId] = remainingUnsaved

	setWalletAttributes(player)
	player:SetAttribute("WalletLoaded", true)
	player:SetAttribute("WalletLastSaveSucceeded", true)

	return true
end

function PlayerWalletService.removePlayer(player)
	if player == nil then
		return
	end

	if getUnsavedBolts(player) > 0 then
		PlayerWalletService.savePlayer(player)
	end

	if getUnsavedBolts(player) > 0 then
		warn("[WALLET] Keeping unsaved wallet delta in memory for " .. player.Name)
		return
	end

	loadedBoltsByUserId[player.UserId] = nil
	sessionBoltsByUserId[player.UserId] = nil
	unsavedBoltsByUserId[player.UserId] = nil
end

return PlayerWalletService
