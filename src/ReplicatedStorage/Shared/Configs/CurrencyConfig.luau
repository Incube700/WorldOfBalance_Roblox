local CurrencyConfig = table.freeze({
	CurrencyId = "Bolts",
	DisplayName = "Bolts",

	Rewards = table.freeze({
		TrainingKill = 1,
		PvPKill = 1,
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
})

return CurrencyConfig
