local BotTargeting = {}

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

local function getParticipantModel(tankParticipantRegistry, participant)
	if participant == nil then
		return nil
	end

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantPhysicalModel ~= nil then
		return tankParticipantRegistry.getParticipantPhysicalModel(participant)
	end

	return participant.PhysicalModel or participant.Model
end

function BotTargeting.GetParticipantBody(tankParticipantRegistry, participant)
	if participant == nil then
		return nil
	end

	if participant.Body ~= nil and participant.Body.Parent ~= nil then
		return participant.Body
	end

	local model = getParticipantModel(tankParticipantRegistry, participant)
	local body = findBasePart(model, "Body") or findBasePart(model, "Hull")

	if body ~= nil then
		participant.Body = body
	end

	return body
end

function BotTargeting.GetParticipantPosition(tankParticipantRegistry, participant)
	if participant == nil then
		return nil
	end

	local controlState = participant.ControlState

	if controlState ~= nil and typeof(controlState.Position) == "Vector3" then
		return controlState.Position
	end

	local body = BotTargeting.GetParticipantBody(tankParticipantRegistry, participant)

	if body ~= nil then
		local position = body.Position
		return Vector3.new(position.X, 0, position.Z)
	end

	local model = getParticipantModel(tankParticipantRegistry, participant)

	if model ~= nil and model.PrimaryPart ~= nil then
		local position = model.PrimaryPart.Position
		return Vector3.new(position.X, 0, position.Z)
	end

	return nil
end

local function isAliveArenaTarget(tankParticipantRegistry, participant)
	if participant == nil or participant.IsActive == false then
		return false
	end

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantIsDead ~= nil then
		return tankParticipantRegistry.getParticipantIsDead(participant) ~= true
	end

	return participant.IsDead ~= true
end

local function isPlayerTarget(participant)
	return participant ~= nil and participant.OwnerPlayer ~= nil and participant.IsBot ~= true
end

local function canTarget(botParticipant, candidate, allowBotTargets)
	if candidate == nil or candidate == botParticipant then
		return false
	end

	if candidate.TeamId ~= nil and botParticipant.TeamId ~= nil and candidate.TeamId == botParticipant.TeamId then
		return false
	end

	if isPlayerTarget(candidate) then
		return true
	end

	return allowBotTargets == true and candidate.IsBot == true
end

function BotTargeting.FindClosestTarget(botParticipant, candidates, tankParticipantRegistry, options)
	options = options or {}
	local botPosition = BotTargeting.GetParticipantPosition(tankParticipantRegistry, botParticipant)

	if botPosition == nil then
		return nil, nil
	end

	local maxDistance = math.max(0, tonumber(options.SearchRadius) or 0)
	local maxDistanceSquared = maxDistance > 0 and maxDistance * maxDistance or math.huge
	local allowBotTargets = options.AllowBotTargets == true
	local bestTarget = nil
	local bestDistanceSquared = math.huge

	local function scan(allowNonPlayerBots)
		for _, candidate in ipairs(candidates or {}) do
			if canTarget(botParticipant, candidate, allowNonPlayerBots)
				and isAliveArenaTarget(tankParticipantRegistry, candidate)
			then
				local targetPosition = BotTargeting.GetParticipantPosition(tankParticipantRegistry, candidate)

				if targetPosition ~= nil then
					local delta = targetPosition - botPosition
					local distanceSquared = delta.X * delta.X + delta.Z * delta.Z

					if distanceSquared <= maxDistanceSquared and distanceSquared < bestDistanceSquared then
						bestTarget = candidate
						bestDistanceSquared = distanceSquared
					end
				end
			end
		end
	end

	scan(false)

	if bestTarget == nil and allowBotTargets then
		scan(true)
	end

	if bestTarget == nil then
		return nil, nil
	end

	return bestTarget, math.sqrt(bestDistanceSquared)
end

return BotTargeting
