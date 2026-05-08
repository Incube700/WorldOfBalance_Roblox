-- Rojo-managed replacement for Studio-owned WOBGameplayServer.
-- Thin Gameplay Orchestrator Refactor v1.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankConfig = require(configs:WaitForChild("TankConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local MatchConfig = require(configs:WaitForChild("MatchConfig"))

-- Services
local PlayerTankSpawner = require(script.Parent:WaitForChild("PlayerTankSpawner"))
local MatchStatsService = require(script.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))
local TankMovementService = require(script.Parent:WaitForChild("Movement"):WaitForChild("TankMovementService"))
local TankParticipantRegistry = require(script.Parent:WaitForChild("TankParticipantRegistry"))
local ProjectileCombatService = require(script.Parent:WaitForChild("Combat"):WaitForChild("ProjectileCombatService"))

-- New Services
local RoundMatchService = require(script.Parent:WaitForChild("Round"):WaitForChild("RoundMatchService"))
local ProjectileService = require(script.Parent:WaitForChild("Projectiles"):WaitForChild("ProjectileService"))
local TankSpawnResetService = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankSpawnResetService"))
local PlayerPossessionService = require(script.Parent:WaitForChild("Players"):WaitForChild("PlayerPossessionService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local MOVE_SPEED = TankConfig.Movement.MoveSpeed
local REVERSE_MOVE_SPEED_MULTIPLIER = TankConfig.Movement.ReverseMoveSpeedMultiplier or 1
local TURN_SPEED = TankConfig.Movement.BodyTurnSpeedRadians

-- Remote Events
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tankInputEvent = remotes:WaitForChild("TankInputEvent")
local shootRequestEvent = remotes:WaitForChild("ShootRequestEvent")
local resetDummyRequestEvent = remotes:WaitForChild("ResetDummyRequestEvent")

local function getOrCreateRemoteEvent(name)
	local remoteEvent = remotes:FindFirstChild(name)
	if remoteEvent == nil then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = name
		remoteEvent.Parent = remotes
	end
	return remoteEvent
end

local combatFeedbackEvent = getOrCreateRemoteEvent("CombatFeedbackEvent")
local startMatchRequestEvent = getOrCreateRemoteEvent("StartMatchRequestEvent")
local returnToMenuRequestEvent = getOrCreateRemoteEvent("ReturnToMenuRequestEvent")

-- Folders
local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")

local projectileFolder = runtime:FindFirstChild("Projectiles") or Instance.new("Folder")
projectileFolder.Name = "Projectiles"
projectileFolder.Parent = runtime

local vfxFolder = runtime:FindFirstChild("VFX") or Instance.new("Folder")
vfxFolder.Name = "VFX"
vfxFolder.Parent = runtime

-- Tank Prototypes
local playerTank = PlayerTankSpawner.ensurePhysicalTankModel(testObjects:WaitForChild("PlayerTankPrototype"))
local dummyTank = PlayerTankSpawner.ensurePhysicalTankModel(testObjects:WaitForChild("DummyTank"))
local player2TankParts = PlayerTankSpawner.getOrCreateRuntimePlayerTank(playerTank, testObjects, "Player2TankPrototype")
local player2Tank = player2TankParts.Model

-- Helpers
local function findOptionalTankChild(model, childName)
	local child = model:FindFirstChild(childName, true) or model:WaitForChild(childName, 5)
	if child == nil then
		warn("[SERVER] " .. model.Name .. "." .. childName .. " missing; continuing without blocking startup")
	end
	return child
end

local function registerTankParticipant(config)
	local model = config.Model
	PlayerTankSpawner.ensurePhysicalTankModel(model)
	local tankParts = PlayerTankSpawner.getTankParts(model)

	local participant = {
		TankId = config.TankId,
		Model = tankParts.Model,
		PhysicalModel = tankParts.Model,
		Body = tankParts.Body or findOptionalTankChild(model, "Body"),
		Turret = tankParts.Turret or findOptionalTankChild(model, "Turret"),
		Barrel = tankParts.Barrel or findOptionalTankChild(model, "Barrel"),
		ShootPoint = tankParts.ShootPoint or findOptionalTankChild(model, "ShootPoint"),
		Hitboxes = tankParts.Hitboxes or findOptionalTankChild(model, "Hitboxes"),
		OwnerPlayer = nil,
		OwnerUserId = nil,
		TeamId = config.TeamId,
		IsBot = config.IsBot,
		IsPlayerTank = config.IsPlayerTank,
		ControllerType = config.IsBot and "Dummy" or "Player",
		SpawnName = config.SpawnName,
		SpawnTransform = nil,
		WeaponTypeId = primaryWeaponConfig.Id,
		WeaponConfig = primaryWeaponConfig,
		LastShotTime = 0,
		WeaponReadyAt = 0,
		WeaponState = { LastShotTime = 0, WeaponReadyAt = 0 },
		Health = 100,
		MaxHealth = 100,
		DefaultMaxHealth = 100,
		IsDead = false,
		IsActive = config.IsActive ~= false,
	}
	return TankParticipantRegistry.registerTankParticipant(participant)
end

-- Initialize Registry
TankParticipantRegistry.init({
	armorHitboxNames = { FrontArmor = true, RearArmor = true, LeftArmor = true, RightArmor = true },
	ARMOR_HITBOXES_VISIBLE = TankConfig.Armor.ArmorHitboxesVisible == true,
	ARMOR_HITBOX_TRANSPARENCY = TankConfig.Armor.ArmorHitboxTransparency or 0.4,
})

local playerParticipant = registerTankParticipant({ TankId = "PlayerTankPrototype", Model = playerTank, TeamId = "Player", IsBot = false, IsPlayerTank = true, SpawnName = "PlayerSpawn" })
local dummyParticipant = registerTankParticipant({ TankId = "DummyTank", Model = dummyTank, TeamId = "Dummy", IsBot = true, IsPlayerTank = false, SpawnName = "DummySpawn" })
local player2Participant = registerTankParticipant({ TankId = "Player2TankPrototype", Model = player2Tank, TeamId = "Player2", IsBot = false, IsPlayerTank = true, SpawnName = "Player2Spawn", IsActive = false })

-- Setup Raycast Params
local tankMovementRaycastParams = RaycastParams.new()
tankMovementRaycastParams.FilterDescendantsInstances = { playerTank, player2Tank, dummyTank, runtime, projectileFolder, vfxFolder }
tankMovementRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
tankMovementRaycastParams.IgnoreWater = true

local tankMovementOverlapParams = OverlapParams.new()
tankMovementOverlapParams.FilterType = Enum.RaycastFilterType.Include
tankMovementOverlapParams.MaxParts = 20

-- Initialize Services
MatchStatsService.init(root)
TankMovementService.init({
	map = map,
	body = playerParticipant.Body,
	tankModels = { playerTank, player2Tank, dummyTank },
	runtime = runtime,
	tankMovementRaycastParams = tankMovementRaycastParams,
	tankMovementOverlapParams = tankMovementOverlapParams,
})
TankSpawnResetService.init(map)

-- Forward declarations for service inter-dependency
local function getPlayerParticipant() return playerParticipant end
local function damageParticipant(participant, amount)
	if RoundMatchService.getRoundState().Ended or TankParticipantRegistry.getParticipantIsDead(participant) then
		return false
	end

	local currentHealth = TankParticipantRegistry.getParticipantHealth(participant)
	local newHealth = math.max(0, currentHealth - amount)
	TankParticipantRegistry.setParticipantHealth(participant, newHealth)

	print("[DAMAGE] " .. participant.TankId .. " -" .. math.floor(amount) .. " HP (" .. math.floor(newHealth) .. ")")

	local impactPos = participant.Body and participant.Body.Position or participant.Model:GetPivot().Position
	ProjectileService.getVFXHelpers().createImpactFlash(impactPos + Vector3.new(0, 3, 0))

	if newHealth <= 0 then
		TankParticipantRegistry.setParticipantIsDead(participant, true)
		TankSpawnResetService.darkenTank(participant.Model)
		print("[DEAD] " .. participant.TankId .. " destroyed")

		RoundMatchService.getRoundState().LoserTankId = participant.TankId
		if RoundMatchService.getMatchMode() == RoundMatchService.MATCH_MODE_PVP then
			if participant == playerParticipant then
				RoundMatchService.getRoundState().WinnerTankId = player2Participant.TankId
				RoundMatchService.endRound(RoundMatchService.ROUND_RESULT_LOSE)
			else
				RoundMatchService.getRoundState().WinnerTankId = playerParticipant.TankId
				RoundMatchService.endRound(RoundMatchService.ROUND_RESULT_WIN)
			end
		elseif participant == dummyParticipant then
			RoundMatchService.getRoundState().WinnerTankId = playerParticipant.TankId
			RoundMatchService.endRound(RoundMatchService.ROUND_RESULT_WIN)
		else
			RoundMatchService.getRoundState().WinnerTankId = dummyParticipant.TankId
			RoundMatchService.endRound(RoundMatchService.ROUND_RESULT_LOSE)
		end
	end
	return true
end

-- Init Projectile Service
ProjectileService.init(root, projectileFolder, vfxFolder, {
	getGameState = function() return RoundMatchService.getGameState() end,
	getRoundState = function() return RoundMatchService.getRoundState() end,
	damageParticipant = damageParticipant,
	getPlayerParticipant = getPlayerParticipant,
})

-- Collect map targets for projectiles
local function collectMapTargets()
	local targets = {}
	local rwalls = map:FindFirstChild("RicochetWalls")
	local cover = map:FindFirstChild("Cover")
	if rwalls then table.insert(targets, rwalls) end
	if cover then table.insert(targets, cover) end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and TankMovementService.isTankMovementObstacle(d) then table.insert(targets, d) end
	end
	return targets
end
ProjectileService.setMapRaycastTargets(collectMapTargets())

-- Init Combat Service
ProjectileCombatService.init({
	getParticipantIsDead = function(p) return TankParticipantRegistry.getParticipantIsDead(p) end,
	createImpactFlash = function(pos) ProjectileService.getVFXHelpers().createImpactFlash(pos) end,
	destroyProjectile = function(proj) ProjectileService.destroyProjectile(proj) end,
	sendCombatFeedback = function(ftype, pos, text, color)
		combatFeedbackEvent:FireAllClients({ Type = ftype, Position = pos, Text = text, Color = color })
	end,
	damageParticipant = damageParticipant,
})

-- Init RoundMatch Service
RoundMatchService.init(root, {
	onDestroyAllProjectiles = function() ProjectileService.destroyAllProjectiles() end,
	onConfigureParticipants = function()
		RoundMatchService.updateMatchMode()
		TankSpawnResetService.configureActiveParticipants(RoundMatchService.getMatchMode(), player2Participant.OwnerPlayer ~= nil)
	end,
	onRestoreColors = function() TankSpawnResetService.restoreAllTankColors() end,
	onResetCombatAttributes = function()
		for _, p in ipairs(TankParticipantRegistry.getParticipants()) do
			if p.IsActive ~= false then TankParticipantRegistry.resetParticipantHealth(p) end
		end
		RoundMatchService.setRoundResult(RoundMatchService.ROUND_RESULT_PLAYING)
	end,
	onApplySpawn = function(p, s) TankSpawnResetService.applySpawnToParticipant(p, s) end,
	getSpawnTransforms = function() return TankSpawnResetService.getAllSpawnTransforms() end,
})

-- Init Possession Service
PlayerPossessionService.init({
	onParticipantAssigned = function(player, participant)
		TankSpawnResetService.configureActiveParticipants(RoundMatchService.getMatchMode(), player2Participant.OwnerPlayer ~= nil)
	end,
})

-- Initial Setup
TankSpawnResetService.captureTankColors(playerParticipant.TankId, playerParticipant.Model)
TankSpawnResetService.captureTankColors(dummyParticipant.TankId, dummyParticipant.Model)
TankSpawnResetService.captureTankColors(player2Participant.TankId, player2Participant.Model)

local transforms = TankSpawnResetService.getAllSpawnTransforms()
TankSpawnResetService.applySpawnToParticipant(playerParticipant, transforms.Player)
TankSpawnResetService.applySpawnToParticipant(dummyParticipant, transforms.Dummy)
TankSpawnResetService.applySpawnToParticipant(player2Participant, transforms.Player2)

-- Player Connections
for _, player in ipairs(Players:GetPlayers()) do PlayerPossessionService.assignPlayer(player) end
Players.PlayerAdded:Connect(function(player) PlayerPossessionService.assignPlayer(player) end)
Players.PlayerRemoving:Connect(function(player) PlayerPossessionService.removePlayer(player) end)

-- Remote Connections
startMatchRequestEvent.OnServerEvent:Connect(function(player)
	print("[SERVER] StartMatch requested by " .. player.Name)
	if PlayerPossessionService.getPlayerParticipantByPlayer(player) then
		RoundMatchService.startNewMatch()
	end
end)

returnToMenuRequestEvent.OnServerEvent:Connect(function(player)
	if player == PlayerPossessionService.getControllingPlayer() then
		ProjectileService.destroyAllProjectiles()
		RoundMatchService.setGameState(RoundMatchService.GAME_STATE_MENU)
	end
end)

resetDummyRequestEvent.OnServerEvent:Connect(function() RoundMatchService.resetRound() end)

local lastInputReceivedLogTimes = {}
local lastInputAppliedLogTime = 0

tankInputEvent.OnServerEvent:Connect(function(player, inputData)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
	if participant and participant.IsActive and RoundMatchService.getGameState() == "Playing" then
		PlayerPossessionService.getInputByPlayer()[player] = {
			Throttle = math.clamp(tonumber(inputData.Throttle) or 0, -1, 1),
			Steer = math.clamp(tonumber(inputData.Steer) or 0, -1, 1),
			AimPosition = typeof(inputData.AimPosition) == "Vector3" and inputData.AimPosition or (participant.ControlState.Position + Vector3.new(0, 0, -20)),
		}

		local now = os.clock()
		if now - (lastInputReceivedLogTimes[player] or 0) > 5 then
			lastInputReceivedLogTimes[player] = now
			print(string.format("[SERVER] TankInput received from %s for %s", player.Name, participant.TankId))
		end
	elseif participant == nil then
		if os.clock() % 5 < 0.1 then
			print("[SERVER] TankInput ignored: participant not found for " .. player.Name)
		end
	end
end)

shootRequestEvent.OnServerEvent:Connect(function(player, aimPosition)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
	if participant and participant.IsActive and RoundMatchService.getGameState() == "Playing" then
		if participant.ShootPoint == nil or participant.ShootPoint.Parent == nil then
			warn("[SERVER] ShootRequest ignored: " .. participant.TankId .. " has no ShootPoint")
			return
		end

		local origin = participant.ShootPoint.Position
		local dir = typeof(aimPosition) == "Vector3" and (Vector3.new(aimPosition.X - origin.X, 0, aimPosition.Z - origin.Z)) or Vector3.new(0,0,-1)
		ProjectileService.tryShoot(participant, dir.Magnitude > 0.1 and dir.Unit or (CFrame.Angles(0, participant.ControlState.TurretYaw, 0)).LookVector)
	end
end)

-- Main Loop
RunService.Heartbeat:Connect(function(deltaTime)
	if RoundMatchService.getGameState() ~= "Playing" then return end

	local inputs = PlayerPossessionService.getInputByPlayer()
	local now = os.clock()
	local shouldLogApply = now - lastInputAppliedLogTime > 5
	if shouldLogApply then
		lastInputAppliedLogTime = now
	end

	for _, p in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
		if p.OwnerPlayer and p.IsActive and p.ControlState then
			local input = inputs[p.OwnerPlayer]
			if input then
				local state = p.ControlState
				state.BodyYaw -= input.Steer * TURN_SPEED * deltaTime
				local moveSpeed = MOVE_SPEED * (input.Throttle < 0 and REVERSE_MOVE_SPEED_MULTIPLIER or 1)
				local desiredMove = (CFrame.Angles(0, state.BodyYaw, 0).LookVector) * input.Throttle * moveSpeed * deltaTime
				local resolvedPos, blocking = TankMovementService.resolveTankMovement(state.Position, state.BodyYaw, desiredMove)
				state.Position = resolvedPos
				state.TurretYaw = math.atan2(-(input.AimPosition - state.Position).X, -(input.AimPosition - state.Position).Z)
				TankSpawnResetService.layoutTank(p.Model, state.Position, state.BodyYaw, state.TurretYaw)

				if shouldLogApply then
					print(string.format("[SERVER] input applied to %s", p.TankId))
				end
			end
		end
	end

	ProjectileService.updateProjectiles(deltaTime)
end)

print("[SERVER] StartMatch handler connected")
print("[WOB] Gameplay server started")
