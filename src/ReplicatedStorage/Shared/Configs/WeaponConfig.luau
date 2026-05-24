-- Shared weapon mechanics config.

local WeaponConfig = table.freeze({
	PrimaryWeapon = table.freeze({
		Id = "PrototypeCannon",
		-- Base cannon reload seconds. Arena FireRateUp multiplies this value.
		ShootCooldown = 1.5,
		ProjectileTypeId = "DefaultRicochetShell",
		BarrelOffset = Vector3.new(0, 0, -5.8),
		MuzzleOffset = Vector3.new(0, 0, -10),
		-- TODO: Spread, burst, reload, ammo, and weapon switching are not present in the snapshot.
	}),
})

return WeaponConfig
