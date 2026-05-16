local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local BotConfig = require(configs:WaitForChild("BotConfig"))
local TankConfig = require(configs:WaitForChild("TankConfig"))

local TrainingBotService = {}

local MATCH_MODE_TRAINING = "Training"
local PARTICIPANT_STATE_IN_MATCH = "InMatch"

local MOVE_SPEED = TankConfig.Movement.MoveSpeed
local REVERSE_MOVE_SPEED_MULTIPLIER = TankConfig.Movement.ReverseMoveSpeedMultiplier or 1
local BODY_TURN_SPEED = BotConfig.BodyTurnSpeedRadians or TankConfig.Movement.BodyTurnSpeedRadians
local turretConfig = TankConfig.Turret or {}
local TURRET_TURN_SPEED = BotConfig.TurretTurnSpeedRadians
	or turretConfig.TurnSpeedRadiansPerSecond
	or math.rad(turretConfig.TurnSpeedDegreesPerSecond or TankConfig.Movement.TurretTurnSpeedDegrees or 240)

local roundMatchService = nil
local tankParticipantRegistry = nil
local tankSpawnResetService = nil
local tankMovementService = nil
local projectileService = nil
local dummyParticipant = nil

local rng = Random.new()
local initialized = false
local elapsedSinceThink = 0
local elapsedSinceFireCheck = 0
local strafeDirection = 1
local nextStrafeSwitchAt = 0
local aimErrorRadians = 0
local nextAimErrorSwitchAt = 0
local nextAllowedShotAt = 0
local lastWarnTimeByKey = {}
local botDecision = {
	DesiredMoveYaw = nil,
	DesiredAimYaw = nil,
	DesiredThrottle = 0,
	DirectionToTarget = nil,
	TargetDistance = nil,
	TargetParticipant = nil,
}

local lineOfSightRaycastParams = RaycastParams.new()
lineOfSightRaycastParams.FilterType = Enum.RaycastFilterType.Include
lineOfSightRaycastParams.IgnoreWater = true

local function randomRange(minValue, maxValue)
	return minValue + rng:NextNumber() * (maxValue - minValue)
end

local function warnThrottled(key, message)
	local now = os.clock()

	if now - (lastWarnTimeByKey[key] or 0) < 3 then
		return
	end

	lastWarnTimeByKey[key] = now
	warn(message)
end

local function normalizeAngle(angle)
	local fullTurn = math.pi * 2
	return ((angle + math.pi) % fullTurn) - math.pi
end

local function shortestAngleDelta(fromAngle, toAngle)
	return normalizeAngle(toAngle - fromAngle)
end

local function moveAngleTowards(currentAngle, targetAngle, maxDelta)
	local delta = shortestAngleDelta(currentAngle, targetAngle)

	if math.abs(delta) <= maxDelta then
		return targetAngle
	end

	local direction = delta >= 0 and 1 or -1
	return currentAngle + direction * maxDelta
end

local function getYawFromFlatDirection(direction, fallbackYaw)
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.001 then
		return fallbackYaw or 0
	end

	local unit = flat.Unit
	return math.atan2(-unit.X, -unit.Z)
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
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
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

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantPhysicalModel ~= nil then
		return tankParticipantRegistry.getParticipantPhysicalModel(participant)
	end

	return participant.PhysicalModel or participant.Model
end

local function getParticipantBody(participant)
	if participant == nil then
		return nil
	end

	if participant.Body ~= nil and participant.Body.Parent ~= nil then
		return participant.Body
	end

	local model = getParticipantModel(participant)
	local body = findBasePart(model, "Body")

	if body ~= nil then
		participant.Body = body
	end

	return body
end

local function getParticipantShootPoint(participant)
	if participant == nil then
		return nil
	end

	if participant.ShootPoint ~= nil and participant.ShootPoint.Parent ~= nil then
		return participant.ShootPoint
	end

	local model = getParticipantModel(participant)
	local shootPoint = findBasePart(model, "ShootPoint")

	if shootPoint ~= nil then
		participant.ShootPoint = shootPoint
	end

	return shootPoint
end

local function getParticipantPosition(participant)
	if participant == nil then
		return nil
	end

	local controlState = participant.ControlState

	if controlState ~= nil and typeof(controlState.Position) == "Vector3" then
		return controlState.Position
	end

	local body = getParticipantBody(participant)

	if body ~= nil then
		return Vector3.new(body.Position.X, 0, body.Position.Z)
	end

	local model = getParticipantModel(participant)

	if model ~= nil and model.PrimaryPart ~= nil then
		local position = model.PrimaryPart.Position
		return Vector3.new(position.X, 0, position.Z)
	end

	return nil
end

local function isParticipantDead(participant)
	if participant == nil then
		return true
	end

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantIsDead ~= nil then
		return tankParticipantRegistry.getParticipantIsDead(participant)
	end

	return participant.IsDead == true
end

local function isParticipantInList(participant, participants)
	for _, activeParticipant in ipairs(participants or {}) do
		if activeParticipant == participant then
			return true
		end
	end

	return false
end

local function getActiveTrainingTarget()
	if not initialized or BotConfig.Enabled ~= true then
		return nil
	end

	if roundMatchService == nil
		or tankParticipantRegistry == nil
		or tankSpawnResetService == nil
		or tankMovementService == nil
		or projectileService == nil
		or dummyParticipant == nil
	then
		return nil
	end

	local activeMatch = roundMatchService.getActiveMatch ~= nil and roundMatchService.getActiveMatch() or nil

	if activeMatch == nil or activeMatch.MatchMode ~= MATCH_MODE_TRAINING then
		return nil
	end

	if not isParticipantInList(dummyParticipant, activeMatch.Participants) then
		return nil
	end

	if dummyParticipant.ParticipantState ~= PARTICIPANT_STATE_IN_MATCH then
		return nil
	end

	local roundState = roundMatchService.getRoundState ~= nil and roundMatchService.getRoundState() or nil

	if roundState ~= nil and roundState.Ended == true then
		return nil
	end

	if isParticipantDead(dummyParticipant) then
		return nil
	end

	local target = roundMatchService.getOpponentForParticipant ~= nil
		and roundMatchService.getOpponentForParticipant(dummyParticipant)
		or nil

	if target == nil
		or target == dummyParticipant
		or not isParticipantInList(target, activeMatch.Participants)
		or target.ParticipantState ~= PARTICIPANT_STATE_IN_MATCH
		or isParticipantDead(target)
	then
		return nil
	end

	return target
end

local function refreshStrafeDirection(now)
	if now < nextStrafeSwitchAt then
		return
	end

	strafeDirection = rng:NextInteger(0, 1) == 0 and -1 or 1
	nextStrafeSwitchAt = now + randomRange(
		BotConfig.StrafeSwitchMinTime,
		BotConfig.StrafeSwitchMaxTime
	)
end

local function refreshAimError(now)
	if now < nextAimErrorSwitchAt then
		return
	end

	aimErrorRadians = math.rad(randomRange(-BotConfig.AimErrorDegrees, BotConfig.AimErrorDegrees))
	nextAimErrorSwitchAt = now + randomRange(0.55, 1.35)
end

local function getBotMoveDecision(distance, directionToTarget)
	local preferredDistance = BotConfig.PreferredDistance
	local minDistance = BotConfig.MinDistance
	local maxDistance = BotConfig.MaxDistance
	local moveThrottle = BotConfig.MoveThrottle
	local reverseThrottle = BotConfig.ReverseThrottle

	if distance > maxDistance or distance > preferredDistance + 8 then
		return directionToTarget, moveThrottle
	end

	if distance < minDistance or distance < preferredDistance - 10 then
		return directionToTarget, reverseThrottle
	end

	local lateral = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X) * strafeDirection

	if lateral.Magnitude < 0.001 then
		lateral = Vector3.new(1, 0, 0)
	end

	return lateral.Unit, moveThrottle * 0.55
end

local function hasLineOfSight(origin, targetPosition)
	if BotConfig.LineOfSightEnabled ~= true then
		return true
	end

	if tankMovementService == nil or tankMovementService.getTankMovementObstacleParts == nil then
		return true
	end

	local obstacleParts = tankMovementService.getTankMovementObstacleParts()

	if #obstacleParts == 0 then
		return true
	end

	lineOfSightRaycastParams.FilterDescendantsInstances = obstacleParts
	local result = Workspace:Raycast(origin, targetPosition - origin, lineOfSightRaycastParams)

	return result == nil
end

local function updateBotDecision(target)
	local state = dummyParticipant.ControlState

	if state == nil or typeof(state.Position) ~= "Vector3" then
		warnThrottled("missingControlState", "[BOT] DummyTank has no ControlState; bot decision skipped.")
		return false
	end

	local targetPosition = getParticipantPosition(target)

	if targetPosition == nil then
		warnThrottled("missingTargetPosition", "[BOT] Training target has no Body/ControlState position.")
		return false
	end

	local directionToTarget, distance = getFlatDirection(state.Position, targetPosition)

	if directionToTarget == nil then
		return false
	end

	local now = os.clock()
	refreshStrafeDirection(now)
	refreshAimError(now)

	local desiredMoveDirection, throttle = getBotMoveDecision(distance, directionToTarget)
	local currentBodyYaw = state.BodyYaw or 0

	botDecision.DesiredMoveYaw = getYawFromFlatDirection(desiredMoveDirection, currentBodyYaw)
	botDecision.DesiredAimYaw = getYawFromFlatDirection(directionToTarget, state.TurretYaw or currentBodyYaw) + aimErrorRadians
	botDecision.DesiredThrottle = throttle
	botDecision.DirectionToTarget = directionToTarget
	botDecision.TargetDistance = distance
	botDecision.TargetParticipant = target

	return true
end

local function applyBotMovement(deltaTime)
	local state = dummyParticipant.ControlState

	if state == nil or typeof(state.Position) ~= "Vector3" then
		warnThrottled("missingControlState", "[BOT] DummyTank has no ControlState; bot movement skipped.")
		return false
	end

	local desiredBodyYaw = botDecision.DesiredMoveYaw
	local desiredTurretYaw = botDecision.DesiredAimYaw

	if desiredBodyYaw == nil or desiredTurretYaw == nil then
		return false
	end

	local currentBodyYaw = state.BodyYaw or desiredBodyYaw
	local resolvedBodyYaw = moveAngleTowards(currentBodyYaw, desiredBodyYaw, BODY_TURN_SPEED * deltaTime)
	local throttle = botDecision.DesiredThrottle or 0

	local moveSpeed = MOVE_SPEED * (throttle < 0 and REVERSE_MOVE_SPEED_MULTIPLIER or 1)
	local desiredMove = getDirectionFromYaw(resolvedBodyYaw) * throttle * moveSpeed * deltaTime
	local resolvedPosition = state.Position

	if tankMovementService.resolveTankMovement ~= nil then
		resolvedPosition = tankMovementService.resolveTankMovement(state.Position, resolvedBodyYaw, desiredMove)
	elseif tankMovementService.resolveTankPose ~= nil then
		resolvedPosition, resolvedBodyYaw = tankMovementService.resolveTankPose(
			state.Position,
			currentBodyYaw,
			desiredMove,
			resolvedBodyYaw,
			{ TankId = dummyParticipant.TankId .. ":Bot" }
		)
	end

	local currentTurretYaw = state.TurretYaw or resolvedBodyYaw

	state.Position = resolvedPosition
	state.BodyYaw = resolvedBodyYaw
	state.TurretYaw = moveAngleTowards(currentTurretYaw, desiredTurretYaw, TURRET_TURN_SPEED * deltaTime)

	local model = getParticipantModel(dummyParticipant)

	if model == nil then
		warnThrottled("missingDummyModel", "[BOT] DummyTank has no model; bot layout skipped.")
		return false
	end

	tankSpawnResetService.layoutTank(model, state.Position, state.BodyYaw, state.TurretYaw)

	return true
end

local function maybeShoot(deltaTime, target, directionToTarget, distance)
	elapsedSinceFireCheck += deltaTime

	if elapsedSinceFireCheck < BotConfig.FireCheckInterval then
		return
	end

	elapsedSinceFireCheck = 0

	if directionToTarget == nil or distance == nil or distance > BotConfig.MaxDistance * 1.2 then
		return
	end

	local now = os.clock()

	if now < nextAllowedShotAt then
		return
	end

	local shootPoint = getParticipantShootPoint(dummyParticipant)

	if shootPoint == nil then
		warnThrottled("missingShootPoint", "[BOT] DummyTank has no ShootPoint; bot cannot shoot.")
		return
	end

	local targetBody = getParticipantBody(target)
	local targetPosition = targetBody ~= nil and targetBody.Position or getParticipantPosition(target)

	if targetPosition == nil then
		return
	end

	local origin = shootPoint.Position
	local targetDirection = Vector3.new(targetPosition.X - origin.X, 0, targetPosition.Z - origin.Z)

	if targetDirection.Magnitude < 0.001 then
		return
	end

	if not hasLineOfSight(origin, targetPosition) then
		nextAllowedShotAt = now + randomRange(0.2, 0.55)
		return
	end

	if rng:NextNumber() > BotConfig.FireChance then
		nextAllowedShotAt = now + randomRange(0.15, 0.45)
		return
	end

	local turretDirection = getDirectionFromYaw(dummyParticipant.ControlState.TurretYaw or 0)
	local targetUnit = targetDirection.Unit
	local minDot = math.cos(math.rad(18 + BotConfig.AimErrorDegrees))

	if turretDirection:Dot(targetUnit) < minDot then
		return
	end

	local fired = projectileService.tryShoot(dummyParticipant, turretDirection)

	if fired then
		nextAllowedShotAt = now + randomRange(0.35, 1.1)
	else
		nextAllowedShotAt = now + randomRange(0.1, 0.35)
	end
end

local function resetBotDecision()
	botDecision.DesiredMoveYaw = nil
	botDecision.DesiredAimYaw = nil
	botDecision.DesiredThrottle = 0
	botDecision.DirectionToTarget = nil
	botDecision.TargetDistance = nil
	botDecision.TargetParticipant = nil
end

function TrainingBotService.init(options)
	options = options or {}

	roundMatchService = options.roundMatchService
	tankParticipantRegistry = options.tankParticipantRegistry
	tankSpawnResetService = options.tankSpawnResetService
	tankMovementService = options.tankMovementService
	projectileService = options.projectileService
	dummyParticipant = options.dummyParticipant

	initialized = true
	elapsedSinceThink = 0
	elapsedSinceFireCheck = 0
	nextStrafeSwitchAt = 0
	nextAimErrorSwitchAt = 0
	nextAllowedShotAt = 0
	resetBotDecision()
end

function TrainingBotService.update(deltaTime)
	if BotConfig.Enabled ~= true then
		resetBotDecision()
		return
	end

	local target = getActiveTrainingTarget()

	if target == nil then
		resetBotDecision()
		return
	end

	elapsedSinceThink += deltaTime

	if elapsedSinceThink >= BotConfig.ThinkInterval or botDecision.TargetParticipant ~= target then
		elapsedSinceThink = 0
		updateBotDecision(target)
	end

	applyBotMovement(deltaTime)
	maybeShoot(deltaTime, target, botDecision.DirectionToTarget, botDecision.TargetDistance)
end

return TrainingBotService
