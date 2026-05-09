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
local LobbyService = require(script.Parent:WaitForChild("Lobby"):WaitForChild("LobbyService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local MOVE_SPEED = TankConfig.Movement.MoveSpeed
local REVERSE_MOVE_SPEED_MULTIPLIER = TankConfig.Movement.ReverseMoveSpeedMultiplier or 1
local TURN_SPEED = TankConfig.Movement.BodyTurnSpeedRadians
local DEBUG_INPUT = false

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
local rematchRequestEvent = getOrCreateRemoteEvent("RematchRequestEvent")

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
local tankMovementIgnoredModels = { playerTank, player2Tank, dummyTank }

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

local playerParticipant = registerTankParticipant({ TankId = "PlayerTankPrototype", Model = playerTank, TeamId = "Player", IsBot = false, IsPlayerTank = true, SpawnName = "PlayerSpawn", IsActive = false })
local dummyParticipant = registerTankParticipant({ TankId = "DummyTank", Model = dummyTank, TeamId = "Dummy", IsBot = true, IsPlayerTank = false, SpawnName = "DummySpawn", IsActive = false })
local player2Participant = registerTankParticipant({ TankId = "Player2TankPrototype", Model = player2Tank, TeamId = "Player2", IsBot = false, IsPlayerTank = true, SpawnName = "Player2Spawn", IsActive = false })

-- Setup Raycast Params
local tankMovementRaycastParams = RaycastParams.new()
tankMovementRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
tankMovementRaycastParams.IgnoreWater = true

local tankMovementOverlapParams = OverlapParams.new()
tankMovementOverlapParams.FilterType = Enum.RaycastFilterType.Include
tankMovementOverlapParams.MaxParts = 20

local function refreshTankMovementRaycastFilter()
	local ignoredInstances = { runtime, projectileFolder, vfxFolder }

	for _, tankModel in ipairs(tankMovementIgnoredModels) do
		table.insert(ignoredInstances, tankModel)
	end

	tankMovementRaycastParams.FilterDescendantsInstances = ignoredInstances
end

refreshTankMovementRaycastFilter()

-- Initialize Services
MatchStatsService.init(root)
TankMovementService.init({
	map = map,
	body = playerParticipant.Body,
	tankModels = tankMovementIgnoredModels,
	runtime = runtime,
	tankMovementRaycastParams = tankMovementRaycastParams,
	tankMovementOverlapParams = tankMovementOverlapParams,
})
TankSpawnResetService.init(map)

local function getOrCreatePlayerParticipantForPlayer(player)
	local tankName = PlayerTankSpawner.getDynamicPlayerTankName(player)
	local existingParticipant = TankParticipantRegistry.getParticipantById(tankName)

	if existingParticipant ~= nil then
		return existingParticipant
	end

	local tankParts, created = PlayerTankSpawner.getOrCreatePlayerTankForPlayer(playerTank, testObjects, player)
	local participant = registerTankParticipant({
		TankId = tankName,
		Model = tankParts.Model,
		TeamId = "Player_" .. tostring(player.UserId),
		IsBot = false,
		IsPlayerTank = true,
		SpawnName = "LobbySpawn",
		IsActive = true,
	})

	table.insert(tankMovementIgnoredModels, participant.Model)
	refreshTankMovementRaycastFilter()
	TankSpawnResetService.captureTankColors(participant.TankId, participant.Model)
	TankParticipantRegistry.setParticipantModelVisible(participant, true)

	if created then
		print("[TANK] created player tank " .. player.Name .. " -> " .. participant.TankId)
	else
		print("[TANK] reused player tank " .. player.Name .. " -> " .. participant.TankId)
	end

	return participant
end

-- Forward declarations for service inter-dependency
local function getPlayerParticipant() return playerParticipant end
local function damageParticipant(participant, amount)
	local activeMatch = RoundMatchService.getActiveMatch()

	if activeMatch == nil
		or activeMatch.IsFinished == true
		or participant.MatchId ~= activeMatch.MatchId
		or RoundMatchService.getRoundState().Ended
		or TankParticipantRegistry.getParticipantIsDead(participant)
	then
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

		local winnerParticipant = RoundMatchService.getOpponentForParticipant(participant)
		RoundMatchService.getRoundState().LoserTankId = participant.TankId

		if winnerParticipant ~= nil then
			RoundMatchService.getRoundState().WinnerTankId = winnerParticipant.TankId
		end

		RoundMatchService.endRound(RoundMatchService.getRoundResultForDestroyedParticipant(participant))
	end
	return true
end

-- Init Projectile Service
ProjectileService.init(root, projectileFolder, vfxFolder, {
	getGameState = function() return RoundMatchService.getGameState() end,
	getRoundState = function() return RoundMatchService.getRoundState() end,
	damageParticipant = damageParticipant,
	getPlayerParticipant = getPlayerParticipant,
	canParticipantShoot = function(participant) return LobbyService.canParticipantShoot(participant) end,
	isNoDamageProjectile = function(participant) return LobbyService.isNoDamageProjectile(participant) end,
	shouldRecordShot = function(participant) return LobbyService.shouldRecordShot(participant) end,
	areProjectilesEnabled = function() return LobbyService.areProjectilesEnabled() end,
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
	canDamageParticipant = function(projectile, targetParticipant)
		return LobbyService.canDamageParticipant(projectile, targetParticipant)
	end,
})

-- Init RoundMatch Service
RoundMatchService.init(root, {
	onDestroyAllProjectiles = function() ProjectileService.destroyAllProjectiles() end,
	onConfigureParticipants = function()
		RoundMatchService.updateMatchMode()
		local activeMatch = RoundMatchService.getActiveMatch()
		TankSpawnResetService.configureActiveParticipants(
			RoundMatchService.getMatchMode(),
			player2Participant.OwnerPlayer ~= nil,
			activeMatch ~= nil and activeMatch.Participants or nil
		)
	end,
	onRestoreColors = function() TankSpawnResetService.restoreAllTankColors() end,
	onResetCombatAttributes = function()
		local activeMatch = RoundMatchService.getActiveMatch()
		local participants = activeMatch ~= nil and activeMatch.Participants or TankParticipantRegistry.getParticipants()

		for _, p in ipairs(participants) do
			TankParticipantRegistry.resetParticipantHealth(p)
		end

		RoundMatchService.setRoundResult(RoundMatchService.ROUND_RESULT_PLAYING)
	end,
	onApplySpawn = function(p, s) TankSpawnResetService.applySpawnToParticipant(p, s) end,
	getSpawnTransforms = function() return TankSpawnResetService.getAllSpawnTransforms() end,
	onMatchEnded = function(activeMatch)
		LobbyService.onMatchEnded(activeMatch)
	end,
})

LobbyService.init({
	root = root,
	tankSpawnResetService = TankSpawnResetService,
	roundMatchService = RoundMatchService,
	projectileService = ProjectileService,
	dummyParticipant = dummyParticipant,
})

-- Init Possession Service
PlayerPossessionService.init({
	getOrCreateParticipantForPlayer = function(player)
		return getOrCreatePlayerParticipantForPlayer(player)
	end,
	onParticipantAssigned = function(player, participant)
		if participant ~= nil then
			LobbyService.playerAssigned(player, participant)
		end

		local activeMatch = RoundMatchService.getActiveMatch()
		TankSpawnResetService.configureActiveParticipants(
			RoundMatchService.getMatchMode(),
			player2Participant.OwnerPlayer ~= nil,
			activeMatch ~= nil and activeMatch.Participants or nil
		)
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
TankParticipantRegistry.setParticipantModelVisible(playerParticipant, false)
TankParticipantRegistry.setParticipantModelVisible(dummyParticipant, false)
TankParticipantRegistry.setParticipantModelVisible(player2Participant, false)

-- Player Connections
for _, player in ipairs(Players:GetPlayers()) do PlayerPossessionService.assignPlayer(player) end
Players.PlayerAdded:Connect(function(player) PlayerPossessionService.assignPlayer(player) end)
Players.PlayerRemoving:Connect(function(player)
	LobbyService.playerRemoving(player)
	PlayerPossessionService.removePlayer(player)
end)

-- Remote Connections
startMatchRequestEvent.OnServerEvent:Connect(function(player)
	if DEBUG_INPUT then
		print("[SERVER] StartMatch requested by " .. player.Name)
	end

	LobbyService.handleStartMatchRequest(player)
end)

returnToMenuRequestEvent.OnServerEvent:Connect(function(player)
	LobbyService.handleReturnToLobbyRequest(player)
end)

rematchRequestEvent.OnServerEvent:Connect(function(player)
	LobbyService.handleRematchRequest(player)
end)

resetDummyRequestEvent.OnServerEvent:Connect(function(player)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)

	if participant ~= nil and participant.ParticipantState == LobbyService.MODE_IN_MATCH then
		RoundMatchService.resetRound()
	end
end)

local lastInputReceivedLogTimes = {}
local lastInputAppliedLogTime = 0

tankInputEvent.OnServerEvent:Connect(function(player, inputData)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
	if participant and participant.IsActive and LobbyService.canParticipantDrive(participant) then
		PlayerPossessionService.getInputByPlayer()[player] = {
			Throttle = math.clamp(tonumber(inputData.Throttle) or 0, -1, 1),
			Steer = math.clamp(tonumber(inputData.Steer) or 0, -1, 1),
			AimPosition = typeof(inputData.AimPosition) == "Vector3" and inputData.AimPosition or (participant.ControlState.Position + Vector3.new(0, 0, -20)),
		}

		local now = os.clock()
		if DEBUG_INPUT and now - (lastInputReceivedLogTimes[player] or 0) > 5 then
			lastInputReceivedLogTimes[player] = now
			print(string.format("[SERVER] TankInput received from %s for %s", player.Name, participant.TankId))
		end
	elseif DEBUG_INPUT and participant == nil then
		if os.clock() % 5 < 0.1 then
			print("[SERVER] TankInput ignored: participant not found for " .. player.Name)
		end
	end
end)

shootRequestEvent.OnServerEvent:Connect(function(player, aimPosition)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
	if participant and participant.IsActive and LobbyService.canParticipantShoot(participant) then
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
	LobbyService.update(deltaTime)

	local inputs = PlayerPossessionService.getInputByPlayer()
	local now = os.clock()
	local shouldLogApply = DEBUG_INPUT and now - lastInputAppliedLogTime > 5
	if shouldLogApply then
		lastInputAppliedLogTime = now
	end

	for _, p in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
		if p.OwnerPlayer and p.IsActive and p.ControlState and LobbyService.canParticipantDrive(p) then
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
