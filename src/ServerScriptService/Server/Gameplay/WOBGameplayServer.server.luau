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
local AchievementService = require(script.Parent:WaitForChild("Stats"):WaitForChild("AchievementService"))
local WinnerPodiumService = require(script.Parent:WaitForChild("Stats"):WaitForChild("WinnerPodiumService"))
local PlayerWalletService = require(script.Parent:WaitForChild("Economy"):WaitForChild("PlayerWalletService"))
local KillRewardService = require(script.Parent:WaitForChild("Economy"):WaitForChild("KillRewardService"))
local CosmeticShopService = require(script.Parent:WaitForChild("Economy"):WaitForChild("CosmeticShopService"))
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
-- Update 0.2: temporary pickup weapons + ground pickups + breakable cover + maze.
local TemporaryWeaponService = require(script.Parent:WaitForChild("Weapons"):WaitForChild("TemporaryWeaponService"))
local ArenaPickupService = require(script.Parent:WaitForChild("Pickups"):WaitForChild("ArenaPickupService"))
local BreakableCoverService = require(script.Parent:WaitForChild("Pickups"):WaitForChild("BreakableCoverService"))
local ArenaMazeService = require(script.Parent:WaitForChild("Arena"):WaitForChild("ArenaMazeService"))
local ArenaSessionLifecycle = require(script.Parent:WaitForChild("Arena"):WaitForChild("ArenaSessionLifecycle"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local movementConfig = TankConfig.Movement or {}
local MOVE_SPEED = movementConfig.MoveSpeed
local MAX_SPEED = math.max(0, tonumber(movementConfig.MaxSpeed) or MOVE_SPEED)
local REVERSE_MOVE_SPEED_MULTIPLIER = movementConfig.ReverseMoveSpeedMultiplier or 1
local REVERSE_MAX_SPEED = math.max(0, tonumber(movementConfig.ReverseMaxSpeed) or (MAX_SPEED * REVERSE_MOVE_SPEED_MULTIPLIER))
local ACCELERATION = math.max(0, tonumber(movementConfig.Acceleration) or 120)
local REVERSE_ACCELERATION = math.max(0, tonumber(movementConfig.ReverseAcceleration) or ACCELERATION)
local DECELERATION = math.max(0, tonumber(movementConfig.Deceleration) or ACCELERATION)
local TURN_ACCELERATION = math.max(0, tonumber(movementConfig.TurnAcceleration) or 12)
local TURN_DECELERATION = math.max(0, tonumber(movementConfig.TurnDeceleration) or TURN_ACCELERATION)
local SHOT_RECOIL_IMPULSE = math.max(0, tonumber(movementConfig.ShotRecoilImpulse) or 0)
local SHOT_RECOIL_MAX_SPEED = math.max(0, tonumber(movementConfig.ShotRecoilMaxSpeed) or SHOT_RECOIL_IMPULSE)
local SHOT_RECOIL_DAMPING = math.max(0, tonumber(movementConfig.ShotRecoilDamping) or 0)
local INVERT_STEERING_WHEN_REVERSING = movementConfig.InvertSteeringWhenReversing == true
local REVERSE_STEERING_DEAD_ZONE = math.max(0, tonumber(movementConfig.ReverseSteeringDeadZone) or 0.05)
local TURN_SPEED = movementConfig.BodyTurnSpeedRadians
local turretConfig = TankConfig.Turret or {}
local TURRET_TURN_SPEED = turretConfig.TurnSpeedRadiansPerSecond
	or math.rad(turretConfig.TurnSpeedDegreesPerSecond or movementConfig.TurretTurnSpeedDegrees or 240)
local SHOOT_USES_TURRET_FACING = turretConfig.ShootUsesTurretFacing ~= false
	and movementConfig.ShootUsesTurretFacing ~= false
local DEBUG_INPUT = false
local SPAWN_STARTUP_TEST_TANKS = DebugCombatConfig.SpawnStartupTestTanks == true

local ARMOR_FOLDER_NAMES = {
	ArmorZones = true,
	Hitboxes = true,
}

local ARMOR_PART_NAMES = {
	FrontArmor = true,
	RearArmor = true,
	LeftArmor = true,
	RightArmor = true,
}

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
local arenaReviveRequestEvent = getOrCreateRemoteEvent("ArenaReviveRequestEvent")
local arenaFreeRespawnRequestEvent = getOrCreateRemoteEvent("ArenaFreeRespawnRequestEvent")
-- Etap 2: kill-feed broadcast. Server fires { Killer, Victim, Weapon } to all clients; a
-- client overlay shows "Killer ⚔ Victim". Display only -- no gameplay effect.
local killFeedEvent = getOrCreateRemoteEvent("KillFeedEvent")
-- Etap 4: achievement unlock toast (server -> one client). Display only.
local achievementToastEvent = getOrCreateRemoteEvent("AchievementToastEvent")
-- Shop remotes: client buys/equips, server pushes the catalog+ownership snapshot back.
local shopBuyEvent = getOrCreateRemoteEvent("ShopBuyEvent")
local shopEquipEvent = getOrCreateRemoteEvent("ShopEquipEvent")
local shopSyncEvent = getOrCreateRemoteEvent("ShopSyncEvent")

-- Folders
local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local wobRuntime = Workspace:FindFirstChild("WOB_Runtime") or Instance.new("Folder")
wobRuntime.Name = "WOB_Runtime"
wobRuntime.Parent = Workspace
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")

local function clearDisabledStartupTestTanks()
	if SPAWN_STARTUP_TEST_TANKS then
		return
	end

	for _, tankId in pairs(TankFactoryConfig.StartupParticipantIds or {}) do
		local model = testObjects:FindFirstChild(tankId)

		if model ~= nil and model:IsA("Model") then
			model:Destroy()
			print("[STARTUP] removed disabled startup test tank " .. tankId)
		end
	end
end

clearDisabledStartupTestTanks()

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

local function getRegisteredTankModelSet()
	local models = {}

	for _, participant in ipairs(TankParticipantRegistry.getParticipants()) do
		local model = TankParticipantRegistry.getParticipantPhysicalModel(participant)

		if model ~= nil then
			models[model] = true
		end
	end

	return models
end

local function isKnownTankTemplateModel(model)
	if model == nil or not model:IsA("Model") then
		return false
	end

	if model.Name == TankFactoryConfig.BaseTankTemplateName then
		return true
	end

	for _, tankId in pairs(TankFactoryConfig.LegacyTankIds or {}) do
		if model.Name == tankId then
			return true
		end
	end

	return false
end

local function isDescendantOfRegisteredTank(instance, registeredModels)
	local current = instance

	while current ~= nil and current ~= root do
		if current:IsA("Model") and registeredModels[current] == true then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isDescendantOfWorkspaceTemplate(instance)
	local model = instance:FindFirstAncestorWhichIsA("Model")

	return model ~= nil
		and model:IsDescendantOf(testObjects)
		and isKnownTankTemplateModel(model)
end

local function folderContainsArmorPart(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and ARMOR_PART_NAMES[child.Name] == true then
			return true
		end
	end

	return false
end

local function looksLikeOrphanArmorPart(part)
	if not part:IsA("BasePart") or ARMOR_PART_NAMES[part.Name] ~= true then
		return false
	end

	local parent = part.Parent

	return part:GetAttribute("WOBArmorHitbox") == true
		or part:GetAttribute("ArmorZone") ~= nil
		or (parent ~= nil and ARMOR_FOLDER_NAMES[parent.Name] == true)
		or parent == root
		or parent == testObjects
		or parent == runtime
end

local function cleanupOrphanArmorZones(reason)
	local registeredModels = getRegisteredTankModelSet()
	local removed = 0

	for _, instance in ipairs(root:GetDescendants()) do
		if instance:IsA("Folder")
			and ARMOR_FOLDER_NAMES[instance.Name] == true
			and folderContainsArmorPart(instance)
			and not isDescendantOfRegisteredTank(instance, registeredModels)
			and not isDescendantOfWorkspaceTemplate(instance)
		then
			instance:Destroy()
			removed += 1
		end
	end

	for _, instance in ipairs(root:GetDescendants()) do
		if looksLikeOrphanArmorPart(instance)
			and not isDescendantOfRegisteredTank(instance, registeredModels)
			and not isDescendantOfWorkspaceTemplate(instance)
		then
			instance:Destroy()
			removed += 1
		end
	end

	if removed > 0 then
		print("[ARMOR CLEANUP] removed " .. tostring(removed) .. " orphan armor object(s) reason=" .. tostring(reason or "Runtime"))
	end

	return removed
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

-- Startup PvP/test participants are dev-only. Training keeps one hidden target
-- participant because the current training loop expects a stable dummy.
local playerParticipant = nil
local player2Participant = nil

if SPAWN_STARTUP_TEST_TANKS then
	playerParticipant = spawnTankParticipant({
		TankId = TankFactoryConfig.StartupParticipantIds.Player,
		Role = TankRole.Player,
		TeamId = "Player",
		IsBot = false,
		IsPlayerTank = true,
		SpawnName = "PlayerSpawn",
		IsActive = false,
		StatsProfileId = TankStatsProfile.DuelNormalized,
	})
	player2Participant = spawnTankParticipant({
		TankId = TankFactoryConfig.StartupParticipantIds.Player2,
		Role = TankRole.DuelOpponent,
		TeamId = "Player2",
		IsBot = false,
		IsPlayerTank = true,
		SpawnName = "Player2Spawn",
		IsActive = false,
		StatsProfileId = TankStatsProfile.DuelNormalized,
	})
end

local dummyParticipant = spawnTankParticipant({
	TankId = (TankFactoryConfig.TrainingParticipantIds and TankFactoryConfig.TrainingParticipantIds.Dummy) or "Training_Dummy",
	Role = TankRole.Dummy,
	TeamId = "Dummy",
	IsBot = true,
	IsPlayerTank = false,
	SpawnName = "DummySpawn",
	IsActive = false,
	StatsProfileId = TankStatsProfile.TrainingDummy,
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
	body = (playerParticipant ~= nil and playerParticipant.Body) or (dummyParticipant ~= nil and dummyParticipant.Body) or nil,
	tankModels = tankMovementIgnoredModels,
	runtime = runtime,
	-- Workspace/WOB_Runtime holds the cloned ActiveArenaLayout walls (Update 0.2.x).
	arenaRuntimeRoot = wobRuntime,
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
		-- Shop: spawn with the player's equipped skin (defaults to "Default" if none).
		Loadout = { SkinId = CosmeticShopService.getEquippedSkin(player) },
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
local function getPlayerParticipant()
	if playerParticipant ~= nil then
		return playerParticipant
	end

	for _, participant in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
		if participant.OwnerPlayer ~= nil then
			return participant
		end
	end

	return nil
end

local function hasStaticDuelOpponentOwner()
	return player2Participant ~= nil and player2Participant.OwnerPlayer ~= nil
end

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

local function moveNumberTowards(currentValue, targetValue, maxDelta)
	if math.abs(targetValue - currentValue) <= maxDelta then
		return targetValue
	end

	return currentValue + (targetValue > currentValue and maxDelta or -maxDelta)
end

local function moveVectorTowards(currentValue, targetValue, maxDelta)
	local delta = targetValue - currentValue

	if delta.Magnitude <= maxDelta then
		return targetValue
	end

	return currentValue + delta.Unit * maxDelta
end

local function getFlatUnitDirection(direction)
	if typeof(direction) ~= "Vector3" then
		return nil
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		return nil
	end

	return flatDirection.Unit
end

local function applyShotRecoil(participant, shotDirection)
	if participant == nil
		or participant.OwnerPlayer == nil
		or participant.ControlState == nil
		or SHOT_RECOIL_IMPULSE <= 0
	then
		return
	end

	local flatDirection = getFlatUnitDirection(shotDirection)

	if flatDirection == nil then
		local bodyYaw = participant.ControlState.BodyYaw or 0
		flatDirection = (CFrame.Angles(0, bodyYaw, 0)).LookVector
	end

	local currentRecoil = participant.ControlState.RecoilVelocity

	if typeof(currentRecoil) ~= "Vector3" then
		currentRecoil = Vector3.zero
	end

	local nextRecoil = currentRecoil - flatDirection * SHOT_RECOIL_IMPULSE

	if SHOT_RECOIL_MAX_SPEED > 0 and nextRecoil.Magnitude > SHOT_RECOIL_MAX_SPEED then
		nextRecoil = nextRecoil.Unit * SHOT_RECOIL_MAX_SPEED
	end

	participant.ControlState.RecoilVelocity = nextRecoil
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
		payload.WeaponId = options.WeaponId -- Etap 3: lets the client pick a per-weapon shot sound.
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

-- Update 0.2: floating world-text feedback for pickups and weapon state changes.
-- Reuses the existing CombatFeedbackEvent billboard pipeline (no new remotes, no
-- screen-space HUD clutter).
local function notifyWeaponEvent(participant, text, color)
	local position = getParticipantVfxPosition(participant)

	if position == nil or text == nil then
		return
	end

	sendCombatFeedbackPayload(
		"PickupNotice",
		position + Vector3.new(0, 5, 0),
		text,
		color or Color3.fromRGB(180, 240, 255),
		false,
		{ Lifetime = 1.4, RiseDistance = 3 }
	)
end

-- Update 0.2: Rocket area-of-effect explosion. Damages live enemies within radius
-- (owner excluded, normal damage rules respected via LobbyService) and breaks nearby
-- cover props. Default-weapon projectiles never call this (no ExplosionRadius).
local function explodeProjectile(projectile, position)
	if typeof(position) ~= "Vector3" then
		return
	end

	local vfxHelpers = ProjectileService.getVFXHelpers()
	-- Rockets get their own detonation FX (falls back to the generic explosion if unset).
	if vfxHelpers.createRocketExplosion ~= nil then
		vfxHelpers.createRocketExplosion(position)
	else
		vfxHelpers.createDeathExplosion(position)
	end
	sendCombatFeedbackPayload("Explosion", position, "", Color3.fromRGB(255, 150, 60), true)

	local radius = math.max(1, tonumber(projectile.ExplosionRadius) or 0)
	local damage = math.max(0, tonumber(projectile.ExplosionDamage) or 0)

	if damage > 0 then
		for _, participant in ipairs(TankParticipantRegistry.getParticipants()) do
			if participant ~= projectile.OwnerParticipant
				and not TankParticipantRegistry.getParticipantIsDead(participant)
				and LobbyService.canDamageParticipant(projectile, participant) == true
			then
				local participantPosition = getParticipantVfxPosition(participant)

				if participantPosition ~= nil and (participantPosition - position).Magnitude <= radius then
					damageParticipant(participant, damage, projectile)
				end
			end
		end
	end

	BreakableCoverService.breakNear(position, radius)
end

-- Init temporary-weapon tracking (ammo, grant, reset) before projectiles use it.
TemporaryWeaponService.init({
	notify = notifyWeaponEvent,
})

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
	sendCombatFeedback = function(ftype, pos, text, color, audioOnly, weaponId)
		sendCombatFeedbackPayload(ftype, pos, text, color, audioOnly, weaponId ~= nil and { WeaponId = weaponId } or nil)
	end,
	onShotFired = function(participant, shotDirection)
		applyShotRecoil(participant, shotDirection)
	end,
	-- Update 0.2 temporary-weapon hooks.
	onWeaponShotConsumed = function(participant)
		TemporaryWeaponService.consumeShot(participant)
	end,
	onProjectileExploded = function(projectile, position)
		explodeProjectile(projectile, position)
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

-- Update 0.2 (fix pass): pickup/maze/breakable services are now ARENA-SCOPED. They
-- are initialized here but NOT started at boot. ArenaSessionLifecycle starts them
-- only when an arena session is actually active and tears them down on session end,
-- so nothing appears in the lobby and everything is cleaned on exit/reset/new run.
ArenaPickupService.init({
	tankParticipantRegistry = TankParticipantRegistry,
	temporaryWeaponService = TemporaryWeaponService,
	notify = notifyWeaponEvent,
	-- Etap 5: Shield pickup grants ReflectShield charges to the arena session.
	grantReflectShieldCharges = function(participant, amount)
		return ArenaCombatService.GrantReflectShieldCharges(participant, amount)
	end,
	playPickupFX = function(position)
		ProjectileService.getVFXHelpers().createImpactFlash(position)
		-- Etap 3: pickup-collected sound (display/audio only, reuses the feedback pipeline).
		if typeof(position) == "Vector3" then
			sendCombatFeedbackPayload("Pickup", position, "", Color3.fromRGB(180, 235, 255), true)
		end
	end,
})

ArenaSessionLifecycle.init({
	mazeService = ArenaMazeService,
	pickupService = ArenaPickupService,
	breakableService = BreakableCoverService,
	-- Maze walls spawned at runtime must also become projectile bounce surfaces.
	-- collectMapTargets() rebuilds the include list from the current TankMovement
	-- obstacle parts, which auto-invalidates when descendants of the arena root are
	-- added/removed.
	refreshProjectileTargets = function()
		ProjectileService.setMapRaycastTargets(collectMapTargets())
	end,
})

KillRewardService.init({
	playerWalletService = PlayerWalletService,
	roundMatchService = RoundMatchService,
	lobbyService = LobbyService,
	tankParticipantRegistry = TankParticipantRegistry,
})

-- Etap 4: leaderstats (Bolts / Kills / Best Level) + achievements + best-level record.
AchievementService.init({
	toastEvent = achievementToastEvent,
	grantBolts = function(player, amount, reason)
		PlayerWalletService.addBolts(player, amount, reason)
	end,
	getBoltsBalance = function(player)
		return PlayerWalletService.getBoltsBalance(player)
	end,
})

-- Etap 5: global winner podiums in the lobby (Arena Champion / Duel King).
WinnerPodiumService.init({
	-- Clone the base tank model for the winner display on the podium.
	getTankTemplate = function()
		local template = tankTemplateProvider:GetBaseTankTemplate()
		return template
	end,
	applySkin = function(model, skinId)
		TankCustomizationService.applySkin(model, skinId)
	end,
})

-- Shop: buy/equip tank skins with Bolts.
CosmeticShopService.init({
	buyEvent = shopBuyEvent,
	equipEvent = shopEquipEvent,
	syncEvent = shopSyncEvent,
	trySpendBolts = function(player, amount, reason)
		return PlayerWalletService.trySpendBolts(player, amount, reason)
	end,
	getBoltsBalance = function(player)
		return PlayerWalletService.getBoltsBalance(player)
	end,
	applySkinToCurrentTank = function(player, skinId)
		local participant = PlayerPossessionService.getPlayerParticipantByPlayer(player)
		if participant ~= nil then
			participant.Loadout = participant.Loadout or {}
			participant.Loadout.SkinId = skinId
			TankSpawnResetService.applyParticipantSkin(participant)
		end
	end,
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
	createShieldReflectVfx = function(pos, normal) ProjectileService.getVFXHelpers().createShieldReflectVfx(pos, normal) end,
	destroyProjectile = function(proj) ProjectileService.destroyProjectile(proj) end,
	sendCombatFeedback = function(ftype, pos, text, color, options)
		sendCombatFeedbackPayload(ftype, pos, text, color, false, options)
	end,
	damageParticipant = damageParticipant,
	canDamageParticipant = function(projectile, targetParticipant)
		return LobbyService.canDamageParticipant(projectile, targetParticipant)
	end,
	tryConsumeReflectShield = function(projectile, targetParticipant)
		return ArenaCombatService.TryConsumeReflectShield(projectile, targetParticipant)
	end,
})

-- Init RoundMatch Service
RoundMatchService.init(root, {
	-- Update 0.2.x: forward GameState transitions AND the match mode to the arena
	-- runtime. The lifecycle uses the mode to keep Duel (PvP) clean -- only Training
	-- spawns the maze/pickups/breakables. updateMatchMode() runs in onConfigureParticipants
	-- (before setGameState("Playing")), so getMatchMode() is current when this fires.
	onGameStateChanged = function(gameState)
		ArenaSessionLifecycle.onGameStateChanged(gameState, RoundMatchService.getMatchMode())
	end,
	onDestroyAllProjectiles = function() ProjectileService.destroyAllProjectiles() end,
	onConfigureParticipants = function()
		RoundMatchService.updateMatchMode()
		local activeMatch = RoundMatchService.getActiveMatch()
		TankSpawnResetService.configureActiveParticipants(
			RoundMatchService.getMatchMode(),
			hasStaticDuelOpponentOwner(),
			activeMatch ~= nil and activeMatch.Participants or nil
		)
		cleanupOrphanArmorZones("ConfigureParticipants")
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
		-- Etap 5: Duel King podium counts COMPLETED DUELS per human player. PvP only.
		if RoundMatchService.getMatchMode() == RoundMatchService.MATCH_MODE_PVP
			and activeMatch ~= nil
			and typeof(activeMatch.Participants) == "table"
		then
			local counted = {}
			for _, participant in ipairs(activeMatch.Participants) do
				local player = participant ~= nil and participant.OwnerPlayer or nil
				if player ~= nil and not counted[player.UserId] then
					counted[player.UserId] = true
					WinnerPodiumService.submitDuelCompletion(player.Name, CosmeticShopService.getEquippedSkin(player))
				end
			end
		end
	end,
	onMatchEnded = function(activeMatch)
		LobbyService.onMatchEnded(activeMatch)
	end,
	getDefaultPlayerParticipant = function()
		return getPlayerParticipant()
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
	playArenaAudio = function(_session, effectKey, position)
		sendCombatFeedbackPayload(effectKey, position, "", Color3.fromRGB(180, 235, 255), true)
	end,
	-- Update 0.2 (fix pass): arena session lifecycle hooks. These drive maze/pickup/
	-- breakable spawn + teardown so nothing appears in the lobby.
	arenaSessionStarted = function(_player)
		-- Movement-bounds fix: clamp the tank to the actual BattleArena floor extents (not
		-- the global world-default box, which cut off the lower part of the arena floor).
		TankMovementService.applyBattleArenaMovementBounds()
		ArenaSessionLifecycle.onBattleArenaEnter()
	end,
	arenaSessionEnded = function(_player)
		TankMovementService.resetMovementBoundsToWorldDefault()
		ArenaSessionLifecycle.onBattleArenaLeave()
	end,
	upgradeChoiceEvent = upgradeChoiceEvent,
	reviveRequestEvent = arenaReviveRequestEvent,
	freeRespawnRequestEvent = arenaFreeRespawnRequestEvent,
	-- Etap 2: kill-feed broadcast. Resolves display names from the tank models and fires to
	-- all clients. Display only.
	broadcastKill = function(killerParticipant, victimParticipant, weaponId)
		local function nameOf(participant)
			if participant == nil then
				return nil
			end
			local model = participant.Model
			local n = model ~= nil and model:GetAttribute("OwnerDisplayName") or nil
			if typeof(n) == "string" and n ~= "" then
				return n
			end
			return participant.IsBot == true and "BOT" or tostring(participant.TankId)
		end

		killFeedEvent:FireAllClients({
			Killer = nameOf(killerParticipant),
			Victim = nameOf(victimParticipant),
			Weapon = weaponId,
		})
	end,
	-- Etap 4: achievement hooks.
	onArenaKill = function(context)
		AchievementService.onKill(context)
	end,
	onArenaLevel = function(player, level)
		AchievementService.onArenaLevel(player, level)
		-- Etap 5: submit to the global Arena Champion podium (record = highest level).
		WinnerPodiumService.submit("Arena", player.Name, level, CosmeticShopService.getEquippedSkin(player))
	end,
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

local DEBUG_TEMPLATE_MODEL_NAMES = {
	[TankFactoryConfig.BaseTankTemplateName] = true,
	[TankFactoryConfig.LegacyTankIds.Player] = true,
	[TankFactoryConfig.LegacyTankIds.DuelOpponent] = true,
	[TankFactoryConfig.LegacyTankIds.Dummy] = true,
}

local function hideDebugPart(part)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function isSpawnMarkerPart(part)
	if not part:IsA("BasePart") then
		return false
	end

	local parent = part.Parent

	return parent ~= nil
		and parent.Name == "SpawnPoints"
		and (
			string.match(part.Name, "^LobbySpawn%d+$") ~= nil
			or string.match(part.Name, "^ArenaSpawn%d+$") ~= nil
			or part.Name == "PlayerSpawn"
			or part.Name == "Player2Spawn"
			or part.Name == "DummySpawn"
		)
end

local function hideTemplateModel(model)
	if model == nil or not model:IsA("Model") then
		return
	end

	if model:GetAttribute("TankId") ~= nil or model:GetAttribute("IsActive") ~= nil then
		return
	end

	model:SetAttribute("WOBDebugTemplateHidden", true)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			hideDebugPart(descendant)
		end
	end
end

local function hideSceneDebugClutter()
	if DebugCombatConfig.SceneDebugVisuals == true then
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if isSpawnMarkerPart(descendant) then
			hideDebugPart(descendant)
		end
	end

	for templateName in pairs(DEBUG_TEMPLATE_MODEL_NAMES) do
		hideTemplateModel(testObjects:FindFirstChild(templateName))
	end
end

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
			hasStaticDuelOpponentOwner(),
			activeMatch ~= nil and activeMatch.Participants or nil
		)
	end,
})

-- Initial Setup
local function captureParticipantColors(participant)
	if participant ~= nil then
		TankSpawnResetService.captureTankColors(participant.TankId, participant.Model)
	end
end

local function applySpawnIfParticipant(participant, spawnTransform)
	if participant ~= nil and spawnTransform ~= nil then
		TankSpawnResetService.applySpawnToParticipant(participant, spawnTransform)
	end
end

local function hideParticipantModel(participant)
	if participant ~= nil then
		TankParticipantRegistry.setParticipantModelVisible(participant, false)
	end
end

captureParticipantColors(playerParticipant)
captureParticipantColors(dummyParticipant)
captureParticipantColors(player2Participant)

local transforms = TankSpawnResetService.getAllSpawnTransforms()
applySpawnIfParticipant(playerParticipant, transforms.Player)
applySpawnIfParticipant(dummyParticipant, transforms.Dummy)
applySpawnIfParticipant(player2Participant, transforms.Player2)
hideParticipantModel(playerParticipant)
hideParticipantModel(dummyParticipant)
hideParticipantModel(player2Participant)
hideSceneDebugClutter()
cleanupOrphanArmorZones("InitialSetup")

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

		local state = participant.ControlState

		local origin = participant.ShootPoint.Position
		local dir = typeof(aimPosition) == "Vector3" and (Vector3.new(aimPosition.X - origin.X, 0, aimPosition.Z - origin.Z)) or Vector3.new(0,0,-1)
		local turretYaw = state ~= nil and state.TurretYaw or 0
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
			local state = p.ControlState
			local fallbackAimDirection = (CFrame.Angles(0, state.TurretYaw or state.BodyYaw or 0, 0)).LookVector
			local input = inputs[p.OwnerPlayer] or {
				Throttle = 0,
				Steer = 0,
				AimPosition = state.Position + fallbackAimDirection * 20,
			}
			local currentBodyYaw = state.BodyYaw
			local steeringInputForYaw = input.Steer
			local throttle = math.clamp(tonumber(input.Throttle) or 0, -1, 1)

			-- Reverse uses arcade car-style path control: A/D steer the backing path, not the tank nose.
			if INVERT_STEERING_WHEN_REVERSING and throttle < -REVERSE_STEERING_DEAD_ZONE then
				steeringInputForYaw = -steeringInputForYaw
			end

			local targetTurnRate = -steeringInputForYaw * TURN_SPEED
			local currentTurnRate = tonumber(state.CurrentTurnRate) or 0
			local turnRate = math.abs(targetTurnRate) > 0.001 and TURN_ACCELERATION or TURN_DECELERATION
			state.CurrentTurnRate = moveNumberTowards(currentTurnRate, targetTurnRate, turnRate * deltaTime)
			local desiredBodyYaw = currentBodyYaw + state.CurrentTurnRate * deltaTime
			local arenaMoveSpeedMultiplier = 1

			if p.ParticipantState == LobbyService.MODE_IN_BATTLE_ARENA then
				arenaMoveSpeedMultiplier = math.max(0.1, tonumber(p.ArenaMoveSpeedMultiplier) or 1)
			end

			local targetMaxSpeed = throttle < 0 and REVERSE_MAX_SPEED or MAX_SPEED
			local targetSpeed = throttle * targetMaxSpeed * arenaMoveSpeedMultiplier
			local currentSpeed = tonumber(state.CurrentSpeed) or 0
			local speedRate = DECELERATION

			if math.abs(throttle) > 0.001 then
				speedRate = throttle < 0 and REVERSE_ACCELERATION or ACCELERATION

				if currentSpeed ~= 0 and (currentSpeed > 0) ~= (targetSpeed > 0) then
					speedRate = DECELERATION + speedRate
				end
			end

			state.CurrentSpeed = moveNumberTowards(currentSpeed, targetSpeed, speedRate * deltaTime)

			local recoilVelocity = state.RecoilVelocity
			if typeof(recoilVelocity) ~= "Vector3" then
				recoilVelocity = Vector3.zero
			end

			local recoilMove = recoilVelocity * deltaTime
			state.RecoilVelocity = SHOT_RECOIL_DAMPING > 0
				and moveVectorTowards(recoilVelocity, Vector3.zero, SHOT_RECOIL_DAMPING * deltaTime)
				or Vector3.zero

			local desiredMove = (CFrame.Angles(0, desiredBodyYaw, 0).LookVector) * state.CurrentSpeed * deltaTime
				+ recoilMove
			local resolvedPos, resolvedBodyYaw = TankMovementService.resolveTankPose(
				state.Position,
				currentBodyYaw,
				desiredMove,
				desiredBodyYaw,
				{ TankId = p.TankId }
			)
			state.Position = resolvedPos
			state.BodyYaw = resolvedBodyYaw

			-- Free turret aiming for ALL modes (BattleArena included): the barrel rotates
			-- toward the aim point, independent of the body. (Reverted the BattleArena
			-- cannon-forward lock so the dome/barrel turns in the arena again.)
			local targetTurretYaw = getYawFromAimPosition(state.Position, input.AimPosition, state.TurretYaw)
			state.TurretYaw = moveAngleTowards(state.TurretYaw, targetTurretYaw, TURRET_TURN_SPEED * deltaTime)

			TankSpawnResetService.layoutTank(p.Model, state.Position, state.BodyYaw, state.TurretYaw)
			-- Movement trail: only smoke when actually driving (speed above a small threshold).
			TankSpawnResetService.setTrailActive(p, math.abs(tonumber(state.CurrentSpeed) or 0) > 2)

			if shouldLogApply then
				print(string.format("[SERVER] input applied to %s", p.TankId))
			end
		elseif p.ControlState ~= nil then
			p.ControlState.CurrentSpeed = 0
			p.ControlState.CurrentTurnRate = 0
			TankSpawnResetService.setTrailActive(p, false)
			p.ControlState.RecoilVelocity = Vector3.zero
		end
	end

	TrainingBotService.update(deltaTime)
	ArenaCombatService.update(deltaTime)
	BotService.update(deltaTime)
	ProjectileService.updateProjectiles(deltaTime)
end)

print("[SERVER] StartMatch handler connected")
print("[WOB] Gameplay server started")
