local BotBrain = {}

local DEFAULT_FORWARD = Vector3.new(0, 0, -1)

local function randomRange(rng, minValue, maxValue)
	return minValue + rng:NextNumber() * (maxValue - minValue)
end

local function getFlatDirection(fromPosition, toPosition)
	local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)

	if delta.Magnitude < 0.001 then
		return nil, 0
	end

	return delta.Unit, delta.Magnitude
end

local function getDirectionFromYaw(yaw)
	local look = CFrame.Angles(0, yaw, 0).LookVector
	local flat = Vector3.new(look.X, 0, look.Z)

	if flat.Magnitude < 0.001 then
		return DEFAULT_FORWARD
	end

	return flat.Unit
end

local function refreshJitter(brainState, brainConfig, rng, now)
	if brainState.NextMoveJitterAt ~= nil and now < brainState.NextMoveJitterAt then
		return
	end

	brainState.StrafeDirection = rng:NextInteger(0, 1) == 0 and -1 or 1
	brainState.WanderYaw = (brainState.WanderYaw or 0) + randomRange(rng, -0.9, 0.9)
	brainState.NextMoveJitterAt = now + math.max(0.2, tonumber(brainConfig.MoveJitterInterval) or 1.25)
end

local function refreshAimJitter(brainState, brainConfig, rng, now, distance)
	if brainState.NextAimJitterAt ~= nil and now < brainState.NextAimJitterAt then
		return
	end

	local jitterDegrees = math.max(0, tonumber(brainConfig.AimJitterDegrees) or 0)
	local jitterRadius = math.tan(math.rad(jitterDegrees)) * math.max(8, tonumber(distance) or 30)
	local angle = rng:NextNumber() * math.pi * 2
	local radius = jitterRadius * math.sqrt(rng:NextNumber())

	brainState.AimJitter = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	brainState.NextAimJitterAt = now + math.max(0.15, tonumber(brainConfig.ReactionDelay) or 0.25)
end

local function getTargetKey(targetParticipant)
	if targetParticipant == nil then
		return ""
	end

	return tostring(targetParticipant.TankId or targetParticipant)
end

local function updateTargetReaction(brainState, brainConfig, targetParticipant, now)
	local targetKey = getTargetKey(targetParticipant)

	if brainState.TargetKey ~= targetKey then
		brainState.TargetKey = targetKey
		brainState.TargetSeenAt = now
		brainState.NextFireCheckAt = now + math.max(0, tonumber(brainConfig.ReactionDelay) or 0)
	end
end

local function shouldShootNow(brainState, brainConfig, rng, now)
	local reactionDelay = math.max(0, tonumber(brainConfig.ReactionDelay) or 0)

	if now - (brainState.TargetSeenAt or now) < reactionDelay then
		return false
	end

	if brainState.NextFireCheckAt ~= nil and now < brainState.NextFireCheckAt then
		return false
	end

	local minCooldown = math.max(0.05, tonumber(brainConfig.FireCooldownMin) or tonumber(brainConfig.FireCheckInterval) or 0.3)
	local maxCooldown = math.max(minCooldown, tonumber(brainConfig.FireCooldownMax) or minCooldown)
	brainState.NextFireCheckAt = now + randomRange(rng, minCooldown, maxCooldown)

	return rng:NextNumber() <= (tonumber(brainConfig.FireChance) or 0.55)
end

local function makeIdleDecision(botPosition, bodyYaw, brainState, brainConfig, rng, now, centerPosition)
	refreshJitter(brainState, brainConfig, rng, now)

	-- With no target, head toward the arena CENTER (so bots don't idle alone in corners while
	-- the player drives around). Blend a little wander in so it's not a dead-straight line.
	local moveDir = getDirectionFromYaw(brainState.WanderYaw or bodyYaw or 0)
	if typeof(centerPosition) == "Vector3" then
		local toCenter, centerDist = getFlatDirection(botPosition, centerPosition)
		if toCenter ~= nil and centerDist > 8 then
			local blended = (toCenter * 0.8 + moveDir * 0.2)
			moveDir = blended.Magnitude > 0.001 and blended.Unit or toCenter
		end
	end

	return {
		TargetParticipant = nil,
		MoveDirection = moveDir,
		AimWorldPoint = botPosition + moveDir * 40,
		Throttle = 0.35,
		WantsShoot = false,
		TargetDistance = nil,
	}
end

function BotBrain.Decide(params)
	params = params or {}
	local brainConfig = params.BrainConfig or {}
	local botPosition = params.BotPosition
	local targetPosition = params.TargetPosition
	local targetParticipant = params.TargetParticipant
	local bodyYaw = params.BodyYaw or 0
	local brainState = params.BrainState or {}
	local rng = params.Random or Random.new()
	local now = params.Now or os.clock()

	if typeof(botPosition) ~= "Vector3" then
		return nil
	end

	if typeof(targetPosition) ~= "Vector3" then
		return makeIdleDecision(botPosition, bodyYaw, brainState, brainConfig, rng, now, params.CenterPosition)
	end

	refreshJitter(brainState, brainConfig, rng, now)
	updateTargetReaction(brainState, brainConfig, targetParticipant, now)

	local directionToTarget, distance = getFlatDirection(botPosition, targetPosition)

	if directionToTarget == nil then
		return makeIdleDecision(botPosition, bodyYaw, brainState, brainConfig, rng, now, params.CenterPosition)
	end

	local preferredDistance = math.max(1, tonumber(brainConfig.PreferredDistance) or 45)
	local tooCloseDistance = math.max(0, tonumber(brainConfig.TooCloseDistance) or 18)
	local moveThrottle = math.clamp(tonumber(brainConfig.MoveThrottle) or 0.75, -1, 1)
	local reverseThrottle = math.clamp(tonumber(brainConfig.ReverseThrottle) or -0.55, -1, 1)
	local moveDirection = directionToTarget
	local throttle = moveThrottle

	-- PRIORITY: detour to grab a nearby pickup (weapon/shield) when it's not far off the
	-- path to the enemy and the bot isn't being rushed. Set by the controller in params.
	local pickupPos = params.PickupPosition
	if typeof(pickupPos) == "Vector3" and distance > tooCloseDistance + 6 then
		local toPickup, pickupDist = getFlatDirection(botPosition, pickupPos)
		if toPickup ~= nil and pickupDist <= (tonumber(brainConfig.PickupSeekRadius) or 60) then
			moveDirection = toPickup
			throttle = moveThrottle
			-- still aim/shoot at the enemy while driving to the pickup (handled below)
			refreshAimJitter(brainState, brainConfig, rng, now, distance)
			local aimJ = brainState.AimJitter
			if typeof(aimJ) ~= "Vector3" then aimJ = Vector3.zero end
			return {
				TargetParticipant = targetParticipant,
				MoveDirection = moveDirection,
				AimWorldPoint = targetPosition + aimJ,
				Throttle = throttle,
				WantsShoot = targetParticipant ~= nil and shouldShootNow(brainState, brainConfig, rng, now),
				TargetDistance = distance,
			}
		end
	end

	-- PRIORITY: hide behind cover when low on HP (controller passes a cover point + low-HP).
	local coverPos = params.CoverPosition
	if params.WantsCover == true and typeof(coverPos) == "Vector3" then
		local toCover = getFlatDirection(botPosition, coverPos)
		if toCover ~= nil then
			refreshAimJitter(brainState, brainConfig, rng, now, distance)
			local aimJ = brainState.AimJitter
			if typeof(aimJ) ~= "Vector3" then aimJ = Vector3.zero end
			return {
				TargetParticipant = targetParticipant,
				MoveDirection = toCover,
				AimWorldPoint = targetPosition + aimJ,
				Throttle = moveThrottle,
				WantsShoot = false, -- focus on getting to cover
				TargetDistance = distance,
			}
		end
	end

	-- DISTANCE KEEPING: bots prefer to fight from RANGE. Back off if closer than preferred,
	-- hold ground near the sweet spot, and only close in if the enemy is very far.
	if distance <= tooCloseDistance then
		-- Too close: reverse away while still facing the enemy.
		throttle = reverseThrottle
		moveDirection = directionToTarget
	elseif distance < preferredDistance then
		-- Inside preferred range: back up a bit + strafe, so they keep their distance.
		local lateral = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
			* (brainState.StrafeDirection or 1)
		local backV = -directionToTarget * 0.6
		local mixed = (lateral.Unit * 0.6 + backV)
		moveDirection = mixed.Magnitude > 0.001 and mixed.Unit or -directionToTarget
		throttle = moveThrottle * 0.5
	elseif distance < preferredDistance + 18 then
		-- In the sweet spot: strafe to be a moving target (this is what lets shots clip
		-- their SIDE armor — intentional, so flank hits happen).
		local lateral = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
			* (brainState.StrafeDirection or 1)
		moveDirection = lateral.Magnitude > 0.001 and lateral.Unit or directionToTarget
		throttle = moveThrottle * 0.4
	else
		-- Far: close the gap toward preferred range.
		throttle = moveThrottle
	end

	refreshAimJitter(brainState, brainConfig, rng, now, distance)

	local aimJitter = brainState.AimJitter
	if typeof(aimJitter) ~= "Vector3" then
		aimJitter = Vector3.zero
	end

	-- TARGET LEADING: aim slightly ahead of where the target is moving, so long-range shots
	-- connect. Target velocity comes from the controller (params.TargetVelocity).
	local aimPoint = targetPosition + aimJitter
	local targetVel = params.TargetVelocity
	if typeof(targetVel) == "Vector3" and targetVel.Magnitude > 0.5 then
		local shellSpeed = math.max(60, tonumber(brainConfig.ShellSpeedEstimate) or 200)
		local lead = math.clamp(distance / shellSpeed, 0, 0.6)
		aimPoint = aimPoint + Vector3.new(targetVel.X, 0, targetVel.Z) * lead
	end

	local wantsShoot = targetParticipant ~= nil and shouldShootNow(brainState, brainConfig, rng, now)

	return {
		TargetParticipant = targetParticipant,
		MoveDirection = moveDirection,
		AimWorldPoint = aimPoint,
		Throttle = throttle,
		WantsShoot = wantsShoot,
		TargetDistance = distance,
	}
end

return BotBrain
