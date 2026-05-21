local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local BotConfig = require(configs:WaitForChild("BotConfig"))
local TankConfig = require(configs:WaitForChild("TankConfig"))

local BotBrain = require(script.Parent:WaitForChild("BotBrain"))
local BotTargeting = require(script.Parent:WaitForChild("BotTargeting"))

local BotController = {}
BotController.__index = BotController

local MOVE_SPEED = TankConfig.Movement.MoveSpeed
local REVERSE_MOVE_SPEED_MULTIPLIER = TankConfig.Movement.ReverseMoveSpeedMultiplier or 1
local BODY_TURN_SPEED = TankConfig.Movement.BodyTurnSpeedRadians
local turretConfig = TankConfig.Turret or {}
local TURRET_TURN_SPEED = turretConfig.TurnSpeedRadiansPerSecond
	or math.rad(turretConfig.TurnSpeedDegreesPerSecond or TankConfig.Movement.TurretTurnSpeedDegrees or 240)

local function normalizeAngle(angle)
	local fullTurn = math.pi * 2
	return ((angle + math.pi) % fullTurn) - math.pi
end

local function moveAngleTowards(currentAngle, targetAngle, maxDelta)
	local delta = normalizeAngle(targetAngle - currentAngle)

	if math.abs(delta) <= maxDelta then
		return targetAngle
	end

	local direction = delta >= 0 and 1 or -1
	return currentAngle + direction * maxDelta
end

local function getYawFromFlatDirection(direction, fallbackYaw)
	if typeof(direction) ~= "Vector3" then
		return fallbackYaw or 0
	end

	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.001 then
		return fallbackYaw or 0
	end

	local unit = flat.Unit
	return math.atan2(-unit.X, -unit.Z)
end

local function getDirectionFromYaw(yaw)
	local look = CFrame.Angles(0, yaw, 0).LookVector
	local flat = Vector3.new(look.X, 0, look.Z)

	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function getYawFromAimPosition(position, aimPosition, fallbackYaw)
	if typeof(position) ~= "Vector3" or typeof(aimPosition) ~= "Vector3" then
		return fallbackYaw or 0
	end

	local delta = Vector3.new(aimPosition.X - position.X, 0, aimPosition.Z - position.Z)

	if delta.Magnitude < 0.001 then
		return fallbackYaw or 0
	end

	return getYawFromFlatDirection(delta, fallbackYaw)
end

local function isDead(tankParticipantRegistry, participant)
	if participant == nil then
		return true
	end

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantIsDead ~= nil then
		return tankParticipantRegistry.getParticipantIsDead(participant)
	end

	return participant.IsDead == true
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

function BotController.new(options)
	options = options or {}

	return setmetatable({
		Participant = options.Participant,
		TankParticipantRegistry = options.TankParticipantRegistry,
		TankMovementService = options.TankMovementService,
		TankSpawnResetService = options.TankSpawnResetService,
		ProjectileService = options.ProjectileService,
		GetArenaParticipants = options.GetArenaParticipants,
		GetControlZonePosition = options.GetControlZonePosition,
		Random = Random.new(options.Seed or math.floor(os.clock() * 1000000)),
		BrainState = {},
		ThinkElapsed = 0,
		Decision = nil,
		LastDebugTargetLogAt = 0,
	}, BotController)
end

function BotController:IsAlive()
	return self.Participant ~= nil
		and self.Participant.IsActive ~= false
		and not isDead(self.TankParticipantRegistry, self.Participant)
end

function BotController:_getTarget()
	local battleArenaConfig = BotConfig.BattleArena or {}
	local brainConfig = BotConfig.Brain or {}
	local participants = self.GetArenaParticipants ~= nil and self.GetArenaParticipants() or {}

	return BotTargeting.FindClosestTarget(self.Participant, participants, self.TankParticipantRegistry, {
		SearchRadius = brainConfig.SearchRadius,
		AllowBotTargets = battleArenaConfig.TargetBotsWhenNoPlayers == true,
	})
end

function BotController:_refreshDecision(deltaTime)
	local brainConfig = BotConfig.Brain or {}
	self.ThinkElapsed += deltaTime

	if self.ThinkElapsed < math.max(0.05, tonumber(brainConfig.TickRate) or 0.15) and self.Decision ~= nil then
		return self.Decision
	end

	self.ThinkElapsed = 0

	local participant = self.Participant
	local state = participant.ControlState
	local botPosition = state ~= nil and state.Position or BotTargeting.GetParticipantPosition(self.TankParticipantRegistry, participant)
	local target = self:_getTarget()
	local targetPosition = BotTargeting.GetParticipantPosition(self.TankParticipantRegistry, target)

	if target == nil and self.GetControlZonePosition ~= nil then
		targetPosition = self.GetControlZonePosition()
	end

	self.Decision = BotBrain.Decide({
		BrainConfig = brainConfig,
		BotPosition = botPosition,
		TargetPosition = targetPosition,
		TargetParticipant = target,
		BodyYaw = state ~= nil and state.BodyYaw or 0,
		BrainState = self.BrainState,
		Random = self.Random,
		Now = os.clock(),
	})

	if BotConfig.Debug == true and target ~= nil then
		local now = os.clock()

		if now - self.LastDebugTargetLogAt >= 1.5 then
			self.LastDebugTargetLogAt = now
			print("[BOT] target=" .. tostring(target.TankId) .. " bot=" .. tostring(participant.TankId))
		end
	end

	return self.Decision
end

function BotController:_applyMovement(deltaTime, decision)
	local participant = self.Participant
	local state = participant.ControlState

	if state == nil or typeof(state.Position) ~= "Vector3" then
		return false
	end

	local currentBodyYaw = state.BodyYaw or 0
	local desiredBodyYaw = getYawFromFlatDirection(decision.MoveDirection, currentBodyYaw)
	local resolvedBodyYaw = moveAngleTowards(currentBodyYaw, desiredBodyYaw, BODY_TURN_SPEED * deltaTime)
	local throttle = math.clamp(tonumber(decision.Throttle) or 0, -1, 1)
	local moveSpeed = MOVE_SPEED * (throttle < 0 and REVERSE_MOVE_SPEED_MULTIPLIER or 1)
	local desiredMove = getDirectionFromYaw(resolvedBodyYaw) * throttle * moveSpeed * deltaTime
	local resolvedPosition = state.Position

	if self.TankMovementService ~= nil and self.TankMovementService.resolveTankPose ~= nil then
		resolvedPosition, resolvedBodyYaw = self.TankMovementService.resolveTankPose(
			state.Position,
			currentBodyYaw,
			desiredMove,
			resolvedBodyYaw,
			{ TankId = tostring(participant.TankId) .. ":Bot" }
		)
	end

	local currentTurretYaw = state.TurretYaw or resolvedBodyYaw
	local targetTurretYaw = getYawFromAimPosition(resolvedPosition, decision.AimWorldPoint, currentTurretYaw)

	state.Position = resolvedPosition
	state.BodyYaw = resolvedBodyYaw
	state.TurretYaw = moveAngleTowards(currentTurretYaw, targetTurretYaw, TURRET_TURN_SPEED * deltaTime)

	local model = getParticipantModel(self.TankParticipantRegistry, participant)

	if model ~= nil and self.TankSpawnResetService ~= nil then
		self.TankSpawnResetService.layoutTank(model, state.Position, state.BodyYaw, state.TurretYaw)
	end

	return true
end

function BotController:_maybeShoot(decision)
	if decision.WantsShoot ~= true or self.ProjectileService == nil then
		return false
	end

	local participant = self.Participant
	local state = participant.ControlState

	if state == nil or typeof(state.Position) ~= "Vector3" or typeof(decision.AimWorldPoint) ~= "Vector3" then
		return false
	end

	local shootPoint = participant.ShootPoint

	if shootPoint == nil or shootPoint.Parent == nil then
		return false
	end

	local toTarget = Vector3.new(
		decision.AimWorldPoint.X - shootPoint.Position.X,
		0,
		decision.AimWorldPoint.Z - shootPoint.Position.Z
	)

	if toTarget.Magnitude < 0.001 then
		return false
	end

	local turretDirection = getDirectionFromYaw(state.TurretYaw or state.BodyYaw or 0)
	local minDot = math.cos(math.rad((BotConfig.Brain or {}).AimToleranceDegrees or 10))

	if turretDirection:Dot(toTarget.Unit) < minDot then
		return false
	end

	local fired = self.ProjectileService.tryShoot(participant, turretDirection)

	if BotConfig.Debug == true and fired then
		print("[BOT] shoot bot=" .. tostring(participant.TankId))
	end

	return fired
end

function BotController:Update(deltaTime)
	if not self:IsAlive() then
		return false
	end

	local decision = self:_refreshDecision(deltaTime)

	if decision == nil then
		return false
	end

	self:_applyMovement(deltaTime, decision)
	self:_maybeShoot(decision)

	return true
end

function BotController:Destroy()
	self.Participant = nil
	self.Decision = nil
	self.GetArenaParticipants = nil
end

return BotController
