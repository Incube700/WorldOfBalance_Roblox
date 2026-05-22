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
local TankFactoryConfig = require(configs:WaitForChild("TankFactoryConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local MatchConfig = require(configs:WaitForChild("MatchConfig"))
local BattleArenaConfig = require(configs:WaitForChild("BattleArenaConfig"))
local DebugBotConfig = require(configs:WaitForChild("DebugBotConfig"))
local DebugCombatConfig = require(configs:WaitForChild("DebugCombatConfig"))
local TankArmorConfig = require(configs:WaitForChild("TankArmorConfig"))

-- Services
local MatchStatsService = require(script.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))
local PlayerWalletService = require(script.Parent:WaitForChild("Economy"):WaitForChild("PlayerWalletService"))
local KillRewardService = require(script.Parent:WaitForChild("Economy"):WaitForChild("KillRewardService"))
local MatchRewardService = require(script.Parent:WaitForChild("Economy"):WaitForChild("MatchRewardService"))
local TankMovementService = require(script.Parent:WaitForChild("Movement"):WaitForChild("TankMovementService"))
local TankParticipantRegistry = require(script.Parent:WaitForChild("TankParticipantRegistry"))
local ProjectileCombatService = require(script.Parent:WaitForChild("Combat"):WaitForChild("ProjectileCombatService"))

-- New Services
local RoundMatchService = require(script.Parent:WaitForChild("Round"):WaitForChild("RoundMatchService"))
local ProjectileService = require(script.Parent:WaitForChild("Projectiles"):WaitForChild("ProjectileService"))
local TankSpawnResetService = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankSpawnResetService"))
local TankFactory = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankFactory"))
local TankRole = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankRole"))
local TankStatsProfile = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankStatsProfile"))
local TankTemplateProvider = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankTemplateProvider"))
local TankStatsProvider = require(script.Parent:WaitForChild("Tanks"):WaitForChild("TankStatsProvider"))
local PlayerPossessionService = require(script.Parent:WaitForChild("Players"):WaitForChild("PlayerPossessionService"))
local LobbyService = require(script.Parent:WaitForChild("Lobby"):WaitForChild("LobbyService"))
local ArenaCombatService = require(script.Parent:WaitForChild("Arena"):WaitForChild("ArenaCombatService"))
local BotService = require(script.Parent:WaitForChild("Bots"):WaitForChild("BotService"))
local TrainingBotService = require(script.Parent:WaitForChild("Bots"):WaitForChild("TrainingBotService"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local MOVE_SPEED = TankConfig.Movement.MoveSpeed
local REVERSE_MOVE_SPEED_MULTIPLIER = TankConfig.Movement.ReverseMoveSpeedMultiplier or 1
local INVERT_STEERING_WHEN_REVERSING = TankConfig.Movement.InvertSteeringWhenReversing == true
local REVERSE_STEERING_DEAD_ZONE = math.max(0, tonumber(TankConfig.Movement.ReverseSteeringDeadZone) or 0.05)
local TURN_SPEED = TankConfig.Movement.BodyTurnSpeedRadians
local turretConfig = TankConfig.Turret or {}
local TURRET_TURN_SPEED = turretConfig.TurnSpeedRadiansPerSecond
	or math.rad(turretConfig.TurnSpeedDegreesPerSecond or TankConfig.Movement.TurretTurnSpeedDegrees or 240)
local SHOOT_USES_TURRET_FACING = turretConfig.ShootUsesTurretFacing ~= false
	and TankConfig.Movement.ShootUsesTurretFacing ~= false
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
local debugSpawnBotRequestEvent = getOrCreateRemoteEvent("DebugSpawnBotRequestEvent")
local debugRemoveBotRequestEvent = getOrCreateRemoteEvent("DebugRemoveBotRequestEvent")
local upgradeChoiceEvent = getOrCreateRemoteEvent("UpgradeChoiceEvent")

-- Folders
local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local wobRuntime = Workspace:FindFirstChild("WOB_Runtime") or Instance.new("Folder")
wobRuntime.Name = "WOB_Runtime"
wobRuntime.Parent = Workspace
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")

local projectileFolder = runtime:FindFirstChild("Projectiles") or Instance.new("Folder")
projectileFolder.Name = "Projectiles"
projectileFolder.Parent = runtime
projectileFolder:ClearAllChildren()

local legacyVfxFolder = runtime:FindFirstChild("VFX")

if legacyVfxFolder ~= nil then
	legacyVfxFolder:ClearAllChildren()
end

local vfxFolder = wobRuntime:FindFirstChild("VFX") or Instance.new("Folder")
vfxFolder.Name = "VFX"
vfxFolder.Parent = wobRuntime
vfxFolder:ClearAllChildren()

-- Tank factory
local tankTemplateProvider = TankTemplateProvider.new(testObjects)
local tankStatsProvider = TankStatsProvider.new()
local tankFactory = TankFactory.new({
	TankParticipantRegistry = TankParticipantRegistry,
	TemplateProvider = tankTemplateProvider,
	TankStatsProvider = tankStatsProvider,
	DefaultWeaponConfig = primaryWeaponConfig,
	SpawnParent = testObjects,
})
local tankMovementIgnoredModels = {}

-- Helpers
local function addTankMovementIgnoredModel(model)
	if model == nil then
		return
	end

	for _, ignoredModel in ipairs(tankMovementIgnoredModels) do
		if ignoredModel == model then
			return
		end
	end

	table.insert(tankMovementIgnoredModels, model)
end

local function addParticipantToMovementIgnore(participant)
	if participant == nil then
		return
	end

	addTankMovementIgnoredModel(TankParticipantRegistry.getParticipantPhysicalModel(participant) or participant.Model)
end

local function spawnTankParticipant(request)
	local result = tankFactory:SpawnTank(request)

	if result == nil or result.Participant == nil then
		error("[TANK] failed to spawn participant role=" .. tostring(request ~= nil and request.Role), 2)
	end

	addParticipantToMovementIgnore(result.Participant)

	return result.Participant, result
end

-- Initialize Registry
TankParticipantRegistry.init({
	armorHitboxNames = { FrontArmor = true, RearArmor = true, LeftArmor = true, RightArmor = true },
	ARMOR_HITBOXES_VISIBLE = TankArmorConfig.Visuals.ArmorZonesVisible ~= false,
	ARMOR_HITBOX_TRANSPARENCY = TankArmorConfig.Visuals.SideTransparency or 0.45,
	armorHitboxTransparencyByName = {
		FrontArmor = TankArmorConfig.Visuals.FrontTransparency or 0.35,
		RearArmor = TankArmorConfig.Visuals.RearTransparency or 0.45,
		LeftArmor = TankArmorConfig.Visuals.SideTransparency or 0.45,
		RightArmor = TankArmorConfig.Visuals.SideTransparency or 0.45,
	},
})

-- Startup static participants (IsActive=false, invisible until assigned).
-- TankIds use StartupParticipantIds so TankFactory runs GetTemplateForRole
-- (choosing BaseTankTemplate when present) instead of reusing the legacy
-- prototype model directly by name.
local playerParticipant = spawnTankParticipant({
	TankId = TankFactoryConfig.StartupParticipantIds.Player,
	Role = TankRole.Player,
	TeamId = "Player",
	IsBot = false,
	IsPlayerTank = true,
	SpawnName = "PlayerSpawn",
	IsActive = false,
	StatsProfileId = TankStatsProfile.DuelNormalized,
})
local dummyParticipant = spawnTankParticipant({
	TankId = TankFactoryConfig.StartupParticipantIds.Dummy,
	Role = TankRole.Dummy,
	TeamId = "Dummy",
	IsBot = true,
	IsPlayerTank = false,
	SpawnName = "DummySpawn",
	IsActive = false,
	StatsProfileId = TankStatsProfile.TrainingDummy,
})
local player2Participant = spawnTankParticipant({
	TankId = TankFactoryConfig.StartupParticipantIds.Player2,
	Role = TankRole.DuelOpponent,
	TeamId = "Player2",
	IsBot = false,
	IsPlayerTank = true,
	SpawnName = "Player2Spawn",
	IsActive = false,
	StatsProfileId = TankStatsProfile.DuelNormalized,
})

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
	root = root,
	map = map,
	body = playerParticipant.Body,
	tankModels = tankMovementIgnoredModels,
	runtime = runtime,
	tankMovementRaycastParams = tankMovementRaycastParams,
	tankMovementOverlapParams = tankMovementOverlapParams,
	collisionBoxSize = TankConfig.Movement.CollisionBoxSize,
	collisionBoxYOffset = TankConfig.Movement.CollisionBoxYOffset,
	collisionSkinWidth = TankConfig.Movement.CollisionSkinWidth,
	worldBoundsMinX = TankConfig.Movement.WorldBoundsMinX,
	worldBoundsMaxX = TankConfig.Movement.WorldBoundsMaxX,
	worldBoundsMinZ = TankConfig.Movement.WorldBoundsMinZ,
	worldBoundsMaxZ = TankConfig.Movement.WorldBoundsMaxZ,
	debugCollision = TankConfig.Movement.DebugCollision == true or BattleArenaConfig.DebugCollision == true,
})
TankSpawnResetService.init(map)

local function getOrCreatePlayerParticipantForPlayer(player)
	local tankName = TankFactoryConfig.GetDynamicPlayerTankId(player)
	local existingParticipant = TankParticipantRegistry.getParticipantById(tankName)

	if existingParticipant ~= nil then
		addParticipantToMovementIgnore(existingParticipant)
		refreshTankMovementRaycastFilter()
		return existingParticipant
	end

	local participant, spawnResult = spawnTankParticipant({
		TankId = tankName,
		Role = TankRole.Player,
		TeamId = "Player_" .. tostring(player.UserId),
		OwnerPlayer = player,
		IsBot = false,
		IsPlayerTank = true,
		SpawnName = "LobbySpawn",
		IsActive = true,
		StatsProfileId = TankStatsProfile.DuelNormalized,
	})

	refreshTankMovementRaycastFilter()
	TankSpawnResetService.captureTankColors(participant.TankId, participant.Model)
	TankParticipantRegistry.setParticipantModelVisible(participant, true)

	if spawnResult.Created then
		print("[TANK] created player tank " .. player.Name .. " -> " .. participant.TankId)
	else
		print("[TANK] reused player tank " .. player.Name .. " -> " .. participant.TankId)
	end

	return participant
end

-- Forward declarations for service inter-dependency
local function getPlayerParticipant() return playerParticipant end
local function normalizeAngleRadians(angle)
	local fullTurn = math.pi * 2
	return ((angle + math.pi) % fullTurn) - math.pi
end

local function moveAngleTowards(currentAngle, targetAngle, maxDelta)
	local delta = normalizeAngleRadians(targetAngle - currentAngle)

	if math.abs(delta) <= maxDelta then
		return targetAngle
	end

	local direction = delta >= 0 and 1 or -1
	return currentAngle + direction * maxDelta
end

local function getYawFromAimPosition(position, aimPosition, fallbackYaw)
	local delta = Vector3.new(aimPosition.X - position.X, 0, aimPosition.Z - position.Z)

	if delta.Magnitude < 0.001 then
		return fallbackYaw
	end

	return math.atan2(-delta.X, -delta.Z)
end

local missingDeathVfxPositionWarnings = {}

local function warnMissingDeathVfxPositionOnce(participant)
	local tankId = participant ~= nil and participant.TankId or "unknown"

	if missingDeathVfxPositionWarnings[tankId] == true then
		return
	end

	missingDeathVfxPositionWarnings[tankId] = true
	warn("[VFX] Death explosion skipped: no position for " .. tostring(tankId))
end

local function getParticipantVfxPosition(participant)
	if participant == nil then
		return nil
	end

	if participant.PrimaryPart ~= nil and participant.PrimaryPart.Parent ~= nil then
		return participant.PrimaryPart.Position
	end

	if participant.Body ~= nil and participant.Body.Parent ~= nil then
		return participant.Body.Position
	end

	local model = TankParticipantRegistry.getParticipantPhysicalModel(participant)

	if model ~= nil then
		if model.PrimaryPart ~= nil and model.PrimaryPart.Parent ~= nil then
			return model.PrimaryPart.Position
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				return descendant.Position
			end
		end
	end

	return nil
end

local function playDeathExplosion(participant)
	local deathPosition = getParticipantVfxPosition(participant)

	if deathPosition == nil then
		warnMissingDeathVfxPositionOnce(participant)
		return
	end

	local vfxHelpers = ProjectileService.getVFXHelpers()
	vfxHelpers.createDeathExplosion(deathPosition)
	vfxHelpers.createBurningTank(deathPosition)
end

local function sendCombatFeedbackPayload(feedbackType, pos, text, color, audioOnly, options)
	local payload = {
		Type = feedbackType,
		Position = pos,
		Text = text,
		Color = color,
		AudioOnly = audioOnly == true,
	}

	if typeof(options) == "table" then
		payload.Lifetime = options.Lifetime
		payload.RiseDistance = options.RiseDistance
	end

	combatFeedbackEvent:FireAllClients(payload)
end

local function clearActiveMatchInputs()
	local activeMatch = RoundMatchService.getActiveMatch()

	if activeMatch == nil then
		return
	end

	local inputs = PlayerPossessionService.getInputByPlayer()

	for _, activeParticipant in ipairs(activeMatch.Participants or {}) do
		if activeParticipant.OwnerPlayer ~= nil then
			inputs[activeParticipant.OwnerPlayer] = nil
		end
	end
end

local function clearParticipantInput(participant)
	if participant ~= nil and participant.OwnerPlayer ~= nil then
		PlayerPossessionService.getInputByPlayer()[participant.OwnerPlayer] = nil
	end
end

local function damageParticipant(participant, amount, sourceProjectile)
	if ArenaCombatService.IsParticipantInArena(participant) then
		if TankParticipantRegistry.getParticipantIsDead(participant) then
			return false
		end

		local currentHealth = TankParticipantRegistry.getParticipantHealth(participant)
		local newHealth = math.max(0, currentHealth - amount)
		TankParticipantRegistry.setParticipantHealth(participant, newHealth)
		TankParticipantRegistry.recordParticipantDamage(participant, amount, newHealth <= 0)

		if DebugCombatConfig.DamageLog then
			print("[ARENA_DAMAGE] " .. participant.TankId .. " -" .. math.floor(amount) .. " HP (" .. math.floor(newHealth) .. ")")
		end

		if newHealth <= 0 then
			TankParticipantRegistry.setParticipantIsDead(participant, true)
			local deathPosition = getParticipantVfxPosition(participant)
			playDeathExplosion(participant)
			sendCombatFeedbackPayload("TankDestroyed", deathPosition, "", Color3.fromRGB(255, 140, 90), true)
			TankSpawnResetService.darkenTank(participant.Model)
			print("[ARENA_DEAD] " .. participant.TankId .. " destroyed")

			local killerParticipant = sourceProjectile ~= nil and sourceProjectile.OwnerParticipant or nil
			ArenaCombatService.OnParticipantKilled(killerParticipant, participant, sourceProjectile)
			clearParticipantInput(participant)
		end

		return true
	end

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
	TankParticipantRegistry.recordParticipantDamage(participant, amount, newHealth <= 0)

	if DebugCombatConfig.DamageLog then
		print("[DAMAGE] " .. participant.TankId .. " -" .. math.floor(amount) .. " HP (" .. math.floor(newHealth) .. ")")
	end

	if newHealth <= 0 then
		TankParticipantRegistry.setParticipantIsDead(participant, true)
		local deathPosition = getParticipantVfxPosition(participant)
		playDeathExplosion(participant)
		sendCombatFeedbackPayload("TankDestroyed", deathPosition, "", Color3.fromRGB(255, 140, 90), true)
		TankSpawnResetService.darkenTank(participant.Model)
		print("[DEAD] " .. participant.TankId .. " destroyed")

		local winnerParticipant = RoundMatchService.getOpponentForParticipant(participant)
		RoundMatchService.getRoundState().LoserTankId = participant.TankId

		if winnerParticipant ~= nil then
			RoundMatchService.getRoundState().WinnerTankId = winnerParticipant.TankId
		end

		KillRewardService.awardTankKill(
			sourceProjectile ~= nil and sourceProjectile.OwnerParticipant or winnerParticipant,
			participant,
			{
				Projectile = sourceProjectile,
				NoDamage = sourceProjectile ~= nil and sourceProjectile.NoDamage == true,
				RoundNumber = root:GetAttribute("RoundNumber"),
			}
		)

		RoundMatchService.endRound(RoundMatchService.getRoundResultForDestroyedParticipant(participant))
		clearActiveMatchInputs()
	end

	return true
end

-- Init Projectile Service
ProjectileService.init(root, projectileFolder, vfxFolder, {
	getGameState = function() return RoundMatchService.getGameState() end,
	getRoundState = function() return RoundMatchService.getRoundState() end,
	getRoundStateForProjectile = function(projectile)
		if ArenaCombatService.IsArenaProjectile(projectile) then
			return { Ended = false }
		end

		return RoundMatchService.getRoundState()
	end,
	damageParticipant = damageParticipant,
	getPlayerParticipant = getPlayerParticipant,
	canParticipantShoot = function(participant) return LobbyService.canParticipantShoot(participant) end,
	isNoDamageProjectile = function(participant) return LobbyService.isNoDamageProjectile(participant) end,
	shouldRecordShot = function(participant) return LobbyService.shouldRecordShot(participant) end,
	areProjectilesEnabled = function() return LobbyService.areProjectilesEnabled() end,
	sendBlockedShotFeedback = function(participant, pos, text)
		if participant ~= nil and participant.OwnerPlayer ~= nil then
			combatFeedbackEvent:FireClient(participant.OwnerPlayer, {
				Type = "BlockedShot",
				Position = pos,
				Text = text,
				Color = Color3.fromRGB(255, 220, 90),
			})
		end
	end,
	sendCombatFeedback = function(ftype, pos, text, color, audioOnly)
		sendCombatFeedbackPayload(ftype, pos, text, color, audioOnly)
	end,
})

-- Collect map targets for projectiles
local function collectMapTargets()
	local targets = {}
	local seen = {}

	local function addTarget(instance)
		if instance ~= nil and seen[instance] ~= true then
			seen[instance] = true
			table.insert(targets, instance)
		end
	end

	for _, obstaclePart in ipairs(TankMovementService.getTankMovementObstacleParts()) do
		addTarget(obstaclePart)
	end

	return targets
end
ProjectileService.setMapRaycastTargets(collectMapTargets())

KillRewardService.init({
	playerWalletService = PlayerWalletService,
	roundMatchService = RoundMatchService,
	lobbyService = LobbyService,
	tankParticipantRegistry = TankParticipantRegistry,
})

MatchRewardService.init({
	playerWalletService = PlayerWalletService,
})

-- Init Combat Service
ProjectileCombatService.init({
	getParticipantIsDead = function(p) return TankParticipantRegistry.getParticipantIsDead(p) end,
	createDamageHitVfx = function(pos, normal) ProjectileService.getVFXHelpers().createDamageHitVfx(pos, normal) end,
	createNoPenVfx = function(pos, normal) ProjectileService.getVFXHelpers().createNoPenVfx(pos, normal) end,
	createSelfHitVfx = function(pos, normal) ProjectileService.getVFXHelpers().createSelfHitVfx(pos, normal) end,
	createRicochetVfx = function(pos, normal) ProjectileService.getVFXHelpers().createRicochetVfx(pos, normal) end,
	destroyProjectile = function(proj) ProjectileService.destroyProjectile(proj) end,
	sendCombatFeedback = function(ftype, pos, text, color, options)
		sendCombatFeedbackPayload(ftype, pos, text, color, false, options)
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
	onFinalMatchRewards = function(activeMatch, matchState)
		MatchRewardService.awardFinalMatchRewards(activeMatch, matchState)
	end,
	onMatchEnded = function(activeMatch)
		LobbyService.onMatchEnded(activeMatch)
	end,
	getDefaultPlayerParticipant = function()
		return playerParticipant
	end,
	getDefaultDuelOpponentParticipant = function()
		return player2Participant
	end,
	getDefaultTrainingOpponentParticipant = function()
		return dummyParticipant
	end,
})

ArenaCombatService.init({
	root = root,
	tankSpawnResetService = TankSpawnResetService,
	playerWalletService = PlayerWalletService,
	setPlayerMode = function(player, participant, mode, matchId, opponentTankId)
		LobbyService.setPlayerMode(player, participant, mode, matchId, opponentTankId)
	end,
	clearPlayerInput = function(player)
		PlayerPossessionService.getInputByPlayer()[player] = nil
	end,
	restoreTankColors = function(participant)
		if participant ~= nil then
			TankSpawnResetService.restoreTankColors(participant.TankId)
		end
	end,
	upgradeChoiceEvent = upgradeChoiceEvent,
})

BotService.init({
	Root = root,
	TankFactory = tankFactory,
	TankParticipantRegistry = TankParticipantRegistry,
	TankSpawnResetService = TankSpawnResetService,
	TankMovementService = TankMovementService,
	ProjectileService = ProjectileService,
	ArenaCombatService = ArenaCombatService,
	AddMovementIgnoredParticipant = function(participant)
		addParticipantToMovementIgnore(participant)
		refreshTankMovementRaycastFilter()
	end,
})

LobbyService.init({
	root = root,
	tankSpawnResetService = TankSpawnResetService,
	roundMatchService = RoundMatchService,
	projectileService = ProjectileService,
	arenaCombatService = ArenaCombatService,
	dummyParticipant = dummyParticipant,
})

TrainingBotService.init({
	roundMatchService = RoundMatchService,
	tankParticipantRegistry = TankParticipantRegistry,
	tankSpawnResetService = TankSpawnResetService,
	tankMovementService = TankMovementService,
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

local function handlePlayerAdded(player)
	task.spawn(function()
		PlayerWalletService.loadPlayer(player)
	end)

	PlayerPossessionService.assignPlayer(player)
end

-- Player Connections
for _, player in ipairs(Players:GetPlayers()) do handlePlayerAdded(player) end
Players.PlayerAdded:Connect(handlePlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PlayerWalletService.savePlayer(player)
	LobbyService.playerRemoving(player)
	PlayerPossessionService.removePlayer(player)
	PlayerWalletService.removePlayer(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerWalletService.savePlayer(player)
	end
end)

local function isDebugBotRequestAllowed(player)
	if DebugBotConfig.Enabled ~= true then
		return false
	end

	if RunService:IsStudio() then
		return true
	end

	for _, userId in ipairs(DebugBotConfig.AllowedUserIds or {}) do
		if userId == player.UserId then
			return true
		end
	end

	return false
end

local function isParticipantInList(participant, participants)
	for _, activeParticipant in ipairs(participants or {}) do
		if activeParticipant == participant then
			return true
		end
	end

	return false
end

local function handleDebugSpawnBotRequest(player)
	if not isDebugBotRequestAllowed(player) then
		return
	end

	local activeMatch = RoundMatchService.getActiveMatch()

	if activeMatch == nil then
		print("[DEBUG BOT] Spawn ignored: no active Training match.")
		return
	end

	if DebugBotConfig.SpawnOnlyInTraining ~= false and activeMatch.MatchMode ~= "Training" then
		print("[DEBUG BOT] Spawn ignored: active match is not Training.")
		return
	end

	if (tonumber(DebugBotConfig.MaxDebugBots) or 0) <= 0 then
		print("[DEBUG BOT] Spawn ignored: MaxDebugBots is 0.")
		return
	end

	if isParticipantInList(dummyParticipant, activeMatch.Participants) then
		print("[DEBUG BOT] Training dummy already active; no extra bot spawned.")
		return
	end

	print("[DEBUG BOT] Spawn request accepted, but dynamic bot spawning is deferred until BotParticipantFactory.")
end

local function handleDebugRemoveBotRequest(player)
	if not isDebugBotRequestAllowed(player) then
		return
	end

	local activeMatch = RoundMatchService.getActiveMatch()

	if activeMatch == nil or activeMatch.MatchMode ~= "Training" then
		print("[DEBUG BOT] Remove ignored: no active Training dummy.")
		return
	end

	print("[DEBUG BOT] Remove request ignored: Training dummy is owned by RoundMatchService v0.")
end

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

debugSpawnBotRequestEvent.OnServerEvent:Connect(handleDebugSpawnBotRequest)
debugRemoveBotRequestEvent.OnServerEvent:Connect(handleDebugRemoveBotRequest)

resetDummyRequestEvent.OnServerEvent:Connect(function(player)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
	local roundState = RoundMatchService.getRoundState()

	if participant ~= nil
		and participant.ParticipantState == LobbyService.MODE_IN_MATCH
		and (roundState == nil or roundState.Ended ~= true)
	then
		RoundMatchService.resetRound()
	end
end)

local lastInputReceivedLogTimes = {}
local lastInputAppliedLogTime = 0

tankInputEvent.OnServerEvent:Connect(function(player, inputData)
	local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
	local inputs = PlayerPossessionService.getInputByPlayer()

	if participant and participant.IsActive and LobbyService.canParticipantDrive(participant) then
		inputs[player] = {
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
	elseif participant ~= nil then
		inputs[player] = nil
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
		local turretYaw = participant.ControlState ~= nil and participant.ControlState.TurretYaw or 0
		local turretDirection = (CFrame.Angles(0, turretYaw, 0)).LookVector
		local requestedDirection = dir.Magnitude > 0.1 and dir.Unit or turretDirection
		ProjectileService.tryShoot(participant, SHOOT_USES_TURRET_FACING and turretDirection or requestedDirection)
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
				local currentBodyYaw = state.BodyYaw
				local steeringInputForYaw = input.Steer

				-- Reverse uses arcade car-style path control: A/D steer the backing path, not the tank nose.
				if INVERT_STEERING_WHEN_REVERSING and input.Throttle < -REVERSE_STEERING_DEAD_ZONE then
					steeringInputForYaw = -steeringInputForYaw
				end

				local desiredBodyYaw = currentBodyYaw - steeringInputForYaw * TURN_SPEED * deltaTime
				local arenaMoveSpeedMultiplier = 1

				if p.ParticipantState == LobbyService.MODE_IN_BATTLE_ARENA then
					arenaMoveSpeedMultiplier = math.max(0.1, tonumber(p.ArenaMoveSpeedMultiplier) or 1)
				end

				local moveSpeed = MOVE_SPEED
					* arenaMoveSpeedMultiplier
					* (input.Throttle < 0 and REVERSE_MOVE_SPEED_MULTIPLIER or 1)
				local desiredMove = (CFrame.Angles(0, desiredBodyYaw, 0).LookVector) * input.Throttle * moveSpeed * deltaTime
				local resolvedPos, resolvedBodyYaw = TankMovementService.resolveTankPose(
					state.Position,
					currentBodyYaw,
					desiredMove,
					desiredBodyYaw,
					{ TankId = p.TankId }
				)
				state.Position = resolvedPos
				state.BodyYaw = resolvedBodyYaw
				local targetTurretYaw = getYawFromAimPosition(state.Position, input.AimPosition, state.TurretYaw)
				state.TurretYaw = moveAngleTowards(state.TurretYaw, targetTurretYaw, TURRET_TURN_SPEED * deltaTime)
				TankSpawnResetService.layoutTank(p.Model, state.Position, state.BodyYaw, state.TurretYaw)

				if shouldLogApply then
					print(string.format("[SERVER] input applied to %s", p.TankId))
				end
			end
		end
	end

	TrainingBotService.update(deltaTime)
	ArenaCombatService.update(deltaTime)
	BotService.update(deltaTime)
	ProjectileService.updateProjectiles(deltaTime)
end)

print("[SERVER] StartMatch handler connected")
print("[WOB] Gameplay server started")
