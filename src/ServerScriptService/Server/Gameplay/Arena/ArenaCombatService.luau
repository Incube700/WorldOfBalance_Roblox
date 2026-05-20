local ArenaCombatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local BattleArenaConfig = require(configs:WaitForChild("BattleArenaConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))

ArenaCombatService.MODE_IN_BATTLE_ARENA = "InBattleArena"
ArenaCombatService.MODE_ARENA_RESPAWNING = "ArenaRespawning"

local root = nil
local tankSpawnResetService = nil

local callbacks = {
	setPlayerMode = nil,
	clearPlayerInput = nil,
	restoreTankColors = nil,
}

local sessionsByPlayer = {}
local sessionsByParticipant = {}
local nextSpawnIndex = 1

local UPGRADE_ORDER = {
	"DamageUp",
	"FireRateUp",
	"DoubleShot",
	"MoveSpeedUp",
	"TripleSpread",
}

local function getServerTimeNow()
	local success, serverTime = pcall(function()
		return Workspace:GetServerTimeNow()
	end)

	if success and typeof(serverTime) == "number" then
		return serverTime
	end

	return os.clock()
end

local function getArenaFolder()
	return root ~= nil and root:FindFirstChild("BattleArena") or nil
end

local function getSpawnFolder()
	local arena = getArenaFolder()

	return arena ~= nil and arena:FindFirstChild("SpawnPoints") or nil
end

local function getYawFromLookVector(lookVector)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLook.Magnitude < 0.001 then
		return 0
	end

	local unit = flatLook.Unit
	return math.atan2(-unit.X, -unit.Z)
end

local function makeSpawnTransform(position, yaw, source)
	return {
		Position = position,
		BodyYaw = yaw,
		TurretYaw = yaw,
		Source = source,
	}
end

local function getArenaSpawnParts()
	local spawnFolder = getSpawnFolder()
	local spawnParts = {}

	if spawnFolder ~= nil then
		for _, child in ipairs(spawnFolder:GetChildren()) do
			if child:IsA("BasePart") and string.match(child.Name, "^ArenaSpawn%d+$") ~= nil then
				table.insert(spawnParts, child)
			end
		end
	end

	table.sort(spawnParts, function(a, b)
		return a.Name < b.Name
	end)

	return spawnParts
end

local function getFallbackArenaSpawnTransform(player)
	local arena = getArenaFolder()
	local arenaCenter = arena ~= nil and arena:GetAttribute("ArenaCenter") or nil
	local halfSize = arena ~= nil and arena:GetAttribute("ArenaHalfSize") or nil

	if typeof(arenaCenter) ~= "Vector3" then
		arenaCenter = Vector3.new(0, 0, -360)
	end

	if typeof(halfSize) ~= "number" then
		halfSize = 130
	end

	local spawnCount = math.max(1, tonumber(BattleArenaConfig.SpawnPointCount) or 8)
	local userOffset = player ~= nil and math.abs(player.UserId % spawnCount) or 0
	local angle = (math.pi * 2) * (userOffset / spawnCount)
	local radius = math.max(36, halfSize * 0.7)
	local position = arenaCenter + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local yaw = getYawFromLookVector((arenaCenter - position).Unit)

	return makeSpawnTransform(position, yaw, "ArenaFallback")
end

local function getArenaSpawnTransform(player)
	local spawnParts = getArenaSpawnParts()

	if #spawnParts == 0 then
		return getFallbackArenaSpawnTransform(player)
	end

	local spawnPart = spawnParts[((nextSpawnIndex - 1) % #spawnParts) + 1]
	nextSpawnIndex += 1

	return makeSpawnTransform(
		spawnPart.Position,
		getYawFromLookVector(spawnPart.CFrame.LookVector),
		spawnPart.Name
	)
end

local function setAttributeOnParticipantModels(participant, attributeName, value)
	if participant == nil then
		return
	end

	local physicalModel = TankParticipantRegistry.getParticipantPhysicalModel(participant)

	if participant.Model ~= nil then
		participant.Model:SetAttribute(attributeName, value)
	end

	if physicalModel ~= nil and physicalModel ~= participant.Model then
		physicalModel:SetAttribute(attributeName, value)
	end
end

local function setPlayerMode(player, participant, mode)
	if callbacks.setPlayerMode ~= nil then
		callbacks.setPlayerMode(player, participant, mode, nil, nil)
		return
	end

	if player ~= nil then
		player:SetAttribute("PlayerMode", mode)
		player:SetAttribute("MatchId", nil)
		player:SetAttribute("OpponentTankId", nil)
	end

	TankParticipantRegistry.setParticipantMatchState(participant, mode, nil, nil)
end

local function clearPlayerInput(player)
	if callbacks.clearPlayerInput ~= nil then
		callbacks.clearPlayerInput(player)
	end
end

local function setArenaModifier(participant, attributeName, value)
	if participant == nil then
		return
	end

	participant[attributeName] = value
	setAttributeOnParticipantModels(participant, attributeName, value)
end

local function resetParticipantArenaModifiers(participant)
	if participant == nil then
		return
	end

	setArenaModifier(participant, "ArenaDamageMultiplier", 1)
	setArenaModifier(participant, "ArenaFireRateMultiplier", 1)
	setArenaModifier(participant, "ArenaMoveSpeedMultiplier", 1)
	setArenaModifier(participant, "ArenaProjectileCount", 1)
	setArenaModifier(participant, "ArenaSpreadDegrees", 0)
	setArenaModifier(participant, "ArenaDoubleShotLateralOffset", 0)
	setArenaModifier(participant, "ArenaUpgradeIds", "")
end

local function setPlayerArenaDefaults(player)
	if player == nil then
		return
	end

	player:SetAttribute("ArenaScore", 0)
	player:SetAttribute("ArenaKills", 0)
	player:SetAttribute("ArenaDeaths", 0)
	player:SetAttribute("ArenaStreak", 0)
	player:SetAttribute("ArenaRespawnAt", 0)
	player:SetAttribute("ArenaRespawnDelay", BattleArenaConfig.RespawnDelay)
	player:SetAttribute("ArenaStatus", "")
	player:SetAttribute("ArenaUpgradeIds", "")
	player:SetAttribute("ArenaDamageMultiplier", 1)
	player:SetAttribute("ArenaFireRateMultiplier", 1)
	player:SetAttribute("ArenaMoveSpeedMultiplier", 1)
	player:SetAttribute("ArenaProjectileCount", 1)
end

local function publishSessionAttributes(session)
	local player = session.Player

	if player == nil then
		return
	end

	player:SetAttribute("ArenaScore", session.Score)
	player:SetAttribute("ArenaKills", session.Kills)
	player:SetAttribute("ArenaDeaths", session.Deaths)
	player:SetAttribute("ArenaStreak", session.Streak)
	player:SetAttribute("ArenaUpgradeIds", table.concat(session.UpgradeIds, ","))
	player:SetAttribute("ArenaDamageMultiplier", session.DamageMultiplier)
	player:SetAttribute("ArenaFireRateMultiplier", session.FireRateMultiplier)
	player:SetAttribute("ArenaMoveSpeedMultiplier", session.MoveSpeedMultiplier)
	player:SetAttribute("ArenaProjectileCount", session.ProjectileCount)
end

local function hasUpgrade(session, upgradeId)
	for _, existingUpgradeId in ipairs(session.UpgradeIds) do
		if existingUpgradeId == upgradeId then
			return true
		end
	end

	return false
end

local function shouldUnlockUpgrade(session, upgradeId)
	if session.ForcedUpgrades[upgradeId] == true then
		return true
	end

	local thresholds = BattleArenaConfig.UpgradeThresholds or {}
	local threshold = tonumber(thresholds[upgradeId])

	return threshold ~= nil and session.Score >= threshold
end

local function collectUnlockedUpgrades(session)
	local upgradeIds = {}

	for _, upgradeId in ipairs(UPGRADE_ORDER) do
		if shouldUnlockUpgrade(session, upgradeId) then
			table.insert(upgradeIds, upgradeId)
		end
	end

	return upgradeIds
end

local function applySessionUpgrades(session)
	local participant = session.Participant
	local upgradeIds = collectUnlockedUpgrades(session)
	local changed = #upgradeIds ~= #session.UpgradeIds

	if not changed then
		for index, upgradeId in ipairs(upgradeIds) do
			if session.UpgradeIds[index] ~= upgradeId then
				changed = true
				break
			end
		end
	end

	session.UpgradeIds = upgradeIds
	session.DamageMultiplier = hasUpgrade(session, "DamageUp") and BattleArenaConfig.DamageUpMultiplier or 1
	session.FireRateMultiplier = hasUpgrade(session, "FireRateUp") and BattleArenaConfig.FireRateMultiplier or 1
	session.MoveSpeedMultiplier = hasUpgrade(session, "MoveSpeedUp") and BattleArenaConfig.MoveSpeedMultiplier or 1

	if hasUpgrade(session, "TripleSpread") then
		session.ProjectileCount = 3
		session.SpreadDegrees = BattleArenaConfig.MultiShotSpreadDegrees
		session.DoubleShotLateralOffset = 0
	elseif hasUpgrade(session, "DoubleShot") then
		session.ProjectileCount = 2
		session.SpreadDegrees = 0
		session.DoubleShotLateralOffset = BattleArenaConfig.DoubleShotLateralOffset
	else
		session.ProjectileCount = 1
		session.SpreadDegrees = 0
		session.DoubleShotLateralOffset = 0
	end

	setArenaModifier(participant, "ArenaDamageMultiplier", session.DamageMultiplier)
	setArenaModifier(participant, "ArenaFireRateMultiplier", session.FireRateMultiplier)
	setArenaModifier(participant, "ArenaMoveSpeedMultiplier", session.MoveSpeedMultiplier)
	setArenaModifier(participant, "ArenaProjectileCount", session.ProjectileCount)
	setArenaModifier(participant, "ArenaSpreadDegrees", session.SpreadDegrees)
	setArenaModifier(participant, "ArenaDoubleShotLateralOffset", session.DoubleShotLateralOffset)
	setArenaModifier(participant, "ArenaUpgradeIds", table.concat(session.UpgradeIds, ","))
	publishSessionAttributes(session)

	if changed and BattleArenaConfig.Debug == true then
		local ownerName = session.Player ~= nil and session.Player.Name or tostring(participant ~= nil and participant.TankId or "Bot")
		print("[ARENA] upgrades " .. ownerName .. " -> " .. table.concat(session.UpgradeIds, ","))
	end
end

local function makeSession(player, participant)
	return {
		Player = player,
		Participant = participant,
		SessionId = "Arena_" .. tostring(player.UserId) .. "_" .. tostring(math.floor(os.clock() * 1000)),
		RespawnToken = 0,
		Score = 0,
		Kills = 0,
		Deaths = 0,
		Streak = 0,
		UpgradeIds = {},
		ForcedUpgrades = {},
		DamageMultiplier = 1,
		FireRateMultiplier = 1,
		MoveSpeedMultiplier = 1,
		ProjectileCount = 1,
		SpreadDegrees = 0,
		DoubleShotLateralOffset = 0,
	}
end

local function makeBotSession(participant)
	return {
		Player = nil,
		Participant = participant,
		SessionId = "ArenaBot_" .. tostring(participant ~= nil and participant.TankId or "Unknown"),
		RespawnToken = 0,
		Score = 0,
		Kills = 0,
		Deaths = 0,
		Streak = 0,
		UpgradeIds = {},
		ForcedUpgrades = {},
		DamageMultiplier = 1,
		FireRateMultiplier = 1,
		MoveSpeedMultiplier = 1,
		ProjectileCount = 1,
		SpreadDegrees = 0,
		DoubleShotLateralOffset = 0,
		IsBotSession = true,
	}
end

function ArenaCombatService.init(options)
	options = options or {}
	root = options.root
	tankSpawnResetService = options.tankSpawnResetService
	callbacks.setPlayerMode = options.setPlayerMode
	callbacks.clearPlayerInput = options.clearPlayerInput
	callbacks.restoreTankColors = options.restoreTankColors
end

function ArenaCombatService.IsEnabled()
	return BattleArenaConfig.Enabled == true
end

function ArenaCombatService.IsPlayerInArena(player)
	return player ~= nil and sessionsByPlayer[player] ~= nil
end

function ArenaCombatService.IsParticipantInArena(participant)
	return participant ~= nil and sessionsByParticipant[participant] ~= nil
end

function ArenaCombatService.GetSession(player)
	return sessionsByPlayer[player]
end

function ArenaCombatService.GetActivePlayerCount()
	local count = 0

	for player, _ in pairs(sessionsByPlayer) do
		if player ~= nil and player.Parent == Players then
			count += 1
		end
	end

	return count
end

function ArenaCombatService.GetActiveParticipants()
	local participants = {}

	for participant, _ in pairs(sessionsByParticipant) do
		if participant ~= nil then
			table.insert(participants, participant)
		end
	end

	return participants
end

function ArenaCombatService.RegisterBotParticipant(participant)
	if participant == nil then
		return nil
	end

	local existingSession = sessionsByParticipant[participant]

	if existingSession ~= nil then
		return existingSession
	end

	local session = makeBotSession(participant)
	sessionsByParticipant[participant] = session
	resetParticipantArenaModifiers(participant)
	TankParticipantRegistry.setParticipantMatchState(participant, ArenaCombatService.MODE_IN_BATTLE_ARENA, nil, nil)

	return session
end

function ArenaCombatService.UnregisterBotParticipant(participant)
	local session = sessionsByParticipant[participant]

	if session == nil or session.IsBotSession ~= true then
		return nil
	end

	sessionsByParticipant[participant] = nil
	resetParticipantArenaModifiers(participant)
	TankParticipantRegistry.setParticipantMatchState(participant, nil, nil, nil)

	return session
end

function ArenaCombatService.EnterArena(player)
	if not ArenaCombatService.IsEnabled() then
		return false
	end

	local participant = TankParticipantRegistry.getPlayerParticipant(player)

	if player == nil or participant == nil then
		return false
	end

	local existingSession = sessionsByPlayer[player]

	if existingSession ~= nil then
		ArenaCombatService.RespawnPlayer(player)
		return true
	end

	local session = makeSession(player, participant)
	sessionsByPlayer[player] = session
	sessionsByParticipant[participant] = session

	setPlayerArenaDefaults(player)
	resetParticipantArenaModifiers(participant)
	player:SetAttribute("ArenaStatus", "Active")
	player:SetAttribute("ArenaSessionId", session.SessionId)
	setPlayerMode(player, participant, ArenaCombatService.MODE_IN_BATTLE_ARENA)

	TankParticipantRegistry.setParticipantModelVisible(participant, true)
	TankParticipantRegistry.resetParticipantHealth(participant)

	if callbacks.restoreTankColors ~= nil then
		callbacks.restoreTankColors(participant)
	end

	tankSpawnResetService.applySpawnToParticipant(participant, getArenaSpawnTransform(player))
	clearPlayerInput(player)
	applySessionUpgrades(session)
	print("[ARENA] player entered battle arena " .. player.Name .. " -> " .. participant.TankId)

	return true
end

function ArenaCombatService.ResetArenaSession(player)
	local session = sessionsByPlayer[player]

	if session ~= nil then
		session.Score = 0
		session.Kills = 0
		session.Deaths = 0
		session.Streak = 0
		session.UpgradeIds = {}
		session.ForcedUpgrades = {}
		session.RespawnToken += 1
		resetParticipantArenaModifiers(session.Participant)
	end

	setPlayerArenaDefaults(player)
end

function ArenaCombatService.LeaveArena(player)
	local session = sessionsByPlayer[player]

	if session == nil then
		setPlayerArenaDefaults(player)
		return nil
	end

	session.RespawnToken += 1
	sessionsByPlayer[player] = nil
	sessionsByParticipant[session.Participant] = nil
	resetParticipantArenaModifiers(session.Participant)
	setPlayerArenaDefaults(player)
	player:SetAttribute("ArenaSessionId", nil)
	clearPlayerInput(player)
	print("[ARENA] left " .. player.Name)

	return session.Participant
end

function ArenaCombatService.GetArenaScore(player)
	local session = sessionsByPlayer[player]

	return session ~= nil and session.Score or 0
end

function ArenaCombatService.ApplyUpgrade(player, upgradeId)
	local session = sessionsByPlayer[player]

	if session == nil or typeof(upgradeId) ~= "string" then
		return false
	end

	for _, validUpgradeId in ipairs(UPGRADE_ORDER) do
		if validUpgradeId == upgradeId then
			session.ForcedUpgrades[upgradeId] = true
			applySessionUpgrades(session)
			return true
		end
	end

	return false
end

function ArenaCombatService.RespawnPlayer(player)
	local session = sessionsByPlayer[player]

	if session == nil or player == nil or player.Parent ~= Players then
		return false
	end

	local participant = session.Participant

	if participant == nil then
		return false
	end

	TankParticipantRegistry.setParticipantModelVisible(participant, true)
	TankParticipantRegistry.resetParticipantHealth(participant)

	if callbacks.restoreTankColors ~= nil then
		callbacks.restoreTankColors(participant)
	end

	tankSpawnResetService.applySpawnToParticipant(participant, getArenaSpawnTransform(player))
	setPlayerMode(player, participant, ArenaCombatService.MODE_IN_BATTLE_ARENA)
	player:SetAttribute("ArenaRespawnAt", 0)
	player:SetAttribute("ArenaStatus", "Active")
	clearPlayerInput(player)
	applySessionUpgrades(session)
	print("[ARENA] respawned " .. player.Name)

	return true
end

function ArenaCombatService.OnParticipantKilled(killerParticipant, victimParticipant)
	local victimSession = sessionsByParticipant[victimParticipant]

	if victimSession == nil then
		return
	end

	local victimPlayer = victimSession.Player
	victimSession.Deaths += 1
	victimSession.Streak = 0

	local killerSession = nil

	if killerParticipant ~= nil and killerParticipant ~= victimParticipant then
		killerSession = sessionsByParticipant[killerParticipant]
	end

	if killerSession ~= nil and killerSession.IsBotSession ~= true then
		killerSession.Score += BattleArenaConfig.KillScore
		killerSession.Kills += 1
		killerSession.Streak += 1
		applySessionUpgrades(killerSession)
	end

	publishSessionAttributes(victimSession)

	if victimPlayer == nil or victimPlayer.Parent ~= Players then
		return
	end

	victimSession.RespawnToken += 1
	local token = victimSession.RespawnToken
	local respawnDelay = math.max(0, tonumber(BattleArenaConfig.RespawnDelay) or 0)
	local respawnAt = getServerTimeNow() + respawnDelay

	setPlayerMode(victimPlayer, victimParticipant, ArenaCombatService.MODE_ARENA_RESPAWNING)
	victimPlayer:SetAttribute("ArenaStatus", "Destroyed")
	victimPlayer:SetAttribute("ArenaRespawnDelay", respawnDelay)
	victimPlayer:SetAttribute("ArenaRespawnAt", respawnAt)
	clearPlayerInput(victimPlayer)

	task.delay(respawnDelay, function()
		local currentSession = sessionsByPlayer[victimPlayer]

		if currentSession ~= victimSession or currentSession.RespawnToken ~= token then
			return
		end

		ArenaCombatService.RespawnPlayer(victimPlayer)
	end)
end

function ArenaCombatService.CanDamageParticipant(projectile, targetParticipant)
	if projectile == nil or targetParticipant == nil or projectile.NoDamage == true then
		return false
	end

	local ownerSession = sessionsByParticipant[projectile.OwnerParticipant]
	local targetSession = sessionsByParticipant[targetParticipant]

	return ownerSession ~= nil and targetSession ~= nil
end

function ArenaCombatService.IsArenaProjectile(projectile)
	return projectile ~= nil and sessionsByParticipant[projectile.OwnerParticipant] ~= nil
end

function ArenaCombatService.PlayerRemoving(player)
	ArenaCombatService.LeaveArena(player)
end

return ArenaCombatService
