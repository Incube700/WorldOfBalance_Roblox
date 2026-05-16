local AudioConfig = table.freeze({
	Enabled = true,
	Debug = false,

	MasterVolume = 1,
	CombatVolume = 0.8,
	UIVolume = 0.7,

	Sounds = table.freeze({
		Shot = table.freeze({
			SoundId = "",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 140,
		}),

		Ricochet = table.freeze({
			SoundId = "",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 120,
		}),

		Hit = table.freeze({
			SoundId = "",
			Volume = 0.65,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 110,
		}),

		NoPenetration = table.freeze({
			SoundId = "",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 110,
		}),

		TankDestroyed = table.freeze({
			SoundId = "",
			Volume = 0.9,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 160,
		}),

		BarrelBlocked = table.freeze({
			SoundId = "",
			Volume = 0.45,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		BoltReward = table.freeze({
			SoundId = "",
			Volume = 0.6,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		ButtonClick = table.freeze({
			SoundId = "",
			Volume = 0.45,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		Win = table.freeze({
			SoundId = "",
			Volume = 0.7,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		Lose = table.freeze({
			SoundId = "",
			Volume = 0.7,
			PlaybackSpeed = 1,
			Is2D = true,
		}),
	}),
})

return AudioConfig
