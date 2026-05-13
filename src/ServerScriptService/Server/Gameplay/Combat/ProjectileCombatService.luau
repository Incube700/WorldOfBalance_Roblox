local ProjectileCombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankConfig = require(configs:WaitForChild("TankConfig"))
local RicochetMath = require(shared:WaitForChild("Utils"):WaitForChild("RicochetMath"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))

local TANK_ARMOR = TankConfig.Armor
local PROJECTILE_RICOCHET_OFFSET = 0.45

local dependencies = {}

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

local function printArmorResult(prefix, targetName, armorHit, projectile)
	if not DEBUG_PROJECTILES then return end
	
	print(
		prefix
			.. " "
			.. targetName
			.. " zone="
			.. armorHit.Zone
			.. " angle="
			.. formatNumber(armorHit.HitAngleDegrees)
			.. " effectiveArmor="
			.. formatNumber(armorHit.EffectiveArmor)
			.. " penetration="
			.. formatNumber(projectile.Penetration)
			.. " damage="
			.. math.floor(armorHit.Damage)
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

local function resolveArmorHit(projectile, targetParticipant, hitNormal, armorZone)
	local tankBodyCFrame = targetParticipant.Model:GetPivot()

	if targetParticipant.Body ~= nil then
		tankBodyCFrame = targetParticipant.Body.CFrame
	end

	return RicochetMath.ResolveArmorHit({
		incomingDirection = projectile.Direction,
		hitNormal = hitNormal,
		tankBodyCFrame = tankBodyCFrame,
		armorZone = armorZone,
		projectilePenetration = projectile.Penetration,
		currentDamage = projectile.Damage,
		armorConfig = TANK_ARMOR,
		autoRicochetAngleDegrees = TANK_ARMOR.AutoRicochetAngleDegrees,
		safeMinCos = TANK_ARMOR.SafeMinCos,
	})
end

local function applyProjectileRicochet(projectile, hitPosition, hitNormal, options)
	options = options or {}
	projectile.Direction = reflect(projectile.Direction, hitNormal)
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
	local roundState = options.roundState
	local getParticipantIsDead = dependencies.getParticipantIsDead
	local createImpactFlash = dependencies.createImpactFlash
	local createRicochetVfx = dependencies.createRicochetVfx
	local destroyProjectile = dependencies.destroyProjectile
	local sendCombatFeedback = dependencies.sendCombatFeedback
	local damageParticipant = dependencies.damageParticipant
	local canDamageParticipant = dependencies.canDamageParticipant

	createImpactFlash(hitPosition)

	if roundState.Ended or getParticipantIsDead(targetParticipant) then
		destroyProjectile(projectile)
		return true
	end

	local canDamageTarget = projectile.NoDamage ~= true
		and (canDamageParticipant == nil or canDamageParticipant(projectile, targetParticipant) == true)

	if not canDamageTarget then
		if projectile.BounceCount >= projectile.MaxBounces then
			destroyProjectile(projectile)
			return true
		end

		applyProjectileRicochet(projectile, hitPosition, hitNormal, { NoStats = true })
		printBounce(projectile)
		return false
	end

	if projectile.NoStats ~= true then
		MatchStatsService.recordProjectileTankHitStats(projectile)
	end

	local armorHit = resolveArmorHit(projectile, targetParticipant, hitNormal, armorZone)

	if armorHit.Result == "Penetrated" then
		printArmorResult("[PEN]", targetParticipant.TankId, armorHit, projectile)

		local damageText = "-" .. math.floor(armorHit.Damage)

		if targetParticipant == projectile.OwnerParticipant and projectile.OwnerPlayer ~= nil then
			if DEBUG_PROJECTILES then
				print("[SELF-HIT] " .. targetParticipant.TankId .. " hit by own ricochet")
			end
			damageText = "SELF HIT " .. damageText
		end

		sendCombatFeedback(
			"Damage",
			hitPosition,
			damageText,
			Color3.fromRGB(255, 105, 75)
		)

		if damageParticipant(targetParticipant, armorHit.Damage) and projectile.NoStats ~= true then
			MatchStatsService.recordProjectileDamageStats(projectile, targetParticipant, armorHit.Damage)
		end

		destroyProjectile(projectile)
		return true
	end

	if armorHit.Result == "Ricochet" then
		printArmorResult("[ARMOR-RICOCHET]", targetParticipant.TankId, armorHit, projectile)

		if createRicochetVfx ~= nil then
			createRicochetVfx(hitPosition, hitNormal)
		end

		sendCombatFeedback(
			"ArmorRicochet",
			hitPosition,
			"RICOCHET",
			Color3.fromRGB(255, 220, 70)
		)
	else
		printArmorResult("[NO-PEN]", targetParticipant.TankId, armorHit, projectile)

		sendCombatFeedback(
			"NoPenetration",
			hitPosition,
			"NO PEN",
			Color3.fromRGB(180, 220, 255)
		)
	end

	if projectile.BounceCount >= projectile.MaxBounces then
		destroyProjectile(projectile)
		return true
	end

	applyProjectileRicochet(projectile, hitPosition, hitNormal)
	printBounce(projectile)

	return false
end

ProjectileCombatService.printBounce = printBounce
ProjectileCombatService.applyProjectileRicochet = applyProjectileRicochet

return ProjectileCombatService
