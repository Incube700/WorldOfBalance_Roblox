-- Image ids should be filled after importing the source PNGs as Roblox assets.
-- Until then the HUD falls back to FallbackText instead of emoji placeholders.
local UpgradeIconConfig = {}

UpgradeIconConfig.FallbackText = "★"

UpgradeIconConfig.Icons = table.freeze({
	DamageUp = table.freeze({
		Image = "rbxassetid://95023821349011",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/DamageUp.png",
		FallbackText = "★",
	}),
	FireRateUp = table.freeze({
		Image = "rbxassetid://74054054852445",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/FireRateUp.png",
		FallbackText = "★",
	}),
	MoveSpeedUp = table.freeze({
		Image = "rbxassetid://119948702121051",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/MoveSpeedUp.png",
		FallbackText = "★",
	}),
	DoubleShot = table.freeze({
		Image = "rbxassetid://98014281402825",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/DoubleShot.png",
		FallbackText = "★",
	}),
	TripleSpread = table.freeze({
		Image = "rbxassetid://103984267112273",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/TripleSpread.png",
		FallbackText = "★",
	}),
	RicochetUp = table.freeze({
		Image = "rbxassetid://130485175566236",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/RicochetUp.png",
		FallbackText = "★",
	}),
	Repair = table.freeze({
		Image = "rbxassetid://86182173953361",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/Repair.png",
		FallbackText = "★",
	}),
	ReflectShield = table.freeze({
		Image = "rbxassetid://123920165907322",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/ReflectShield.png",
		FallbackText = "★",
	}),
	VampireShells = table.freeze({
		Image = "rbxassetid://111039230596636",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/VampireShells.png",
		FallbackText = "★",
		FutureOnly = true,
	}),

	-- Etap 1 new upgrades. No imported PNG yet -> HUD shows the FallbackText letter.
	-- Drop a PNG into UpgradeIcons/ and set Image = "rbxassetid://..." to use art instead.
	Lifesteal = table.freeze({
		Image = "",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/Lifesteal.png",
		FallbackText = "♥",
	}),
	Piercing = table.freeze({
		Image = "",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/Piercing.png",
		FallbackText = "➹",
	}),
	Overcharge = table.freeze({
		Image = "",
		SourceFile = "src/ReplicatedStorage/Shared/Assets/UI/UpgradeIcons/Overcharge.png",
		FallbackText = "⚡",
	}),
})

return table.freeze(UpgradeIconConfig)
