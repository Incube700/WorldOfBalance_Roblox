local AudioCatalog = table.freeze({
	DefaultSoundIds = table.freeze({
		Shot = "DefaultCannonShot",
		ProjectileImpact = "DefaultProjectileImpact",
		Ricochet = "DefaultRicochet",
		RicochetImpact = "DefaultRicochet",
		Hit = "DefaultProjectileImpact",
		NoPenetration = "DefaultNoPenetration",
		TankExplosion = "DefaultExplosion",
		TankDestroyed = "DefaultExplosion",
		UpgradeSelect = "DefaultUpgradeSelect",
		LevelUp = "DefaultLevelUp",
		ReflectShield = "DefaultReflectShield",
		Repair = "DefaultRepair",
		EngineLoop = "DefaultEngineLoop",
		BarrelBlocked = "DefaultBarrelBlocked",
		BoltReward = "DefaultBoltReward",
		CrystalReward = "DefaultBoltReward",
		ButtonClick = "DefaultButtonClick",
		Win = "DefaultWin",
		Lose = "DefaultLose",
		-- Etap 3: per-weapon shot variants (fall back to Shot if their SoundId is empty) and
		-- a pickup-collected sound.
		ShotRocket = "RocketShot",
		ShotMachineGun = "MachineGunShot",
		ShotRailGun = "RailGunShot",
		PickupCollect = "DefaultPickupCollect",
	}),

	Sounds = table.freeze({
		DefaultCannonShot = table.freeze({
			Category = "Shot",
			SoundId = "rbxassetid://139771888058836",
			DisplayName = "Default Cannon Shot",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 140,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),

		DefaultRicochet = table.freeze({
			Category = "Ricochet",
			SoundId = "rbxassetid://140602821561280",
			DisplayName = "Default Ricochet",
			Volume = 1,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 220,
			ThrottleSeconds = 0.08,
			Is2D = false,
		}),

		DefaultProjectileImpact = table.freeze({
			Category = "ProjectileImpact",
			SoundId = "rbxassetid://871701190",
			DisplayName = "Default Projectile Impact",
			Volume = 0.65,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 110,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),

		DefaultNoPenetration = table.freeze({
			Category = "NoPenetration",
			SoundId = "",
			DisplayName = "Default No Penetration",
			Volume = 0.7,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 110,
			ThrottleSeconds = 0.08,
			Is2D = false,
		}),

		DefaultExplosion = table.freeze({
			Category = "TankDestroyed",
			SoundId = "rbxassetid://4810729508",
			DisplayName = "Default Explosion",
			Volume = 0.9,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 160,
			ThrottleSeconds = 0.2,
			Is2D = false,
		}),

		DefaultUpgradeSelect = table.freeze({
			Category = "UpgradeSelect",
			SoundId = "",
			DisplayName = "Default Upgrade Select",
			Volume = 0.55,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultLevelUp = table.freeze({
			Category = "LevelUp",
			SoundId = "",
			DisplayName = "Default Level Up",
			Volume = 0.65,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultReflectShield = table.freeze({
			Category = "ReflectShield",
			SoundId = "",
			DisplayName = "Default Reflect Shield",
			Volume = 0.75,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 130,
			ThrottleSeconds = 0.12,
			Is2D = false,
		}),

		DefaultRepair = table.freeze({
			Category = "Repair",
			SoundId = "",
			DisplayName = "Default Repair",
			Volume = 0.6,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultEngineLoop = table.freeze({
			Category = "EngineLoop",
			SoundId = "",
			DisplayName = "Default Engine Loop",
			Volume = 0.35,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 90,
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

		-- Etap 3 additions. SoundId left empty: drop in your rbxassetid to enable. While empty
		-- the AudioController simply skips them (no error); per-weapon shots fall back to Shot.
		RocketShot = table.freeze({
			Category = "ShotRocket",
			SoundId = "",
			DisplayName = "Rocket Shot",
			Volume = 0.75,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 150,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),

		MachineGunShot = table.freeze({
			Category = "ShotMachineGun",
			SoundId = "",
			DisplayName = "Machine Gun Shot",
			Volume = 0.55,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 130,
			ThrottleSeconds = 0.04,
			Is2D = false,
		}),

		RailGunShot = table.freeze({
			Category = "ShotRailGun",
			SoundId = "",
			DisplayName = "Rail Gun Shot",
			Volume = 0.8,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 170,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),

		DefaultPickupCollect = table.freeze({
			Category = "PickupCollect",
			SoundId = "",
			DisplayName = "Default Pickup Collect",
			Volume = 0.6,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 120,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),
	}),
})

return AudioCatalog
