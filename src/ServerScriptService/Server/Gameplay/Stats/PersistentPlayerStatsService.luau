local DataStoreService = game:GetService("DataStoreService")

local PersistentPlayerStatsService = {}

local STORE_NAME = "WOBPersistentPlayerStatsV1"
local KEY_PREFIX = "Player_"

local statDefaults = {
	TotalMatches = 0,
	TotalWins = 0,
	TotalLosses = 0,
	TotalShotsFired = 0,
	TotalHits = 0,
	TotalRicochets = 0,
	TotalRicochetHits = 0,
	TotalSelfHits = 0,
	TotalDamageDealt = 0,
	TotalDamageTaken = 0,
}

local attributeNames = {
	TotalMatches = "PersistentTotalMatches",
	TotalWins = "PersistentTotalWins",
	TotalLosses = "PersistentTotalLosses",
	TotalShotsFired = "PersistentTotalShotsFired",
	TotalHits = "PersistentTotalHits",
	TotalRicochets = "PersistentTotalRicochets",
	TotalRicochetHits = "PersistentTotalRicochetHits",
	TotalSelfHits = "PersistentTotalSelfHits",
	TotalDamageDealt = "PersistentTotalDamageDealt",
	TotalDamageTaken = "PersistentTotalDamageTaken",
}

local sessionAttributeNames = {
	TotalMatches = "SessionTotalMatches",
	TotalWins = "SessionTotalWins",
	TotalLosses = "SessionTotalLosses",
	TotalShotsFired = "SessionTotalShotsFired",
	TotalHits = "SessionTotalHits",
	TotalRicochets = "SessionTotalRicochets",
	TotalRicochetHits = "SessionTotalRicochetHits",
	TotalSelfHits = "SessionTotalSelfHits",
	TotalDamageDealt = "SessionTotalDamageDealt",
	TotalDamageTaken = "SessionTotalDamageTaken",
}

local unsavedAttributeNames = {
	TotalMatches = "UnsavedTotalMatches",
	TotalWins = "UnsavedTotalWins",
	TotalLosses = "UnsavedTotalLosses",
	TotalShotsFired = "UnsavedTotalShotsFired",
	TotalHits = "UnsavedTotalHits",
	TotalRicochets = "UnsavedTotalRicochets",
	TotalRicochetHits = "UnsavedTotalRicochetHits",
	TotalSelfHits = "UnsavedTotalSelfHits",
	TotalDamageDealt = "UnsavedTotalDamageDealt",
	TotalDamageTaken = "UnsavedTotalDamageTaken",
}

local dataStore = nil
local sessionStatsByUserId = {}
local unsavedStatsByUserId = {}

local function copyDefaultStats()
	local stats = {}

	for statName, defaultValue in pairs(statDefaults) do
		stats[statName] = defaultValue
	end

	return stats
end

local function sanitizeStats(value)
	local stats = copyDefaultStats()

	if typeof(value) ~= "table" then
		return stats
	end

	for statName in pairs(statDefaults) do
		local numberValue = tonumber(value[statName])

		if numberValue ~= nil then
			stats[statName] = math.max(0, math.floor(numberValue))
		end
	end

	return stats
end

local function setPlayerAttributes(player, stats, attributes)
	if player == nil then
		return
	end

	for statName, attributeName in pairs(attributes) do
		player:SetAttribute(attributeName, stats[statName] or 0)
	end
end

local function getPlayerKey(player)
	return KEY_PREFIX .. tostring(player.UserId)
end

local function getPlayerStatsBucket(player, bucketByUserId)
	local stats = bucketByUserId[player.UserId]

	if stats == nil then
		stats = copyDefaultStats()
		bucketByUserId[player.UserId] = stats
	end

	return stats
end

local function addDeltas(stats, deltas)
	for statName, delta in pairs(deltas) do
		stats[statName] = (stats[statName] or 0) + delta
	end
end

local function clearStats(stats)
	for statName in pairs(statDefaults) do
		stats[statName] = 0
	end
end

local function getDataStore()
	if dataStore ~= nil then
		return dataStore, nil
	end

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)

	if not success then
		return nil, result
	end

	dataStore = result
	return dataStore, nil
end

local function getRuntimeNumber(runtimeStats, statName)
	local value = runtimeStats[statName]

	if typeof(value) == "number" then
		return math.max(0, math.floor(value))
	end

	return math.max(0, math.floor(tonumber(value) or 0))
end

local function getMatchDeltas(runtimeStats)
	local matchResult = runtimeStats.MatchResult
	local isWin = matchResult == "Win" or matchResult == "PlayerMatchWin"
	local isLoss = matchResult == "Loss" or matchResult == "DummyMatchWin"

	return {
		TotalMatches = 1,
		TotalWins = isWin and 1 or 0,
		TotalLosses = isLoss and 1 or 0,
		TotalShotsFired = getRuntimeNumber(runtimeStats, "StatsShotsFired"),
		TotalHits = getRuntimeNumber(runtimeStats, "StatsHits"),
		TotalRicochets = getRuntimeNumber(runtimeStats, "StatsRicochets"),
		TotalRicochetHits = getRuntimeNumber(runtimeStats, "StatsRicochetHits"),
		TotalSelfHits = getRuntimeNumber(runtimeStats, "StatsSelfHits"),
		TotalDamageDealt = getRuntimeNumber(runtimeStats, "StatsDamageDealt"),
		TotalDamageTaken = getRuntimeNumber(runtimeStats, "StatsDamageTaken"),
	}
end

function PersistentPlayerStatsService.loadPlayer(player)
	local fallbackStats = copyDefaultStats()
	local sessionStats = getPlayerStatsBucket(player, sessionStatsByUserId)
	local unsavedStats = getPlayerStatsBucket(player, unsavedStatsByUserId)

	clearStats(sessionStats)
	clearStats(unsavedStats)

	setPlayerAttributes(player, fallbackStats, attributeNames)
	setPlayerAttributes(player, sessionStats, sessionAttributeNames)
	setPlayerAttributes(player, unsavedStats, unsavedAttributeNames)
	player:SetAttribute("PersistentStatsLoaded", false)
	player:SetAttribute("PersistentStatsLastSaveSucceeded", false)

	local store, storeError = getDataStore()

	if store == nil then
		warn("[DATASTORE] Persistent stats unavailable for " .. player.Name .. ": " .. tostring(storeError))
		return fallbackStats, false
	end

	local success, result = pcall(function()
		return store:GetAsync(getPlayerKey(player))
	end)

	if not success then
		warn("[DATASTORE] Failed to load persistent stats for " .. player.Name .. ": " .. tostring(result))
		return fallbackStats, false
	end

	local stats = sanitizeStats(result)
	setPlayerAttributes(player, stats, attributeNames)
	player:SetAttribute("PersistentStatsLoaded", true)
	player:SetAttribute("PersistentStatsLastSaveSucceeded", true)

	return stats, true
end

function PersistentPlayerStatsService.saveMatchResult(player, runtimeStats)
	if player == nil then
		return false
	end

	runtimeStats = runtimeStats or {}

	local deltas = getMatchDeltas(runtimeStats)
	local savedStats = nil
	local sessionStats = getPlayerStatsBucket(player, sessionStatsByUserId)
	local unsavedStats = getPlayerStatsBucket(player, unsavedStatsByUserId)

	addDeltas(sessionStats, deltas)
	addDeltas(unsavedStats, deltas)
	setPlayerAttributes(player, sessionStats, sessionAttributeNames)
	setPlayerAttributes(player, unsavedStats, unsavedAttributeNames)
	player:SetAttribute("PersistentStatsLastSaveSucceeded", false)

	local store, storeError = getDataStore()

	if store == nil then
		warn("[DATASTORE] Persistent stats unavailable for " .. player.Name .. ": " .. tostring(storeError))
		return false
	end

	local success, result = pcall(function()
		savedStats = store:UpdateAsync(getPlayerKey(player), function(oldValue)
			local stats = sanitizeStats(oldValue)

			addDeltas(stats, unsavedStats)

			return stats
		end)
	end)

	if not success then
		warn("[DATASTORE] Failed to save persistent stats for " .. player.Name .. ": " .. tostring(result))
		return false
	end

	savedStats = sanitizeStats(savedStats)
	clearStats(unsavedStats)
	setPlayerAttributes(player, savedStats, attributeNames)
	setPlayerAttributes(player, unsavedStats, unsavedAttributeNames)
	player:SetAttribute("PersistentStatsLoaded", true)
	player:SetAttribute("PersistentStatsLastSaveSucceeded", true)

	return true
end

return PersistentPlayerStatsService
