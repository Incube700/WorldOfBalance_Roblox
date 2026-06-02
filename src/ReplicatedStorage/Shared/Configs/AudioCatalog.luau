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
			SoundId = "rbxassetid://87047730068459",
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
			SoundId = "rbxassetid://86070307558627",
			DisplayName = "Default Upgrade Select",
			Volume = 0.55,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultLevelUp = table.freeze({
			Category = "LevelUp",
			SoundId = "rbxassetid://112485797063762",
			DisplayName = "Default Level Up",
			Volume = 0.65,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultReflectShield = table.freeze({
			Category = "ReflectShield",
			SoundId = "rbxassetid://131054948529487",
			DisplayName = "Default Reflect Shield",
			Volume = 0.75,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 130,
			ThrottleSeconds = 0.12,
			Is2D = false,
		}),

		DefaultRepair = table.freeze({
			Category = "Repair",
			SoundId = "rbxassetid://5728423829",
			DisplayName = "Default Repair",
			Volume = 0.6,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultEngineLoop = table.freeze({
			Category = "EngineLoop",
			SoundId = "rbxassetid://139868743650686",
			DisplayName = "Default Engine Loop",
			Volume = 0.35,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 90,
			Is2D = false,
		}),

		DefaultBarrelBlocked = table.freeze({
			Category = "BarrelBlocked",
			SoundId = "rbxassetid://90453849339216",
			DisplayName = "Default Barrel Blocked",
			Volume = 0.45,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultBoltReward = table.freeze({
			Category = "BoltReward",
			SoundId = "rbxassetid://500472891",
			DisplayName = "Default Bolt Reward",
			Volume = 0.6,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultButtonClick = table.freeze({
			Category = "ButtonClick",
			SoundId = "rbxassetid://119110533352768",
			DisplayName = "Default Button Click",
			Volume = 0.45,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultWin = table.freeze({
			Category = "Win",
			SoundId = "rbxassetid://139938083576490",
			DisplayName = "Default Win",
			Volume = 0.7,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		DefaultLose = table.freeze({
			Category = "Lose",
			SoundId = "rbxassetid://110221946472088",
			DisplayName = "Default Lose",
			Volume = 0.7,
			PlaybackSpeed = 1,
			Is2D = true,
		}),

		-- Etap 3 additions. SoundId left empty: drop in your rbxassetid to enable. While empty
		-- the AudioController simply skips them (no error); per-weapon shots fall back to Shot.
		RocketShot = table.freeze({
			Category = "ShotRocket",
			SoundId = "rbxassetid://132024417055760",
			DisplayName = "Rocket Shot",
			Volume = 0.75,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 150,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),

		MachineGunShot = table.freeze({
			Category = "ShotMachineGun",
			SoundId = "rbxassetid://2598368598",
			DisplayName = "Machine Gun Shot",
			Volume = 0.55,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 130,
			ThrottleSeconds = 0.04,
			Is2D = false,
		}),

		RailGunShot = table.freeze({
			Category = "ShotRailGun",
			SoundId = "rbxassetid://9114270777",
			DisplayName = "Rail Gun Shot",
			Volume = 0.8,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 170,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),

		DefaultPickupCollect = table.freeze({
			Category = "PickupCollect",
			SoundId = "rbxassetid://140693247883244",
			DisplayName = "Default Pickup Collect",
			Volume = 0.6,
			PlaybackSpeed = 1,
			RollOffMaxDistance = 120,
			ThrottleSeconds = 0.05,
			Is2D = false,
		}),
	}),

	-- ---------------------------------------------------------------------------
	-- MUSIC. Metadata only -- вписывай SoundId, остальное уже настроено.
	-- Музыка всегда 2D (на весь экран), зациклена (Looped=true) и с плавным
	-- появлением/затуханием (FadeInSeconds / FadeOutSeconds). Пока SoundId пустой,
	-- трек просто не играет (без ошибок). Стингеры (Victory/Defeat) — НЕ зациклены:
	-- играют один раз поверх/вместо фоновой музыки.
	--
	-- Активный трек по состоянию игры выбирается через Music.Tracks ключ:
	--   Lobby -> LobbyTheme, BattleArena/Match -> ArenaBattle, Duel -> DuelBattle.
	-- (Систему проигрывания подключим кодом, когда наберёшь хотя бы один трек.)
	-- ---------------------------------------------------------------------------
	Music = table.freeze({
		Tracks = table.freeze({
			LobbyTheme = table.freeze({
				SoundId = "rbxassetid://140734003539749",
				DisplayName = "Lobby Theme",
				-- Спокойный фон лобби (игрок тут долго) -- не утомляющий.
				Volume = 0.1,
				PlaybackSpeed = 1,
				Looped = true,
				FadeInSeconds = 1.5,
				FadeOutSeconds = 1.0,
				Is2D = true,
			}),

			ArenaBattle = table.freeze({
				SoundId = "",
				DisplayName = "Arena Battle",
				-- Энергичный боевой трек для арены.
				Volume = 0.1,
				PlaybackSpeed = 1,
				Looped = true,
				FadeInSeconds = 1.0,
				FadeOutSeconds = 0.8,
				Is2D = true,
			}),

			DuelBattle = table.freeze({
				SoundId = "rbxassetid://135550430945498",
				DisplayName = "Duel Battle",
				-- Напряжённый трек для дуэли 1на1 (можно тот же, что ArenaBattle).
				Volume = 0.1,
				PlaybackSpeed = 1,
				Looped = true,
				FadeInSeconds = 1.0,
				FadeOutSeconds = 0.8,
				Is2D = true,
			}),
		}),

		Stingers = table.freeze({
			Victory = table.freeze({
				SoundId = "rbxassetid://139077800627782",
				DisplayName = "Victory Sting",
				-- Короткий триумфальный джингл при победе. НЕ зациклен.
				Volume = 0.6,
				PlaybackSpeed = 1,
				Looped = false,
				FadeInSeconds = 0,
				FadeOutSeconds = 0.5,
				Is2D = true,
			}),

			Defeat = table.freeze({
				SoundId = "rbxassetid://138789805346213",
				DisplayName = "Defeat Sting",
				-- Короткий джингл поражения. НЕ зациклен.
				Volume = 0.6,
				PlaybackSpeed = 1,
				Looped = false,
				FadeInSeconds = 0,
				FadeOutSeconds = 0.5,
				Is2D = true,
			}),
		}),
	}),

	-- Какой музыкальный трек включать в каждом состоянии игры (ключи -> Music.Tracks выше).
	-- PlayerMode значения: Lobby / InBattleArena / InMatch / QueuedForDuel и т.п.
	MusicByState = table.freeze({
		Lobby = "LobbyTheme",
		QueuedForDuel = "LobbyTheme",
		InBattleArena = "ArenaBattle",
		ArenaRespawning = "ArenaBattle",
		InMatch = "DuelBattle",
	}),
})

return AudioCatalog
