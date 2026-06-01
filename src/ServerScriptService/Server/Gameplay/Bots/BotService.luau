local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local BotConfig = require(configs:WaitForChild("BotConfig"))
local BattleArenaLoopConfig = require(configs:WaitForChild("BattleArenaLoopConfig"))
local PerformanceConfig = require(configs:WaitForChild("PerformanceConfig"))

local BotController = require(script.Parent:WaitForChild("BotController"))
local BotSpawnPlanner = require(script.Parent:WaitForChild("BotSpawnPlanner"))
local TankRole = require(script.Parent.Parent:WaitForChild("Tanks"):WaitForChild("TankRole"))
local TankStatsProfile = require(script.Parent.Parent:WaitForChild("Tanks"):WaitForChild("TankStatsProfile"))

local BotService = {}

local MODE_IN_BATTLE_ARENA = "InBattleArena"
local BOT_ID_PREFIX = "ArenaBot_"
local BOT_TEAM_ID = "Bots"

local tankFactory = nil
local tankParticipantRegistry = nil
local tankSpawnResetService = nil
local tankMovementService = nil
local projectileService = nil
local arenaCombatService = nil
local spawnPlanner = nil
local addMovementIgnoredParticipant = nil

local initialized = false
local botRecords = {}
local botRecordsById = {}
local nextBotIndex = 1
local lastDebugLogAtByKey = {}
local spawnStaggerTimer = 0

local function getDiagnosticsConfig()
	return PerformanceConfig.Diagnostics or {}
end

local function debugLog(key, message)
	if BotConfig.Debug ~= true then
		return
	end

	local now = os.clock()

	if now - (lastDebugLogAtByKey[key] or 0) < 1 then
		return
	end

	lastDebugLogAtByKey[key] = now
	print(message)
end

local function isBattleArenaBotsEnabled()
	local battleArenaConfig = BotConfig.BattleArena or {}
	local diagnosticsConfig = getDiagnosticsConfig()

	return diagnosticsConfig.BattleArenaBotsEnabled ~= false
		and BotConfig.Enabled == true
		and battleArenaConfig.Enabled == true
end

local function getConfiguredBotLimit()
	local battleArenaConfig = BotConfig.BattleArena or {}
	local loopBotConfig = BattleArenaLoopConfig.Enabled == true and BattleArenaLoopConfig.Bots or {}
	local safetyConfig = BotConfig.Safety or {}
	local diagnosticsConfig = getDiagnosticsConfig()
	local maxBots = math.max(0, math.floor(tonumber(loopBotConfig.MaxBots) or tonumber(battleArenaConfig.MaxBots) or 0))
	local hardLimit = math.max(0, math.floor(tonumber(safetyConfig.MaxBotsHardLimit) or maxBots))
	local maxBotsOverride = tonumber(diagnosticsConfig.BattleArenaMaxBotsOverride)

	if maxBotsOverride ~= nil then
		maxBots = math.max(0, math.floor(maxBotsOverride))
	end

	if hardLimit <= 0 then
		return maxBots
	end

	return math.min(maxBots, hardLimit)
end

local function getDesiredBotCount()
	if not isBattleArenaBotsEnabled() or arenaCombatService == nil then
		return 0
	end

	local battleArenaConfig = BotConfig.BattleArena or {}
	local loopBotConfig = BattleArenaLoopConfig.Enabled == true and BattleArenaLoopConfig.Bots or {}
	local playerCount = arenaCombatService.GetActivePlayerCount ~= nil
		and arenaCombatService.GetActivePlayerCount()
		or 0

	if playerCount <= 0 then
		return 0
	end

	if loopBotConfig.MaintainMinBots == true then
		local minBots = playerCount <= 1
			and math.max(0, math.floor(tonumber(loopBotConfig.MinBotsSolo) or 0))
			or math.max(0, math.floor(tonumber(loopBotConfig.MinBotsWithPlayers) or 0))

		return math.min(minBots, getConfiguredBotLimit())
	end

	local spawnThreshold = math.max(1, math.floor(tonumber(battleArenaConfig.SpawnWhenPlayerCountLessThan) or 2))

	if playerCount >= spawnThreshold then
		return 0
	end

	local minBots = math.max(0, math.floor(tonumber(battleArenaConfig.MinBots) or 0))

	return math.min(minBots, getConfiguredBotLimit())
end

local function getActiveBotRecords()
	local activeRecords = {}

	for _, record in ipairs(botRecords) do
		if record.Active == true then
			table.insert(activeRecords, record)
		end
	end

	return activeRecords
end

local function makeBotTankId()
	local tankId = BOT_ID_PREFIX .. tostring(nextBotIndex)
	nextBotIndex += 1
	return tankId
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

local function isParticipantDead(participant)
	if participant == nil then
		return true
	end

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantIsDead ~= nil then
		return tankParticipantRegistry.getParticipantIsDead(participant)
	end

	return participant.IsDead == true
end

local function registerBotInArena(participant)
	if arenaCombatService ~= nil and arenaCombatService.RegisterBotParticipant ~= nil then
		arenaCombatService.RegisterBotParticipant(participant)
	end
end

local function unregisterBotFromArena(participant)
	if arenaCombatService ~= nil and arenaCombatService.UnregisterBotParticipant ~= nil then
		arenaCombatService.UnregisterBotParticipant(participant)
	end
end

local function makeController(participant)
	return BotController.new({
		Participant = participant,
		TankParticipantRegistry = tankParticipantRegistry,
		TankMovementService = tankMovementService,
		TankSpawnResetService = tankSpawnResetService,
		ProjectileService = projectileService,
		GetArenaParticipants = function()
			if arenaCombatService ~= nil and arenaCombatService.GetActiveParticipants ~= nil then
				return arenaCombatService.GetActiveParticipants()
			end

			return {}
		end,
		GetControlZonePosition = function()
			if arenaCombatService ~= nil and arenaCombatService.GetControlZonePosition ~= nil then
				return arenaCombatService.GetControlZonePosition()
			end

			return nil
		end,
	})
end

-- Per-spawn (not per-frame) log of where an arena bot was placed and from which source.
local function logArenaSpawn(participant, spawnTransform)
	if participant == nil or spawnTransform == nil then
		return
	end

	local arena = spawnPlanner ~= nil and spawnPlanner.Root ~= nil and spawnPlanner.Root:FindFirstChild("BattleArena") or nil
	local pos = spawnTransform.Position or Vector3.zero

	print(("[ARENA SPAWN] Bot %s spawn=%s pos=(%.1f, %.1f, %.1f) arena=%s"):format(
		tostring(participant.TankId),
		tostring(spawnTransform.SourcePath or spawnTransform.Source or "?"),
		pos.X, pos.Y, pos.Z,
		arena ~= nil and arena:GetFullName() or "Workspace.WOB_Generated.BattleArena (missing)"))
end

local function activateBotRecord(record)
	local participant = record.Participant
	local spawnTransform = spawnPlanner:GetNextSpawnTransform()

	if addMovementIgnoredParticipant ~= nil then
		addMovementIgnoredParticipant(participant)
	end

	registerBotInArena(participant)
	tankParticipantRegistry.setParticipantMatchState(participant, MODE_IN_BATTLE_ARENA, nil, nil)
	tankParticipantRegistry.setParticipantModelVisible(participant, true)
	tankParticipantRegistry.resetParticipantHealth(participant)
	tankSpawnResetService.restoreTankColors(participant.TankId)
	tankSpawnResetService.applySpawnToParticipant(participant, spawnTransform)

	record.Controller = makeController(participant)
	record.Active = true
	record.RespawnAt = nil

	logArenaSpawn(participant, spawnTransform)
	debugLog("spawn:" .. participant.TankId, "[BOT] spawned id=" .. tostring(participant.TankId))
end

local function createBotRecord()
	local tankId = makeBotTankId()
	local spawnTransform = spawnPlanner:GetNextSpawnTransform()
	local result = tankFactory:SpawnTank({
		TankId = tankId,
		Role = TankRole.ArenaBot,
		TeamId = BOT_TEAM_ID,
		OwnerUserId = 0,
		OwnerName = "Bot",
		IsBot = true,
		IsPlayerTank = false,
		IsActive = true,
		StatsProfileId = TankStatsProfile.BotDefault,
		SpawnTransform = spawnTransform,
		SpawnName = "ArenaBotSpawn",
	})
	local participant = result.Participant
	local model = getParticipantModel(participant)

	if model ~= nil then
		tankSpawnResetService.captureTankColors(participant.TankId, model)
	end

	-- Place the freshly-cloned bot at a BattleArena spawn immediately. Without this the clone
	-- keeps the template's CFrame (which can sit near the Duel/Map area) until activation,
	-- which is exactly the "bot appears near Duel" symptom. Arena-only source via spawnPlanner.
	tankSpawnResetService.applySpawnToParticipant(participant, spawnTransform)

	local record = {
		TankId = tankId,
		Participant = participant,
		Controller = nil,
		Active = false,
		RespawnAt = nil,
	}

	table.insert(botRecords, record)
	botRecordsById[tankId] = record
	activateBotRecord(record)

	return record
end

local function deactivateBotRecord(record)
	if record == nil or record.Active ~= true then
		return
	end

	local participant = record.Participant

	if record.Controller ~= nil then
		record.Controller:Destroy()
		record.Controller = nil
	end

	unregisterBotFromArena(participant)

	if participant ~= nil then
		tankParticipantRegistry.setParticipantMatchState(participant, nil, nil, nil)
		tankParticipantRegistry.setParticipantModelVisible(participant, false)
	end

	record.Active = false
	record.RespawnAt = nil

	debugLog("despawn:" .. tostring(record.TankId), "[BOT] despawned id=" .. tostring(record.TankId))
end

local function getSpawnStaggerConfig()
	local spawnConfig = BotConfig.Spawn or {}
	local interval = math.max(0, tonumber(spawnConfig.IntervalSeconds) or 0)
	local maxPerTick = math.max(1, math.floor(tonumber(spawnConfig.MaxPerTick) or 1))

	return interval, maxPerTick
end

-- Activates one inactive record if available (reuse, no clone), otherwise creates
-- a fresh bot record. Returns the (now active) record. Both paths count as one
-- spawn for stagger purposes, because reactivating many records in one frame also
-- causes a spike (registration, color/health reset, controller creation).
local function spawnOneBot(activeRecords)
	local inactiveRecord = nil

	for _, record in ipairs(botRecords) do
		if record.Active ~= true then
			inactiveRecord = record
			break
		end
	end

	if inactiveRecord ~= nil then
		activateBotRecord(inactiveRecord)
		table.insert(activeRecords, inactiveRecord)
		return inactiveRecord
	end

	local createdRecord = createBotRecord()
	table.insert(activeRecords, createdRecord)
	return createdRecord
end

-- Brings the active bot population toward desiredCount.
-- Removal of excess bots happens immediately (deactivation is cheap and does not
-- clone/spawn anything). Filling missing bots is *staggered*: at most MaxPerTick
-- bots are added per call, and only after IntervalSeconds has elapsed, so the
-- whole deficit is not filled on a single Heartbeat frame (e.g. on BattleArena
-- entry). The eventual desired count is still reached over subsequent ticks, so
-- gameplay outcome is unchanged.
local function ensureBotCount(desiredCount, deltaTime)
	local activeRecords = getActiveBotRecords()
	local activeCount = #activeRecords

	if activeCount > desiredCount then
		for index = activeCount, desiredCount + 1, -1 do
			deactivateBotRecord(activeRecords[index])
		end

		spawnStaggerTimer = 0
		return
	end

	if activeCount >= desiredCount then
		spawnStaggerTimer = 0
		return
	end

	local interval, maxPerTick = getSpawnStaggerConfig()

	if interval > 0 then
		spawnStaggerTimer += math.max(0, tonumber(deltaTime) or 0)

		if spawnStaggerTimer < interval then
			return
		end
	end

	spawnStaggerTimer = 0

	local spawnedThisTick = 0

	while activeCount < desiredCount and spawnedThisTick < maxPerTick do
		spawnOneBot(activeRecords)
		activeCount += 1
		spawnedThisTick += 1
	end
end

local function updateRespawn(record)
	local participant = record.Participant

	if participant == nil or not isParticipantDead(participant) then
		return false
	end

	local battleArenaConfig = BotConfig.BattleArena or {}
	local loopBotConfig = BattleArenaLoopConfig.Enabled == true and BattleArenaLoopConfig.Bots or {}
	local now = os.clock()

	if record.RespawnAt == nil then
		record.RespawnAt = now + math.max(0, tonumber(loopBotConfig.RespawnDelay) or tonumber(battleArenaConfig.RespawnDelay) or 3)
		debugLog("died:" .. tostring(record.TankId), "[BOT] died id=" .. tostring(record.TankId))
		return true
	end

	if now < record.RespawnAt then
		return true
	end

	if record.Controller ~= nil then
		record.Controller:Destroy()
	end

	activateBotRecord(record)
	debugLog("respawn:" .. tostring(record.TankId), "[BOT] respawned id=" .. tostring(record.TankId))

	return true
end

function BotService.init(options)
	options = options or {}

	tankFactory = options.TankFactory
	tankParticipantRegistry = options.TankParticipantRegistry
	tankSpawnResetService = options.TankSpawnResetService
	tankMovementService = options.TankMovementService
	projectileService = options.ProjectileService
	arenaCombatService = options.ArenaCombatService
	addMovementIgnoredParticipant = options.AddMovementIgnoredParticipant
	spawnPlanner = options.SpawnPlanner or BotSpawnPlanner.new(options.Root)
	initialized = true
end

function BotService.update(deltaTime)
	if not initialized then
		return
	end

	local desiredCount = getDesiredBotCount()
	ensureBotCount(desiredCount, deltaTime)

	if desiredCount <= 0 and (BotConfig.Safety or {}).CleanupOnPlayerLeave ~= false then
		return
	end

	for _, record in ipairs(getActiveBotRecords()) do
		if updateRespawn(record) then
			continue
		end

		if record.Controller ~= nil then
			record.Controller:Update(deltaTime)
		end
	end
end

function BotService.cleanupAll()
	for _, record in ipairs(botRecords) do
		deactivateBotRecord(record)
	end
end

return BotService
