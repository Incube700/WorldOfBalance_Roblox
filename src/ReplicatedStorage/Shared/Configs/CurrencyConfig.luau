local CurrencyConfig = table.freeze({
	CurrencyId = "Bolts",
	DisplayName = "Bolts",
	CrystalCurrencyId = "Crystals",
	CrystalDisplayName = "Crystals",

	Rewards = table.freeze({
		TrainingKill = 1,
		PvPKill = 1,
		BattleArenaBotKill = 3,
		BattleArenaRicochetKillBonus = 2,
		SelfKill = 0,
		MatchWin = 0,
	}),

	Attributes = table.freeze({
		PersistentBalance = "PersistentBolts",
		SessionEarned = "SessionBoltsEarned",
		UnsavedBalance = "UnsavedBolts",
		LastRewardAmount = "LastBoltsRewardAmount",
		LastRewardReason = "LastBoltsRewardReason",
	}),

	Crystals = table.freeze({
		CurrencyId = "Crystals",
		DisplayName = "Crystals",

		Attributes = table.freeze({
			Balance = "Crystals",
			PersistentBalance = "PersistentCrystals",
			SessionEarned = "SessionCrystalsEarned",
			UnsavedBalance = "UnsavedCrystals",
			LastRewardAmount = "LastCrystalsRewardAmount",
			LastRewardReason = "LastCrystalsRewardReason",
			LastRewardSequence = "LastCrystalsRewardSequence",
			LastRewardMatchId = "LastCrystalsRewardMatchId",
		}),
	}),
})

return CurrencyConfig
