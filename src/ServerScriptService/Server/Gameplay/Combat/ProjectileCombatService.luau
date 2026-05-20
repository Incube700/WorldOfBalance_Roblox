local ProjectileCombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local DebugCombatConfig = require(configs:WaitForChild("DebugCombatConfig"))
local ArmorHitResolver = require(script.Parent:WaitForChild("ArmorHitResolver"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))

local PROJECTILE_RICOCHET_OFFSET = 0.45
local ARMOR_DEBUG_THROTTLE_SECONDS = math.max(0.05, tonumber(DebugCombatConfig.ArmorDebugThrottleSeconds) or 0.25)

local dependencies = {}
local lastArmorDebugLogByKey = {}

function ProjectileCombatService.init(deps)
	dependencies = deps
end

local function reflect(direction, normal)
	return direction - 2 * direction:Dot(normal) * normal
end

local function formatNumber(value)
	return string.format("%.1f", value)
end

local DEBUG_PROJECTILES = false

local function printArmorResult(_prefix, targetName, armorHit, projectile)
	if DebugCombatConfig.ArmorDebug ~= true and not DEBUG_PROJECTILES then
		return
	end

	local key = tostring(targetName) .. ":" .. tostring(armorHit.Result)
	local now = os.clock()

	if now - (lastArmorDebugLogByKey[key] or 0) < ARMOR_DEBUG_THROTTLE_SECONDS then
		return
	end

	lastArmorDebugLogByKey[key] = now

	print(
		"[ARMOR] zone="
			.. armorHit.Zone
			.. " angle="
			.. formatNumber(armorHit.ImpactAngleDegrees)
			.. " effective="
			.. formatNumber(armorHit.EffectiveArmor)
			.. " pen="
			.. formatNumber(projectile.PenetrationPower or projectile.Penetration or 0)
			.. " result="
			.. armorHit.Result
			.. " damage="
			.. math.floor(armorHit.FinalDamage)
			.. " tank="
			.. targetName
	)
end

local function printBounce(projectile)
	if not DEBUG_PROJECTILES then return end

	print(
		"[BOUNCE] count="
			.. projectile.BounceCount
			.. " damage="
			.. math.floor(projectile.Damage)
			.. " speed="
			.. math.floor(projectile.Speed)
	)
end

local function getParticipantModel(participant)
	if participant == nil then
		return nil
	end

	return participant.PhysicalModel or participant.Model
end

local function applyProjectileRicochet(projectile, hitPosition, hitNormal, options)
	options = options or {}
	local nextDirection = options.Direction

	if typeof(nextDirection) ~= "Vector3" or nextDirection.Magnitude < 0.001 then
		nextDirection = reflect(projectile.Direction, hitNormal)
	end

	projectile.Direction = nextDirection.Unit
	projectile.Position = hitPosition + projectile.Direction * PROJECTILE_RICOCHET_OFFSET
	projectile.BounceCount += 1
	projectile.Damage *= projectile.DamageMultiplierPerBounce
	projectile.Speed = math.max(projectile.MinSpeed, projectile.Speed * projectile.BounceSpeedMultiplier)
	projectile.CanHitOwner = true

	if projectile.NoStats ~= true and options.NoStats ~= true then
		MatchStatsService.recordProjectileRicochet(projectile)
	end
end

function ProjectileCombatService.handleProjectileTankHit(projectile, targetParticipant, hitPosition, hitNormal, armorZone, options)
	options = options or {}
	local roundState = options.roundState or {}
	local getParticipantIsDead = dependencies.getParticipantIsDead
	local createDamageHitVfx = dependencies.createDamageHitVfx
	local createNoPenVfx = dependencies.createNoPenVfx
	local createSelfHitVfx = dependencies.createSelfHitVfx
	local createRicochetVfx = dependencies.createRicochetVfx
	local destroyProjectile = dependencies.destroyProjectile
	local sendCombatFeedback = dependencies.sendCombatFeedback
	local damageParticipant = dependencies.damageParticipant
	local canDamageParticipant = dependencies.canDamageParticipant

	if roundState.Ended or getParticipantIsDead(targetParticipant) then
		destroyProjectile(projectile)
		return true
	end

	local canDamageTarget = projectile.NoDamage ~= true
		and (canDamageParticipant == nil or canDamageParticipant(projectile, targetParticipant) == true)

	if not canDamageTarget then
		if projectile.BounceCount >= projectile.MaxBounces then
			if createNoPenVfx ~= nil then
				createNoPenVfx(hitPosition, hitNormal)
			end
			destroyProjectile(projectile)
			return true
		end

		if createRicochetVfx ~= nil then
			createRicochetVfx(hitPosition, hitNormal)
		end
		applyProjectileRicochet(projectile, hitPosition, hitNormal, { NoStats = true })
		printBounce(projectile)
		return false
	end

	if projectile.NoStats ~= true then
		MatchStatsService.recordProjectileTankHitStats(projectile)
	end

	local armorHit = ArmorHitResolver.ResolveHit({
		TankModel = getParticipantModel(targetParticipant),
		BodyPart = targetParticipant.Body,
		HitPosition = hitPosition,
		ProjectileDirection = projectile.Direction,
		BaseDamage = projectile.Damage,
		PenetrationPower = projectile.PenetrationPower or projectile.Penetration,
		ArmorZoneHint = armorZone,
	})
	local armorNormal = armorHit.NormalWorld or hitNormal

	if armorHit.Result == "Penetration" then
		printArmorResult("[PEN]", targetParticipant.TankId, armorHit, projectile)

		local damageText = "-" .. math.floor(armorHit.FinalDamage)
		local isSelfHit = targetParticipant == projectile.OwnerParticipant

		if isSelfHit and projectile.OwnerPlayer ~= nil then
			if DEBUG_PROJECTILES then
				print("[SELF-HIT] " .. targetParticipant.TankId .. " hit by own ricochet")
			end
			damageText = "SELF HIT " .. damageText
		end

		if isSelfHit and createSelfHitVfx ~= nil then
			createSelfHitVfx(hitPosition, armorNormal)
		elseif createDamageHitVfx ~= nil then
			createDamageHitVfx(hitPosition, armorNormal)
		end

		sendCombatFeedback(
			"Damage",
			hitPosition,
			damageText,
			Color3.fromRGB(255, 105, 75)
		)

		if damageParticipant(targetParticipant, armorHit.FinalDamage, projectile) and projectile.NoStats ~= true then
			MatchStatsService.recordProjectileDamageStats(projectile, targetParticipant, armorHit.FinalDamage)
		end

		destroyProjectile(projectile)
		return true
	end

	if armorHit.Result == "Ricochet" then
		printArmorResult("[ARMOR-RICOCHET]", targetParticipant.TankId, armorHit, projectile)

		if createRicochetVfx ~= nil then
			createRicochetVfx(hitPosition, armorNormal)
		end

		sendCombatFeedback(
			"ArmorRicochet",
			hitPosition,
			"RICOCHET",
			Color3.fromRGB(255, 220, 70)
		)

		if projectile.BounceCount >= projectile.MaxBounces then
			destroyProjectile(projectile)
			return true
		end

		applyProjectileRicochet(projectile, hitPosition, armorNormal, {
			Direction = armorHit.RicochetDirection,
		})
		printBounce(projectile)

		return false
	end

	printArmorResult("[NO-PEN]", targetParticipant.TankId, armorHit, projectile)

	if createNoPenVfx ~= nil then
		createNoPenVfx(hitPosition, armorNormal)
	end

	sendCombatFeedback(
		"NoPenetration",
		hitPosition,
		"NO PEN",
		Color3.fromRGB(180, 220, 255)
	)

	destroyProjectile(projectile)
	return true
end

ProjectileCombatService.printBounce = printBounce
ProjectileCombatService.applyProjectileRicochet = applyProjectileRicochet

return ProjectileCombatService
