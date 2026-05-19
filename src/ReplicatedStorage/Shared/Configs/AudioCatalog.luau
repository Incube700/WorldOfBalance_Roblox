local AudioCatalog = table.freeze({
	DefaultSoundIds = table.freeze({
		Shot = "DefaultCannonShot",
		Ricochet = "DefaultRicochet",
		Hit = "DefaultHit",
		NoPenetration = "DefaultNoPenetration",
		TankDestroyed = "DefaultExplosion",
		BarrelBlocked = "DefaultBarrelBlocked",
		BoltReward = "DefaultBoltReward",
		CrystalReward = "DefaultBoltReward",
		ButtonClick = "DefaultButtonClick",
		Win = "DefaultWin",
		Lose = "DefaultLose",
	}),

	Sounds = table.freeze({
		DefaultCannonShot = table.freeze({
			Category = "Shot",
			SoundId = "rbxassetid://139771888058836",
			DisplayName = "Default Cannon Shot",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 140,
			Is2D = false,
		}),

		DefaultRicochet = table.freeze({
			Category = "Ricochet",
			SoundId = "rbxassetid://140602821561280",
			DisplayName = "Default Ricochet",
			Volume = 1,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 220,
			Is2D = false,
		}),

		DefaultHit = table.freeze({
			Category = "Hit",
			SoundId = "",
			DisplayName = "Default Hit",
			Volume = 0.65,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 110,
			Is2D = false,
		}),

		DefaultNoPenetration = table.freeze({
			Category = "NoPenetration",
			SoundId = "",
			DisplayName = "Default No Penetration",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 110,
			Is2D = false,
		}),

		DefaultExplosion = table.freeze({
			Category = "TankDestroyed",
			SoundId = "",
			DisplayName = "Default Explosion",
			Volume = 0.9,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 160,
			Is2D = false,
		}),

		DefaultBarrelBlocked = table.freeze({
			Category = "BarrelBlocked",
			SoundId = "",
			DisplayName = "Default Barrel Blocked",
			Volume = 0.45,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultBoltReward = table.freeze({
			Category = "BoltReward",
			SoundId = "",
			DisplayName = "Default Bolt Reward",
			Volume = 0.6,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultButtonClick = table.freeze({
			Category = "ButtonClick",
			SoundId = "",
			DisplayName = "Default Button Click",
			Volume = 0.45,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultWin = table.freeze({
			Category = "Win",
			SoundId = "",
			DisplayName = "Default Win",
			Volume = 0.7,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultLose = table.freeze({
			Category = "Lose",
			SoundId = "",
			DisplayName = "Default Lose",
			Volume = 0.7,
			PlaybackSpeed = 1,
			Is2D = true,
		}),
	}),
})

return AudioCatalog
