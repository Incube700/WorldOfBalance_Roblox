local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankArmorConfig = require(configs:WaitForChild("TankArmorConfig"))
local RicochetMath = require(shared:WaitForChild("Utils"):WaitForChild("RicochetMath"))

local ArmorHitResolver = {}

local EPSILON = 0.00001
local DEFAULT_NORMAL = Vector3.new(0, 0, -1)
local ZONE_FRONT = "Front"
local ZONE_SIDE = "Side"
local ZONE_REAR = "Rear"
local ZONE_CORNER = "Corner"

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeUnit(vector, fallback)
	if typeof(vector) == "Vector3" then
		local flat = flatten(vector)

		if flat.Magnitude > EPSILON then
			return flat.Unit
		end
	end

	if typeof(fallback) == "Vector3" then
		local flatFallback = flatten(fallback)

		if flatFallback.Magnitude > EPSILON then
			return flatFallback.Unit
		end
	end

	return DEFAULT_NORMAL
end

local function findBasePart(model, partName)
	if model == nil then
		return nil
	end

	local child = model:FindFirstChild(partName)

	if child ~= nil and child:IsA("BasePart") then
		return child
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

function ArmorHitResolver.GetStableBodyPart(tankModel, bodyPart)
	if bodyPart ~= nil and bodyPart:IsA("BasePart") and bodyPart.Parent ~= nil then
		return bodyPart
	end

	local body = findBasePart(tankModel, "Body")

	if body ~= nil then
		return body
	end

	local hull = findBasePart(tankModel, "Hull")

	if hull ~= nil then
		return hull
	end

	if tankModel ~= nil and tankModel.PrimaryPart ~= nil and tankModel.PrimaryPart:IsDescendantOf(tankModel) then
		return tankModel.PrimaryPart
	end

	return nil
end

local function getConfig(params)
	local armorConfig = params.ArmorConfig or TankArmorConfig.Default

	if armorConfig.Default ~= nil then
		armorConfig = armorConfig.Default
	end

	return armorConfig
end

local function getZoneConfig(armorConfig, zone)
	local zones = armorConfig.Zones or {}

	return zones[zone] or zones[ZONE_SIDE] or {
		Armor = 0,
		DamageMultiplier = 1,
		RicochetAngleDegrees = armorConfig.DefaultRicochetAngleDegrees or 60,
	}
end

local function getCornerThreshold(armorConfig)
	return math.clamp(tonumber(armorConfig.CornerThreshold) or 0.82, 0.5, 0.98)
end

local function shouldUpgradeToCorner(bodyPart, localHit, armorConfig)
	local size = bodyPart.Size
	local halfX = math.max(size.X * 0.5, EPSILON)
	local halfZ = math.max(size.Z * 0.5, EPSILON)
	local threshold = getCornerThreshold(armorConfig)

	return math.abs(localHit.X) / halfX >= threshold
		and math.abs(localHit.Z) / halfZ >= threshold
end

local function getZoneFromLocalHit(bodyPart, localHit, armorConfig)
	if shouldUpgradeToCorner(bodyPart, localHit, armorConfig) then
		return ZONE_CORNER
	end

	local size = bodyPart.Size
	local halfX = math.max(size.X * 0.5, EPSILON)
	local halfZ = math.max(size.Z * 0.5, EPSILON)
	local xRatio = math.abs(localHit.X) / halfX
	local zRatio = math.abs(localHit.Z) / halfZ

	if zRatio >= xRatio then
		if localHit.Z <= 0 then
			return ZONE_FRONT
		end

		return ZONE_REAR
	end

	return ZONE_SIDE
end

function ArmorHitResolver.DetectArmorZone(bodyPart, hitPosition, armorZoneHint, armorConfig)
	if bodyPart == nil then
		return armorZoneHint or ZONE_SIDE, Vector3.zero
	end

	local localHit = bodyPart.CFrame:PointToObjectSpace(hitPosition)

	if shouldUpgradeToCorner(bodyPart, localHit, armorConfig) then
		return ZONE_CORNER, localHit
	end

	if armorZoneHint == ZONE_FRONT or armorZoneHint == ZONE_SIDE or armorZoneHint == ZONE_REAR then
		return armorZoneHint, localHit
	end

	return getZoneFromLocalHit(bodyPart, localHit, armorConfig), localHit
end

function ArmorHitResolver.GetZoneNormal(bodyPart, zone, localHit)
	if bodyPart == nil then
		return DEFAULT_NORMAL
	end

	if zone == ZONE_FRONT then
		return bodyPart.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1))
	elseif zone == ZONE_REAR then
		return bodyPart.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
	elseif zone == ZONE_CORNER then
		local xSign = localHit.X >= 0 and 1 or -1
		local zSign = localHit.Z >= 0 and 1 or -1
		return bodyPart.CFrame:VectorToWorldSpace(Vector3.new(xSign, 0, zSign)).Unit
	end

	local xSign = 1

	if localHit ~= nil and localHit.X < 0 then
		xSign = -1
	end

	return bodyPart.CFrame:VectorToWorldSpace(Vector3.new(xSign, 0, 0))
end

function ArmorHitResolver.CalculateImpactAngle(projectileDirection, normal)
	local incoming = safeUnit(-projectileDirection, -normal)
	local surfaceNormal = safeUnit(normal, incoming)
	local dot = math.clamp(math.abs(incoming:Dot(surfaceNormal)), 0, 1)

	return math.deg(math.acos(dot))
end

function ArmorHitResolver.CalculateEffectiveArmor(baseArmor, impactAngleDegrees, minCos)
	local angleRadians = math.rad(math.clamp(impactAngleDegrees, 0, 89.9))
	local effectiveMinCos = math.max(0.01, tonumber(minCos) or 0.25)
	local cos = math.max(math.cos(angleRadians), effectiveMinCos)

	return baseArmor / cos
end

function ArmorHitResolver.ResolveHit(params)
	params = params or {}

	local armorConfig = getConfig(params)
	local bodyPart = ArmorHitResolver.GetStableBodyPart(params.TankModel, params.BodyPart)
	local zone, localHit = ArmorHitResolver.DetectArmorZone(
		bodyPart,
		params.HitPosition or (bodyPart ~= nil and bodyPart.Position or Vector3.zero),
		params.ArmorZoneHint,
		armorConfig
	)
	local zoneConfig = getZoneConfig(armorConfig, zone)
	local normal = safeUnit(ArmorHitResolver.GetZoneNormal(bodyPart, zone, localHit), DEFAULT_NORMAL)
	local projectileDirection = safeUnit(params.ProjectileDirection, -normal)
	local impactAngleDegrees = ArmorHitResolver.CalculateImpactAngle(projectileDirection, normal)
	local baseArmor = math.max(0, tonumber(zoneConfig.Armor) or 0)
	local effectiveArmor = ArmorHitResolver.CalculateEffectiveArmor(
		baseArmor,
		impactAngleDegrees,
		armorConfig.EffectiveArmorMinCos
	)
	-- Penetration power = shell's base pen + any bonus (Piercing upgrade / RailGun add to it,
	-- they do NOT ignore the gate -- a stronger shell simply crosses the threshold).
	-- PenetrationBonus may be negative (weak pellet weapons); clamp the SUM to >= 0.
	local penetrationPower = math.max(0,
		(tonumber(params.PenetrationPower) or TankArmorConfig.Projectile.DefaultPenetrationPower)
			+ (tonumber(params.PenetrationBonus) or 0))
	local ricochetAngle = tonumber(zoneConfig.RicochetAngleDegrees)
		or tonumber(armorConfig.DefaultRicochetAngleDegrees)
		or 60
	local baseDamage = math.max(0, tonumber(params.BaseDamage) or 0)
	local ricochetDirection = RicochetMath.Reflect(projectileDirection, normal)

	-- ARMOR MODEL (Сергей's design):
	--   1. Steep ANGLE  -> ricochet (shell skips off), 0 damage.
	--   2. PEN THRESHOLD -> penetrationPower must be >= effectiveArmor (armor/cos(angle)),
	--      otherwise NoPen, 0 damage. A glancing angle makes armor "thicker" via 1/cos.
	--   3. DAMAGE = (baseDamage - effectiveArmor), then scaled by how head-on the hit is
	--      (straighter angle = closer to full, glancing = less). Example: 100 dmg vs 80
	--      armor, dead-on -> ~20 damage. Pierce that just crossed the gate also gets cut.

	if impactAngleDegrees >= ricochetAngle then
		return {
			Result = "Ricochet",
			Zone = zone,
			ImpactAngleDegrees = impactAngleDegrees,
			EffectiveArmor = effectiveArmor,
			FinalDamage = 0,
			NormalWorld = normal,
			RicochetDirection = ricochetDirection,
		}
	end

	if penetrationPower < effectiveArmor then
		return {
			Result = "NoPen",
			Zone = zone,
			ImpactAngleDegrees = impactAngleDegrees,
			EffectiveArmor = effectiveArmor,
			FinalDamage = math.max(0, tonumber(armorConfig.NoPenDamage) or 0),
			NormalWorld = normal,
		}
	end

	-- Penetrated: subtract armor from damage, then scale by hit angle (head-on = full).
	-- MinDamageFloor lets a barely-penetrating shot (e.g. a pellet that only crossed the
	-- front plate thanks to a Piercing stack) still chip a small, ramping amount: 2, 4, ...
	local afterArmor = baseDamage - effectiveArmor
	local angleRad = math.rad(math.clamp(impactAngleDegrees, 0, 89))
	local angleFactor = math.clamp(math.cos(angleRad), 0.3, 1) -- 1 = dead-on, less when glancing
	local minFloor = math.max(tonumber(armorConfig.MinPenetrationDamage) or 1, tonumber(params.MinDamageFloor) or 0)
	local finalDamage = math.max(minFloor, afterArmor * angleFactor)

	return {
		Result = "Penetration",
		Zone = zone,
		ImpactAngleDegrees = impactAngleDegrees,
		EffectiveArmor = effectiveArmor,
		FinalDamage = finalDamage,
		NormalWorld = normal,
	}
end

return ArmorHitResolver
