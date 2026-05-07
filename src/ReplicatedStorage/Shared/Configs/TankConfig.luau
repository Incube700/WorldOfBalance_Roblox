-- Shared tank config. WOBGameplayServer reads movement values.

local TankConfig = table.freeze({
	Movement = table.freeze({
		MoveSpeed = 34,
		ReverseMoveSpeedMultiplier = 0.85,
		BodyTurnSpeedRadians = 2.007128639793479,
		BodyTurnSpeedDegrees = 115,
		-- TODO: No turret turn speed exists in the snapshot; current turret yaw follows client aim direction directly.
	}),

	Armor = table.freeze({
		FrontArmor = 50,
		SideArmor = 40,
		RearArmor = 10,
		AutoRicochetAngleDegrees = 72,
		SafeMinCos = 0.15,
		ArmorHitboxPadding = 0.75,
		ArmorHitboxThickness = 1.2,
		ArmorHitboxHeight = 5.4,
		ArmorHitboxYOffset = 1.4,
		ArmorHitboxesVisible = false,
	}),

	PlayerInitialState = table.freeze({
		Position = Vector3.new(-42, 0, -42),
		BodyYawRadians = 0,
		TurretYawRadians = 0,
	}),

	DummyInitialState = table.freeze({
		Position = Vector3.new(42, 0, 42),
		BodyYawRadians = 3.141592653589793,
		TurretYawRadians = 3.141592653589793,
	}),

	ModelNames = table.freeze({
		PlayerTank = "PlayerTankPrototype",
		DummyTank = "DummyTank",
		Body = "Body",
		Turret = "Turret",
		Barrel = "Barrel",
		ShootPoint = "ShootPoint",
		Hitboxes = "Hitboxes",
		FrontArmor = "FrontArmor",
		RearArmor = "RearArmor",
		LeftArmor = "LeftArmor",
		RightArmor = "RightArmor",
	}),

	Layout = table.freeze({
		BodyOffset = Vector3.new(0, 2, 0),
		TurretOffset = Vector3.new(0, 4.6, 0),
		BarrelOffset = Vector3.new(0, 0, -5.8),
		ShootPointOffset = Vector3.new(0, 0, -10),
		HitboxOffsets = table.freeze({
			FrontArmor = Vector3.new(0, 0, -5.7),
			RearArmor = Vector3.new(0, 0, 5.7),
			LeftArmor = Vector3.new(-4.2, 0, 0),
			RightArmor = Vector3.new(4.2, 0, 0),
		}),
	}),
})

return TankConfig
