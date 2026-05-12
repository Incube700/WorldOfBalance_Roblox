local ProjectileService = {}

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local VfxConfig = require(configs:WaitForChild("VfxConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local ProjectileCombatService = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ProjectileCombatService"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local projectileTypeId = primaryWeaponConfig.ProjectileTypeId or ProjectileCatalog.DefaultProjectileTypeId
local projectileConfig = ProjectileCatalog.Projectiles[projectileTypeId]
	or ProjectileCatalog.Projectiles[ProjectileCatalog.DefaultProjectileTypeId]
local shotVfxConfig = VfxConfig.Shot

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
	getPlayerParticipant = nil,
	canParticipantShoot = nil,
	isNoDamageProjectile = nil,
	shouldRecordShot = nil,
	areProjectilesEnabled = nil,
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

local function hasTexture(config)
	return config ~= nil and typeof(config.TextureId) == "string" and config.TextureId ~= ""
end

local function getParticleContainerLifetime(config)
	return math.max(
		config.ParticleLifetimeMax or config.Lifetime or 0.2,
		config.Lifetime or 0.2
	) + 0.25
end

local function createParticleBurst(position, direction, config, name)
	if config == nil or config.Enabled ~= true or not hasTexture(config) then
		return false
	end

	local holder = Instance.new("Part")
	holder.Name = name or "VFX_ParticleBurst"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(position, position + direction, Vector3.yAxis)
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Parent = vfxFolder

	local attachment = Instance.new("Attachment")
	attachment.Name = "VFXAttachment"
	attachment.Parent = holder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Emitter"
	emitter.Enabled = false
	emitter.Texture = config.TextureId
	emitter.Color = ColorSequence.new(config.Color or Color3.new(1, 1, 1))
	emitter.LightEmission = config.LightEmission or 0.7
	emitter.LightInfluence = config.LightInfluence or 0
	emitter.Lifetime = NumberRange.new(config.ParticleLifetimeMin or 0.1, config.ParticleLifetimeMax or 0.2)
	emitter.Speed = NumberRange.new(config.ParticleSpeedMin or 0, config.ParticleSpeedMax or 0)
	emitter.SpreadAngle = config.ParticleSpreadAngle or Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, config.ParticleSizeStart or 1),
		NumberSequenceKeypoint.new(1, config.ParticleSizeEnd or 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, config.ParticleTransparencyStart or 0),
		NumberSequenceKeypoint.new(1, config.ParticleTransparencyEnd or 1),
	})
	emitter.Parent = attachment
	emitter:Emit(config.EmitCount or 1)

	Debris:AddItem(holder, getParticleContainerLifetime(config))
	return true
end

local function createFlash(position, config, name)
	if config == nil or config.Enabled ~= true then return nil end
	if createParticleBurst(position, Vector3.new(0, 0, -1), config, name) and config.UseProceduralFallback ~= true then
		return nil
	end
	local flash = Instance.new("Part")
	flash.Name = "VFX_Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(config.Size, config.Size, config.Size)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = config.Color
	flash.Parent = vfxFolder
	Debris:AddItem(flash, config.Lifetime)
	return flash
end

local function createShotSound(position)
	if shotVfxConfig.SoundId == nil or shotVfxConfig.SoundId == "" then return end
	local emitter = Instance.new("Part")
	emitter.Name = "SFX_CannonShotEmitter"
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Position = position
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanTouch = false
	emitter.CanQuery = false
	emitter.CastShadow = false
	emitter.Transparency = 1
	emitter.Parent = vfxFolder
	local sound = Instance.new("Sound")
	sound.Name = "SFX_CannonShot"
	sound.SoundId = shotVfxConfig.SoundId
	sound.Volume = shotVfxConfig.SoundVolume or 0.7
	sound.PlaybackSpeed = shotVfxConfig.SoundPlaybackSpeed or 1
	sound.RollOffMaxDistance = shotVfxConfig.SoundRollOffMaxDistance or 180
	sound.RollOffMinDistance = shotVfxConfig.SoundRollOffMinDistance or 8
	sound.Parent = emitter
	sound:Play()
	Debris:AddItem(emitter, shotVfxConfig.SoundLifetime or 4)
end

local function createMuzzleFlash(position, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.001 then
		flatDirection = Vector3.new(0, 0, -1)
	else
		flatDirection = flatDirection.Unit
	end
	createShotSound(position)
	createFlash(position, shotVfxConfig.MuzzleFlash, "VFX_MuzzleParticleFlash")
	local blastConfig = shotVfxConfig.MuzzleBlast
	if blastConfig ~= nil and blastConfig.Enabled == true then
		local blast = Instance.new("Part")
		blast.Name = "VFX_MuzzleBlast"
		blast.Size = blastConfig.Size
		blast.Anchored = true
		blast.CanCollide = false
		blast.CanTouch = false
		blast.CanQuery = false
		blast.CastShadow = false
		blast.Material = Enum.Material.Neon
		blast.Color = blastConfig.Color
		blast.Transparency = blastConfig.Transparency
		blast.CFrame = CFrame.lookAt(position, position + flatDirection, Vector3.yAxis) * CFrame.new(0, 0, -(blastConfig.ForwardOffset or 2.6))
		blast.Parent = vfxFolder
		local light = Instance.new("PointLight")
		light.Brightness = blastConfig.LightBrightness or 4
		light.Range = blastConfig.LightRange or 15
		light.Color = blastConfig.LightColor or Color3.fromRGB(255, 205, 95)
		light.Parent = blast
		Debris:AddItem(blast, blastConfig.Lifetime or 0.075)
	end
	local smokeConfig = shotVfxConfig.Smoke
	if smokeConfig ~= nil and smokeConfig.Enabled == true then
		local smokePosition = position - flatDirection * (smokeConfig.BackwardOffset or 0.8) + Vector3.new(0, smokeConfig.UpOffset or 0.3, 0)
		local particleHandled = createParticleBurst(smokePosition, -flatDirection, smokeConfig, "VFX_MuzzleParticleSmoke")
		if not particleHandled or smokeConfig.UseProceduralFallback == true then
			local smoke = Instance.new("Part")
			smoke.Name = "VFX_MuzzleSmoke"
			smoke.Shape = Enum.PartType.Ball
			smoke.Size = smokeConfig.Size
			smoke.Anchored = true
			smoke.CanCollide = false
			smoke.CanTouch = false
			smoke.CanQuery = false
			smoke.CastShadow = false
			smoke.Material = Enum.Material.SmoothPlastic
			smoke.Color = smokeConfig.Color
			smoke.Transparency = smokeConfig.Transparency
			smoke.CFrame = CFrame.new(smokePosition)
			smoke.Parent = vfxFolder
			Debris:AddItem(smoke, smokeConfig.Lifetime or 0.16)
		end
	end
end

local function createImpactFlash(position)
	createFlash(position, shotVfxConfig.ImpactFlash, "VFX_ImpactParticleFlash")
	local sparkConfig = shotVfxConfig.ImpactSparks
	if sparkConfig == nil or sparkConfig.Enabled ~= true then return end
	local particleHandled = createParticleBurst(position, Vector3.new(0, 1, 0), sparkConfig, "VFX_ImpactParticleSparks")
	if particleHandled and sparkConfig.UseProceduralFallback ~= true then return end
	for _ = 1, sparkConfig.Count or 3 do
		local spark = Instance.new("Part")
		spark.Name = "VFX_Spark"
		spark.Size = sparkConfig.Size
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Material = Enum.Material.Neon
		spark.Color = sparkConfig.Color
		spark.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		spark.Parent = vfxFolder
		Debris:AddItem(spark, sparkConfig.Lifetime or 0.12)
	end
end

local function createProjectilePart(position, direction)
	local visualConfig = shotVfxConfig.Projectile
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(visualConfig.Size, visualConfig.Size, visualConfig.Size)
	part.CFrame = CFrame.lookAt(position, position + direction, Vector3.yAxis)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = visualConfig.Color
	part.Parent = projectileFolder
	local light = Instance.new("PointLight")
	light.Brightness = visualConfig.LightBrightness or 2.4
	light.Range = visualConfig.LightRange or 10
	light.Color = visualConfig.LightColor or Color3.fromRGB(255, 220, 120)
	light.Parent = part
	local frontAttachment = Instance.new("Attachment")
	frontAttachment.Name = "TrailFront"
	frontAttachment.Position = Vector3.new(0, 0, visualConfig.TrailFrontOffset or -0.65)
	frontAttachment.Parent = part
	local backAttachment = Instance.new("Attachment")
	backAttachment.Name = "TrailBack"
	backAttachment.Position = Vector3.new(0, 0, visualConfig.TrailBackOffset or 0.65)
	backAttachment.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "ProjectileTrail"
	trail.Attachment0 = frontAttachment
	trail.Attachment1 = backAttachment
	trail.Color = ColorSequence.new(visualConfig.TrailColorStart, visualConfig.TrailColorEnd)
	trail.Lifetime = visualConfig.TrailLifetime or 0.18
	trail.MinLength = 0.05
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, visualConfig.TrailWidthStart or 1.6),
		NumberSequenceKeypoint.new(0.6, visualConfig.TrailWidthMid or 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = part
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
	local flatDirection = Vector3.new(direction.X, 0, direction.Z).Unit
	local projectilePart = createProjectilePart(origin, flatDirection)
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
		Direction = flatDirection,
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
		MatchId = ownerParticipant.MatchId,
		NoDamage = callbacks.isNoDamageProjectile ~= nil and callbacks.isNoDamageProjectile(ownerParticipant) == true,
		NoStats = callbacks.isNoDamageProjectile ~= nil and callbacks.isNoDamageProjectile(ownerParticipant) == true,
	}
	table.insert(projectiles, projectile)
	createMuzzleFlash(origin, flatDirection)
end

function ProjectileService.tryShoot(participant, direction)
	if callbacks.canParticipantShoot ~= nil then
		if callbacks.canParticipantShoot(participant) ~= true then return false end
	elseif callbacks.getGameState() ~= "Playing" or (callbacks.getRoundState() and callbacks.getRoundState().Ended) then
		return false
	end
	if participant.ShootPoint == nil or participant.ShootPoint.Parent == nil then
		warn("[PROJECTILE] Shoot ignored: " .. participant.TankId .. " has no ShootPoint")
		return false
	end
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.001 then return false end
	local currentTime = os.clock()
	local cooldown = participant.WeaponConfig.ShootCooldown or SHOOT_COOLDOWN
	local lastShotTime = participant.LastShotTime or 0
	if currentTime - lastShotTime < cooldown then return false end
	participant.LastShotTime = currentTime
	participant.WeaponReadyAt = currentTime + cooldown
	participant.WeaponState.LastShotTime = participant.LastShotTime
	participant.WeaponState.WeaponReadyAt = participant.WeaponReadyAt
	ProjectileService.createProjectile(participant, participant.ShootPoint.Position, flatDirection.Unit)
	if callbacks.shouldRecordShot == nil or callbacks.shouldRecordShot(participant) == true then
		MatchStatsService.recordShotFired(participant)
	end
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
		if participant.IsActive ~= false and hitboxes ~= nil and (participant ~= projectile.OwnerParticipant or projectile.CanHitOwner) then
			table.insert(targets, hitboxes)
		end
	end
	return targets
end

function ProjectileService.updateProjectiles(deltaTime)
	if callbacks.areProjectilesEnabled ~= nil and callbacks.areProjectilesEnabled() ~= true then return end
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
		local result = Workspace:Raycast(projectile.Position, projectile.Direction * distance, projectileRaycastParams)
		if result ~= nil then
			local targetParticipant = TankParticipantRegistry.getParticipantFromArmorHitbox(result.Instance)
			local armorZone = TankParticipantRegistry.getArmorZoneFromHitbox(result.Instance)
			if targetParticipant ~= nil then
				local destroyed = ProjectileCombatService.handleProjectileTankHit(projectile, targetParticipant, result.Position, result.Normal, armorZone, {
					roundState = callbacks.getRoundState(),
				})
				if destroyed then table.remove(projectiles, i) end
			else
				createImpactFlash(result.Position)
				if projectile.BounceCount >= projectile.MaxBounces then
					ProjectileService.destroyProjectile(projectile)
					table.remove(projectiles, i)
				else
					ProjectileCombatService.applyProjectileRicochet(projectile, result.Position, result.Normal)
					ProjectileCombatService.printBounce(projectile)
				end
			end
		else
			projectile.Position += projectile.Direction * distance
			if projectile.Part then
				projectile.Part.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + projectile.Direction, Vector3.yAxis)
			end
		end
	end
end

function ProjectileService.getVFXHelpers()
	return {
		createImpactFlash = createImpactFlash,
	destroyProjectile = ProjectileService.destroyProjectile,
	}
end

return ProjectileService
