-- AchievementCatalog (Etap 4): definitions for arena achievements + leaderboard stats.
-- Pure data. The server AchievementService reads this to track progress, grant Bolt
-- rewards, and toast the client. Add a new achievement by adding an entry here.

local AchievementCatalog = {}

-- leaderstats columns shown on the Roblox leaderboard (Tab menu).
AchievementCatalog.Leaderstats = table.freeze({
	-- key -> { Name = display column, Attribute = source player attribute (optional) }
	Bolts = table.freeze({ Name = "Bolts" }),
	Kills = table.freeze({ Name = "Kills" }),
	BestLevel = table.freeze({ Name = "Best Level" }),
})

-- Achievement metadata. Each is unlocked once; RewardBolts is granted on unlock.
-- Kinds the AchievementService understands:
--   "KillsTotal"      -> Threshold lifetime kills
--   "KillsInSession"  -> Threshold kills within one arena session
--   "ArenaLevel"      -> reach Threshold arena level in a session
--   "RicochetKill"    -> a kill whose shell had bounced at least once
--   "WeaponKill"      -> a kill with WeaponId == Weapon
AchievementCatalog.Achievements = table.freeze({
	FirstBlood = table.freeze({
		Id = "FirstBlood",
		Title = "First Blood",
		Description = "Get your first kill.",
		Kind = "KillsTotal",
		Threshold = 1,
		RewardBolts = 10,
		Icon = "⚔",
	}),
	Killer10 = table.freeze({
		Id = "Killer10",
		Title = "On a Roll",
		Description = "Get 10 kills in one arena run.",
		Kind = "KillsInSession",
		Threshold = 10,
		RewardBolts = 25,
		Icon = "🔥",
	}),
	Level10 = table.freeze({
		Id = "Level10",
		Title = "Veteran",
		Description = "Reach arena level 10.",
		Kind = "ArenaLevel",
		Threshold = 10,
		RewardBolts = 40,
		Icon = "★",
	}),
	Level20 = table.freeze({
		Id = "Level20",
		Title = "Arena Legend",
		Description = "Reach arena level 20.",
		Kind = "ArenaLevel",
		Threshold = 20,
		RewardBolts = 100,
		Icon = "👑",
	}),
	TrickShot = table.freeze({
		Id = "TrickShot",
		Title = "Trick Shot",
		Description = "Kill an enemy with a ricochet shot.",
		Kind = "RicochetKill",
		Threshold = 1,
		RewardBolts = 20,
		Icon = "↩",
	}),
	Sniper = table.freeze({
		Id = "Sniper",
		Title = "Sniper",
		Description = "Get a kill with the Rail Gun.",
		Kind = "WeaponKill",
		Weapon = "RailGun",
		Threshold = 1,
		RewardBolts = 20,
		Icon = "➤",
	}),
})

return table.freeze(AchievementCatalog)
