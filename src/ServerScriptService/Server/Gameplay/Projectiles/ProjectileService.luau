local ProjectileService = {}

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local ProjectileCombatService = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ProjectileCombatService"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local projectileTypeId = primaryWeaponConfig.ProjectileTypeId or ProjectileCatalog.DefaultProjectileTypeId
local projectileConfig = ProjectileCatalog.Projectiles[projectileTypeId]
	or ProjectileCatalog.Projectiles[ProjectileCatalog.DefaultProjectileTypeId]

local PROJECTILE_SPEED = projectileConfig.Speed
local PROJECTILE_MAX_DAMAGE = projectileConfig.MaxDamage
local PROJECTILE_PENETRATION = projectileConfig.Penetration
local PROJECTILE_MAX_BOUNCES = projectileConfig.MaxRicochets
local PROJECTILE_BOUNCE_SPEED_MULTIPLIER = projectileConfig.BounceSpeedMultiplier
local PROJECTILE_DAMAGE_MULTIPLIER = projectileConfig.DamageMultiplierPerBounce
local PROJECTILE_MIN_SPEED = projectileConfig.MinProjectileSpeed
local PROJECTILE_LIFETIME = projectileConfig.Lifetime
local SHOOT_COOLDOWN = primaryWeaponConfig.ShootCooldown

local projectiles = {}
local projectileFolder = nil
local vfxFolder = nil
local root = nil
local projectileRaycastParams = nil
local projectileMapRaycastTargets = {}

local callbacks = {
	getGameState = nil,
	getRoundState = nil,
	damageParticipant = nil,
	getPlayerParticipant = nil, -- legacy support
}

function ProjectileService.init(orchestratorRoot, projFolder, effectsFolder, options)
	root = orchestratorRoot
	projectileFolder = projFolder
	vfxFolder = effectsFolder
	callbacks = options

	projectileRaycastParams = RaycastParams.new()
	projectileRaycastParams.FilterType = Enum.RaycastFilterType.Include
	projectileRaycastParams.IgnoreWater = true
end

function ProjectileService.setMapRaycastTargets(targets)
	projectileMapRaycastTargets = targets
end

local function createFlash(position, color, size, lifetime)
	local flash = Instance.new("Part")
	flash.Name = "VFX_Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(size, size, size)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Parent = vfxFolder

	Debris:AddItem(flash, lifetime)

	return flash
end

local function createMuzzleFlash(position)
	createFlash(position, Color3.fromRGB(255, 220, 80), 3.2, 0.08)
end

local function createImpactFlash(position)
	createFlash(position, Color3.fromRGB(255, 130, 40), 2.5, 0.12)

	for i = 1, 3 do
		local spark = Instance.new("Part")
		spark.Name = "VFX_Spark"
		spark.Size = Vector3.new(0.25, 0.25, 1.2)
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 200, 90)
		spark.CFrame = CFrame.new(position) * CFrame.Angles(
			math.random() * math.pi,
			math.random() * math.pi,
			math.random() * math.pi
		)
		spark.Parent = vfxFolder

		Debris:AddItem(spark, 0.12)
	end
end

local function createProjectilePart(position)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 230, 120)
	part.Parent = projectileFolder

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 6
	light.Parent = part

	return part
end

function ProjectileService.destroyProjectile(projectile)
	if projectile.Part ~= nil then
		projectile.Part:Destroy()
		projectile.Part = nil
	end

	projectile.Destroyed = true
end

function ProjectileService.destroyAllProjectiles()
	for i = #projectiles, 1, -1 do
		ProjectileService.destroyProjectile(projectiles[i])
		table.remove(projectiles, i)
	end
end

function ProjectileService.createProjectile(ownerParticipant, origin, direction)
	local projectilePart = createProjectilePart(origin)
	local ownerTankModel = TankParticipantRegistry.getParticipantPhysicalModel(ownerParticipant)

	projectilePart:SetAttribute("OwnerTankId", ownerParticipant.TankId)
	projectilePart:SetAttribute("OwnerTeamId", ownerParticipant.TeamId)
	projectilePart:SetAttribute("OwnerIsBot", ownerParticipant.IsBot)
	projectilePart:SetAttribute("WeaponTypeId", ownerParticipant.WeaponTypeId)

	if ownerParticipant.OwnerUserId ~= nil then
		projectilePart:SetAttribute("OwnerUserId", ownerParticipant.OwnerUserId)
	end

	local projectile = {
		Owner = ownerParticipant.OwnerPlayer,
		OwnerPlayer = ownerParticipant.OwnerPlayer,
		OwnerParticipant = ownerParticipant,
		OwnerTank = ownerTankModel,
		OwnerTankId = ownerParticipant.TankId,
		OwnerUserId = ownerParticipant.OwnerUserId,
		OwnerTeamId = ownerParticipant.TeamId,
		OwnerIsBot = ownerParticipant.IsBot,
		ProjectileTypeId = projectileConfig.Id,
		WeaponTypeId = ownerParticipant.WeaponTypeId,
		WeaponConfig = ownerParticipant.WeaponConfig,
		Position = origin,
		Direction = Vector3.new(direction.X, 0, direction.Z).Unit,
		Speed = PROJECTILE_SPEED,
		Damage = PROJECTILE_MAX_DAMAGE,
		Penetration = PROJECTILE_PENETRATION,
		BounceCount = 0,
		MaxBounces = PROJECTILE_MAX_BOUNCES,
		BounceSpeedMultiplier = PROJECTILE_BOUNCE_SPEED_MULTIPLIER,
		DamageMultiplierPerBounce = PROJECTILE_DAMAGE_MULTIPLIER,
		MinSpeed = PROJECTILE_MIN_SPEED,
		LifeTime = 0,
		MaxLifeTime = PROJECTILE_LIFETIME,
		Part = projectilePart,
		Destroyed = false,
		CanHitOwner = false,
	}

	table.insert(projectiles, projectile)
	createMuzzleFlash(origin)
end

function ProjectileService.tryShoot(participant, direction)
	if callbacks.getGameState() ~= "Playing" or (callbacks.getRoundState() and callbacks.getRoundState().Ended) then
		return false
	end

	if participant.ShootPoint == nil or participant.ShootPoint.Parent == nil then
		warn("[PROJECTILE] Shoot ignored: " .. participant.TankId .. " has no ShootPoint")
		return false
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		return false
	end

	local currentTime = os.clock()
	local cooldown = participant.WeaponConfig.ShootCooldown or SHOOT_COOLDOWN
	local lastShotTime = participant.LastShotTime or 0

	if currentTime - lastShotTime < cooldown then
		return false
	end

	participant.LastShotTime = currentTime
	participant.WeaponReadyAt = currentTime + cooldown
	participant.WeaponState.LastShotTime = participant.LastShotTime
	participant.WeaponState.WeaponReadyAt = participant.WeaponReadyAt

	ProjectileService.createProjectile(participant, participant.ShootPoint.Position, flatDirection.Unit)
	
	-- Legacy playerParticipant support
	local playerParticipant = callbacks.getPlayerParticipant and callbacks.getPlayerParticipant()
	MatchStatsService.recordShotFired(participant, playerParticipant)

	return true
end

local function getProjectileRaycastTargets(projectile)
	local targets = table.clone(projectileMapRaycastTargets)

	for _, participant in ipairs(TankParticipantRegistry.getParticipants()) do
		local physicalModel = TankParticipantRegistry.getParticipantPhysicalModel(participant)
		local hitboxes = participant.Hitboxes

		if (hitboxes == nil or hitboxes.Parent == nil) and physicalModel ~= nil then
			hitboxes = physicalModel:FindFirstChild("Hitboxes", true)
			participant.Hitboxes = hitboxes
		end

		if participant.IsActive ~= false
			and hitboxes ~= nil
			and (participant ~= projectile.OwnerParticipant or projectile.CanHitOwner)
		then
			table.insert(targets, hitboxes)
		end
	end

	return targets
end

function ProjectileService.updateProjectiles(deltaTime)
	if callbacks.getGameState() ~= "Playing" then
		return
	end

	for i = #projectiles, 1, -1 do
		local projectile = projectiles[i]

		if projectile.Destroyed then
			table.remove(projectiles, i)
			continue
		end

		projectile.LifeTime += deltaTime

		if projectile.LifeTime >= projectile.MaxLifeTime then
			ProjectileService.destroyProjectile(projectile)
			table.remove(projectiles, i)
			continue
		end

		local distance = projectile.Speed * deltaTime
		projectileRaycastParams.FilterDescendantsInstances = getProjectileRaycastTargets(projectile)

		local result = Workspace:Raycast(
			projectile.Position,
			projectile.Direction * distance,
			projectileRaycastParams
		)

		if result ~= nil then
			local hitInstance = result.Instance
			local hitPosition = result.Position
			local hitNormal = result.Normal
			local targetParticipant = TankParticipantRegistry.getParticipantFromArmorHitbox(hitInstance)
			local armorZone = TankParticipantRegistry.getArmorZoneFromHitbox(hitInstance)

			if targetParticipant ~= nil then
				local destroyed = ProjectileCombatService.handleProjectileTankHit(
					projectile,
					targetParticipant,
					hitPosition,
					hitNormal,
					armorZone,
					{
						playerParticipant = callbacks.getPlayerParticipant and callbacks.getPlayerParticipant(),
						roundState = callbacks.getRoundState(),
					}
				)

				if destroyed then
					table.remove(projectiles, i)
				end
			else
				createImpactFlash(hitPosition)

				if projectile.BounceCount >= projectile.MaxBounces then
					ProjectileService.destroyProjectile(projectile)
					table.remove(projectiles, i)
				else
					ProjectileCombatService.applyProjectileRicochet(projectile, hitPosition, hitNormal)
					ProjectileCombatService.printBounce(projectile)
				end
			end
		else
			projectile.Position += projectile.Direction * distance
			if projectile.Part then
				projectile.Part.Position = projectile.Position
			end
		end
	end
end

-- Export VFX helpers for combat service if needed
function ProjectileService.getVFXHelpers()
	return {
		createImpactFlash = createImpactFlash,
		destroyProjectile = ProjectileService.destroyProjectile,
	}
end

return ProjectileService
