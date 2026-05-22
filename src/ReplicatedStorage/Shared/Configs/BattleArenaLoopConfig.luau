local BattleArenaLoopConfig = table.freeze({
	Enabled = true,

	Session = table.freeze({
		ShowSessionTimer = true,
		SoftSessionLengthSeconds = 180,
		EndlessMode = true,
	}),

	Bots = table.freeze({
		MaintainMinBots = true,
		MinBotsSolo = 2,
		MinBotsWithPlayers = 1,
		MaxBots = 4,
		RespawnDelay = 3,
	}),

	Score = table.freeze({
		PlayerKillBot = 10,
		BotKillPlayer = 0,
		RicochetKillBonus = 5,
		NoPenBlockedBonus = 1,
		SurvivalTickSeconds = 30,
		SurvivalTickReward = 2,
	}),

	Rewards = table.freeze({
		BoltsPerBotKill = 3,
		BoltsPerRicochetKillBonus = 2,
		CrystalsPerDailyFirstDuelWin = 1,
		CrystalsPerBattleArenaMilestone = 1,
		BattleArenaMilestoneKills = 10,
		EnableBattleArenaCrystalMilestones = false,
	}),
})

return BattleArenaLoopConfig
