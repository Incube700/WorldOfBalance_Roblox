local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local function getEffectiveBrainConfig()
	local baseConfig = BotConfig.Brain or {}
	local profiles = BotConfig.DifficultyProfiles or {}
	local difficulty = BotConfig.Difficulty or "Easy"
	local profile = profiles[difficulty] or profiles.Easy or {}
	local merged = {}

	for key, value in pairs(baseConfig) do
		merged[key] = value
	end

	for key, value in pairs(profile) do
		merged[key] = value
	end

	return merged
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
		StuckElapsed = 0,
		LastResolvedPosition = nil,
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
	local brainConfig = getEffectiveBrainConfig()
	local participants = self.GetArenaParticipants ~= nil and self.GetArenaParticipants() or {}

	return BotTargeting.FindClosestTarget(self.Participant, participants, self.TankParticipantRegistry, {
		SearchRadius = brainConfig.SearchRadius,
		AllowBotTargets = battleArenaConfig.TargetBotsWhenNoPlayers == true,
	})
end

function BotController:_refreshDecision(deltaTime)
	local brainConfig = getEffectiveBrainConfig()
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

	local now = os.clock()

	-- TARGET VELOCITY (for aim leading): derive from how the target moved since last think.
	local targetVelocity = nil
	if typeof(targetPosition) == "Vector3" then
		if typeof(self.LastTargetPos) == "Vector3" and self.LastTargetAt ~= nil then
			local dt = math.max(0.01, now - self.LastTargetAt)
			targetVelocity = (targetPosition - self.LastTargetPos) / dt
		end
		self.LastTargetPos = targetPosition
		self.LastTargetAt = now
	end

	-- LOW HP -> wants cover. Cover point = behind the nearest obstacle from the enemy.
	local wantsCover, coverPosition = false, nil
	local hp = self.TankParticipantRegistry.getParticipantHealth ~= nil
		and self.TankParticipantRegistry.getParticipantHealth(participant) or nil
	local maxHp = self.TankParticipantRegistry.getParticipantMaxHealth ~= nil
		and self.TankParticipantRegistry.getParticipantMaxHealth(participant) or nil
	if hp ~= nil and maxHp ~= nil and maxHp > 0 and (hp / maxHp) <= 0.4 then
		wantsCover = true
		coverPosition = self:_findCoverPoint(botPosition, targetPosition)
	end

	-- NEAREST PICKUP to seek (weapon/shield/repair markers in the runtime arena).
	local pickupPosition = self:_findNearestPickup(botPosition)

	self.Decision = BotBrain.Decide({
		BrainConfig = brainConfig,
		BotPosition = botPosition,
		TargetPosition = targetPosition,
		TargetParticipant = target,
		TargetVelocity = targetVelocity,
		PickupPosition = pickupPosition,
		WantsCover = wantsCover,
		CoverPosition = coverPosition,
		CenterPosition = self:_getArenaCenter(),
		BodyYaw = state ~= nil and state.BodyYaw or 0,
		BrainState = self.BrainState,
		Random = self.Random,
		Now = now,
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

-- Finds the nearest live pickup marker/model in the runtime arena, or nil. Looks in
-- WOB_Runtime/ArenaMode/ArenaPickups (live pickup models spawned by ArenaPickupService).
function BotController:_findNearestPickup(botPosition)
	if typeof(botPosition) ~= "Vector3" then
		return nil
	end
	local runtime = Workspace:FindFirstChild("WOB_Runtime")
	local arenaMode = runtime and runtime:FindFirstChild("ArenaMode")
	local pickups = arenaMode and arenaMode:FindFirstChild("ArenaPickups")
	if pickups == nil then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, model in ipairs(pickups:GetChildren()) do
		local part = model:IsA("BasePart") and model
			or (model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")))
		if part ~= nil then
			local d = (Vector3.new(part.Position.X, 0, part.Position.Z)
				- Vector3.new(botPosition.X, 0, botPosition.Z)).Magnitude
			if d < bestDist then
				bestDist = d
				best = part.Position
			end
		end
	end
	return best
end

-- Returns a point on the far side of the nearest obstacle from the enemy (simple cover): step
-- away from the threat. Good enough to break line of sight without full pathfinding.
function BotController:_findCoverPoint(botPosition, threatPosition)
	if typeof(botPosition) ~= "Vector3" or typeof(threatPosition) ~= "Vector3" then
		return nil
	end
	-- Move directly away from the threat by a fixed distance; the movement resolver handles
	-- walls, so the bot will tuck behind whatever obstacle is in that direction.
	local away = Vector3.new(botPosition.X - threatPosition.X, 0, botPosition.Z - threatPosition.Z)
	if away.Magnitude < 0.001 then
		return nil
	end
	return botPosition + away.Unit * 30
end

-- Arena center = the BattleArena floor centre (cached). Bots steer here when they have no
-- target, so they gather mid-arena instead of idling in corners.
function BotController:_getArenaCenter()
	if self.CachedArenaCenter ~= nil then
		return self.CachedArenaCenter
	end
	local generated = Workspace:FindFirstChild("WOB_Generated")
	local arena = generated and generated:FindFirstChild("BattleArena")
	local floor = arena and arena:FindFirstChild("Floor")
	if floor ~= nil and floor:IsA("BasePart") then
		self.CachedArenaCenter = Vector3.new(floor.Position.X, 0, floor.Position.Z)
		return self.CachedArenaCenter
	end
	return nil
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

	local movedDistance = self.LastResolvedPosition ~= nil and (resolvedPosition - self.LastResolvedPosition).Magnitude or math.huge
	local antiStuckSeconds = math.max(0, tonumber((BotConfig.Brain or {}).AntiStuckSeconds) or 0)
	local antiStuckDistance = math.max(0.01, tonumber((BotConfig.Brain or {}).AntiStuckDistance) or 0.35)

	if math.abs(throttle) > 0.1 and movedDistance < antiStuckDistance * deltaTime then
		self.StuckElapsed += deltaTime
	else
		self.StuckElapsed = 0
	end

	if antiStuckSeconds > 0 and self.StuckElapsed >= antiStuckSeconds then
		-- Stuck (likely a corner): point the wander toward the arena centre and reverse a
		-- moment so the next think drives back out instead of grinding the wall.
		local center = self:_getArenaCenter()
		if typeof(center) == "Vector3" then
			local toCenter = Vector3.new(center.X - resolvedPosition.X, 0, center.Z - resolvedPosition.Z)
			if toCenter.Magnitude > 0.001 then
				self.BrainState.WanderYaw = getYawFromFlatDirection(toCenter.Unit, resolvedBodyYaw)
			end
		else
			self.BrainState.WanderYaw = (self.BrainState.WanderYaw or resolvedBodyYaw) + self.Random:NextNumber(-1.7, 1.7)
		end
		self.BrainState.NextMoveJitterAt = 0
		self.Decision = nil
		self.StuckElapsed = 0
	end

	self.LastResolvedPosition = resolvedPosition

	local currentTurretYaw = state.TurretYaw or resolvedBodyYaw
	local targetTurretYaw = getYawFromAimPosition(resolvedPosition, decision.AimWorldPoint, currentTurretYaw)

	state.Position = resolvedPosition
	state.BodyYaw = resolvedBodyYaw
	state.TurretYaw = moveAngleTowards(currentTurretYaw, targetTurretYaw, TURRET_TURN_SPEED * deltaTime)

	local model = getParticipantModel(self.TankParticipantRegistry, participant)

	if model ~= nil and self.TankSpawnResetService ~= nil then
		self.TankSpawnResetService.layoutTank(model, state.Position, state.BodyYaw, state.TurretYaw)
		-- Movement dust for arena bots: smoke only while actually driving.
		if self.TankSpawnResetService.setTrailActive ~= nil then
			self.TankSpawnResetService.setTrailActive(participant, math.abs(throttle) > 0.05)
		end
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
	local brainConfig = getEffectiveBrainConfig()
	local minDot = math.cos(math.rad(brainConfig.AimToleranceDegrees or 10))

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
