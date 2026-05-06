-- Read-only snapshot config. Do not wire without a dedicated task.

local WeaponConfig = table.freeze({
	PrimaryWeapon = table.freeze({
		Id = "PrototypeCannon",
		ShootCooldown = 0.45,
		ProjectileTypeId = "PrototypeRicochetShell",
		BarrelOffset = Vector3.new(0, 0, -5.8),
		MuzzleOffset = Vector3.new(0, 0, -10),
		-- TODO: ProjectileTypeId is a new config id; the Studio snapshot has no projectile id system yet.
		-- TODO: Spread, burst, reload, ammo, and weapon switching are not present in the snapshot.
	}),
})

return WeaponConfig
