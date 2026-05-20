local ProjectileService = {}

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local TankArmorConfig = require(configs:WaitForChild("TankArmorConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local WeaponSafetyConfig = require(configs:WaitForChild("WeaponSafetyConfig"))
local VfxConfig = require(configs:WaitForChild("VfxConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local ProjectileCombatService = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ProjectileCombatService"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))
local CombatVfxService = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("CombatVfxService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local projectileTypeId = primaryWeaponConfig.ProjectileTypeId or ProjectileCatalog.DefaultProjectileTypeId
local projectileConfig = ProjectileCatalog.Projectiles[projectileTypeId]
	or ProjectileCatalog.Projectiles[ProjectileCatalog.DefaultProjectileTypeId]
local shotVfxConfig = VfxConfig.Shot
local impactVfxConfig = VfxConfig.Impact or {}
local deathExplosionConfig = VfxConfig.DeathExplosion
local burningTankConfig = VfxConfig.BurningTank
local ricochetConfig = VfxConfig.Ricochet

local PROJECTILE_SPEED = projectileConfig.Speed
local PROJECTILE_DAMAGE = projectileConfig.Damage or projectileConfig.MaxDamage
local PROJECTILE_PENETRATION_POWER = projectileConfig.PenetrationPower
	or projectileConfig.Penetration
	or TankArmorConfig.Projectile.DefaultPenetrationPower
local PROJECTILE_LEGACY_PENETRATION = projectileConfig.Penetration or PROJECTILE_PENETRATION_POWER
local PROJECTILE_MAX_BOUNCES = projectileConfig.MaxRicochets
local PROJECTILE_BOUNCE_SPEED_MULTIPLIER = projectileConfig.BounceSpeedMultiplier
local PROJECTILE_DAMAGE_MULTIPLIER = projectileConfig.DamageMultiplierPerBounce
local PROJECTILE_MIN_SPEED = projectileConfig.MinProjectileSpeed
local PROJECTILE_LIFETIME = projectileConfig.Lifetime
local SHOOT_COOLDOWN = primaryWeaponConfig.ShootCooldown
local ARENA_PARTICIPANT_STATE = "InBattleArena"

local projectiles = {}
local projectileFolder = nil
local vfxFolder = nil
local root = nil
local projectileRaycastParams = nil
local muzzleObstructionRaycastParams = nil
local muzzleObstructionOverlapParams = nil
local projectileMapRaycastTargets = {}

local callbacks = {
	getGameState = nil,
	getRoundState = nil,
	getRoundStateForProjectile = nil,
	damageParticipant = nil,
	getPlayerParticipant = nil,
	canParticipantShoot = nil,
	isNoDamageProjectile = nil,
	shouldRecordShot = nil,
	areProjectilesEnabled = nil,
	sendBlockedShotFeedback = nil,
	sendCombatFeedback = nil,
}

function ProjectileService.init(orchestratorRoot, projFolder, effectsFolder, options)
	root = orchestratorRoot
	projectileFolder = projFolder
	vfxFolder = effectsFolder
	callbacks = options
	CombatVfxService.init(vfxFolder)
	projectileRaycastParams = RaycastParams.new()
	projectileRaycastParams.FilterType = Enum.RaycastFilterType.Include
	projectileRaycastParams.IgnoreWater = true
	muzzleObstructionRaycastParams = RaycastParams.new()
	muzzleObstructionRaycastParams.FilterType = Enum.RaycastFilterType.Include
	muzzleObstructionRaycastParams.IgnoreWater = true
	muzzleObstructionOverlapParams = OverlapParams.new()
	muzzleObstructionOverlapParams.FilterType = Enum.RaycastFilterType.Include
	muzzleObstructionOverlapParams.MaxParts = 10
end

function ProjectileService.setMapRaycastTargets(targets)
	projectileMapRaycastTargets = targets
end

local function findBasePart(model, partName)
	if model == nil then
		return nil
	end

	local directChild = model:FindFirstChild(partName)

	if directChild ~= nil and directChild:IsA("BasePart") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getParticipantModel(participant)
	if participant == nil then
		return nil
	end

	return TankParticipantRegistry.getParticipantPhysicalModel(participant) or participant.Model or participant.PhysicalModel
end

local function getServerTimeNow()
	local success, serverTime = pcall(function()
		return Workspace:GetServerTimeNow()
	end)

	if success and typeof(serverTime) == "number" then
		return serverTime
	end

	return os.clock()
end

local function publishReloadPresentationState(participant, cooldown)
	local model = getParticipantModel(participant)

	if model == nil then
		return
	end

	local shotServerTime = getServerTimeNow()
	local reloadDuration = math.max(0.01, tonumber(cooldown) or 0)

	model:SetAttribute("LastShotAtServerTime", shotServerTime)
	model:SetAttribute("ReloadDuration", reloadDuration)
	model:SetAttribute("ReloadProgress", 0)
	model:SetAttribute("ReloadReady", false)

	task.delay(reloadDuration, function()
		if model.Parent == nil then
			return
		end

		if model:GetAttribute("LastShotAtServerTime") ~= shotServerTime then
			return
		end

		model:SetAttribute("ReloadProgress", 1)
		model:SetAttribute("ReloadReady", true)
	end)
end

local function getParticipantBasePart(participant, partName)
	if participant == nil then
		return nil
	end

	local directPart = participant[partName]

	if directPart ~= nil and directPart:IsA("BasePart") and directPart.Parent ~= nil then
		return directPart
	end

	local model = getParticipantModel(participant)
	local resolvedPart = findBasePart(model, partName)

	if resolvedPart ~= nil then
		participant[partName] = resolvedPart
	end

	return resolvedPart
end

local function getSafeMuzzleOrigin(participant)
	local turret = getParticipantBasePart(participant, "Turret")

	if turret ~= nil then
		return turret.Position
	end

	local body = getParticipantBasePart(participant, "Body")

	if body ~= nil then
		return body.Position + Vector3.new(0, 2, 0)
	end

	local controlState = participant ~= nil and participant.ControlState or nil

	if controlState ~= nil and typeof(controlState.Position) == "Vector3" then
		return controlState.Position + Vector3.new(0, 2, 0)
	end

	return nil
end

local function getValidMapRaycastTargets()
	local targets = {}

	for _, target in ipairs(projectileMapRaycastTargets or {}) do
		if target ~= nil and target.Parent ~= nil then
			table.insert(targets, target)
		end
	end

	return targets
end

local function debugMuzzleBlocked(participant, obstaclePart, reason)
	if WeaponSafetyConfig.Debug ~= true then
		return
	end

	local obstaclePath = obstaclePart ~= nil and obstaclePart:GetFullName() or "unknown"
	local tankId = participant ~= nil and participant.TankId or "unknown"
	print(("[MUZZLE BLOCKED] tank=%s reason=%s obstacle=%s"):format(tostring(tankId), tostring(reason), obstaclePath))
end

local function getMuzzleOverlapObstacle(muzzlePosition, targets)
	local radius = math.max(0, tonumber(WeaponSafetyConfig.MuzzleCheckRadius) or 0)

	if radius <= 0 or muzzleObstructionOverlapParams == nil then
		return nil
	end

	muzzleObstructionOverlapParams.FilterDescendantsInstances = targets
	local overlappingParts = Workspace:GetPartBoundsInRadius(
		muzzlePosition,
		radius + math.max(0, tonumber(WeaponSafetyConfig.MuzzleClearancePadding) or 0),
		muzzleObstructionOverlapParams
	)

	for _, part in ipairs(overlappingParts) do
		if part ~= nil and part.Parent ~= nil then
			return part
		end
	end

	return nil
end

local function getMuzzleObstruction(participant)
	if WeaponSafetyConfig.MuzzleObstructionCheckEnabled ~= true then
		return false, nil, nil, nil
	end

	local shootPoint = getParticipantBasePart(participant, "ShootPoint")

	if shootPoint == nil then
		return false, nil, nil, nil
	end

	local safeOrigin = getSafeMuzzleOrigin(participant)

	if safeOrigin == nil then
		return false, nil, nil, nil
	end

	local muzzlePosition = shootPoint.Position
	local segment = muzzlePosition - safeOrigin

	if segment.Magnitude < 0.001 then
		return false, nil, nil, nil
	end

	local targets = getValidMapRaycastTargets()

	if #targets == 0 then
		return false, nil, nil, nil
	end

	if muzzleObstructionRaycastParams ~= nil then
		muzzleObstructionRaycastParams.FilterDescendantsInstances = targets
		local result = Workspace:Raycast(safeOrigin, segment, muzzleObstructionRaycastParams)

		if result ~= nil then
			return true, result.Instance, result.Position, "raycast"
		end
	end

	local overlapObstacle = getMuzzleOverlapObstacle(muzzlePosition, targets)

	if overlapObstacle ~= nil then
		return true, overlapObstacle, muzzlePosition, "muzzleOverlap"
	end

	return false, nil, nil, nil
end

local function sendBlockedShotFeedback(participant, position)
	if WeaponSafetyConfig.BlockedShotFeedbackEnabled ~= true then
		return
	end

	if callbacks.sendBlockedShotFeedback ~= nil then
		callbacks.sendBlockedShotFeedback(
			participant,
			position,
			WeaponSafetyConfig.BlockedShotFeedbackText or "BARREL BLOCKED"
		)
	end
end

local function sendProjectileFeedback(feedbackType, position, text, color, audioOnly)
	if callbacks.sendCombatFeedback == nil then
		return
	end

	callbacks.sendCombatFeedback(feedbackType, position, text, color, audioOnly == true)
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
	local spreadAngle = config.ParticleSpreadAngle
	if spreadAngle == nil and typeof(config.ParticleSpread) == "number" then
		spreadAngle = Vector2.new(config.ParticleSpread, config.ParticleSpread)
	end
	emitter.SpreadAngle = spreadAngle or Vector2.new(180, 180)
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

local function createFlash(position, config, name, direction, skipParticleBurst)
	if config == nil or config.Enabled ~= true then return nil end
	local particleHandled = false

	if skipParticleBurst ~= true then
		particleHandled = createParticleBurst(position, direction or Vector3.new(0, 0, -1), config, name)
	end

	if particleHandled and config.UseProceduralFallback ~= true then
		return nil
	end
	local flashSize = tonumber(config.Size)
	if flashSize == nil or flashSize <= 0 then return nil end
	local flash = Instance.new("Part")
	flash.Name = name or "VFX_Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(flashSize, flashSize, flashSize)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = config.Material or Enum.Material.Neon
	flash.Color = config.Color or Color3.new(1, 1, 1)
	flash.Transparency = config.Transparency or 0
	flash.Parent = vfxFolder

	if (config.LightBrightness or 0) > 0 then
		local light = Instance.new("PointLight")
		light.Brightness = config.LightBrightness
		light.Range = config.LightRange or 10
		light.Color = config.LightColor or config.Color or Color3.new(1, 1, 1)
		light.Parent = flash
	end

	Debris:AddItem(flash, config.Lifetime or 0.1)
	return flash
end

local function createMuzzleFlash(position, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.001 then
		flatDirection = Vector3.new(0, 0, -1)
	else
		flatDirection = flatDirection.Unit
	end
	local muzzleTemplateHandled = CombatVfxService.playVfxTemplate(
		position,
		flatDirection,
		shotVfxConfig.MuzzleFlash,
		"MuzzleFlash"
	)

	if not muzzleTemplateHandled then
		createFlash(position, shotVfxConfig.MuzzleFlash, "VFX_MuzzleParticleFlash")
	end

	local blastConfig = shotVfxConfig.MuzzleBlast
	if blastConfig ~= nil and blastConfig.Enabled == true then
		local blastPosition = position + flatDirection * (blastConfig.ForwardOffset or 2.6)
		local blastTemplateHandled = CombatVfxService.playVfxTemplate(
			blastPosition,
			flatDirection,
			blastConfig,
			"MuzzleBlast"
		)

		if not blastTemplateHandled then
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
	end
	local smokeConfig = shotVfxConfig.Smoke
	if smokeConfig ~= nil and smokeConfig.Enabled == true then
		local smokePosition = position - flatDirection * (smokeConfig.BackwardOffset or 0.8) + Vector3.new(0, smokeConfig.UpOffset or 0.3, 0)
		local smokeTemplateHandled = CombatVfxService.playVfxTemplate(
			smokePosition,
			-flatDirection,
			smokeConfig,
			"Smoke"
		)
		local particleHandled = false

		if not smokeTemplateHandled then
			particleHandled = createParticleBurst(smokePosition, -flatDirection, smokeConfig, "VFX_MuzzleParticleSmoke")
		end

		if not smokeTemplateHandled and (not particleHandled or smokeConfig.UseProceduralFallback == true) then
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

local function getVfxDirection(direction)
	if typeof(direction) ~= "Vector3" then
		return Vector3.new(0, 0, -1)
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flatDirection.Unit
end

local function createImpactBurst(position, direction, config, effectName)
	if config == nil or config.Enabled ~= true then return false end
	local effectDirection = getVfxDirection(direction)
	local templateHandled = CombatVfxService.playVfxTemplate(
		position,
		effectDirection,
		config,
		effectName
	)

	if templateHandled then return true end

	local handled = false

	if config.UseFlashFallback ~= false then
		handled = createFlash(position, config, "VFX_" .. tostring(effectName) .. "_Flash", effectDirection, true) ~= nil or handled
	end

	local particleHandled = createParticleBurst(position, effectDirection, config, "VFX_" .. tostring(effectName) .. "_Particles")
	handled = particleHandled or handled

	if particleHandled and config.UseProceduralFallback ~= true then return true end
	if config.UseProceduralFallback == false then return handled end

	local sparkSize = config.SparkSize
	if typeof(sparkSize) ~= "Vector3" then
		sparkSize = Vector3.new(0.16, 0.16, 0.75)
	end

	for _ = 1, config.Count or 3 do
		local spark = Instance.new("Part")
		spark.Name = "VFX_" .. tostring(effectName) .. "_Spark"
		spark.Size = sparkSize
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Material = config.Material or Enum.Material.Neon
		spark.Color = config.Color or Color3.fromRGB(255, 206, 84)
		spark.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		spark.Parent = vfxFolder
		Debris:AddItem(spark, config.Lifetime or 0.12)
	end

	return true
end

local function createWallImpactVfx(position, normal)
	return createImpactBurst(position, normal, impactVfxConfig.WallImpact, "WallImpact")
end

local function createDamageHitVfx(position, normal)
	return createImpactBurst(position, normal, impactVfxConfig.DamageHit, "DamageHit")
end

local function createNoPenVfx(position, normal)
	return createImpactBurst(position, normal, impactVfxConfig.NoPen, "NoPen")
end

local function createSelfHitVfx(position, normal)
	return createImpactBurst(position, normal, impactVfxConfig.SelfHit, "SelfHit")
end

local function createImpactFlash(position)
	return createWallImpactVfx(position, Vector3.yAxis)
end

local function createRicochetVfx(position, normal)
	local direction = typeof(normal) == "Vector3" and normal or Vector3.yAxis

	local templateHandled = CombatVfxService.playVfxTemplate(
		position,
		direction,
		ricochetConfig,
		"Ricochet"
	)

	if templateHandled then
		return true
	end

	if ricochetConfig == nil or ricochetConfig.UseImpactFallback ~= false then
		if not createImpactBurst(position, direction, ricochetConfig, "Ricochet") then
			createWallImpactVfx(position, direction)
		end
	end

	return false
end

local function createProceduralDeathExplosion(position, config)
	if config == nil or config.Enabled ~= true or config.UseProceduralFallback ~= true then
		return false
	end

	local lifetime = math.max(0.25, config.FallbackLifetime or config.TemplateLifetime or 1.2)
	local shardCount = math.clamp(math.floor(tonumber(config.FallbackPartCount) or 8), 0, 12)

	local flash = Instance.new("Part")
	flash.Name = "VFX_DeathExplosionFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(9, 9, 9)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 120, 45)
	flash.Transparency = 0.18
	flash.Parent = vfxFolder

	local light = Instance.new("PointLight")
	light.Brightness = 7
	light.Range = 28
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Parent = flash
	Debris:AddItem(flash, math.min(lifetime, 0.45))

	for index = 1, shardCount do
		local spark = Instance.new("Part")
		spark.Name = "VFX_DeathExplosionShard"
		spark.Size = Vector3.new(0.35, 0.35, 2.2)
		spark.CFrame = CFrame.new(position)
			* CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
			* CFrame.new(0, 0, -math.random(2, 7))
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Material = Enum.Material.Neon
		spark.Color = index % 2 == 0 and Color3.fromRGB(255, 220, 110) or Color3.fromRGB(255, 85, 35)
		spark.Parent = vfxFolder
		Debris:AddItem(spark, math.min(lifetime, 0.7))
	end

	return true
end

local function createDeathExplosion(position)
	if deathExplosionConfig == nil or deathExplosionConfig.Enabled ~= true then
		return false
	end

	local templateHandled = CombatVfxService.playVfxTemplate(
		position,
		Vector3.yAxis,
		deathExplosionConfig,
		"DeathExplosion"
	)

	if templateHandled then
		return true
	end

	return createProceduralDeathExplosion(position, deathExplosionConfig)
end

local function createBurningTank(position)
	if burningTankConfig == nil or burningTankConfig.Enabled ~= true then
		return false
	end

	return CombatVfxService.playVfxTemplate(
		position,
		Vector3.yAxis,
		burningTankConfig,
		"BurningTank"
	)
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

local function getArenaNumberModifier(participant, attributeName, fallback)
	if participant == nil or participant.ParticipantState ~= ARENA_PARTICIPANT_STATE then
		return fallback
	end

	local value = participant[attributeName]

	if typeof(value) ~= "number" then
		local physicalModel = TankParticipantRegistry.getParticipantPhysicalModel(participant)
		value = physicalModel ~= nil and physicalModel:GetAttribute(attributeName) or nil
	end

	if typeof(value) ~= "number" then
		return fallback
	end

	return value
end

local function rotateFlatDirection(direction, degrees)
	local rotated = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(direction)
	local flat = Vector3.new(rotated.X, 0, rotated.Z)

	if flat.Magnitude < 0.001 then
		return direction
	end

	return flat.Unit
end

local function getLateralDirection(direction)
	local lateral = Vector3.new(-direction.Z, 0, direction.X)

	if lateral.Magnitude < 0.001 then
		return Vector3.new(1, 0, 0)
	end

	return lateral.Unit
end

local function getShotPattern(participant, origin, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		return {}
	end

	local unitDirection = flatDirection.Unit
	local projectileCount = math.max(1, math.floor(getArenaNumberModifier(participant, "ArenaProjectileCount", 1)))
	local spreadDegrees = getArenaNumberModifier(participant, "ArenaSpreadDegrees", 0)
	local doubleShotLateralOffset = getArenaNumberModifier(participant, "ArenaDoubleShotLateralOffset", 0)

	if projectileCount == 2 then
		local lateral = getLateralDirection(unitDirection) * math.max(0, doubleShotLateralOffset)

		return {
			{ Origin = origin - lateral, Direction = unitDirection },
			{ Origin = origin + lateral, Direction = unitDirection },
		}
	elseif projectileCount >= 3 then
		local spread = math.max(0, spreadDegrees)

		return {
			{ Origin = origin, Direction = rotateFlatDirection(unitDirection, -spread) },
			{ Origin = origin, Direction = unitDirection },
			{ Origin = origin, Direction = rotateFlatDirection(unitDirection, spread) },
		}
	end

	return {
		{ Origin = origin, Direction = unitDirection },
	}
end

function ProjectileService.createProjectile(ownerParticipant, origin, direction, options)
	options = options or {}
	local flatDirection = Vector3.new(direction.X, 0, direction.Z).Unit
	local projectilePart = createProjectilePart(origin, flatDirection)
	local ownerTankModel = TankParticipantRegistry.getParticipantPhysicalModel(ownerParticipant)
	local noDamage = callbacks.isNoDamageProjectile ~= nil and callbacks.isNoDamageProjectile(ownerParticipant) == true
	local noStats = noDamage

	if callbacks.shouldRecordShot ~= nil then
		noStats = callbacks.shouldRecordShot(ownerParticipant) ~= true
	end

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
		BaseDamage = PROJECTILE_DAMAGE,
		Damage = PROJECTILE_DAMAGE * (tonumber(options.DamageMultiplier) or 1),
		PenetrationPower = PROJECTILE_PENETRATION_POWER,
		Penetration = PROJECTILE_LEGACY_PENETRATION,
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
		NoDamage = noDamage,
		NoStats = noStats,
	}
	table.insert(projectiles, projectile)
	createMuzzleFlash(origin, flatDirection)
end

function ProjectileService.tryShoot(participant, direction)
	if participant == nil
		or participant.IsControllable == false
		or participant.CanShoot == false
		or TankParticipantRegistry.getParticipantIsDead(participant)
	then
		return false
	end

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
	local cooldownMultiplier = math.max(0.05, getArenaNumberModifier(participant, "ArenaFireRateMultiplier", 1))
	local cooldown = (participant.WeaponConfig.ShootCooldown or SHOOT_COOLDOWN) * cooldownMultiplier
	local lastShotTime = participant.LastShotTime or 0
	if currentTime - lastShotTime < cooldown then return false end

	local isMuzzleBlocked, obstaclePart, blockedPosition, blockedReason = getMuzzleObstruction(participant)

	if isMuzzleBlocked then
		debugMuzzleBlocked(participant, obstaclePart, blockedReason)
		sendBlockedShotFeedback(participant, blockedPosition or participant.ShootPoint.Position)
		return false
	end

	participant.LastShotTime = currentTime
	participant.WeaponReadyAt = currentTime + cooldown
	participant.WeaponState.LastShotTime = participant.LastShotTime
	participant.WeaponState.WeaponReadyAt = participant.WeaponReadyAt
	publishReloadPresentationState(participant, cooldown)
	local damageMultiplier = math.max(0, getArenaNumberModifier(participant, "ArenaDamageMultiplier", 1))
	local shotOrigin = participant.ShootPoint.Position
	for _, shot in ipairs(getShotPattern(participant, participant.ShootPoint.Position, flatDirection.Unit)) do
		ProjectileService.createProjectile(participant, shot.Origin, shot.Direction, {
			DamageMultiplier = damageMultiplier,
		})
	end
	sendProjectileFeedback("Shot", shotOrigin, "", Color3.fromRGB(255, 230, 150), true)
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
                local roundState = callbacks.getRoundStateForProjectile ~= nil
                    and callbacks.getRoundStateForProjectile(projectile)
                    or callbacks.getRoundState()
                local destroyed = ProjectileCombatService.handleProjectileTankHit(
                    projectile,
                    targetParticipant,
                    result.Position,
                    result.Normal,
                    armorZone,
                    { roundState = roundState }
                )

                if destroyed then table.remove(projectiles, i) end
            elseif projectile.BounceCount >= projectile.MaxBounces then
                createWallImpactVfx(result.Position, result.Normal)
                ProjectileService.destroyProjectile(projectile)
                table.remove(projectiles, i)
            else
                createRicochetVfx(result.Position, result.Normal)
                sendProjectileFeedback("Ricochet", result.Position, "", Color3.fromRGB(255, 220, 70), true)
                ProjectileCombatService.applyProjectileRicochet(projectile, result.Position, result.Normal)
                ProjectileCombatService.printBounce(projectile)
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
		createWallImpactVfx = createWallImpactVfx,
		createDamageHitVfx = createDamageHitVfx,
		createNoPenVfx = createNoPenVfx,
		createSelfHitVfx = createSelfHitVfx,
		createRicochetVfx = createRicochetVfx,
		createDeathExplosion = createDeathExplosion,
		createBurningTank = createBurningTank,
		destroyProjectile = ProjectileService.destroyProjectile,
	}
end

return ProjectileService
