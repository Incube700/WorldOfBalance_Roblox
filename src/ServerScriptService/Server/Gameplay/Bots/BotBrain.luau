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

local function makeIdleDecision(botPosition, bodyYaw, brainState, brainConfig, rng, now)
	refreshJitter(brainState, brainConfig, rng, now)

	return {
		TargetParticipant = nil,
		MoveDirection = getDirectionFromYaw(brainState.WanderYaw or bodyYaw or 0),
		AimWorldPoint = botPosition + getDirectionFromYaw(bodyYaw or 0) * 40,
		Throttle = 0.18,
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
		return makeIdleDecision(botPosition, bodyYaw, brainState, brainConfig, rng, now)
	end

	refreshJitter(brainState, brainConfig, rng, now)

	local directionToTarget, distance = getFlatDirection(botPosition, targetPosition)

	if directionToTarget == nil then
		return makeIdleDecision(botPosition, bodyYaw, brainState, brainConfig, rng, now)
	end

	local preferredDistance = math.max(1, tonumber(brainConfig.PreferredDistance) or 45)
	local tooCloseDistance = math.max(0, tonumber(brainConfig.TooCloseDistance) or 18)
	local moveThrottle = math.clamp(tonumber(brainConfig.MoveThrottle) or 0.75, -1, 1)
	local reverseThrottle = math.clamp(tonumber(brainConfig.ReverseThrottle) or -0.55, -1, 1)
	local moveDirection = directionToTarget
	local throttle = moveThrottle

	if distance <= tooCloseDistance then
		if rng:NextNumber() <= (tonumber(brainConfig.ReverseChanceWhenTooClose) or 0.35) then
			throttle = reverseThrottle
			moveDirection = directionToTarget
		else
			local lateral = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
				* (brainState.StrafeDirection or 1)

			moveDirection = lateral.Magnitude > 0.001 and lateral.Unit or directionToTarget
			throttle = moveThrottle * 0.45
		end
	elseif distance < preferredDistance then
		local lateral = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
			* (brainState.StrafeDirection or 1)

		moveDirection = lateral.Magnitude > 0.001 and lateral.Unit or directionToTarget
		throttle = moveThrottle * 0.35
	elseif distance < preferredDistance + 12 then
		throttle = moveThrottle * 0.5
	end

	local wantsShoot = targetParticipant ~= nil
		and rng:NextNumber() <= (tonumber(brainConfig.FireChance) or 0.55)

	return {
		TargetParticipant = targetParticipant,
		MoveDirection = moveDirection,
		AimWorldPoint = targetPosition,
		Throttle = throttle,
		WantsShoot = wantsShoot,
		TargetDistance = distance,
	}
end

return BotBrain
