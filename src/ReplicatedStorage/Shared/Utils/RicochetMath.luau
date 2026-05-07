local RicochetMath = {}

local EPSILON = 0.00001

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeUnit(vector, fallback)
	local flat = flatten(vector)

	if flat.Magnitude > EPSILON then
		return flat.Unit
	end

	if fallback ~= nil then
		local flatFallback = flatten(fallback)

		if flatFallback.Magnitude > EPSILON then
			return flatFallback.Unit
		end
	end

	return Vector3.new(0, 0, -1)
end

function RicochetMath.Reflect(direction, normal)
	local incoming = safeUnit(direction)
	local surfaceNormal = safeUnit(normal, -incoming)
	local reflected = incoming - 2 * incoming:Dot(surfaceNormal) * surfaceNormal
	local flatReflected = flatten(reflected)

	if flatReflected.Magnitude <= EPSILON then
		return safeUnit(-incoming)
	end

	return flatReflected.Unit
end

function RicochetMath.GetHitAngleDegrees(incomingDirection, hitNormal)
	local incoming = safeUnit(incomingDirection)
	local surfaceNormal = safeUnit(hitNormal, -incoming)
	local dot = math.clamp((-incoming):Dot(surfaceNormal), -1, 1)

	return math.deg(math.acos(dot))
end

function RicochetMath.CalculateEffectiveArmor(baseArmor, incomingDirection, hitNormal, safeMinCos)
	local incoming = safeUnit(incomingDirection)
	local surfaceNormal = safeUnit(hitNormal, -incoming)
	local minCos = safeMinCos or 0.15
	local dot = math.clamp((-incoming):Dot(surfaceNormal), -1, 1)
	local cos = math.max(dot, minCos)

	return baseArmor / cos
end

function RicochetMath.ClassifyArmorZone(tankBodyCFrame, hitNormal)
	local worldNormal = safeUnit(hitNormal)
	local localNormal = tankBodyCFrame:VectorToObjectSpace(worldNormal)
	local absX = math.abs(localNormal.X)
	local absZ = math.abs(localNormal.Z)

	-- Raycast gives the outward surface normal. By design, +Z local armor is Front,
	-- -Z local armor is Rear, and +/-X local armor is Side.
	if absZ >= absX then
		if localNormal.Z >= 0 then
			return "Front"
		end

		return "Rear"
	end

	return "Side"
end

function RicochetMath.GetBaseArmorForZone(zone, armorConfig)
	if zone == "Front" then
		return armorConfig.FrontArmor
	elseif zone == "Rear" then
		return armorConfig.RearArmor
	end

	return armorConfig.SideArmor
end

function RicochetMath.ResolveArmorHit(params)
	local armorConfig = params.armorConfig
	local safeMinCos = params.safeMinCos or armorConfig.SafeMinCos or 0.15
	local autoRicochetAngleDegrees = params.autoRicochetAngleDegrees
		or armorConfig.AutoRicochetAngleDegrees
		or 72
	local hitAngleDegrees = RicochetMath.GetHitAngleDegrees(params.incomingDirection, params.hitNormal)
	local zone = params.armorZone or RicochetMath.ClassifyArmorZone(params.tankBodyCFrame, params.hitNormal)
	local baseArmor = RicochetMath.GetBaseArmorForZone(zone, armorConfig)
	local effectiveArmor = RicochetMath.CalculateEffectiveArmor(
		baseArmor,
		params.incomingDirection,
		params.hitNormal,
		safeMinCos
	)

	if hitAngleDegrees >= autoRicochetAngleDegrees then
		return {
			Result = "Ricochet",
			Damage = 0,
			Zone = zone,
			HitAngleDegrees = hitAngleDegrees,
			EffectiveArmor = effectiveArmor,
		}
	end

	if params.projectilePenetration < effectiveArmor then
		return {
			Result = "NoPenetration",
			Damage = 0,
			Zone = zone,
			HitAngleDegrees = hitAngleDegrees,
			EffectiveArmor = effectiveArmor,
		}
	end

	return {
		Result = "Penetrated",
		Damage = params.currentDamage,
		Zone = zone,
		HitAngleDegrees = hitAngleDegrees,
		EffectiveArmor = effectiveArmor,
	}
end

return RicochetMath
