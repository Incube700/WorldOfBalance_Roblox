local Players = game:GetService("Players")

local PersistentPlayerStatsService = require(script.Parent:WaitForChild("PersistentPlayerStatsService"))

local MatchStatsService = {}

local DEBUG_STATS = false
local STATS_LOG_INTERVAL = 5

local matchStatDefaults = {
	{ Name = "StatsShotsFired", Value = 0 },
	{ Name = "StatsHits", Value = 0 },
	{ Name = "StatsRicochets", Value = 0 },
	{ Name = "StatsRicochetHits", Value = 0 },
	{ Name = "StatsSelfHits", Value = 0 },
	{ Name = "StatsDamageDealt", Value = 0 },
	{ Name = "StatsDamageTaken", Value = 0 },
	{ Name = "StatsRoundsWon", Value = 0 },
	{ Name = "StatsRoundsLost", Value = 0 },
	{ Name = "StatsMatchResult", Value = "" },
}

local numericMatchStatNames = {
	"StatsShotsFired",
	"StatsHits",
	"StatsRicochets",
	"StatsRicochetHits",
	"StatsSelfHits",
	"StatsDamageDealt",
	"StatsDamageTaken",
	"StatsRoundsWon",
	"StatsRoundsLost",
}

local matchStatsByParticipant = {}
local root = nil
local lastDebugLogByKey = {}

local function copyDefaultStats()
	local stats = {}

	for _, stat in ipairs(matchStatDefaults) do
		stats[stat.Name] = stat.Value
	end

	return stats
end

local function setStatsAttributes(instance, stats)
	if instance == nil then
		return
	end

	for _, stat in ipairs(matchStatDefaults) do
		instance:SetAttribute(stat.Name, stats[stat.Name])
	end
end

local function getParticipantStats(participant)
	if participant == nil then
		return nil
	end

	local stats = matchStatsByParticipant[participant]

	if stats == nil then
		stats = copyDefaultStats()
		matchStatsByParticipant[participant] = stats
	end

	return stats
end

local function participantHasPlayerOwner(participant)
	return participant ~= nil and participant.OwnerPlayer ~= nil and participant.IsPlayerTank == true
end

local function shouldMirrorRootStats(participant)
	if root == nil or participant == nil then
		return false
	end

	local playerSideTankId = root:GetAttribute("PlayerSideTankId")

	if typeof(playerSideTankId) == "string" and playerSideTankId ~= "" then
		return participant.TankId == playerSideTankId
	end

	return participantHasPlayerOwner(participant)
end

local function mirrorParticipantStats(participant)
	local stats = getParticipantStats(participant)

	if stats == nil then
		return
	end

	if participant.OwnerPlayer ~= nil then
		setStatsAttributes(participant.OwnerPlayer, stats)
	end

	if shouldMirrorRootStats(participant) then
		setStatsAttributes(root, stats)
	end
end

local function resetPlayerRuntimeAttributes(player)
	setStatsAttributes(player, copyDefaultStats())
end

local function maybeDebugStats(participant, message)
	if not DEBUG_STATS then
		return
	end

	local tankId = participant ~= nil and participant.TankId or "nil"
	local key = tankId .. ":" .. message
	local now = os.clock()

	if now - (lastDebugLogByKey[key] or 0) < STATS_LOG_INTERVAL then
		return
	end

	lastDebugLogByKey[key] = now
	local userId = participant ~= nil and participant.OwnerUserId or nil
	print("[STATS] runtime recorded tankId=" .. tostring(tankId) .. " userId=" .. tostring(userId) .. " " .. message)
end

local function incrementParticipantStat(participant, statName, amount)
	if not participantHasPlayerOwner(participant) then
		return
	end

	local stats = getParticipantStats(participant)
	stats[statName] = (tonumber(stats[statName]) or 0) + (amount or 1)
	mirrorParticipantStats(participant)
	maybeDebugStats(participant, statName .. "+=" .. tostring(amount or 1))
end

local function setParticipantStat(participant, statName, value)
	if not participantHasPlayerOwner(participant) then
		return
	end

	local stats = getParticipantStats(participant)
	stats[statName] = value
	mirrorParticipantStats(participant)
end

function MatchStatsService.init(targetRoot)
	root = targetRoot
	MatchStatsService.resetRuntimeMatchStats()
end

function MatchStatsService.setMatchStat(name, value)
	if root then
		root:SetAttribute(name, value)
	end
end

function MatchStatsService.incrementMatchStat(name, amount)
	local current = root ~= nil and root:GetAttribute(name) or 0
	MatchStatsService.setMatchStat(name, (tonumber(current) or 0) + (amount or 1))
end

function MatchStatsService.resetRuntimeMatchStats(participants)
	table.clear(matchStatsByParticipant)
	table.clear(lastDebugLogByKey)

	if participants ~= nil then
		for _, participant in ipairs(participants) do
			if participantHasPlayerOwner(participant) then
				matchStatsByParticipant[participant] = copyDefaultStats()
				mirrorParticipantStats(participant)
			end
		end

		return
	end

	if root ~= nil then
		setStatsAttributes(root, copyDefaultStats())
	end

	for _, player in ipairs(Players:GetPlayers()) do
		resetPlayerRuntimeAttributes(player)
	end
end

function MatchStatsService.recordShotFired(participant)
	incrementParticipantStat(participant, "StatsShotsFired", 1)
end

function MatchStatsService.recordProjectileRicochet(projectile)
	if projectile == nil then
		return
	end

	incrementParticipantStat(projectile.OwnerParticipant, "StatsRicochets", 1)
end

function MatchStatsService.recordProjectileTankHitStats(projectile)
	if projectile == nil then
		return
	end

	incrementParticipantStat(projectile.OwnerParticipant, "StatsHits", 1)

	if projectile.BounceCount > 0 then
		incrementParticipantStat(projectile.OwnerParticipant, "StatsRicochetHits", 1)
	end
end

function MatchStatsService.recordProjectileDamageStats(projectile, targetParticipant, damage)
	if projectile == nil then
		return
	end

	local ownerParticipant = projectile.OwnerParticipant
	local resolvedDamage = tonumber(damage) or 0

	if ownerParticipant == targetParticipant then
		incrementParticipantStat(ownerParticipant, "StatsSelfHits", 1)
		incrementParticipantStat(ownerParticipant, "StatsDamageTaken", resolvedDamage)
		return
	end

	incrementParticipantStat(ownerParticipant, "StatsDamageDealt", resolvedDamage)
	incrementParticipantStat(targetParticipant, "StatsDamageTaken", resolvedDamage)
end

function MatchStatsService.recordRoundStats(winnerTankId, loserTankId, participants)
	for _, participant in ipairs(participants or {}) do
		if participant.TankId == winnerTankId then
			incrementParticipantStat(participant, "StatsRoundsWon", 1)
		elseif participant.TankId == loserTankId then
			incrementParticipantStat(participant, "StatsRoundsLost", 1)
		end
	end
end

function MatchStatsService.setParticipantMatchResult(participant, result)
	setParticipantStat(participant, "StatsMatchResult", result)

	if participantHasPlayerOwner(participant) then
		print("[STATS] match result userId=" .. tostring(participant.OwnerUserId) .. " result=" .. tostring(result))
	end
end

function MatchStatsService.getRuntimeMatchStatsSnapshot(participant, currentMatchResult)
	local stats = getParticipantStats(participant) or copyDefaultStats()
	local matchResult = stats.StatsMatchResult

	if matchResult == nil or matchResult == "" then
		matchResult = currentMatchResult
	end

	local snapshot = {
		MatchResult = matchResult or "",
	}

	for _, statName in ipairs(numericMatchStatNames) do
		snapshot[statName] = tonumber(stats[statName]) or 0
	end

	return snapshot
end

function MatchStatsService.persistFinalMatchStats(playerParticipant, currentMatchResult)
	local ownerPlayer = playerParticipant.OwnerPlayer

	if ownerPlayer == nil then
		return
	end

	local statsSnapshot = MatchStatsService.getRuntimeMatchStatsSnapshot(playerParticipant, currentMatchResult)
	print("[STATS] persistent save queued player=" .. ownerPlayer.Name)

	task.spawn(function()
		PersistentPlayerStatsService.saveMatchResult(ownerPlayer, statsSnapshot)
	end)
end

return MatchStatsService
