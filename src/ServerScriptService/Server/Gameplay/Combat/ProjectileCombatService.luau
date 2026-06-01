local ProjectileCombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local DebugCombatConfig = require(configs:WaitForChild("DebugCombatConfig"))
local TankArmorConfig = require(configs:WaitForChild("TankArmorConfig"))
local ArmorHitResolver = require(script.Parent:WaitForChild("ArmorHitResolver"))
local ProjectileHitResult = require(script.Parent.Parent:WaitForChild("Projectiles"):WaitForChild("ProjectileHitResult"))
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

local function getFeedbackConfig()
	return TankArmorConfig.Feedback or {}
end

local function getFeedbackOptions()
	local feedbackConfig = getFeedbackConfig()

	return {
		Lifetime = tonumber(feedbackConfig.Lifetime) or 0.6,
		RiseDistance = tonumber(feedbackConfig.RiseDistance) or 2.1,
	}
end

local function getParticipantModel(participant)
	if participant == nil then
		return nil
	end

	return participant.PhysicalModel or participant.Model
end

local function getParticipantPosition(participant)
	local model = getParticipantModel(participant)

	if model == nil then
		return nil
	end

	local body = model:FindFirstChild("Body", true)
		or model:FindFirstChild("Hull", true)
		or model.PrimaryPart

	if body ~= nil and body:IsA("BasePart") then
		return body.Position
	end

	local success, pivot = pcall(function()
		return model:GetPivot()
	end)

	if success then
		return pivot.Position
	end

	return nil
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

local function getShieldReflectDirection(projectile, targetParticipant, hitPosition, hitNormal)
	local ownerPosition = getParticipantPosition(projectile.OwnerParticipant)

	if projectile.OwnerParticipant ~= targetParticipant
		and typeof(ownerPosition) == "Vector3"
		and typeof(hitPosition) == "Vector3"
	then
		local toOwner = ownerPosition - hitPosition
		local flatToOwner = Vector3.new(toOwner.X, 0, toOwner.Z)

		if flatToOwner.Magnitude >= 0.001 then
			return flatToOwner.Unit
		end
	end

	if typeof(projectile.Direction) == "Vector3" and projectile.Direction.Magnitude >= 0.001 then
		return (-projectile.Direction).Unit
	end

	if typeof(hitNormal) == "Vector3" and hitNormal.Magnitude >= 0.001 then
		return hitNormal.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function applyShieldProjectileReflect(projectile, targetParticipant, hitPosition, hitNormal)
	local nextDirection = getShieldReflectDirection(projectile, targetParticipant, hitPosition, hitNormal)
	local reflectCount = (tonumber(projectile.ShieldReflectCount) or 0) + 1
	local reflectedAt = os.clock()

	projectile.Direction = nextDirection
	projectile.Position = hitPosition + nextDirection * PROJECTILE_RICOCHET_OFFSET
	projectile.PreviousPosition = projectile.Position
	projectile.NextPosition = projectile.Position
	projectile.CanHitOwner = true
	projectile.ShieldReflectCount = reflectCount
	projectile.LastReflectedByTankId = targetParticipant ~= nil and targetParticipant.TankId or nil
	projectile.LastShieldReflectAt = reflectedAt

	if projectile.Part ~= nil then
		projectile.Part.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + projectile.Direction, Vector3.yAxis)
		projectile.Part:SetAttribute("ShieldReflectCount", reflectCount)
		projectile.Part:SetAttribute("LastReflectedByTankId", projectile.LastReflectedByTankId)
		projectile.Part:SetAttribute("LastShieldReflectAt", reflectedAt)
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
	local tryConsumeReflectShield = dependencies.tryConsumeReflectShield
	local createShieldReflectVfx = dependencies.createShieldReflectVfx

	if roundState.Ended or getParticipantIsDead(targetParticipant) then
		destroyProjectile(projectile)
		return true
	end

	-- Phase Shot (PierceEnemies, Update 0.2): apply flat damage but keep flying so
	-- the shell passes through the enemy. A short per-tank cooldown stops a single
	-- shot from multi-hitting the same tank while it is inside the hitbox. After
	-- the configured pierce limit is exhausted (PierceEnemyLimit), the shell
	-- destroys on the next enemy hit instead of passing through. This branch is
	-- fully skipped for the default cannon (PierceEnemies is nil/false), so default
	-- ricochet behavior is unchanged.
	if projectile.PierceEnemies == true and projectile.NoDamage ~= true then
		local canPierceDamage = canDamageParticipant == nil
			or canDamageParticipant(projectile, targetParticipant) == true

		if canPierceDamage and damageParticipant ~= nil then
			local now = os.clock()
			local tankId = targetParticipant.TankId
			projectile.PierceHitTimes = projectile.PierceHitTimes or {}

			if (projectile.PierceHitTimes[tankId] or 0) <= now then
				projectile.PierceHitTimes[tankId] = now + (projectile.PierceHitCooldownSeconds or 0.3)
				projectile.LastHitResult = ProjectileHitResult.TankPenetration

				if projectile.NoStats ~= true then
					MatchStatsService.recordProjectileTankHitStats(projectile)
				end

				-- Armor matters for pierce too (anti-cheese): the shell does NOT deal flat full
				-- damage through the front plate. Run the same armor resolver as normal hits, so
				-- thick/angled armor cuts the pierce damage (or blocks it as a NoPen graze).
				local pierceArmorHit = ArmorHitResolver.ResolveHit({
					TankModel = getParticipantModel(targetParticipant),
					BodyPart = targetParticipant.Body,
					HitPosition = hitPosition,
					ProjectileDirection = projectile.Direction,
					BaseDamage = projectile.Damage,
					PenetrationPower = projectile.PenetrationPower or projectile.Penetration,
					ArmorZoneHint = armorZone,
					-- Piercing ADDS to penetration power (so it crosses the armor threshold,
					-- e.g. can pen the front plate), but armor still subtracts from damage.
					PenetrationBonus = projectile.PenetrationBonus or 0,
					MinDamageFloor = projectile.PierceDamageFloor or 0,
				})
				local pierceDamage = math.max(0, tonumber(pierceArmorHit.FinalDamage) or 0)

				if createDamageHitVfx ~= nil then
					createDamageHitVfx(hitPosition, pierceArmorHit.NormalWorld or hitNormal)
				end

				sendCombatFeedback(
					"Damage",
					hitPosition,
					"-" .. math.floor(pierceDamage),
					getFeedbackConfig().DamageColor or Color3.fromRGB(255, 105, 75),
					getFeedbackOptions()
				)

				if pierceDamage > 0
					and damageParticipant(targetParticipant, pierceDamage, projectile)
					and projectile.NoStats ~= true
				then
					MatchStatsService.recordProjectileDamageStats(projectile, targetParticipant, pierceDamage)
				end

				-- Pierce-limit: each NEW enemy (cooldown gate passed) consumes one
				-- pierce. When exhausted, destroy on this hit instead of passing
				-- through.
				if projectile.PierceEnemyLeft ~= nil then
					projectile.PierceEnemyLeft -= 1

					if projectile.PierceEnemyLeft <= 0 then
						destroyProjectile(projectile)
						return true
					end
				end
			end
		end

		return false -- keep flying through the enemy
	end

	local canDamageTarget = projectile.NoDamage ~= true
		and (canDamageParticipant == nil or canDamageParticipant(projectile, targetParticipant) == true)

	if not canDamageTarget then
		if projectile.BounceCount >= projectile.MaxBounces then
			projectile.LastHitResult = ProjectileHitResult.TankNoPen
			if createNoPenVfx ~= nil then
				createNoPenVfx(hitPosition, hitNormal)
			end
			destroyProjectile(projectile)
			return true
		end

		if createRicochetVfx ~= nil then
			createRicochetVfx(hitPosition, hitNormal)
		end
		projectile.LastHitResult = ProjectileHitResult.TankRicochet
		applyProjectileRicochet(projectile, hitPosition, hitNormal, { NoStats = true })
		printBounce(projectile)
		return false
	end

	local reflectedByShield = false
	local shieldFeedback = nil

	if tryConsumeReflectShield ~= nil then
		reflectedByShield, shieldFeedback = tryConsumeReflectShield(projectile, targetParticipant)
	end

	if reflectedByShield then
		projectile.LastHitResult = ProjectileHitResult.ShieldReflect
		applyShieldProjectileReflect(projectile, targetParticipant, hitPosition, hitNormal)

		if createShieldReflectVfx ~= nil then
			createShieldReflectVfx(hitPosition, hitNormal)
		elseif createRicochetVfx ~= nil then
			createRicochetVfx(hitPosition, hitNormal)
		end

		shieldFeedback = shieldFeedback or {}
		sendCombatFeedback(
			"ShieldReflect",
			hitPosition,
			shieldFeedback.Text or "REFLECT",
			shieldFeedback.Color or Color3.fromRGB(116, 210, 255),
			{
				Lifetime = tonumber(shieldFeedback.Lifetime) or 0.6,
				RiseDistance = tonumber(shieldFeedback.RiseDistance) or 2.2,
			}
		)

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
		PenetrationBonus = projectile.PenetrationBonus or 0,
		MinDamageFloor = projectile.PierceDamageFloor or 0,
		ArmorZoneHint = armorZone,
	})
	local armorNormal = armorHit.NormalWorld or hitNormal

	if armorHit.Result == "Penetration" then
		projectile.LastHitResult = ProjectileHitResult.TankPenetration
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
			getFeedbackConfig().DamageColor or Color3.fromRGB(255, 105, 75),
			getFeedbackOptions()
		)

		if damageParticipant(targetParticipant, armorHit.FinalDamage, projectile) and projectile.NoStats ~= true then
			MatchStatsService.recordProjectileDamageStats(projectile, targetParticipant, armorHit.FinalDamage)
		end

		destroyProjectile(projectile)
		return true
	end

	if armorHit.Result == "Ricochet" then
		projectile.LastHitResult = ProjectileHitResult.TankRicochet
		printArmorResult("[ARMOR-RICOCHET]", targetParticipant.TankId, armorHit, projectile)

		if createRicochetVfx ~= nil then
			createRicochetVfx(hitPosition, armorNormal)
		end

		sendCombatFeedback(
			"ArmorRicochet",
			hitPosition,
			getFeedbackConfig().RicochetText or "RICOCHET",
			getFeedbackConfig().RicochetColor or Color3.fromRGB(255, 220, 70),
			getFeedbackOptions()
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
	projectile.LastHitResult = ProjectileHitResult.TankNoPen

	if createNoPenVfx ~= nil then
		createNoPenVfx(hitPosition, armorNormal)
	end

	sendCombatFeedback(
		"NoPenetration",
		hitPosition,
		getFeedbackConfig().NoPenText or "NO PEN",
		getFeedbackConfig().NoPenColor or Color3.fromRGB(180, 220, 255),
		getFeedbackOptions()
	)

	destroyProjectile(projectile)
	return true
end

ProjectileCombatService.printBounce = printBounce
ProjectileCombatService.applyProjectileRicochet = applyProjectileRicochet

return ProjectileCombatService
