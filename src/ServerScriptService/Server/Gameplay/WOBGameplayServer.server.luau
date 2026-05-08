-- Rojo-managed replacement for Studio-owned WOBGameplayServer.
-- Before Play Mode, disable old ServerScriptService/Services/WOBGameplayServer in Roblox Studio.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankConfig = require(configs:WaitForChild("TankConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local ProjectileCatalog = require(configs:WaitForChild("ProjectileCatalog"))
local MatchConfig = require(configs:WaitForChild("MatchConfig"))
local RicochetMath = require(shared:WaitForChild("Utils"):WaitForChild("RicochetMath"))
local PlayerTankSpawner = require(script.Parent:WaitForChild("PlayerTankSpawner"))
local PersistentPlayerStatsService = require(script.Parent:WaitForChild("Stats"):WaitForChild("PersistentPlayerStatsService"))
local primaryWeaponConfig = WeaponConfig.PrimaryWeapon
local projectileTypeId = primaryWeaponConfig.ProjectileTypeId or ProjectileCatalog.DefaultProjectileTypeId
local projectileConfig = ProjectileCatalog.Projectiles[projectileTypeId]
	or ProjectileCatalog.Projectiles[ProjectileCatalog.DefaultProjectileTypeId]

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

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")
local ricochetWalls = map:FindFirstChild("RicochetWalls")
local cover = map:FindFirstChild("Cover")

local projectileFolder = runtime:FindFirstChild("Projectiles") or Instance.new("Folder")
projectileFolder.Name = "Projectiles"
projectileFolder.Parent = runtime

local vfxFolder = runtime:FindFirstChild("VFX") or Instance.new("Folder")
vfxFolder.Name = "VFX"
vfxFolder.Parent = runtime

local playerTank = testObjects:WaitForChild("PlayerTankPrototype")
local dummyTank = testObjects:WaitForChild("DummyTank")

local body = playerTank:WaitForChild("Body")
local turret = playerTank:WaitForChild("Turret")
local barrel = playerTank:WaitForChild("Barrel")
local shootPoint = playerTank:WaitForChild("ShootPoint")
local hitboxes = playerTank:WaitForChild("Hitboxes")

local dummyBody = dummyTank:WaitForChild("Body")
local dummyTurret = dummyTank:WaitForChild("Turret")
local dummyBarrel = dummyTank:WaitForChild("Barrel")
local dummyShootPoint = dummyTank:WaitForChild("ShootPoint")
local dummyHitboxes = dummyTank:WaitForChild("Hitboxes")

local player2TankParts = PlayerTankSpawner.getOrCreateRuntimePlayerTank(playerTank, testObjects, "Player2TankPrototype")
local player2Tank = player2TankParts.Model
local player2Body = player2TankParts.Body
local player2Turret = player2TankParts.Turret
local player2Barrel = player2TankParts.Barrel
local player2ShootPoint = player2TankParts.ShootPoint
local player2Hitboxes = player2TankParts.Hitboxes

local MAX_PLAYER_HEALTH = 100
local MAX_DUMMY_HEALTH = 100

local armorHitboxNames = {
	FrontArmor = true,
	RearArmor = true,
	LeftArmor = true,
	RightArmor = true,
}

local tankParticipants = {}
local tankParticipantsById = {}
local tankParticipantsByModel = {}

local function registerTankParticipant(participant)
	table.insert(tankParticipants, participant)
	tankParticipantsById[participant.TankId] = participant
	tankParticipantsByModel[participant.Model] = participant

	return participant
end

local playerParticipant = registerTankParticipant({
	TankId = "PlayerTankPrototype",
	Model = playerTank,
	Body = body,
	Turret = turret,
	Barrel = barrel,
	ShootPoint = shootPoint,
	Hitboxes = hitboxes,
	OwnerPlayer = nil,
	OwnerUserId = nil,
	TeamId = "Player",
	IsBot = false,
	SpawnName = "PlayerSpawn",
	SpawnTransform = nil,
	WeaponTypeId = primaryWeaponConfig.Id,
	WeaponConfig = primaryWeaponConfig,
	LastShotTime = 0,
	WeaponReadyAt = 0,
	WeaponState = {
		LastShotTime = 0,
		WeaponReadyAt = 0,
	},
	Health = MAX_PLAYER_HEALTH,
	MaxHealth = MAX_PLAYER_HEALTH,
	DefaultMaxHealth = MAX_PLAYER_HEALTH,
	IsDead = false,
	IsActive = true,
})

local dummyParticipant = registerTankParticipant({
	TankId = "DummyTank",
	Model = dummyTank,
	Body = dummyBody,
	Turret = dummyTurret,
	Barrel = dummyBarrel,
	ShootPoint = dummyShootPoint,
	Hitboxes = dummyHitboxes,
	OwnerPlayer = nil,
	OwnerUserId = nil,
	TeamId = "Dummy",
	IsBot = true,
	SpawnName = "DummySpawn",
	SpawnTransform = nil,
	WeaponTypeId = primaryWeaponConfig.Id,
	WeaponConfig = primaryWeaponConfig,
	LastShotTime = 0,
	WeaponReadyAt = 0,
	WeaponState = {
		LastShotTime = 0,
		WeaponReadyAt = 0,
	},
	Health = MAX_DUMMY_HEALTH,
	MaxHealth = MAX_DUMMY_HEALTH,
	DefaultMaxHealth = MAX_DUMMY_HEALTH,
	IsDead = false,
	IsActive = true,
})

local player2Participant = registerTankParticipant({
	TankId = "Player2TankPrototype",
	Model = player2Tank,
	Body = player2Body,
	Turret = player2Turret,
	Barrel = player2Barrel,
	ShootPoint = player2ShootPoint,
	Hitboxes = player2Hitboxes,
	OwnerPlayer = nil,
	OwnerUserId = nil,
	TeamId = "Player2",
	IsBot = false,
	SpawnName = "Player2Spawn",
	SpawnTransform = nil,
	WeaponTypeId = primaryWeaponConfig.Id,
	WeaponConfig = primaryWeaponConfig,
	LastShotTime = 0,
	WeaponReadyAt = 0,
	WeaponState = {
		LastShotTime = 0,
		WeaponReadyAt = 0,
	},
	Health = MAX_PLAYER_HEALTH,
	MaxHealth = MAX_PLAYER_HEALTH,
	DefaultMaxHealth = MAX_PLAYER_HEALTH,
	IsDead = false,
	IsActive = false,
})

local function getParticipantFromModel(model)
	return tankParticipantsByModel[model]
end

local function getParticipantFromArmorHitbox(hitInstance)
	if hitInstance == nil
		or not hitInstance:IsA("BasePart")
		or armorHitboxNames[hitInstance.Name] ~= true
	then
		return nil
	end

	local participant = getParticipantFromModel(hitInstance:FindFirstAncestorWhichIsA("Model"))

	if participant ~= nil
		and participant.Hitboxes ~= nil
		and hitInstance:IsDescendantOf(participant.Hitboxes)
	then
		return participant
	end

	return nil
end

local function isArmorHitbox(instance)
	return getParticipantFromArmorHitbox(instance) ~= nil
end

local function getArmorZoneFromHitbox(hitInstance)
	if hitInstance == nil then
		return nil
	elseif hitInstance.Name == "FrontArmor" then
		return "Front"
	elseif hitInstance.Name == "RearArmor" then
		return "Rear"
	elseif hitInstance.Name == "LeftArmor" or hitInstance.Name == "RightArmor" then
		return "Side"
	end

	return nil
end

local MOVE_SPEED = TankConfig.Movement.MoveSpeed
local REVERSE_MOVE_SPEED_MULTIPLIER = TankConfig.Movement.ReverseMoveSpeedMultiplier or 1
local TURN_SPEED = TankConfig.Movement.BodyTurnSpeedRadians
local TANK_ARMOR = TankConfig.Armor
local SHOOT_COOLDOWN = primaryWeaponConfig.ShootCooldown

local PROJECTILE_SPEED = projectileConfig.Speed
local PROJECTILE_MAX_DAMAGE = projectileConfig.MaxDamage
local PROJECTILE_PENETRATION = projectileConfig.Penetration
local PROJECTILE_MAX_BOUNCES = projectileConfig.MaxRicochets
local PROJECTILE_BOUNCE_SPEED_MULTIPLIER = projectileConfig.BounceSpeedMultiplier
local PROJECTILE_DAMAGE_MULTIPLIER = projectileConfig.DamageMultiplierPerBounce
local PROJECTILE_MIN_SPEED = projectileConfig.MinProjectileSpeed
local PROJECTILE_LIFETIME = projectileConfig.Lifetime
local PROJECTILE_RICOCHET_OFFSET = 0.45
local ARMOR_HITBOX_PADDING = TANK_ARMOR.ArmorHitboxPadding or 0.75
local ARMOR_HITBOX_THICKNESS = TANK_ARMOR.ArmorHitboxThickness or 1.2
local ARMOR_HITBOX_HEIGHT = TANK_ARMOR.ArmorHitboxHeight or 5.4
local ARMOR_HITBOX_Y_OFFSET = TANK_ARMOR.ArmorHitboxYOffset or 1.4
local ARMOR_HITBOXES_VISIBLE = TANK_ARMOR.ArmorHitboxesVisible == true
local ARMOR_HITBOX_TRANSPARENCY = TANK_ARMOR.ArmorHitboxTransparency or 0.4
local ARMOR_HITBOX_MATERIAL = TANK_ARMOR.ArmorHitboxMaterial or Enum.Material.SmoothPlastic
local FRONT_ARMOR_COLOR = TANK_ARMOR.FrontArmorColor or Color3.fromRGB(80, 255, 120)
local REAR_ARMOR_COLOR = TANK_ARMOR.RearArmorColor or Color3.fromRGB(255, 90, 90)
local SIDE_ARMOR_COLOR = TANK_ARMOR.SideArmorColor or Color3.fromRGB(255, 220, 80)

local ROUND_RESULT_PLAYING = "Playing"
local ROUND_RESULT_WIN = "Win"
local ROUND_RESULT_LOSE = "Lose"
local MATCH_RESULT_PLAYER_WIN = "PlayerMatchWin"
local MATCH_RESULT_DUMMY_WIN = "DummyMatchWin"
local GAME_STATE_MENU = "Menu"
local GAME_STATE_PLAYING = "Playing"
local GAME_STATE_RESULT = "Result"
local MATCH_MODE_TRAINING = "Training"
local MATCH_MODE_PVP = "PvP"
local MATCH_SERIES_ENABLED = MatchConfig.EnableMatchSeries == true
local MATCH_TARGET_WINS = math.max(1, math.floor(tonumber(MatchConfig.TargetWins) or 3))

local PLAYER_INITIAL_POSITION = TankConfig.PlayerInitialState.Position
local DUMMY_INITIAL_POSITION = TankConfig.DummyInitialState.Position
local PLAYER2_INITIAL_POSITION = DUMMY_INITIAL_POSITION

local TANK_MOVEMENT_CAST_PADDING = -0.25
local TANK_MOVEMENT_CAST_HEIGHT = 1.4
local TANK_MOVEMENT_CAST_Y_OFFSET = 2
local TANK_MOVEMENT_EPSILON = 0.03
local TANK_UNSTICK_DISTANCE_EPSILON = 0.02
local WALL_BLOCK_PRINT_INTERVAL = 0.5

local function getYawFromFlatDirection(direction, fallbackYaw)
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.001 then
		return fallbackYaw
	end

	local unit = flat.Unit

	return math.atan2(-unit.X, -unit.Z)
end

local function getSpawnPart(spawnName)
	local spawnPointsFolder = map:FindFirstChild("SpawnPoints")

	if spawnPointsFolder == nil then
		return nil
	end

	local spawnPart = spawnPointsFolder:FindFirstChild(spawnName)

	if spawnPart ~= nil and spawnPart:IsA("BasePart") then
		return spawnPart
	end

	return nil
end

local function formatVector3(vector)
	return "("
		.. string.format("%.1f", vector.X)
		.. ", "
		.. string.format("%.1f", vector.Y)
		.. ", "
		.. string.format("%.1f", vector.Z)
		.. ")"
end

local function makeSpawnTransform(position, yaw, source)
	return {
		Position = position,
		BodyYaw = yaw,
		TurretYaw = yaw,
		Source = source,
	}
end

local function getSpawnLabel(spawnName)
	if spawnName == "PlayerSpawn" then
		return "Player"
	elseif spawnName == "Player2Spawn" then
		return "Player2"
	elseif spawnName == "DummySpawn" then
		return "Dummy"
	end

	return spawnName
end

local function getSpawnTransform(spawnName, fallbackPosition, fallbackTargetPosition)
	local label = getSpawnLabel(spawnName)
	local fallbackYaw = getYawFromFlatDirection(fallbackTargetPosition - fallbackPosition, 0)
	local spawnPart = getSpawnPart(spawnName)

	if spawnPart == nil then
		local fallbackTransform = makeSpawnTransform(fallbackPosition, fallbackYaw, "Fallback")

		print(
			"[SPAWN] "
				.. label
				.. " using fallback pos="
				.. formatVector3(fallbackTransform.Position)
				.. " yaw="
				.. string.format("%.1f", math.deg(fallbackTransform.BodyYaw))
		)

		return fallbackTransform
	end

	local position = Vector3.new(spawnPart.Position.X, 0, spawnPart.Position.Z)
	local yaw = getYawFromFlatDirection(spawnPart.CFrame.LookVector, fallbackYaw)
	local transform = makeSpawnTransform(position, yaw, "SpawnPoint")

	print(
		"[SPAWN] "
			.. label
			.. " from SpawnPoint "
			.. spawnName
			.. " pos="
			.. formatVector3(transform.Position)
			.. " yaw="
			.. string.format("%.1f", math.deg(transform.BodyYaw))
	)

	return transform
end

local function getPlayerSpawnTransform()
	return getSpawnTransform("PlayerSpawn", PLAYER_INITIAL_POSITION, DUMMY_INITIAL_POSITION)
end

local function getDummySpawnTransform()
	return getSpawnTransform("DummySpawn", DUMMY_INITIAL_POSITION, PLAYER_INITIAL_POSITION)
end

local function getPlayer2SpawnTransform()
	return getSpawnTransform("Player2Spawn", PLAYER2_INITIAL_POSITION, PLAYER_INITIAL_POSITION)
end

local resolvedArmorHitboxMaterial = nil

local function getArmorHitboxMaterial()
	if resolvedArmorHitboxMaterial ~= nil then
		return resolvedArmorHitboxMaterial
	end

	if typeof(ARMOR_HITBOX_MATERIAL) == "EnumItem"
		and ARMOR_HITBOX_MATERIAL.EnumType == Enum.Material
	then
		resolvedArmorHitboxMaterial = ARMOR_HITBOX_MATERIAL
		return resolvedArmorHitboxMaterial
	end

	if typeof(ARMOR_HITBOX_MATERIAL) == "string" then
		local success, material = pcall(function()
			return Enum.Material[ARMOR_HITBOX_MATERIAL]
		end)

		if success and material ~= nil then
			resolvedArmorHitboxMaterial = material
			return resolvedArmorHitboxMaterial
		end

		warn(
			"[ARMOR] Unknown ArmorHitboxMaterial "
				.. tostring(ARMOR_HITBOX_MATERIAL)
				.. "; using SmoothPlastic"
		)
	end

	resolvedArmorHitboxMaterial = Enum.Material.SmoothPlastic
	return resolvedArmorHitboxMaterial
end

local controllingPlayer = nil
local playerParticipants = {
	playerParticipant,
	player2Participant,
}
local playerParticipantByPlayer = {}
local inputByPlayer = {}
local projectiles = {}
local lastWallBlockPrintTime = 0
local matchMode = MATCH_MODE_TRAINING

local roundState = {
	Ended = false,
	Result = ROUND_RESULT_PLAYING,
	WinnerTankId = "",
	LoserTankId = "",
}

local gameState = GAME_STATE_MENU

local matchState = {
	PlayerWins = 0,
	DummyWins = 0,
	RoundNumber = 1,
	TargetWins = MATCH_TARGET_WINS,
	MatchEnded = false,
	MatchResult = "",
}

local matchStatDefaults = {
	{ Name = "StatsShotsFired", Value = 0 },
	{ Name = "StatsHits", Value = 0 },
	{ Name = "StatsRicochets", Value = 0 },
	{ Name = "StatsRicochetHits", Value = 0 },
	{ Name = "StatsSelfHits", Value = 0 },
	{ Name = "StatsDamageDealt", Value = 0 },
	{ Name = "StatsDamageTaken", Value = 0 },
	{ Name = "StatsRoundsWon", Value = 0 },
	{ Name = "StatsRoundsLost", Value = 0 },
	{ Name = "StatsMatchResult", Value = "" },
}

local matchStats = {}

local function setMatchStat(name, value)
	matchStats[name] = value
	root:SetAttribute(name, value)
end

local function incrementMatchStat(name, amount)
	setMatchStat(name, (matchStats[name] or 0) + (amount or 1))
end

local function resetRuntimeMatchStats()
	for _, stat in ipairs(matchStatDefaults) do
		setMatchStat(stat.Name, stat.Value)
	end
end

local function isPlayerProjectile(projectile)
	return projectile.OwnerParticipant == playerParticipant
end

local function recordShotFired(participant)
	if participant == playerParticipant then
		incrementMatchStat("StatsShotsFired", 1)
	end
end

local function recordProjectileRicochet(projectile)
	if isPlayerProjectile(projectile) then
		incrementMatchStat("StatsRicochets", 1)
	end
end

local function recordProjectileTankHitStats(projectile)
	if isPlayerProjectile(projectile) then
		incrementMatchStat("StatsHits", 1)

		if projectile.BounceCount > 0 then
			incrementMatchStat("StatsRicochetHits", 1)
		end
	end
end

local function recordProjectileDamageStats(projectile, targetParticipant, damage)
	if isPlayerProjectile(projectile) then
		if targetParticipant == playerParticipant then
			incrementMatchStat("StatsSelfHits", 1)
			incrementMatchStat("StatsDamageTaken", damage)
		else
			incrementMatchStat("StatsDamageDealt", damage)
		end
	elseif targetParticipant == playerParticipant then
		incrementMatchStat("StatsDamageTaken", damage)
	end
end

local function recordRoundStats(result)
	if result == ROUND_RESULT_WIN then
		incrementMatchStat("StatsRoundsWon", 1)
	elseif result == ROUND_RESULT_LOSE then
		incrementMatchStat("StatsRoundsLost", 1)
	end
end

local function getRuntimeMatchStatsSnapshot()
	return {
		MatchResult = matchStats.StatsMatchResult or matchState.MatchResult,
		StatsShotsFired = matchStats.StatsShotsFired or 0,
		StatsHits = matchStats.StatsHits or 0,
		StatsRicochets = matchStats.StatsRicochets or 0,
		StatsRicochetHits = matchStats.StatsRicochetHits or 0,
		StatsSelfHits = matchStats.StatsSelfHits or 0,
		StatsDamageDealt = matchStats.StatsDamageDealt or 0,
		StatsDamageTaken = matchStats.StatsDamageTaken or 0,
		StatsRoundsWon = matchStats.StatsRoundsWon or 0,
		StatsRoundsLost = matchStats.StatsRoundsLost or 0,
	}
end

local function persistFinalMatchStats()
	local ownerPlayer = playerParticipant.OwnerPlayer

	if ownerPlayer == nil then
		return
	end

	local statsSnapshot = getRuntimeMatchStatsSnapshot()

	task.spawn(function()
		PersistentPlayerStatsService.saveMatchResult(ownerPlayer, statsSnapshot)
	end)
end

local function setGameState(nextGameState)
	if nextGameState ~= GAME_STATE_MENU
		and nextGameState ~= GAME_STATE_PLAYING
		and nextGameState ~= GAME_STATE_RESULT
	then
		warn("[GAMESTATE] Ignoring unknown state " .. tostring(nextGameState))
		return
	end

	gameState = nextGameState
	root:SetAttribute("GameState", gameState)
end

local initialPlayerSpawnState = getPlayerSpawnTransform()
playerParticipant.SpawnTransform = initialPlayerSpawnState

local tankState = {
	Position = initialPlayerSpawnState.Position,
	BodyYaw = initialPlayerSpawnState.BodyYaw,
	TurretYaw = initialPlayerSpawnState.TurretYaw,
}
playerParticipant.ControlState = tankState

local initialPlayer2SpawnState = getPlayer2SpawnTransform()
player2Participant.SpawnTransform = initialPlayer2SpawnState

local player2TankState = {
	Position = initialPlayer2SpawnState.Position,
	BodyYaw = initialPlayer2SpawnState.BodyYaw,
	TurretYaw = initialPlayer2SpawnState.TurretYaw,
}
player2Participant.ControlState = player2TankState

local function setPartPhysics(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false

			if isArmorHitbox(descendant) then
				descendant.CanCollide = false
				descendant.CanQuery = true
			else
				descendant.CanQuery = false
			end
		end
	end
end

setPartPhysics(playerTank)
setPartPhysics(dummyTank)
setPartPhysics(player2Tank)

local function capturePartColors(model)
	local colorsByPart = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			colorsByPart[descendant] = descendant.Color
		end
	end

	return colorsByPart
end

local playerTankPartColors = capturePartColors(playerTank)
local dummyTankPartColors = capturePartColors(dummyTank)
local player2TankPartColors = capturePartColors(player2Tank)

local function restorePartColors(colorsByPart)
	for part, color in pairs(colorsByPart) do
		if part.Parent ~= nil then
			part.Color = color
		end
	end
end

local function darkenTank(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = Color3.fromRGB(30, 30, 30)
		end
	end
end

local function setParticipantModelVisible(participant, isVisible)
	participant.IsActive = isVisible == true
	participant.Model:SetAttribute("TankId", participant.TankId)
	participant.Model:SetAttribute("IsActive", participant.IsActive)
	participant.Model:SetAttribute("TeamId", participant.TeamId)
	participant.Model:SetAttribute("IsBot", participant.IsBot)

	if participant.OwnerUserId == nil then
		participant.Model:SetAttribute("OwnerUserId", nil)
		participant.Model:SetAttribute("OwnerName", nil)
	end

	for _, descendant in ipairs(participant.Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if participant.IsActive then
				if armorHitboxNames[descendant.Name] == true then
					descendant.CanQuery = true
					descendant.Transparency = ARMOR_HITBOXES_VISIBLE and ARMOR_HITBOX_TRANSPARENCY or 1
				else
					descendant.CanQuery = false
					descendant.Transparency = 0
				end
			else
				descendant.CanQuery = false
				descendant.Transparency = 1
			end
		end
	end
end

local function setParticipantOwner(participant, player)
	participant.OwnerPlayer = player
	participant.OwnerUserId = player.UserId
	participant.Model:SetAttribute("TankId", participant.TankId)
	participant.Model:SetAttribute("OwnerUserId", player.UserId)
	participant.Model:SetAttribute("OwnerName", player.Name)
	participant.Model:SetAttribute("TeamId", participant.TeamId)
	participant.Model:SetAttribute("IsBot", participant.IsBot)
end

local function clearParticipantOwner(participant)
	participant.OwnerPlayer = nil
	participant.OwnerUserId = nil
	participant.LastShotTime = 0
	participant.WeaponReadyAt = 0
	participant.WeaponState.LastShotTime = 0
	participant.WeaponState.WeaponReadyAt = 0
	participant.Model:SetAttribute("OwnerUserId", nil)
	participant.Model:SetAttribute("OwnerName", nil)
end

local function getParticipantMaxHealth(participant)
	local maxHealth = participant.Model:GetAttribute("MaxHealth")

	if typeof(maxHealth) == "number" then
		participant.MaxHealth = maxHealth
		return maxHealth
	end

	return participant.MaxHealth
end

local function getParticipantHealth(participant)
	local health = participant.Model:GetAttribute("Health")

	if typeof(health) == "number" then
		participant.Health = health
		return health
	end

	return participant.Health or getParticipantMaxHealth(participant)
end

local function setParticipantHealth(participant, health)
	participant.Health = health
	participant.Model:SetAttribute("Health", health)
end

local function getParticipantIsDead(participant)
	local isDead = participant.Model:GetAttribute("IsDead") == true
	participant.IsDead = isDead

	return isDead
end

local function setParticipantIsDead(participant, isDead)
	participant.IsDead = isDead == true
	participant.Model:SetAttribute("IsDead", participant.IsDead)
end

local function resetParticipantHealth(participant)
	participant.MaxHealth = participant.DefaultMaxHealth
	participant.Model:SetAttribute("MaxHealth", participant.MaxHealth)
	setParticipantHealth(participant, participant.MaxHealth)
	setParticipantIsDead(participant, false)
end

local function setRoundResult(result)
	roundState.Result = result
	roundState.Ended = result ~= ROUND_RESULT_PLAYING

	if result == ROUND_RESULT_PLAYING then
		roundState.WinnerTankId = ""
		roundState.LoserTankId = ""
	end

	root:SetAttribute("RoundResult", result)
	root:SetAttribute("RoundEnded", roundState.Ended)
	root:SetAttribute("RoundWinnerTankId", roundState.WinnerTankId)
	root:SetAttribute("RoundLoserTankId", roundState.LoserTankId)
end

local function setMatchAttributes()
	root:SetAttribute("MatchMode", matchMode)
	root:SetAttribute("PlayerWins", matchState.PlayerWins)
	root:SetAttribute("DummyWins", matchState.DummyWins)
	root:SetAttribute("RoundNumber", matchState.RoundNumber)
	root:SetAttribute("TargetWins", matchState.TargetWins)
	root:SetAttribute("MatchEnded", matchState.MatchEnded)
	root:SetAttribute("MatchResult", matchState.MatchResult)
end

local function resetMatchState()
	matchState.PlayerWins = 0
	matchState.DummyWins = 0
	matchState.RoundNumber = 1
	matchState.TargetWins = MATCH_TARGET_WINS
	matchState.MatchEnded = false
	matchState.MatchResult = ""

	resetRuntimeMatchStats()
	setMatchAttributes()
end

local function resetCombatAttributes()
	for _, participant in ipairs(tankParticipants) do
		if participant.IsActive ~= false then
			resetParticipantHealth(participant)
		end
	end

	setRoundResult(ROUND_RESULT_PLAYING)
end

local function getAssignedPlayerCount()
	local count = 0

	for _, participant in ipairs(playerParticipants) do
		if participant.OwnerPlayer ~= nil then
			count += 1
		end
	end

	return count
end

local function updateMatchMode()
	if getAssignedPlayerCount() >= 2 then
		matchMode = MATCH_MODE_PVP
	else
		matchMode = MATCH_MODE_TRAINING
	end

	root:SetAttribute("MatchMode", matchMode)
end

local function configureActiveParticipantsForMatchMode()
	updateMatchMode()

	setParticipantModelVisible(playerParticipant, true)
	setParticipantModelVisible(player2Participant, matchMode == MATCH_MODE_PVP and player2Participant.OwnerPlayer ~= nil)
	setParticipantModelVisible(dummyParticipant, matchMode == MATCH_MODE_TRAINING)
end

local function refreshIdleParticipantVisibility()
	if gameState == GAME_STATE_PLAYING and not roundState.Ended then
		root:SetAttribute("MatchMode", matchMode)
		return
	end

	configureActiveParticipantsForMatchMode()
end

resetRuntimeMatchStats()
configureActiveParticipantsForMatchMode()
setMatchAttributes()
resetCombatAttributes()
setGameState(GAME_STATE_MENU)

local function setCharacterHidden(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
end

local function getPlayerParticipant(player)
	return playerParticipantByPlayer[player]
end

local function getAvailablePlayerParticipant()
	for _, participant in ipairs(playerParticipants) do
		if participant.OwnerPlayer == nil then
			return participant
		end
	end

	return nil
end

local function setInitialInputForParticipant(player, participant)
	local state = participant.ControlState or tankState

	inputByPlayer[player] = {
		Throttle = 0,
		Steer = 0,
		AimPosition = state.Position + Vector3.new(0, 0, -20),
	}
end

local function assignPlayer(player)
	task.spawn(function()
		PersistentPlayerStatsService.loadPlayer(player)
	end)

	if playerParticipantByPlayer[player] ~= nil then
		return
	end

	local assignedParticipant = getAvailablePlayerParticipant()

	if assignedParticipant == nil then
		warn("[PVP] No player tank participant available for " .. player.Name)
		return
	end

	if controllingPlayer == nil then
		controllingPlayer = player
	end

	playerParticipantByPlayer[player] = assignedParticipant
	setParticipantOwner(assignedParticipant, player)
	setInitialInputForParticipant(player, assignedParticipant)
	refreshIdleParticipantVisibility()

	player.CharacterAdded:Connect(setCharacterHidden)

	if player.Character ~= nil then
		setCharacterHidden(player.Character)
	end

	print("[PVP] " .. player.Name .. " assigned to " .. assignedParticipant.TankId)
end

for _, player in ipairs(Players:GetPlayers()) do
	assignPlayer(player)
end

Players.PlayerAdded:Connect(assignPlayer)

Players.PlayerRemoving:Connect(function(player)
	local assignedParticipant = playerParticipantByPlayer[player]

	inputByPlayer[player] = nil
	playerParticipantByPlayer[player] = nil

	if assignedParticipant ~= nil then
		clearParticipantOwner(assignedParticipant)
		setParticipantModelVisible(assignedParticipant, assignedParticipant == playerParticipant)
	end

	if controllingPlayer == player then
		controllingPlayer = nil

		for _, participant in ipairs(playerParticipants) do
			if participant.OwnerPlayer ~= nil then
				controllingPlayer = participant.OwnerPlayer
				break
			end
		end
	end

	refreshIdleParticipantVisibility()
end)

local function isControllingPlayerRequest(player)
	if controllingPlayer == nil then
		assignPlayer(player)
	end

	return getPlayerParticipant(player) ~= nil
end

local function getYawFromDirection(direction, fallbackYaw)
	return getYawFromFlatDirection(direction, fallbackYaw)
end

local tankMovementRaycastParams = RaycastParams.new()
tankMovementRaycastParams.FilterDescendantsInstances = {
	playerTank,
	player2Tank,
	dummyTank,
	runtime,
	projectileFolder,
	vfxFolder,
}
tankMovementRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
tankMovementRaycastParams.IgnoreWater = true

local tankMovementOverlapParams = OverlapParams.new()
tankMovementOverlapParams.FilterType = Enum.RaycastFilterType.Include
tankMovementOverlapParams.MaxParts = 20

local boundaryWallNames = {
	Wall_North = true,
	Wall_South = true,
	Wall_East = true,
	Wall_West = true,
}

local function isObstacleName(name)
	return boundaryWallNames[name] == true
		or string.match(name, "^RicochetWall_") ~= nil
		or string.match(name, "^Cover_Block_") ~= nil
end

local function collectProjectileMapRaycastTargets()
	local targets = {}
	local currentRicochetWalls = map:FindFirstChild("RicochetWalls")
	local currentCover = map:FindFirstChild("Cover")

	if currentRicochetWalls ~= nil then
		table.insert(targets, currentRicochetWalls)
	end

	if currentCover ~= nil then
		table.insert(targets, currentCover)
	end

	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart") and isObstacleName(descendant.Name) then
			table.insert(targets, descendant)
		end
	end

	return targets
end

local projectileMapRaycastTargets = collectProjectileMapRaycastTargets()

local projectileRaycastParams = RaycastParams.new()
projectileRaycastParams.FilterType = Enum.RaycastFilterType.Include
projectileRaycastParams.IgnoreWater = true

local function getProjectileRaycastTargets(projectile)
	local targets = table.clone(projectileMapRaycastTargets)

	for _, participant in ipairs(tankParticipants) do
		if participant.IsActive ~= false
			and participant.Hitboxes ~= nil
			and (participant ~= projectile.OwnerParticipant or projectile.CanHitOwner)
		then
			table.insert(targets, participant.Hitboxes)
		end
	end

	return targets
end

local function isTankMovementObstacle(instance)
	if instance == nil then
		return false
	end

	if not instance:IsA("BasePart") then
		return false
	end

	if not instance.CanQuery then
		return false
	end

	if instance:IsDescendantOf(playerTank)
		or instance:IsDescendantOf(player2Tank)
		or instance:IsDescendantOf(dummyTank)
		or instance:IsDescendantOf(runtime)
	then
		return false
	end

	if ricochetWalls == nil then
		ricochetWalls = map:FindFirstChild("RicochetWalls")
	end

	if cover == nil then
		cover = map:FindFirstChild("Cover")
	end

	if ricochetWalls ~= nil and instance:IsDescendantOf(ricochetWalls) then
		return true
	end

	if cover ~= nil and instance:IsDescendantOf(cover) then
		return true
	end

	return isObstacleName(instance.Name)
end

local function getTankMovementObstacleParts()
	local obstacleParts = {}

	for _, descendant in ipairs(map:GetDescendants()) do
		if isTankMovementObstacle(descendant) then
			table.insert(obstacleParts, descendant)
		end
	end

	return obstacleParts
end

local function getTankMovementCastSize()
	return Vector3.new(
		math.max(1, body.Size.X + TANK_MOVEMENT_CAST_PADDING),
		TANK_MOVEMENT_CAST_HEIGHT,
		math.max(1, body.Size.Z + TANK_MOVEMENT_CAST_PADDING)
	)
end

local function getTankMovementCastCFrame(position, bodyYaw)
	return CFrame.new(position + Vector3.new(0, TANK_MOVEMENT_CAST_Y_OFFSET, 0)) * CFrame.Angles(0, bodyYaw, 0)
end

local function getFlatSeparationSquaredFromPart(position, obstaclePart)
	local localPoint = obstaclePart.CFrame:PointToObjectSpace(Vector3.new(position.X, obstaclePart.Position.Y, position.Z))
	local halfSize = obstaclePart.Size * 0.5
	local clampedX = math.clamp(localPoint.X, -halfSize.X, halfSize.X)
	local clampedZ = math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	local deltaX = localPoint.X - clampedX
	local deltaZ = localPoint.Z - clampedZ

	return deltaX * deltaX + deltaZ * deltaZ
end

local function isMovementAwayFromObstacle(fromPosition, movement, obstaclePart)
	if obstaclePart == nil then
		return false
	end

	local beforeDistance = getFlatSeparationSquaredFromPart(fromPosition, obstaclePart)
	local afterDistance = getFlatSeparationSquaredFromPart(fromPosition + movement, obstaclePart)

	return afterDistance >= beforeDistance - TANK_UNSTICK_DISTANCE_EPSILON
end

local function findTankBlockcastObstacle(fromPosition, bodyYaw, movement)
	local castCFrame = getTankMovementCastCFrame(fromPosition, bodyYaw)
	local success, result = pcall(function()
		return Workspace:Blockcast(
			castCFrame,
			getTankMovementCastSize(),
			movement,
			tankMovementRaycastParams
		)
	end)

	if not success or result == nil then
		return nil
	end

	if isTankMovementObstacle(result.Instance) then
		return result.Instance
	end

	return nil
end

local function findTankOverlapObstacle(position, bodyYaw)
	local obstacleParts = getTankMovementObstacleParts()

	if #obstacleParts == 0 then
		return nil
	end

	tankMovementOverlapParams.FilterDescendantsInstances = obstacleParts

	local overlappingParts = Workspace:GetPartBoundsInBox(
		getTankMovementCastCFrame(position, bodyYaw),
		getTankMovementCastSize(),
		tankMovementOverlapParams
	)

	for _, overlappingPart in ipairs(overlappingParts) do
		if isTankMovementObstacle(overlappingPart) then
			return overlappingPart
		end
	end

	return nil
end

local function printTankMovementBlocked(blockingPart)
	local currentTime = os.clock()

	if currentTime - lastWallBlockPrintTime < WALL_BLOCK_PRINT_INTERVAL then
		return
	end

	lastWallBlockPrintTime = currentTime

	local blockingName = "unknown"

	if blockingPart ~= nil then
		blockingName = blockingPart.Name
	end

	print("[WALL] blocked by " .. blockingName)
end

local function isTankMovementBlocked(fromPosition, bodyYaw, movement)
	if movement.Magnitude <= TANK_MOVEMENT_EPSILON then
		return false, nil
	end

	local blockcastObstacle = findTankBlockcastObstacle(fromPosition, bodyYaw, movement)

	if blockcastObstacle ~= nil then
		if isMovementAwayFromObstacle(fromPosition, movement, blockcastObstacle) then
			return false, nil
		end

		return true, blockcastObstacle
	end

	local overlapObstacle = findTankOverlapObstacle(fromPosition + movement, bodyYaw)

	if overlapObstacle ~= nil then
		local currentOverlapObstacle = findTankOverlapObstacle(fromPosition, bodyYaw)

		if currentOverlapObstacle == overlapObstacle
			and isMovementAwayFromObstacle(fromPosition, movement, overlapObstacle)
		then
			return false, nil
		end

		return true, overlapObstacle
	end

	return false, nil
end

local function clampTankPosition(position)
	return Vector3.new(
		math.clamp(position.X, -58, 58),
		0,
		math.clamp(position.Z, -58, 58)
	)
end

local function resolveTankMovement(fromPosition, bodyYaw, desiredMove)
	local fullMove = clampTankPosition(fromPosition + desiredMove) - fromPosition
	local fullBlocked, fullBlockingPart = isTankMovementBlocked(fromPosition, bodyYaw, fullMove)

	if not fullBlocked then
		return fromPosition + fullMove, nil
	end

	local xMove = Vector3.new(fullMove.X, 0, 0)
	local xBlockingPart = nil

	if xMove.Magnitude > TANK_MOVEMENT_EPSILON then
		local xBlocked
		xBlocked, xBlockingPart = isTankMovementBlocked(fromPosition, bodyYaw, xMove)

		if not xBlocked then
			return fromPosition + xMove, nil
		end
	end

	local zMove = Vector3.new(0, 0, fullMove.Z)
	local zBlockingPart = nil

	if zMove.Magnitude <= TANK_MOVEMENT_EPSILON then
		return fromPosition, xBlockingPart or fullBlockingPart
	end

	local zBlocked
	zBlocked, zBlockingPart = isTankMovementBlocked(fromPosition, bodyYaw, zMove)

	if not zBlocked then
		return fromPosition + zMove, nil
	end

	return fromPosition, zBlockingPart or xBlockingPart or fullBlockingPart
end

local function configureArmorHitbox(part, size, color)
	if part == nil or not part:IsA("BasePart") then
		return
	end

	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Transparency = ARMOR_HITBOXES_VISIBLE and ARMOR_HITBOX_TRANSPARENCY or 1
	part.Color = color
	part.Material = getArmorHitboxMaterial()
end

local function layoutTank(tank, position, bodyYaw, turretYaw)
	local tankBody = tank:FindFirstChild("Body")
	local tankTurret = tank:FindFirstChild("Turret")
	local tankBarrel = tank:FindFirstChild("Barrel")
	local tankShootPoint = tank:FindFirstChild("ShootPoint")
	local tankHitboxes = tank:FindFirstChild("Hitboxes")

	if tankBody == nil or tankTurret == nil or tankBarrel == nil or tankShootPoint == nil then
		return
	end

	local bodyCFrame = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, bodyYaw, 0)
	local turretCFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, turretYaw, 0)

	tankBody.CFrame = bodyCFrame
	tankTurret.CFrame = turretCFrame
	tankBarrel.CFrame = turretCFrame * CFrame.new(0, 0, -5.8)
	tankShootPoint.CFrame = turretCFrame * CFrame.new(0, 0, -10)

	if tankHitboxes ~= nil then
		local frontArmor = tankHitboxes:FindFirstChild("FrontArmor")
		local rearArmor = tankHitboxes:FindFirstChild("RearArmor")
		local leftArmor = tankHitboxes:FindFirstChild("LeftArmor")
		local rightArmor = tankHitboxes:FindFirstChild("RightArmor")
		local frontRearSize = Vector3.new(
			tankBody.Size.X + ARMOR_HITBOX_PADDING * 2,
			ARMOR_HITBOX_HEIGHT,
			ARMOR_HITBOX_THICKNESS
		)
		local sideSize = Vector3.new(
			ARMOR_HITBOX_THICKNESS,
			ARMOR_HITBOX_HEIGHT,
			tankBody.Size.Z + ARMOR_HITBOX_PADDING * 2
		)
		local frontZ = -(tankBody.Size.Z * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5)
		local rearZ = tankBody.Size.Z * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5
		local leftX = -(tankBody.Size.X * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5)
		local rightX = tankBody.Size.X * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5
		local hitboxYOffset = ARMOR_HITBOX_Y_OFFSET

		if frontArmor ~= nil then
			configureArmorHitbox(frontArmor, frontRearSize, FRONT_ARMOR_COLOR)
			frontArmor.CFrame = bodyCFrame * CFrame.new(0, hitboxYOffset, frontZ)
		end

		if rearArmor ~= nil then
			configureArmorHitbox(rearArmor, frontRearSize, REAR_ARMOR_COLOR)
			rearArmor.CFrame = bodyCFrame * CFrame.new(0, hitboxYOffset, rearZ)
		end

		if leftArmor ~= nil then
			configureArmorHitbox(leftArmor, sideSize, SIDE_ARMOR_COLOR)
			leftArmor.CFrame = bodyCFrame * CFrame.new(leftX, hitboxYOffset, 0)
		end

		if rightArmor ~= nil then
			configureArmorHitbox(rightArmor, sideSize, SIDE_ARMOR_COLOR)
			rightArmor.CFrame = bodyCFrame * CFrame.new(rightX, hitboxYOffset, 0)
		end
	end
end

layoutTank(playerTank, tankState.Position, tankState.BodyYaw, tankState.TurretYaw)
layoutTank(player2Tank, player2TankState.Position, player2TankState.BodyYaw, player2TankState.TurretYaw)
local initialDummySpawnState = getDummySpawnTransform()
dummyParticipant.SpawnTransform = initialDummySpawnState
layoutTank(dummyTank, initialDummySpawnState.Position, initialDummySpawnState.BodyYaw, initialDummySpawnState.TurretYaw)
setParticipantModelVisible(player2Participant, false)

local function createFlash(position, color, size, lifetime)
	local flash = Instance.new("Part")
	flash.Name = "VFX_Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(size, size, size)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Parent = vfxFolder

	Debris:AddItem(flash, lifetime)

	return flash
end

local function createMuzzleFlash(position)
	createFlash(position, Color3.fromRGB(255, 220, 80), 3.2, 0.08)
end

local function createImpactFlash(position)
	createFlash(position, Color3.fromRGB(255, 130, 40), 2.5, 0.12)

	for i = 1, 3 do
		local spark = Instance.new("Part")
		spark.Name = "VFX_Spark"
		spark.Size = Vector3.new(0.25, 0.25, 1.2)
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 200, 90)
		spark.CFrame = CFrame.new(position) * CFrame.Angles(
			math.random() * math.pi,
			math.random() * math.pi,
			math.random() * math.pi
		)
		spark.Parent = vfxFolder

		Debris:AddItem(spark, 0.12)
	end
end

local function createProjectilePart(position)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 230, 120)
	part.Parent = projectileFolder

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 6
	light.Parent = part

	return part
end

local function reflect(direction, normal)
	return RicochetMath.Reflect(direction, normal)
end

local function destroyProjectile(projectile)
	if projectile.Part ~= nil then
		projectile.Part:Destroy()
		projectile.Part = nil
	end

	projectile.Destroyed = true
end

local function destroyAllProjectiles()
	for i = #projectiles, 1, -1 do
		destroyProjectile(projectiles[i])
		table.remove(projectiles, i)
	end
end

local function printMatchScore(prefix)
	print(
		prefix
			.. " round="
			.. matchState.RoundNumber
			.. " score=Player "
			.. matchState.PlayerWins
			.. " / Dummy "
			.. matchState.DummyWins
			.. " firstTo="
			.. matchState.TargetWins
	)
end

local function endRound(result)
	if roundState.Ended then
		return
	end

	setRoundResult(result)

	if MATCH_SERIES_ENABLED then
		if result == ROUND_RESULT_WIN then
			matchState.PlayerWins += 1
		elseif result == ROUND_RESULT_LOSE then
			matchState.DummyWins += 1
		end

		if matchState.PlayerWins >= matchState.TargetWins then
			matchState.MatchEnded = true
			matchState.MatchResult = MATCH_RESULT_PLAYER_WIN
		elseif matchState.DummyWins >= matchState.TargetWins then
			matchState.MatchEnded = true
			matchState.MatchResult = MATCH_RESULT_DUMMY_WIN
		end
	end

	recordRoundStats(result)

	if matchState.MatchEnded then
		setMatchStat("StatsMatchResult", matchState.MatchResult)
		persistFinalMatchStats()
	end

	setMatchAttributes()

	if matchState.MatchEnded then
		setGameState(GAME_STATE_RESULT)
		task.defer(destroyAllProjectiles)
	end

	printMatchScore("[ROUND] " .. result)

	if matchState.MatchEnded then
		print("[MATCH] " .. matchState.MatchResult)
	end
end

local function resetParticipantWeaponState(participant)
	participant.LastShotTime = 0
	participant.WeaponReadyAt = 0
	participant.WeaponState.LastShotTime = 0
	participant.WeaponState.WeaponReadyAt = 0
end

local function applySpawnToParticipant(participant, spawnState)
	participant.SpawnTransform = spawnState

	if participant.ControlState == nil then
		participant.ControlState = {}
	end

	participant.ControlState.Position = spawnState.Position
	participant.ControlState.BodyYaw = spawnState.BodyYaw
	participant.ControlState.TurretYaw = spawnState.TurretYaw
	resetParticipantWeaponState(participant)
	layoutTank(participant.Model, spawnState.Position, spawnState.BodyYaw, spawnState.TurretYaw)
end

local function resetRound()
	if gameState ~= GAME_STATE_PLAYING then
		return
	end

	destroyAllProjectiles()
	configureActiveParticipantsForMatchMode()

	if matchState.MatchEnded then
		resetMatchState()
		print("[MATCH] reset")
	elseif roundState.Ended then
		matchState.RoundNumber += 1
		setMatchAttributes()
	else
		print("[ROUND] current round reset")
	end

	local playerSpawnState = getPlayerSpawnTransform()
	local dummySpawnState = getDummySpawnTransform()
	local player2SpawnState = getPlayer2SpawnTransform()

	restorePartColors(playerTankPartColors)
	restorePartColors(dummyTankPartColors)
	restorePartColors(player2TankPartColors)
	resetCombatAttributes()

	applySpawnToParticipant(playerParticipant, playerSpawnState)

	if matchMode == MATCH_MODE_PVP then
		applySpawnToParticipant(player2Participant, player2SpawnState)
	else
		applySpawnToParticipant(dummyParticipant, dummySpawnState)
	end

	print("[ROUND] reset")
end

local function startNewMatch()
	destroyAllProjectiles()
	configureActiveParticipantsForMatchMode()
	resetMatchState()

	local playerSpawnState = getPlayerSpawnTransform()
	local dummySpawnState = getDummySpawnTransform()
	local player2SpawnState = getPlayer2SpawnTransform()

	restorePartColors(playerTankPartColors)
	restorePartColors(dummyTankPartColors)
	restorePartColors(player2TankPartColors)
	resetCombatAttributes()

	applySpawnToParticipant(playerParticipant, playerSpawnState)

	if matchMode == MATCH_MODE_PVP then
		applySpawnToParticipant(player2Participant, player2SpawnState)
	else
		applySpawnToParticipant(dummyParticipant, dummySpawnState)
	end

	setGameState(GAME_STATE_PLAYING)
	print("[SERVER] Match started -> Playing mode=" .. matchMode)
end

local function returnToMenu()
	destroyAllProjectiles()
	setGameState(GAME_STATE_MENU)
	print("[SERVER] Menu state active")
end

local function applyDamageToParticipant(participant, amount)
	if roundState.Ended or getParticipantIsDead(participant) then
		return false
	end

	local currentHealth = getParticipantHealth(participant)
	local newHealth = math.max(0, currentHealth - amount)

	setParticipantHealth(participant, newHealth)

	print(
		"[DAMAGE] "
			.. participant.TankId
			.. " -"
			.. math.floor(amount)
			.. " HP: "
			.. math.floor(currentHealth)
			.. " -> "
			.. math.floor(newHealth)
	)

	if newHealth > 0 then
		return true
	end

	setParticipantIsDead(participant, true)
	darkenTank(participant.Model)

	print("[DEAD] " .. participant.TankId .. " destroyed")

	return true
end

local function damageParticipant(participant, amount)
	if participant.IsActive == false then
		return false
	end

	if not applyDamageToParticipant(participant, amount) then
		return false
	end

	createImpactFlash(participant.Body.Position + Vector3.new(0, 3, 0))

	if not getParticipantIsDead(participant) then
		return true
	end

	roundState.LoserTankId = participant.TankId

	if matchMode == MATCH_MODE_PVP then
		if participant == playerParticipant then
			roundState.WinnerTankId = player2Participant.TankId
			endRound(ROUND_RESULT_LOSE)
		elseif participant == player2Participant then
			roundState.WinnerTankId = playerParticipant.TankId
			endRound(ROUND_RESULT_WIN)
		end
	elseif participant == dummyParticipant then
		roundState.WinnerTankId = playerParticipant.TankId
		endRound(ROUND_RESULT_WIN)
	elseif participant == playerParticipant then
		roundState.WinnerTankId = dummyParticipant.TankId
		endRound(ROUND_RESULT_LOSE)
	end

	return true
end

local function formatNumber(value)
	return string.format("%.1f", value)
end

local function sendCombatFeedback(feedbackType, position, text, color)
	combatFeedbackEvent:FireAllClients({
		Type = feedbackType,
		Position = position,
		Text = text,
		Color = color,
	})
end

local function resolveArmorHit(projectile, targetParticipant, hitNormal, armorZone)
	return RicochetMath.ResolveArmorHit({
		incomingDirection = projectile.Direction,
		hitNormal = hitNormal,
		tankBodyCFrame = targetParticipant.Body.CFrame,
		armorZone = armorZone,
		projectilePenetration = projectile.Penetration,
		currentDamage = projectile.Damage,
		armorConfig = TANK_ARMOR,
		autoRicochetAngleDegrees = TANK_ARMOR.AutoRicochetAngleDegrees,
		safeMinCos = TANK_ARMOR.SafeMinCos,
	})
end

local function printArmorResult(prefix, targetName, armorHit, projectile)
	print(
		prefix
			.. " "
			.. targetName
			.. " zone="
			.. armorHit.Zone
			.. " angle="
			.. formatNumber(armorHit.HitAngleDegrees)
			.. " effectiveArmor="
			.. formatNumber(armorHit.EffectiveArmor)
			.. " penetration="
			.. formatNumber(projectile.Penetration)
			.. " damage="
			.. math.floor(armorHit.Damage)
	)
end

local function applyProjectileRicochet(projectile, hitPosition, hitNormal)
	projectile.Direction = reflect(projectile.Direction, hitNormal)
	projectile.Position = hitPosition + projectile.Direction * PROJECTILE_RICOCHET_OFFSET
	projectile.BounceCount += 1
	projectile.Damage *= projectile.DamageMultiplierPerBounce
	projectile.Speed = math.max(projectile.MinSpeed, projectile.Speed * projectile.BounceSpeedMultiplier)
	projectile.CanHitOwner = true
	recordProjectileRicochet(projectile)
end

local function createProjectile(ownerParticipant, origin, direction)
	local projectilePart = createProjectilePart(origin)

	projectilePart:SetAttribute("OwnerTankId", ownerParticipant.TankId)
	projectilePart:SetAttribute("OwnerTeamId", ownerParticipant.TeamId)
	projectilePart:SetAttribute("OwnerIsBot", ownerParticipant.IsBot)
	projectilePart:SetAttribute("WeaponTypeId", ownerParticipant.WeaponTypeId)

	if ownerParticipant.OwnerUserId ~= nil then
		projectilePart:SetAttribute("OwnerUserId", ownerParticipant.OwnerUserId)
	end

	local projectile = {
		Owner = ownerParticipant.OwnerPlayer,
		OwnerPlayer = ownerParticipant.OwnerPlayer,
		OwnerParticipant = ownerParticipant,
		OwnerTank = ownerParticipant.Model,
		OwnerTankId = ownerParticipant.TankId,
		OwnerUserId = ownerParticipant.OwnerUserId,
		OwnerTeamId = ownerParticipant.TeamId,
		OwnerIsBot = ownerParticipant.IsBot,
		ProjectileTypeId = projectileConfig.Id,
		WeaponTypeId = ownerParticipant.WeaponTypeId,
		WeaponConfig = ownerParticipant.WeaponConfig,
		Position = origin,
		Direction = Vector3.new(direction.X, 0, direction.Z).Unit,
		Speed = PROJECTILE_SPEED,
		Damage = PROJECTILE_MAX_DAMAGE,
		Penetration = PROJECTILE_PENETRATION,
		BounceCount = 0,
		MaxBounces = PROJECTILE_MAX_BOUNCES,
		BounceSpeedMultiplier = PROJECTILE_BOUNCE_SPEED_MULTIPLIER,
		DamageMultiplierPerBounce = PROJECTILE_DAMAGE_MULTIPLIER,
		MinSpeed = PROJECTILE_MIN_SPEED,
		LifeTime = 0,
		MaxLifeTime = PROJECTILE_LIFETIME,
		Part = projectilePart,
		Destroyed = false,
		CanHitOwner = false,
	}

	table.insert(projectiles, projectile)
	createMuzzleFlash(origin)
end

local function tryShoot(participant, direction)
	if gameState ~= GAME_STATE_PLAYING or roundState.Ended then
		return false
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		return false
	end

	local currentTime = os.clock()
	local cooldown = participant.WeaponConfig.ShootCooldown or SHOOT_COOLDOWN
	local lastShotTime = participant.LastShotTime or 0

	if currentTime - lastShotTime < cooldown then
		return false
	end

	participant.LastShotTime = currentTime
	participant.WeaponReadyAt = currentTime + cooldown
	participant.WeaponState.LastShotTime = participant.LastShotTime
	participant.WeaponState.WeaponReadyAt = participant.WeaponReadyAt

	createProjectile(participant, participant.ShootPoint.Position, flatDirection.Unit)
	recordShotFired(participant)

	return true
end

resetDummyRequestEvent.OnServerEvent:Connect(function()
	resetRound()
end)

startMatchRequestEvent.OnServerEvent:Connect(function(player)
	print("[SERVER] StartMatch requested by " .. player.Name)

	if not isControllingPlayerRequest(player) then
		warn("[SERVER] StartMatch ignored for non-controlling player " .. player.Name)
		return
	end

	startNewMatch()
end)

returnToMenuRequestEvent.OnServerEvent:Connect(function(player)
	print("[SERVER] ReturnToMenu requested by " .. player.Name)

	if not isControllingPlayerRequest(player) then
		warn("[SERVER] ReturnToMenu ignored for non-controlling player " .. player.Name)
		return
	end

	returnToMenu()
end)

tankInputEvent.OnServerEvent:Connect(function(player, inputData)
	local participant = getPlayerParticipant(player)

	if participant == nil or participant.IsActive == false then
		return
	end

	if gameState ~= GAME_STATE_PLAYING then
		return
	end

	if typeof(inputData) ~= "table" then
		return
	end

	local throttle = tonumber(inputData.Throttle) or 0
	local steer = tonumber(inputData.Steer) or 0
	local aimPosition = inputData.AimPosition
	local state = participant.ControlState

	if typeof(aimPosition) ~= "Vector3" then
		aimPosition = state.Position + Vector3.new(0, 0, -20)
	end

	inputByPlayer[player] = {
		Throttle = math.clamp(throttle, -1, 1),
		Steer = math.clamp(steer, -1, 1),
		AimPosition = aimPosition,
	}
end)

shootRequestEvent.OnServerEvent:Connect(function(player, aimPosition)
	local participant = getPlayerParticipant(player)

	if participant == nil or participant.IsActive == false then
		return
	end

	if gameState ~= GAME_STATE_PLAYING then
		return
	end

	if typeof(aimPosition) ~= "Vector3" then
		return
	end

	local state = participant.ControlState
	local origin = participant.ShootPoint.Position
	local direction = Vector3.new(aimPosition.X - origin.X, 0, aimPosition.Z - origin.Z)

	if direction.Magnitude < 0.1 then
		direction = (CFrame.Angles(0, state.TurretYaw, 0)).LookVector
	end

	tryShoot(participant, direction.Unit)
end)

local function printBounce(projectile)
	print(
		"[BOUNCE] count="
			.. projectile.BounceCount
			.. " damage="
			.. math.floor(projectile.Damage)
			.. " speed="
			.. math.floor(projectile.Speed)
	)
end

local function handleProjectileTankHit(projectile, targetParticipant, hitPosition, hitNormal, armorZone)
	createImpactFlash(hitPosition)

	if roundState.Ended or getParticipantIsDead(targetParticipant) then
		destroyProjectile(projectile)
		return true
	end

	recordProjectileTankHitStats(projectile)

	local armorHit = resolveArmorHit(projectile, targetParticipant, hitNormal, armorZone)

	if armorHit.Result == "Penetrated" then
		printArmorResult("[PEN]", targetParticipant.TankId, armorHit, projectile)

		local damageText = "-" .. math.floor(armorHit.Damage)

		if targetParticipant == projectile.OwnerParticipant and projectile.OwnerPlayer ~= nil then
			print("[SELF-HIT] " .. targetParticipant.TankId .. " hit by own ricochet")
			damageText = "SELF HIT " .. damageText
		end

		sendCombatFeedback(
			"Damage",
			hitPosition,
			damageText,
			Color3.fromRGB(255, 105, 75)
		)

		if damageParticipant(targetParticipant, armorHit.Damage) then
			recordProjectileDamageStats(projectile, targetParticipant, armorHit.Damage)
		end

		destroyProjectile(projectile)
		return true
	end

	if armorHit.Result == "Ricochet" then
		printArmorResult("[ARMOR-RICOCHET]", targetParticipant.TankId, armorHit, projectile)

		sendCombatFeedback(
			"ArmorRicochet",
			hitPosition,
			"RICOCHET",
			Color3.fromRGB(255, 220, 70)
		)
	else
		printArmorResult("[NO-PEN]", targetParticipant.TankId, armorHit, projectile)

		sendCombatFeedback(
			"NoPenetration",
			hitPosition,
			"NO PEN",
			Color3.fromRGB(180, 220, 255)
		)
	end

	if projectile.BounceCount >= projectile.MaxBounces then
		destroyProjectile(projectile)
		return true
	end

	applyProjectileRicochet(projectile, hitPosition, hitNormal)
	printBounce(projectile)

	return false
end

local function updateTankParticipant(participant, deltaTime)
	if participant.OwnerPlayer == nil or participant.IsActive == false then
		return
	end

	local state = participant.ControlState

	if state == nil then
		return
	end

	local input = inputByPlayer[participant.OwnerPlayer]

	if input == nil then
		return
	end

	-- Steering stays independent from throttle so reverse never flips A/D body rotation.
	state.BodyYaw -= input.Steer * TURN_SPEED * deltaTime

	local bodyCFrame = CFrame.new(state.Position) * CFrame.Angles(0, state.BodyYaw, 0)
	local forward = bodyCFrame.LookVector

	local moveSpeed = MOVE_SPEED

	if input.Throttle < 0 then
		moveSpeed *= REVERSE_MOVE_SPEED_MULTIPLIER
	end

	local desiredMove = forward * input.Throttle * moveSpeed * deltaTime
	local resolvedPosition, blockingPart = resolveTankMovement(state.Position, state.BodyYaw, desiredMove)

	if blockingPart ~= nil then
		printTankMovementBlocked(blockingPart)
	else
		state.Position = resolvedPosition
	end

	local aimDirection = input.AimPosition - state.Position
	state.TurretYaw = getYawFromDirection(aimDirection, state.TurretYaw)

	layoutTank(participant.Model, state.Position, state.BodyYaw, state.TurretYaw)
end

local function updateTank(deltaTime)
	if gameState ~= GAME_STATE_PLAYING then
		return
	end

	for _, participant in ipairs(playerParticipants) do
		updateTankParticipant(participant, deltaTime)
	end
end

local function updateProjectiles(deltaTime)
	if gameState ~= GAME_STATE_PLAYING then
		return
	end

	for i = #projectiles, 1, -1 do
		local projectile = projectiles[i]

		if projectile.Destroyed then
			table.remove(projectiles, i)
			continue
		end

		projectile.LifeTime += deltaTime

		if projectile.LifeTime >= projectile.MaxLifeTime then
			destroyProjectile(projectile)
			table.remove(projectiles, i)
			continue
		end

		local distance = projectile.Speed * deltaTime
		projectileRaycastParams.FilterDescendantsInstances = getProjectileRaycastTargets(projectile)

		local result = Workspace:Raycast(
			projectile.Position,
			projectile.Direction * distance,
			projectileRaycastParams
		)

		if result ~= nil then
			local hitInstance = result.Instance
			local hitPosition = result.Position
			local hitNormal = result.Normal
			local targetParticipant = getParticipantFromArmorHitbox(hitInstance)
			local armorZone = getArmorZoneFromHitbox(hitInstance)

			if targetParticipant ~= nil then
				local destroyed = handleProjectileTankHit(
					projectile,
					targetParticipant,
					hitPosition,
					hitNormal,
					armorZone
				)

				if destroyed then
					table.remove(projectiles, i)
				end
			else
				createImpactFlash(hitPosition)

				if projectile.BounceCount >= projectile.MaxBounces then
					destroyProjectile(projectile)
					table.remove(projectiles, i)
				else
					applyProjectileRicochet(projectile, hitPosition, hitNormal)
					printBounce(projectile)
				end
			end
		else
			projectile.Position += projectile.Direction * distance
		end

		if projectile.Part ~= nil then
			projectile.Part.Position = projectile.Position
		end
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	updateTank(deltaTime)
	updateProjectiles(deltaTime)
end)

print("[WOB] Gameplay server started")
