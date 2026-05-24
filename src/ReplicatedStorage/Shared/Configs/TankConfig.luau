-- Shared tank config. WOBGameplayServer reads movement values.

local TankConfig = table.freeze({
	Movement = table.freeze({
		MoveSpeed = 30,
		MaxSpeed = 30,
		ReverseMaxSpeed = 22.5,
		Acceleration = 92,
		ReverseAcceleration = 72,
		Deceleration = 70,
		TurnAcceleration = 8.5,
		TurnDeceleration = 11,
		ShotRecoilImpulse = 13.5,
		ShotRecoilMaxSpeed = 18,
		ShotRecoilDamping = 20,
		ReverseMoveSpeedMultiplier = 0.85,
		InvertSteeringWhenReversing = true,
		ReverseSteeringDeadZone = 0.05,
		BodyTurnSpeedRadians = math.rad(90),
		BodyTurnSpeedDegrees = 90,
		TurretTurnSpeedRadians = math.rad(155),
		TurretTurnSpeedDegrees = 155,
		ShootUsesTurretFacing = true,
		CollisionBoxSize = Vector3.new(8.7, 4.2, 11.7),
		CollisionBoxYOffset = 1.9,
		CollisionSkinWidth = 0.15,
		WorldBoundsMinX = -520,
		WorldBoundsMaxX = 520,
		WorldBoundsMinZ = -560,
		WorldBoundsMaxZ = 280,
		DebugCollision = false,
	}),

	Armor = table.freeze({
		FrontArmor = 50,
		SideArmor = 40,
		RearArmor = 10,
		AutoRicochetAngleDegrees = 72,
		SafeMinCos = 0.15,
		ArmorHitboxPadding = 0.35,
		ArmorHitboxThickness = 0.25,
		ArmorHitboxHeight = 5.4,
		ArmorHitboxYOffset = 1.4,
		ArmorHitboxesVisible = true,
		ArmorHitboxTransparency = 0.45,
		ArmorHitboxMaterial = "SmoothPlastic",
		-- Intentional color-coded armor readability (front/rear/side). Keep visible
		-- and colored; do not collapse to a single dark color.
		FrontArmorColor = Color3.fromRGB(80, 255, 120),
		RearArmorColor = Color3.fromRGB(255, 90, 90),
		SideArmorColor = Color3.fromRGB(255, 220, 80),
	}),

	Turret = table.freeze({
		TurnSpeedDegreesPerSecond = 155,
		TurnSpeedRadiansPerSecond = math.rad(155),
		ShootUsesTurretFacing = true,
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
