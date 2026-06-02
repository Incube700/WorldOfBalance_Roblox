local ProjectileService = {}

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local TankArmorConfig = require(configs:WaitForChild("TankArmorConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local WeaponSafetyConfig = require(configs:WaitForChild("WeaponSafetyConfig"))
local VfxConfig = require(configs:WaitForChild("VfxConfig"))
local DebugCombatConfig = require(configs:WaitForChild("DebugCombatConfig"))
local PerformanceConfig = require(configs:WaitForChild("PerformanceConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local ProjectileCollisionService = require(script.Parent:WaitForChild("ProjectileCollisionService"))
local ProjectileHitResult = require(script.Parent:WaitForChild("ProjectileHitResult"))
local ProjectileCombatService = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ProjectileCombatService"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))
local CombatVfxService = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("CombatVfxService"))
local GameplayCombatFXService = require(shared:WaitForChild("FX"):WaitForChild("CombatFXService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local projectileTypeId = primaryWeaponConfig.ProjectileTypeId or ProjectileCatalog.DefaultProjectileTypeId
local projectileConfig = ProjectileCatalog.Projectiles[projectileTypeId]
	or ProjectileCatalog.Projectiles[ProjectileCatalog.DefaultProjectileTypeId]
local shotVfxConfig = VfxConfig.Shot
local impactVfxConfig = VfxConfig.Impact or {}
local deathExplosionConfig = VfxConfig.DeathExplosion
local burningTankConfig = VfxConfig.BurningTank
local ricochetConfig = VfxConfig.Ricochet
local shieldVfxConfig = VfxConfig.Shield or {}

local function getDiagnosticsConfig()
	return PerformanceConfig.Diagnostics or {}
end

local function isMuzzleVfxEnabled()
	local diagnosticsConfig = getDiagnosticsConfig()

	return diagnosticsConfig.ProjectileVfxEnabled ~= false
		and diagnosticsConfig.MuzzleFlashEnabled ~= false
end

local function isImpactVfxEnabled()
	local diagnosticsConfig = getDiagnosticsConfig()

	return diagnosticsConfig.ProjectileVfxEnabled ~= false
		and diagnosticsConfig.ImpactVfxEnabled ~= false
end

local function playGameplayFXAt(effectKey, position, direction, options)
	if typeof(position) ~= "Vector3" then
		return false
	end

	options = options or {}

	if typeof(direction) == "Vector3" then
		options.Direction = direction
	end

	return GameplayCombatFXService.PlayAt(effectKey, position, options) ~= nil
end

local PROJECTILE_SPEED = projectileConfig.Speed
local PROJECTILE_DAMAGE = projectileConfig.Damage or projectileConfig.BaseDamage or projectileConfig.MaxDamage
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
	onShotFired = nil,
	-- Update 0.2 temporary-weapon hooks (optional; nil-safe at every call site).
	onWeaponShotConsumed = nil, -- (participant) after a temp-weapon shot fires.
	onProjectileExploded = nil, -- (projectile, position) for Rocket area damage + FX.
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

local function sendProjectileFeedback(feedbackType, position, text, color, audioOnly, weaponId)
	if callbacks.sendCombatFeedback == nil then
		return
	end

	-- weaponId (optional, Etap 3) lets the client play a per-weapon shot sound.
	callbacks.sendCombatFeedback(feedbackType, position, text, color, audioOnly == true, weaponId)
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

local function createMuzzleFlash(position, direction, weaponId)
	if not isMuzzleVfxEnabled() then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.001 then
		flatDirection = Vector3.new(0, 0, -1)
	else
		flatDirection = flatDirection.Unit
	end

	-- Weapon-specific muzzle FX when defined (RailGun/Rocket), else the generic muzzle flash.
	local muzzleKey = "MuzzleFlash"
	if weaponId == "RailGun" then
		muzzleKey = "RailGunShot"
	elseif weaponId == "Rocket" then
		muzzleKey = "RocketShot"
	end

	if playGameplayFXAt(muzzleKey, position, flatDirection) then
		return
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

local gameplayImpactEffectKeyByName = {
	DamageHit = "ProjectileImpact",
	NoPen = "ProjectileImpact",
	SelfHit = "ProjectileImpact",
	WallImpact = "ProjectileImpact",
}

local function createImpactBurst(position, direction, config, effectName)
	if not isImpactVfxEnabled() then return false end
	if config == nil or config.Enabled ~= true then return false end
	local effectDirection = getVfxDirection(direction)
	local gameplayEffectKey = gameplayImpactEffectKeyByName[effectName]

	if gameplayEffectKey ~= nil and playGameplayFXAt(gameplayEffectKey, position, effectDirection) then
		return true
	end

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
	if not isImpactVfxEnabled() then
		return false
	end

	local direction = typeof(normal) == "Vector3" and normal or Vector3.yAxis

	if playGameplayFXAt("RicochetImpact", position, direction) then
		return true
	end

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

local function createShieldReflectVfx(position, normal)
	if not isImpactVfxEnabled() then
		return false
	end

	local direction = typeof(normal) == "Vector3" and normal or Vector3.yAxis
	local reflectConfig = shieldVfxConfig.Reflect

	if playGameplayFXAt("ReflectShield", position, direction) then
		return true
	end

	if createImpactBurst(position, direction, reflectConfig, "ShieldReflect") then
		return true
	end

	return createRicochetVfx(position, direction)
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
	if not isImpactVfxEnabled() then
		return false
	end

	if deathExplosionConfig == nil or deathExplosionConfig.Enabled ~= true then
		return false
	end

	if playGameplayFXAt("TankExplosion", position, Vector3.yAxis) then
		return true
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

-- Rocket detonation: its OWN explosion FX (RocketExplosion). Falls back to the death
-- explosion / procedural burst if no authored rocket asset exists yet.
local function createRocketExplosion(position)
	if not isImpactVfxEnabled() then
		return false
	end
	if playGameplayFXAt("RocketExplosion", position, Vector3.yAxis) then
		return true
	end
	return createDeathExplosion(position)
end

local function createBurningTank(position)
	if not isImpactVfxEnabled() then
		return false
	end

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

local function createProjectilePart(position, direction, visualOverride, visualScale)
	local visualConfig = shotVfxConfig.Projectile
	-- visualOverride (temporary pickup weapons only) recolors/resizes the shell so
	-- the active weapon is obvious. nil override = default cannon visuals, unchanged.
	-- visualScale (>= 1) is a subtle upgrade-driven size/brightness bump (default 1).
	visualScale = math.clamp(tonumber(visualScale) or 1, 1, 1.5)
	local overrideColor = visualOverride ~= nil and visualOverride.ProjectileColor or nil
	local overrideRadius = visualOverride ~= nil and tonumber(visualOverride.ProjectileRadius) or nil
	-- Per-weapon FX flavor (temporary pickup weapons): a dedicated trail tail color, an extra
	-- light punch, and a wider trail. Falls back to the projectile color so any weapon with just
	-- a ProjectileColor still gets a tinted tail. nil override = default cannon, unchanged.
	local overrideTrailColor = visualOverride ~= nil and visualOverride.ProjectileTrailColor or nil
	local overrideLightBoost = visualOverride ~= nil and tonumber(visualOverride.ProjectileLightBoost) or nil
	local overrideTrailWidth = visualOverride ~= nil and tonumber(visualOverride.ProjectileTrailWidthScale) or nil
	local partSize = (overrideRadius ~= nil and (overrideRadius * 2) or visualConfig.Size) * visualScale
	local partColor = overrideColor or visualConfig.Color or Color3.fromRGB(255, 235, 140)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(partSize, partSize, partSize)
	part.CFrame = CFrame.lookAt(position, position + direction, Vector3.yAxis)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = visualConfig.Material or Enum.Material.Neon
	part.Color = partColor
	part.Transparency = 0
	part.Parent = projectileFolder
	local light = Instance.new("PointLight")
	light.Brightness = (visualConfig.LightBrightness or 1) * visualScale * (overrideLightBoost or 1)
	light.Range = (visualConfig.LightRange or 6) * visualScale * (overrideLightBoost ~= nil and 1.35 or 1)
	light.Color = overrideTrailColor or overrideColor or visualConfig.Color or Color3.fromRGB(255, 235, 140)
	light.Parent = part
	local trailHalfLength = math.max(0.45, visualConfig.Size * 0.55)
	local frontAttachment = Instance.new("Attachment")
	frontAttachment.Name = "TrailAttachment0"
	frontAttachment.Position = Vector3.new(0, 0, visualConfig.TrailFrontOffset or -trailHalfLength)
	frontAttachment.Parent = part
	local backAttachment = Instance.new("Attachment")
	backAttachment.Name = "TrailAttachment1"
	backAttachment.Position = Vector3.new(0, 0, visualConfig.TrailBackOffset or trailHalfLength)
	backAttachment.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "ProjectileTrail"
	trail.Attachment0 = frontAttachment
	trail.Attachment1 = backAttachment
	if overrideTrailColor ~= nil then
		-- Per-weapon flavored tail: a hot near-white core fading into the weapon's signature
		-- color (e.g. RailGun bright-blue beam, Rocket scarlet exhaust) so the shot reads instantly.
		local core = partColor:Lerp(Color3.new(1, 1, 1), 0.55)
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, core),
			ColorSequenceKeypoint.new(0.35, overrideTrailColor),
			ColorSequenceKeypoint.new(1, overrideTrailColor),
		})
	else
		trail.Color = visualConfig.TrailColor
			or ColorSequence.new(Color3.fromRGB(255, 235, 140), Color3.fromRGB(255, 95, 40))
	end
	trail.Transparency = visualConfig.TrailTransparency
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 1),
		})
	trail.Lifetime = visualConfig.TrailLifetime or 0.18
	trail.MinLength = visualConfig.TrailMinLength or 0.05
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	local widthMul = overrideTrailWidth or 1
	trail.WidthScale = (overrideTrailWidth == nil and visualConfig.TrailWidth)
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1 * widthMul),
			NumberSequenceKeypoint.new(0.6, 0.55 * widthMul),
			NumberSequenceKeypoint.new(1, 0),
		})
	trail.Enabled = true
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
	local weaponOverride = options.WeaponOverride
	local flatDirection = Vector3.new(direction.X, 0, direction.Z).Unit
	-- Subtle upgrade feedback: the shell grows/brightens a touch with the damage multiplier
	-- (caps at +25% size) so a buffed tank's shots read as "heavier". Default = 1.0 (unchanged).
	local dmgMult = getArenaNumberModifier(ownerParticipant, "ArenaDamageMultiplier", 1)
	local visualScale = math.clamp(1 + (dmgMult - 1) * 0.25, 1, 1.25)
	local projectilePart = createProjectilePart(origin, flatDirection, weaponOverride, visualScale)
	local ownerTankModel = TankParticipantRegistry.getParticipantPhysicalModel(ownerParticipant)
	local noDamage = callbacks.isNoDamageProjectile ~= nil and callbacks.isNoDamageProjectile(ownerParticipant) == true
	local noStats = noDamage
	local ricochetBonus = math.max(0, math.floor(getArenaNumberModifier(ownerParticipant, "ArenaRicochetBonus", 0)))

	-- Etap 1 Piercing run upgrade: lets the DEFAULT cannon pass through N enemies. A weapon
	-- override with its own PierceEnemies (e.g. Phase Shot) takes precedence and is unchanged.
	local upgradePierce = math.max(0, math.floor(getArenaNumberModifier(ownerParticipant, "ArenaPierceEnemies", 0)))
	local pierceEnemies, pierceEnemyLimit
	if weaponOverride ~= nil and weaponOverride.PierceEnemies == true then
		pierceEnemies = true
		pierceEnemyLimit = tonumber(weaponOverride.PierceEnemyLimit)
	elseif upgradePierce > 0 then
		pierceEnemies = true
		pierceEnemyLimit = upgradePierce
	else
		pierceEnemies = false
		pierceEnemyLimit = nil
	end

	-- Penetration BONUS (added to the shell's base pen by the armor resolver). The Piercing
	-- run upgrade and armor-piercing weapons (RailGun) raise pen so the shell can cross the
	-- armor threshold (e.g. punch the front plate). It does NOT ignore the gate.
	local pierceBonus = 0
	if upgradePierce > 0 then
		pierceBonus += 12 * upgradePierce
	end
	-- Weapon pen modifier (can be NEGATIVE, e.g. MachineGun/Shotgun pellets are weak vs armor).
	if weaponOverride ~= nil and tonumber(weaponOverride.PenetrationBonus) ~= nil then
		pierceBonus += tonumber(weaponOverride.PenetrationBonus)
	end

	if callbacks.shouldRecordShot ~= nil then
		noStats = callbacks.shouldRecordShot(ownerParticipant) ~= true
	end

	-- Temporary pickup weapons LAYER on top of run upgrades. The default cannon
	-- (weaponOverride == nil) keeps every value below exactly as before.
	-- MaxBounces starts from the default + the player's ricochet upgrade bonus, so
	-- temporary weapons inherit run progression unless they explicitly opt out via
	-- OverrideMaxRicochets = true (e.g., Phase Shot disables ricochet). Weapons can
	-- also add a MaxRicochetsBonus on top of the upgraded base.
	local projectileSpeed = PROJECTILE_SPEED
	local projectileLifetime = PROJECTILE_LIFETIME
	local maxBounces = PROJECTILE_MAX_BOUNCES + ricochetBonus
	local projectileAcceleration = nil
	local projectileMaxSpeed = nil

	if weaponOverride ~= nil then
		projectileSpeed = tonumber(weaponOverride.ProjectileSpeed) or projectileSpeed
		projectileLifetime = tonumber(weaponOverride.ProjectileLifetime) or projectileLifetime
		projectileAcceleration = tonumber(weaponOverride.ProjectileAcceleration)
		projectileMaxSpeed = tonumber(weaponOverride.ProjectileMaxSpeed)

		if weaponOverride.OverrideMaxRicochets == true then
			maxBounces = math.max(0, math.floor(tonumber(weaponOverride.MaxRicochets) or 0))
		elseif tonumber(weaponOverride.MaxRicochetsBonus) ~= nil then
			maxBounces = math.max(0, maxBounces + math.floor(weaponOverride.MaxRicochetsBonus))
		end
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
		PreviousPosition = origin,
		NextPosition = origin,
		Direction = flatDirection,
		Speed = projectileSpeed,
		BaseDamage = PROJECTILE_DAMAGE,
		Damage = PROJECTILE_DAMAGE * (tonumber(options.DamageMultiplier) or 1),
		PenetrationPower = PROJECTILE_PENETRATION_POWER,
		Penetration = PROJECTILE_LEGACY_PENETRATION,
		PenetrationBonus = pierceBonus,
		-- Ramping floor for pierce: 2 dmg at 1 stack, 4 at 2, ... so a pellet that only just
		-- crosses the front plate still chips a small, growing amount.
		PierceDamageFloor = upgradePierce > 0 and (2 * upgradePierce) or 0,
		PiercesWalls = weaponOverride ~= nil and weaponOverride.PiercesWalls == true,
		BounceCount = 0,
		MaxBounces = maxBounces,
		BounceSpeedMultiplier = PROJECTILE_BOUNCE_SPEED_MULTIPLIER,
		DamageMultiplierPerBounce = PROJECTILE_DAMAGE_MULTIPLIER,
		MinSpeed = PROJECTILE_MIN_SPEED,
		LifeTime = 0,
		MaxLifeTime = projectileLifetime,
		LastHitResult = ProjectileHitResult.NoHit,
		Part = projectilePart,
		Destroyed = false,
		CanHitOwner = false,
		MatchId = ownerParticipant.MatchId,
		NoDamage = noDamage,
		NoStats = noStats,
		-- Temporary-weapon-only fields (nil/false for the default cannon).
		WeaponOverrideId = weaponOverride ~= nil and weaponOverride.Id or nil,
		ExplosionRadius = weaponOverride ~= nil and tonumber(weaponOverride.ExplosionRadius) or nil,
		ExplosionDamage = weaponOverride ~= nil and tonumber(weaponOverride.ExplosionDamage) or nil,
		PierceEnemies = pierceEnemies,
		PierceHitCooldownSeconds = weaponOverride ~= nil and tonumber(weaponOverride.PierceHitCooldownSeconds) or 0.3,
		-- How many enemies the shell can pass through before destroying. Phase Shot sets its
		-- own limit; otherwise the Piercing run upgrade (ArenaPierceEnemies) applies.
		PierceEnemyLeft = pierceEnemyLimit,
		PierceHitTimes = {},
		-- Rocket-style acceleration. nil for non-accelerating shells (default cannon).
		Acceleration = projectileAcceleration,
		MaxSpeed = projectileMaxSpeed,
	}
	table.insert(projectiles, projectile)
	createMuzzleFlash(origin, flatDirection, weaponOverride ~= nil and weaponOverride.Id or nil)
end

function ProjectileService.tryShoot(participant, direction, options_isChargedShot)
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
	-- Temporary pickup weapon (nil for the default cannon -> behavior unchanged).
	local weaponOverride = participant.TempWeapon ~= nil and participant.TempWeapon.Config or nil
	local cooldownMultiplier = math.max(0.05, getArenaNumberModifier(participant, "ArenaFireRateMultiplier", 1))
	local baseCooldown = participant.WeaponConfig.ShootCooldown or SHOOT_COOLDOWN
	if weaponOverride ~= nil and tonumber(weaponOverride.ShootCooldown) ~= nil then
		baseCooldown = weaponOverride.ShootCooldown
	end
	local cooldown = baseCooldown * cooldownMultiplier
	local lastShotTime = participant.LastShotTime or 0
	-- bypassGates (true) is used by charge-up and burst FOLLOW-UP shots so they skip the
	-- cooldown + charge gates the first trigger already paid.
	if not options_isChargedShot and currentTime - lastShotTime < cooldown then
		return false
	end

	-- Charge-up weapons (RailGun): first trigger starts a charge; the actual shot fires
	-- after ChargeSeconds. While charging, further pulls are ignored. If the tank dies or
	-- is disarmed mid-charge, the delayed shot self-cancels (re-checks state below).
	local chargeSeconds = weaponOverride ~= nil and tonumber(weaponOverride.ChargeSeconds) or nil
	if chargeSeconds ~= nil and chargeSeconds > 0 and participant.WeaponCharging ~= true and not options_isChargedShot then
		participant.WeaponCharging = true
		participant.LastShotTime = currentTime -- gate re-triggers during charge
		sendProjectileFeedback("Charge", participant.ShootPoint.Position, "", Color3.fromRGB(120, 220, 255), true)

		-- Charge visual: a glowing blue orb at the muzzle that grows over the charge time,
		-- so the player and enemies can read the incoming RailGun shot. Pure visual, anchored.
		local shootPoint = participant.ShootPoint
		local chargeOrb = Instance.new("Part")
		chargeOrb.Name = "RailGunCharge"
		chargeOrb.Shape = Enum.PartType.Ball
		chargeOrb.Size = Vector3.new(0.4, 0.4, 0.4)
		chargeOrb.Anchored = true
		chargeOrb.CanCollide = false
		chargeOrb.CanQuery = false
		chargeOrb.CanTouch = false
		chargeOrb.CastShadow = false
		chargeOrb.Material = Enum.Material.Neon
		chargeOrb.Color = Color3.fromRGB(150, 230, 255)
		chargeOrb.CFrame = CFrame.new(shootPoint.Position)
		chargeOrb.Parent = projectileFolder
		local chargeLight = Instance.new("PointLight")
		chargeLight.Color = Color3.fromRGB(90, 190, 255)
		chargeLight.Range = 16
		chargeLight.Brightness = 5
		chargeLight.Parent = chargeOrb
		-- Inward-pulling sparks: energy visibly gathering into the orb, so allies and enemies
		-- both clearly read "RailGun is charging here". Pure visual on the anchored orb.
		local chargeSpark = Instance.new("Attachment")
		chargeSpark.Parent = chargeOrb
		local chargeEmitter = Instance.new("ParticleEmitter")
		chargeEmitter.Color = ColorSequence.new(Color3.fromRGB(180, 240, 255), Color3.fromRGB(60, 170, 255))
		chargeEmitter.LightEmission = 1
		chargeEmitter.LightInfluence = 0
		chargeEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1),
			NumberSequenceKeypoint.new(1, 0),
		})
		chargeEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		chargeEmitter.Lifetime = NumberRange.new(0.25, 0.45)
		chargeEmitter.Rate = 60
		chargeEmitter.Speed = NumberRange.new(-9, -6) -- negative = pulled inward toward the orb
		chargeEmitter.SpreadAngle = Vector2.new(360, 360)
		chargeEmitter.Acceleration = Vector3.new(0, 0, 0)
		chargeEmitter.Parent = chargeSpark
		local growTween = TweenService:Create(
			chargeOrb,
			TweenInfo.new(chargeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = Vector3.new(2.2, 2.2, 2.2) }
		)
		growTween:Play()
		-- Keep it stuck to the muzzle while charging.
		local followConn
		followConn = RunService.Heartbeat:Connect(function()
			if chargeOrb.Parent == nil or shootPoint == nil or shootPoint.Parent == nil then
				if followConn then followConn:Disconnect() end
				return
			end
			chargeOrb.CFrame = CFrame.new(shootPoint.Position)
		end)

		local capturedDir = flatDirection.Unit
		task.delay(chargeSeconds, function()
			participant.WeaponCharging = false
			if followConn then followConn:Disconnect() end
			if chargeOrb.Parent ~= nil then
				chargeOrb:Destroy()
			end
			-- Fire the real shot now (bypass the charge gate via the bypass flag).
			ProjectileService.tryShoot(participant, capturedDir, true)
		end)
		return false
	end

	-- BURST weapons (MachineGun): one trigger fires BurstCount shells one-after-another (a
	-- stream, not a spread). The first shell fires now via the normal flow below; the rest
	-- are scheduled as bypass follow-ups. Only the FIRST (non-bypass) trigger schedules them.
	local burstCount = weaponOverride ~= nil and math.floor(tonumber(weaponOverride.BurstCount) or 0) or 0
	if burstCount >= 2 and not options_isChargedShot then
		local interval = math.max(0.02, tonumber(weaponOverride.BurstIntervalSeconds) or 0.07)
		local spread = math.max(0, tonumber(weaponOverride.BurstSpreadDegrees) or 0)
		local baseDir = flatDirection.Unit
		for i = 1, burstCount - 1 do
			task.delay(interval * i, function()
				if participant == nil or TankParticipantRegistry.getParticipantIsDead(participant) then
					return
				end
				local jitter = spread > 0 and (math.random() * 2 - 1) * spread or 0
				ProjectileService.tryShoot(participant, rotateFlatDirection(baseDir, jitter), true)
			end)
		end
	end

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
	if callbacks.onShotFired ~= nil then
		callbacks.onShotFired(participant, flatDirection.Unit)
	end
	local damageMultiplier = math.max(0, getArenaNumberModifier(participant, "ArenaDamageMultiplier", 1))
	if weaponOverride ~= nil and tonumber(weaponOverride.DamageMultiplier) ~= nil then
		damageMultiplier = damageMultiplier * weaponOverride.DamageMultiplier
	end
	local shotOrigin = participant.ShootPoint.Position
	local shots = getShotPattern(participant, participant.ShootPoint.Position, flatDirection.Unit)

	-- Fan expansion (e.g., MachineGun): a weapon with FanCount > 1 turns EACH base shot
	-- into a spread of FanCount projectiles across FanSpreadDegrees. Because the base shots
	-- already include the multishot pattern, Double Shot (2 base shots) naturally becomes
	-- TWO fans, Triple Shot becomes three, etc. The MaxProjectilesPerTrigger cap below then
	-- bounds the total so the server is never flooded.
	local fanCount = weaponOverride ~= nil and math.floor(tonumber(weaponOverride.FanCount) or 0) or 0
	if fanCount >= 2 then
		local fanSpread = math.max(0, tonumber(weaponOverride.FanSpreadDegrees) or 0)
		local expanded = {}
		for _, shot in ipairs(shots) do
			-- Evenly distribute fanCount directions across [-fanSpread/2, +fanSpread/2].
			local span = fanSpread
			local step = fanCount > 1 and (span / (fanCount - 1)) or 0
			local startAngle = -span * 0.5
			for i = 0, fanCount - 1 do
				local angle = startAngle + step * i
				table.insert(expanded, {
					Origin = shot.Origin,
					Direction = rotateFlatDirection(shot.Direction, angle),
				})
			end
		end
		shots = expanded
	end

	-- Optional per-trigger projectile cap (e.g., MachineGun caps multishot to keep
	-- server-side projectile count bounded even with upgrades). When omitted, all
	-- upgraded shots fire (one trigger pull = 1 ammo, supports rocket + multishot).
	local maxPerTrigger = weaponOverride ~= nil and tonumber(weaponOverride.MaxProjectilesPerTrigger) or nil
	if maxPerTrigger ~= nil then
		while #shots > maxPerTrigger do
			table.remove(shots)
		end
	end
	for _, shot in ipairs(shots) do
		ProjectileService.createProjectile(participant, shot.Origin, shot.Direction, {
			DamageMultiplier = damageMultiplier,
			WeaponOverride = weaponOverride,
		})
	end
	local shotWeaponId = weaponOverride ~= nil and weaponOverride.Id or "DefaultCannon"
	sendProjectileFeedback("Shot", shotOrigin, "", Color3.fromRGB(255, 230, 150), true, shotWeaponId)
	if callbacks.shouldRecordShot == nil or callbacks.shouldRecordShot(participant) == true then
		MatchStatsService.recordShotFired(participant)
	end
	-- Decrement temporary-weapon ammo (reverts to default cannon when depleted).
	if weaponOverride ~= nil and callbacks.onWeaponShotConsumed ~= nil then
		callbacks.onWeaponShotConsumed(participant)
	end
	return true
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
			projectile.LastHitResult = ProjectileHitResult.Expired
			if projectile.ExplosionRadius ~= nil and callbacks.onProjectileExploded ~= nil then
				callbacks.onProjectileExploded(projectile, projectile.Position)
			end
			ProjectileService.destroyProjectile(projectile)
			table.remove(projectiles, i)
			continue
		end

		-- Apply per-projectile acceleration (Rocket starts slow, accelerates over its
		-- flight). Default cannon shells have Acceleration == nil and are unchanged.
		if projectile.Acceleration ~= nil then
			local cap = projectile.MaxSpeed or projectile.Speed
			projectile.Speed = math.min(cap, projectile.Speed + projectile.Acceleration * deltaTime)
		end

		local result, nextPosition = ProjectileCollisionService.CastSweptRay(
			Workspace,
			projectile,
			deltaTime,
			projectileRaycastParams,
			ProjectileCollisionService.GetProjectileRaycastTargets(
				projectile,
				projectileMapRaycastTargets,
				TankParticipantRegistry
			)
		)

		if result ~= nil then
			local targetParticipant = TankParticipantRegistry.getParticipantFromArmorHitbox(result.Instance)
			local armorZone = TankParticipantRegistry.getArmorZoneFromHitbox(result.Instance)

			if DebugCombatConfig.ProjectileDebug == true then
				local partName = result.Instance ~= nil and result.Instance.Name or "nil"
				local tankId = targetParticipant ~= nil and targetParticipant.TankId or "nil"
				local active = targetParticipant ~= nil and tostring(targetParticipant.IsActive) or "nil"
				print(("[PROJECTILE HIT] part=%s tank=%s active=%s zone=%s"):format(
					partName, tankId, active, tostring(armorZone)
				))
			end

			if targetParticipant ~= nil then
				if projectile.ExplosionRadius ~= nil then
					-- Explosive shells (Rocket) deal area damage on contact and skip the
					-- normal armor/ricochet flow entirely.
					projectile.LastHitResult = ProjectileHitResult.WallRicochet
					if callbacks.onProjectileExploded ~= nil then
						callbacks.onProjectileExploded(projectile, result.Position)
					end
					ProjectileService.destroyProjectile(projectile)
					table.remove(projectiles, i)
					continue
				end

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

				if destroyed then
					table.remove(projectiles, i)
				elseif projectile.PierceEnemies == true then
					-- Phase Shot passed through the enemy: advance past the hit point so
					-- the next sweep starts on the far side of the tank.
					projectile.Position = result.Position + projectile.Direction * 5
					if projectile.Part then
						projectile.Part.CFrame = CFrame.lookAt(
							projectile.Position,
							projectile.Position + projectile.Direction,
							Vector3.yAxis
						)
					end
				end
			elseif projectile.PiercesWalls == true then
				-- RailGun beam: ignore the wall entirely, advance past it and keep flying.
				projectile.Position = result.Position + projectile.Direction * 5
				if projectile.Part then
					projectile.Part.CFrame = CFrame.lookAt(
						projectile.Position,
						projectile.Position + projectile.Direction,
						Vector3.yAxis
					)
				end
			elseif projectile.BounceCount >= projectile.MaxBounces then
				projectile.LastHitResult = ProjectileHitResult.WallRicochet
				if projectile.ExplosionRadius ~= nil and callbacks.onProjectileExploded ~= nil then
					-- Rocket reached a wall with no bounces left -> explode there.
					callbacks.onProjectileExploded(projectile, result.Position)
				else
					createWallImpactVfx(result.Position, result.Normal)
				end
				ProjectileService.destroyProjectile(projectile)
				table.remove(projectiles, i)
			else
				projectile.LastHitResult = ProjectileHitResult.WallRicochet
				createRicochetVfx(result.Position, result.Normal)
				sendProjectileFeedback("Ricochet", result.Position, "", Color3.fromRGB(255, 220, 70), true)
				ProjectileCombatService.applyProjectileRicochet(projectile, result.Position, result.Normal)
				ProjectileCombatService.printBounce(projectile)
			end
		else
			projectile.Position = nextPosition

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
		createShieldReflectVfx = createShieldReflectVfx,
		createDeathExplosion = createDeathExplosion,
		createRocketExplosion = createRocketExplosion,
		createBurningTank = createBurningTank,
		destroyProjectile = ProjectileService.destroyProjectile,
	}
end

return ProjectileService
