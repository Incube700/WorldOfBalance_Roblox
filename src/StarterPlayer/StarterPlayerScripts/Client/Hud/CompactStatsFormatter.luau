local CompactStatsFormatter = {}

local function floorNumber(value)
	return math.floor(tonumber(value) or 0)
end

function CompactStatsFormatter.FormatArenaStats(stats)
	stats = stats or {}

	local useShortLabels = stats.UseShortLabels == true
	local levelPrefix = useShortLabels and "Lv" or "Level"
	local crystalsPrefix = useShortLabels and "C" or "Crystals"
	local boltsPrefix = useShortLabels and "B" or "Bolts"
	local level = floorNumber(stats.Level or 1)
	local coreBuildLevel = math.max(1, floorNumber(stats.CoreBuildLevel or 5))
	local isPostCoreLevel = level > coreBuildLevel
	local recordPrefix = useShortLabels and "Rec" or "Record"
	local xp = floorNumber(stats.XP)
	local nextLevelXP = tonumber(stats.NextLevelXP)
	local xpText = nextLevelXP ~= nil and nextLevelXP > 0
		and (tostring(xp) .. "/" .. tostring(floorNumber(nextLevelXP)))
		or tostring(xp)

	return {
		Score = (isPostCoreLevel and recordPrefix or levelPrefix) .. " " .. tostring(level) .. " XP " .. xpText,
		KillsDeaths = "K/D: " .. tostring(floorNumber(stats.Kills)) .. "/" .. tostring(floorNumber(stats.Deaths)),
		Crystals = crystalsPrefix .. ": " .. tostring(floorNumber(stats.Crystals)),
		Bolts = boltsPrefix .. ": " .. tostring(floorNumber(stats.Bolts)),
	}
end

return CompactStatsFormatter
