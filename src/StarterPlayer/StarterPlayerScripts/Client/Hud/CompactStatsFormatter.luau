local CompactStatsFormatter = {}

local function floorNumber(value)
	return math.floor(tonumber(value) or 0)
end

function CompactStatsFormatter.FormatArenaStats(stats)
	stats = stats or {}

	local useShortLabels = stats.UseShortLabels == true
	local scorePrefix = useShortLabels and "S" or "Score"
	local crystalsPrefix = useShortLabels and "C" or "Crystals"
	local boltsPrefix = useShortLabels and "B" or "Bolts"

	return {
		Score = scorePrefix .. ": " .. tostring(floorNumber(stats.Score)),
		KillsDeaths = "K/D: " .. tostring(floorNumber(stats.Kills)) .. "/" .. tostring(floorNumber(stats.Deaths)),
		Crystals = crystalsPrefix .. ": " .. tostring(floorNumber(stats.Crystals)),
		Bolts = boltsPrefix .. ": " .. tostring(floorNumber(stats.Bolts)),
	}
end

return CompactStatsFormatter
