local PersistentPlayerStatsService = require(script.Parent:WaitForChild("PersistentPlayerStatsService"))

local MatchStatsService = {}

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

local matchStats = {}
local root = nil

function MatchStatsService.init(targetRoot)
	root = targetRoot
end

function MatchStatsService.setMatchStat(name, value)
	matchStats[name] = value
	if root then
		root:SetAttribute(name, value)
	end
end

function MatchStatsService.incrementMatchStat(name, amount)
	MatchStatsService.setMatchStat(name, (matchStats[name] or 0) + (amount or 1))
end

function MatchStatsService.resetRuntimeMatchStats()
	for _, stat in ipairs(matchStatDefaults) do
		MatchStatsService.setMatchStat(stat.Name, stat.Value)
	end
end

function MatchStatsService.recordShotFired(participant, playerParticipant)
	if participant == playerParticipant then
		MatchStatsService.incrementMatchStat("StatsShotsFired", 1)
	end
end

function MatchStatsService.recordProjectileRicochet(projectile, playerParticipant)
	if projectile.OwnerParticipant == playerParticipant then
		MatchStatsService.incrementMatchStat("StatsRicochets", 1)
	end
end

function MatchStatsService.recordProjectileTankHitStats(projectile, playerParticipant)
	if projectile.OwnerParticipant == playerParticipant then
		MatchStatsService.incrementMatchStat("StatsHits", 1)

		if projectile.BounceCount > 0 then
			MatchStatsService.incrementMatchStat("StatsRicochetHits", 1)
		end
	end
end

function MatchStatsService.recordProjectileDamageStats(projectile, targetParticipant, damage, playerParticipant)
	if projectile.OwnerParticipant == playerParticipant then
		if targetParticipant == playerParticipant then
			MatchStatsService.incrementMatchStat("StatsSelfHits", 1)
			MatchStatsService.incrementMatchStat("StatsDamageTaken", damage)
		else
			MatchStatsService.incrementMatchStat("StatsDamageDealt", damage)
		end
	elseif targetParticipant == playerParticipant then
		MatchStatsService.incrementMatchStat("StatsDamageTaken", damage)
	end
end

function MatchStatsService.recordRoundStats(result, ROUND_RESULT_WIN, ROUND_RESULT_LOSE)
	if result == ROUND_RESULT_WIN then
		MatchStatsService.incrementMatchStat("StatsRoundsWon", 1)
	elseif result == ROUND_RESULT_LOSE then
		MatchStatsService.incrementMatchStat("StatsRoundsLost", 1)
	end
end

function MatchStatsService.getRuntimeMatchStatsSnapshot(currentMatchResult)
	return {
		MatchResult = matchStats.StatsMatchResult ~= "" and matchStats.StatsMatchResult or currentMatchResult,
		StatsShotsFired = matchStats.StatsShotsFired or 0,
		StatsHits = matchStats.StatsHits or 0,
		StatsRicochets = matchStats.StatsRicochets or 0,
		StatsRicochetHits = matchStats.StatsRicochetHits or 0,
		StatsSelfHits = matchStats.StatsSelfHits or 0,
		StatsDamageDealt = matchStats.StatsDamageDealt or 0,
		StatsDamageTaken = matchStats.StatsDamageTaken or 0,
		StatsRoundsWon = matchStats.StatsRoundsWon or 0,
		StatsRoundsLost = matchStats.StatsRoundsLost or 0,
	}
end

function MatchStatsService.persistFinalMatchStats(playerParticipant, currentMatchResult)
	local ownerPlayer = playerParticipant.OwnerPlayer

	if ownerPlayer == nil then
		return
	end

	local statsSnapshot = MatchStatsService.getRuntimeMatchStatsSnapshot(currentMatchResult)

	task.spawn(function()
		PersistentPlayerStatsService.saveMatchResult(ownerPlayer, statsSnapshot)
	end)
end

return MatchStatsService
