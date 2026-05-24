local ArenaCombatService = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local BattleArenaConfig = require(configs:WaitForChild("BattleArenaConfig"))
local BattleArenaLoopConfig = require(configs:WaitForChild("BattleArenaLoopConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))

ArenaCombatService.MODE_IN_BATTLE_ARENA = "InBattleArena"
ArenaCombatService.MODE_ARENA_RESPAWNING = "ArenaRespawning"

local root = nil
local tankSpawnResetService = nil
local playerWalletService = nil
local upgradeChoiceEvent = nil
local reviveRequestEvent = nil
local freeRespawnRequestEvent = nil
local upgradeChoiceConnection = nil
local reviveRequestConnection = nil
local freeRespawnRequestConnection = nil

local callbacks = {
	setPlayerMode = nil,
	clearPlayerInput = nil,
	restoreTankColors = nil,
}

local sessionsByPlayer = {}
local sessionsByParticipant = {}
local nextSpawnIndex = 1
local poiStateByInstance = {}
local pickupAccumulator = 0
local controlZoneAccumulator = 0
local survivalAccumulator = 0
local random = Random.new()

local UPGRADE_ORDER = {
	"DamageUp",
	"FireRateUp",
	"MoveSpeedUp",
	"DoubleShot",
	"TripleSpread",
	"RicochetUp",
	"ReflectShield",
	"Repair",
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

local function isLoopV02Enabled()
	return BattleArenaLoopConfig.Enabled == true
end

local function getLoopSection(sectionName)
	if not isLoopV02Enabled() then
		return {}
	end

	return BattleArenaLoopConfig[sectionName] or {}
end

local function getLoopNumber(sectionName, valueName, fallback)
	local section = getLoopSection(sectionName)

	return tonumber(section[valueName]) or fallback
end

local function hasProjectileRicochet(sourceProjectile)
	return sourceProjectile ~= nil and (tonumber(sourceProjectile.BounceCount) or 0) > 0
end

local function getSessionSoftEndAt(startedAt)
	local sessionConfig = getLoopSection("Session")

	if sessionConfig.ShowSessionTimer ~= true then
		return 0
	end

	local duration = math.max(0, tonumber(sessionConfig.SoftSessionLengthSeconds) or 0)

	if duration <= 0 then
		return 0
	end

	return startedAt + duration
end

local function getArenaFolder()
	return root ~= nil and root:FindFirstChild("BattleArena") or nil
end

local function getArenaChild(name)
	local arena = getArenaFolder()

	return arena ~= nil and arena:FindFirstChild(name) or nil
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

local function getReflectShieldConfig()
	return BattleArenaConfig.ReflectShield or {}
end

local function getReflectShieldMaxCharges()
	return math.max(0, math.floor(tonumber(getReflectShieldConfig().MaxCharges) or 3))
end

local function getReflectShieldSpawnDuration()
	return math.max(0, tonumber(getReflectShieldConfig().SpawnDurationSeconds) or 3)
end

local function isSpawnShieldActive(session, now)
	if session == nil then
		return false
	end

	local serverTime = typeof(now) == "number" and now or getServerTimeNow()
	local spawnShieldUntil = tonumber(session.SpawnShieldUntil)

	return spawnShieldUntil ~= nil and serverTime < spawnShieldUntil
end

local function hasReflectShieldCharge(session)
	return session ~= nil and (tonumber(session.ReflectShieldCharges) or 0) > 0
end

local function isAnyReflectShieldActive(session, now)
	return isSpawnShieldActive(session, now) or hasReflectShieldCharge(session)
end

local function publishShieldAttributes(session, now)
	if session == nil then
		return
	end

	local serverTime = typeof(now) == "number" and now or getServerTimeNow()
	local charges = math.clamp(
		math.floor(tonumber(session.ReflectShieldCharges) or 0),
		0,
		getReflectShieldMaxCharges()
	)
	local spawnShieldUntil = math.max(0, tonumber(session.SpawnShieldUntil) or 0)
	local player = session.Player
	local participant = session.Participant

	session.ReflectShieldCharges = charges
	session.SpawnShieldUntil = spawnShieldUntil
	local shieldActive = isAnyReflectShieldActive(session, serverTime)

	if player ~= nil then
		player:SetAttribute("ArenaReflectShieldCharges", charges)
		player:SetAttribute("ArenaSpawnShieldUntil", spawnShieldUntil)
		player:SetAttribute("ArenaShieldActive", shieldActive)
	end

	if participant ~= nil then
		participant.ArenaReflectShieldCharges = charges
		participant.ArenaSpawnShieldUntil = spawnShieldUntil
		participant.ArenaShieldActive = shieldActive
		setAttributeOnParticipantModels(participant, "ArenaReflectShieldCharges", charges)
		setAttributeOnParticipantModels(participant, "ArenaSpawnShieldUntil", spawnShieldUntil)
		setAttributeOnParticipantModels(participant, "ArenaShieldActive", shieldActive)
	end
end

local function republishShieldAttributesSoon(session)
	task.defer(function()
		local currentSession = session ~= nil
			and (
				(session.Player ~= nil and sessionsByPlayer[session.Player])
				or sessionsByParticipant[session.Participant]
			)
			or nil

		if currentSession == session then
			publishShieldAttributes(session)
		end
	end)
end

local function scheduleSpawnShieldExpiry(session)
	if session == nil then
		return
	end

	local duration = getReflectShieldSpawnDuration()

	if duration <= 0 then
		return
	end

	session.ShieldToken = (session.ShieldToken or 0) + 1
	local shieldToken = session.ShieldToken

	task.delay(duration, function()
		if session.ShieldToken ~= shieldToken then
			return
		end

		local currentSession = session.Player ~= nil
			and sessionsByPlayer[session.Player]
			or sessionsByParticipant[session.Participant]

		if currentSession ~= session then
			return
		end

		local now = getServerTimeNow()

		if (tonumber(session.SpawnShieldUntil) or 0) <= now then
			session.SpawnShieldUntil = 0
			publishShieldAttributes(session, now)
		end
	end)
end

local function grantSpawnReflectShield(session, _reason)
	if session == nil then
		return
	end

	local duration = getReflectShieldSpawnDuration()

	if duration <= 0 then
		session.SpawnShieldUntil = 0
		publishShieldAttributes(session)
		return
	end

	local now = getServerTimeNow()
	session.SpawnShieldUntil = now + duration
	publishShieldAttributes(session, now)
	scheduleSpawnShieldExpiry(session)
	republishShieldAttributesSoon(session)
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
	setArenaModifier(participant, "ArenaRicochetBonus", 0)
	setArenaModifier(participant, "ArenaUpgradeIds", "")
	setArenaModifier(participant, "ArenaReflectShieldCharges", 0)
	setArenaModifier(participant, "ArenaSpawnShieldUntil", 0)
	setArenaModifier(participant, "ArenaShieldActive", false)
end

local function getReviveConfig()
	return BattleArenaConfig.Revive or {}
end

local function isReviveEnabled()
	return getReviveConfig().Enabled == true
end

local function getMaxRevivesPerRun()
	return math.max(0, math.floor(tonumber(getReviveConfig().MaxRevivesPerRun) or 0))
end

local function getReviveCost(session)
	local reviveConfig = getReviveConfig()
	local reviveCount = math.max(0, math.floor(tonumber(session ~= nil and session.ReviveCount) or 0))
	local baseCost = tonumber(reviveConfig.CostBase)
		or tonumber(reviveConfig.CostBaseBolts)
		or 5
	local perRevive = tonumber(reviveConfig.CostPerRevive)
		or tonumber(reviveConfig.CostAdditiveBolts)
		or 0
	local multiplier = tonumber(reviveConfig.CostMultiplier) or 1
	local scaledCost = (baseCost + perRevive * reviveCount) * (multiplier ^ reviveCount)

	return math.max(1, math.floor(scaledCost + 0.5))
end

local function getReviveRestoreHpPercent()
	local reviveConfig = getReviveConfig()
	local percent = tonumber(reviveConfig.RestoreHpPercent)
		or tonumber(reviveConfig.ReviveHpPercent)
		or 0.5

	return math.clamp(percent, 0.05, 1)
end

local function isFreeRespawnEnabled()
	return getReviveConfig().FreeRespawnEnabled == true
end

local function shouldFreeRespawnResetRun()
	return getReviveConfig().FreeRespawnResetsRun ~= false
end

local function getFreeRespawnRestoreHpPercent()
	local percent = tonumber(getReviveConfig().FreeRespawnRestoreHpPercent) or 1

	return math.clamp(percent, 0.05, 1)
end

local function canOfferRevive(session)
	return isReviveEnabled()
		and session ~= nil
		and session.IsBotSession ~= true
		and session.Player ~= nil
		and (tonumber(session.ReviveCount) or 0) < getMaxRevivesPerRun()
end

local function canOfferFreeRespawn(session)
	return isFreeRespawnEnabled()
		and session ~= nil
		and session.IsBotSession ~= true
		and session.Player ~= nil
end

local function canAffordRevive(session)
	if session == nil or session.Player == nil or playerWalletService == nil then
		return false
	end

	local getBalance = playerWalletService.getBoltsBalance

	if getBalance == nil then
		return false
	end

	return getBalance(session.Player) >= getReviveCost(session)
end

local function clearRevivePending(session)
	if session == nil then
		return
	end

	session.RevivePending = false
	session.ReviveCost = 0
	session.ReviveLastError = ""
end

local function clearFreeRespawnPending(session)
	if session == nil then
		return
	end

	session.FreeRespawnPending = false
	session.FreeRespawnLastError = ""
end

local function resetReviveRunState(session)
	if session == nil then
		return
	end

	session.ReviveCount = 0
	clearRevivePending(session)
	clearFreeRespawnPending(session)
end

local function beginRevivePending(session)
	if not canOfferRevive(session) then
		return false
	end

	session.RevivePending = true
	session.ReviveCost = getReviveCost(session)
	session.ReviveLastError = ""

	return true
end

local function beginFreeRespawnPending(session)
	if not canOfferFreeRespawn(session) then
		return false
	end

	session.FreeRespawnPending = true
	session.FreeRespawnLastError = ""

	return true
end

local function setPlayerArenaDefaults(player)
	if player == nil then
		return
	end

	player:SetAttribute("ArenaScore", 0)
	player:SetAttribute("ArenaXP", 0)
	player:SetAttribute("ArenaLevel", 1)
	player:SetAttribute("ArenaNextLevelXP", BattleArenaConfig.LevelThresholds[2])
	player:SetAttribute("ArenaKills", 0)
	player:SetAttribute("ArenaDeaths", 0)
	player:SetAttribute("ArenaStreak", 0)
	player:SetAttribute("ArenaRespawnAt", 0)
	player:SetAttribute("ArenaRespawnDelay", BattleArenaConfig.RespawnDelay)
	player:SetAttribute("ArenaStatus", "")
	player:SetAttribute("ArenaUpgradeIds", "")
	player:SetAttribute("ArenaPendingUpgradeOfferId", "")
	player:SetAttribute("ArenaPendingUpgradeOfferSource", "")
	player:SetAttribute("ArenaSessionStartedAt", 0)
	player:SetAttribute("ArenaSessionSoftEndsAt", 0)
	player:SetAttribute("ArenaSessionBolts", 0)
	player:SetAttribute("ArenaLastSummary", "")
	player:SetAttribute("ArenaRevivePending", false)
	player:SetAttribute("ArenaReviveCost", 0)
	player:SetAttribute("ArenaRevivesUsed", 0)
	player:SetAttribute("ArenaMaxRevives", getMaxRevivesPerRun())
	player:SetAttribute("ArenaCanRevive", false)
	player:SetAttribute("ArenaReviveLastError", "")
	player:SetAttribute("ArenaFreeRespawnAvailable", false)
	player:SetAttribute("ArenaDamageMultiplier", 1)
	player:SetAttribute("ArenaFireRateMultiplier", 1)
	player:SetAttribute("ArenaMoveSpeedMultiplier", 1)
	player:SetAttribute("ArenaProjectileCount", 1)
	player:SetAttribute("ArenaRicochetBonus", 0)
	player:SetAttribute("ArenaReflectShieldCharges", 0)
	player:SetAttribute("ArenaSpawnShieldUntil", 0)
	player:SetAttribute("ArenaShieldActive", false)
end

local function publishSessionAttributes(session)
	local player = session.Player

	if player == nil then
		return
	end

	player:SetAttribute("ArenaScore", session.Score)
	player:SetAttribute("ArenaXP", session.ArenaXP)
	player:SetAttribute("ArenaLevel", session.ArenaLevel)
	player:SetAttribute("ArenaNextLevelXP", session.NextLevelXP)
	player:SetAttribute("ArenaKills", session.Kills)
	player:SetAttribute("ArenaDeaths", session.Deaths)
	player:SetAttribute("ArenaStreak", session.Streak)
	player:SetAttribute("ArenaUpgradeIds", table.concat(session.UpgradeIds, ","))
	player:SetAttribute("ArenaPendingUpgradeOfferId", session.PendingUpgradeOfferId or "")
	player:SetAttribute("ArenaPendingUpgradeOfferSource", session.PendingUpgradeOfferSource or "")
	player:SetAttribute("ArenaSessionStartedAt", session.StartedAt or 0)
	player:SetAttribute("ArenaSessionSoftEndsAt", session.SoftEndsAt or 0)
	player:SetAttribute("ArenaSessionBolts", session.EarnedBolts or 0)
	player:SetAttribute("ArenaLastSummary", session.LastSummary or "")
	player:SetAttribute("ArenaRevivePending", session.RevivePending == true)
	player:SetAttribute("ArenaReviveCost", session.RevivePending == true and getReviveCost(session) or 0)
	player:SetAttribute("ArenaRevivesUsed", math.max(0, math.floor(tonumber(session.ReviveCount) or 0)))
	player:SetAttribute("ArenaMaxRevives", getMaxRevivesPerRun())
	player:SetAttribute("ArenaCanRevive", session.RevivePending == true and canAffordRevive(session))
	player:SetAttribute("ArenaReviveLastError", tostring(session.ReviveLastError or ""))
	player:SetAttribute("ArenaFreeRespawnAvailable", session.FreeRespawnPending == true)
	player:SetAttribute("ArenaDamageMultiplier", session.DamageMultiplier)
	player:SetAttribute("ArenaFireRateMultiplier", session.FireRateMultiplier)
	player:SetAttribute("ArenaMoveSpeedMultiplier", session.MoveSpeedMultiplier)
	player:SetAttribute("ArenaProjectileCount", session.ProjectileCount)
	player:SetAttribute("ArenaRicochetBonus", session.RicochetBonus)
	publishShieldAttributes(session)
end

local function hasUpgrade(session, upgradeId)
	for _, existingUpgradeId in ipairs(session.UpgradeIds) do
		if existingUpgradeId == upgradeId then
			return true
		end
	end

	return false
end

local function countUpgradeStacks(session, upgradeId)
	local count = 0

	for _, existingUpgradeId in ipairs(session.UpgradeIds) do
		if existingUpgradeId == upgradeId then
			count += 1
		end
	end

	return count
end

local function getUpgradeDefinition(upgradeId)
	local pool = BattleArenaConfig.UpgradePool or {}

	return pool[upgradeId]
end

local function getUpgradeMaxStacks(upgradeId)
	local definition = getUpgradeDefinition(upgradeId)

	if definition == nil then
		return 0
	end

	if definition.Immediate == true then
		return math.huge
	end

	return math.max(1, math.floor(tonumber(definition.MaxStacks) or 1))
end

local function isBlockedByOwnedUpgrade(session, blockedUpgradeIds)
	if typeof(blockedUpgradeIds) == "string" then
		return hasUpgrade(session, blockedUpgradeIds)
	end

	if typeof(blockedUpgradeIds) ~= "table" then
		return false
	end

	for _, blockedUpgradeId in ipairs(blockedUpgradeIds) do
		if typeof(blockedUpgradeId) == "string" and hasUpgrade(session, blockedUpgradeId) then
			return true
		end
	end

	return false
end

local function isUpgradeChoiceValid(session, upgradeId)
	if session == nil or typeof(upgradeId) ~= "string" then
		return false
	end

	local definition = getUpgradeDefinition(upgradeId)

	if definition == nil then
		return false
	end

	if definition.Enabled == false or definition.FutureOnly == true then
		return false
	end

	local minArenaLevel = tonumber(definition.MinArenaLevel)

	if minArenaLevel ~= nil and session.ArenaLevel < minArenaLevel then
		return false
	end

	local maxOfferLevel = tonumber(definition.MaxOfferLevel)

	if maxOfferLevel ~= nil and session.ArenaLevel > maxOfferLevel then
		return false
	end

	local offerAfterLevel = tonumber(definition.OfferAfterLevel)

	if offerAfterLevel ~= nil and session.ArenaLevel <= offerAfterLevel then
		return false
	end

	if isBlockedByOwnedUpgrade(session, definition.BlocksUpgrade) then
		return false
	end

	if definition.Immediate == true then
		return true
	end

	if upgradeId == "DoubleShot" and hasUpgrade(session, "TripleSpread") then
		return false
	end

	if upgradeId == "TripleSpread" and not hasUpgrade(session, "DoubleShot") then
		return false
	end

	local requiredUpgrade = definition.RequiresUpgrade

	if typeof(requiredUpgrade) == "string" and not hasUpgrade(session, requiredUpgrade) then
		return false
	end

	return countUpgradeStacks(session, upgradeId) < getUpgradeMaxStacks(upgradeId)
end

local function getValidUpgradeIds(session)
	local upgradeIds = {}

	for _, upgradeId in ipairs(UPGRADE_ORDER) do
		if isUpgradeChoiceValid(session, upgradeId) then
			table.insert(upgradeIds, upgradeId)
		end
	end

	return upgradeIds
end

local function makeUpgradeChoicePayload(session, upgradeId)
	local definition = getUpgradeDefinition(upgradeId) or {}
	local currentStacks = countUpgradeStacks(session, upgradeId)
	local maxStacks = getUpgradeMaxStacks(upgradeId)

	return {
		Id = upgradeId,
		Title = definition.Title or upgradeId,
		Description = definition.Description or "",
		Stack = definition.Immediate == true and 0 or currentStacks + 1,
		MaxStacks = maxStacks == math.huge and 0 or maxStacks,
		Immediate = definition.Immediate == true,
	}
end

local function applySessionUpgrades(session)
	local participant = session.Participant
	local damageStacks = countUpgradeStacks(session, "DamageUp")
	local moveSpeedStacks = countUpgradeStacks(session, "MoveSpeedUp")
	local damageStep = (tonumber(BattleArenaConfig.DamageUpMultiplier) or 1.2) - 1
	local moveSpeedStep = (tonumber(BattleArenaConfig.MoveSpeedMultiplier) or 1.1) - 1

	session.DamageMultiplier = 1 + damageStep * damageStacks
	session.FireRateMultiplier = hasUpgrade(session, "FireRateUp") and BattleArenaConfig.FireRateMultiplier or 1
	session.MoveSpeedMultiplier = 1 + moveSpeedStep * moveSpeedStacks
	session.RicochetBonus = hasUpgrade(session, "RicochetUp") and (tonumber(BattleArenaConfig.RicochetUpBonus) or 1) or 0

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
	setArenaModifier(participant, "ArenaRicochetBonus", session.RicochetBonus)
	setArenaModifier(participant, "ArenaUpgradeIds", table.concat(session.UpgradeIds, ","))
	publishSessionAttributes(session)

	if BattleArenaConfig.Debug == true then
		local ownerName = session.Player ~= nil and session.Player.Name or tostring(participant ~= nil and participant.TankId or "Bot")
		print("[ARENA] upgrades " .. ownerName .. " -> " .. table.concat(session.UpgradeIds, ","))
	end
end

local function getLevelThreshold(level)
	local thresholds = BattleArenaConfig.LevelThresholds or {}
	local numericLevel = math.max(1, math.floor(tonumber(level) or 1))
	local explicitThreshold = tonumber(thresholds[numericLevel])

	if explicitThreshold ~= nil then
		return explicitThreshold
	end

	local highestLevel = 1
	local highestThreshold = 0

	for thresholdLevel, threshold in pairs(thresholds) do
		local parsedLevel = tonumber(thresholdLevel)
		local parsedThreshold = tonumber(threshold)

		if parsedLevel ~= nil
			and parsedThreshold ~= nil
			and parsedLevel > highestLevel
		then
			highestLevel = parsedLevel
			highestThreshold = parsedThreshold
		end
	end

	if numericLevel <= highestLevel then
		return nil
	end

	local postMaxLevelXPStep = math.max(1, math.floor(tonumber(BattleArenaConfig.PostMaxLevelXPStep) or 350))

	return highestThreshold + (numericLevel - highestLevel) * postMaxLevelXPStep
end

local function getNextLevelThreshold(level)
	return getLevelThreshold((tonumber(level) or 1) + 1)
end

local function getMaxArenaLevel()
	local maxArenaLevel = tonumber(BattleArenaConfig.MaxArenaLevel)

	if maxArenaLevel == nil or maxArenaLevel <= 0 then
		return math.huge
	end

	return math.max(1, math.floor(maxArenaLevel))
end

local function getMaxUpgradeLevel()
	local maxUpgradeLevel = tonumber(BattleArenaConfig.MaxUpgradeLevel)
		or tonumber(BattleArenaConfig.CoreBuildLevel)
		or 5

	return math.max(1, math.floor(maxUpgradeLevel))
end

local function shouldGrantLevelUpgradeOffer(arenaLevel)
	return (tonumber(arenaLevel) or 1) <= getMaxUpgradeLevel()
end

local function updateNextLevelXP(session)
	if session.ArenaLevel >= getMaxArenaLevel() then
		session.NextLevelXP = nil
	else
		session.NextLevelXP = getNextLevelThreshold(session.ArenaLevel)
	end
end

local function clearPendingUpgradeOffer(session)
	session.PendingUpgradeOffer = nil
	session.PendingUpgradeOfferId = ""
	session.PendingUpgradeOfferSource = ""
	publishSessionAttributes(session)
end

local function fireUpgradeOffer(session)
	if upgradeChoiceEvent == nil or session.Player == nil or session.PendingUpgradeOffer == nil then
		return
	end

	upgradeChoiceEvent:FireClient(session.Player, session.PendingUpgradeOffer)
end

local function createUpgradeOffer(session, source)
	if session == nil or session.Player == nil or session.PendingUpgradeOffer ~= nil then
		return false
	end

	local validUpgradeIds = getValidUpgradeIds(session)

	if #validUpgradeIds == 0 then
		return false
	end

	for index = #validUpgradeIds, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		validUpgradeIds[index], validUpgradeIds[swapIndex] = validUpgradeIds[swapIndex], validUpgradeIds[index]
	end

	local choiceCount = math.min(
		math.max(1, math.floor(tonumber(BattleArenaConfig.UpgradeChoicesPerOffer) or 3)),
		#validUpgradeIds
	)
	local choices = {}

	for index = 1, choiceCount do
		table.insert(choices, makeUpgradeChoicePayload(session, validUpgradeIds[index]))
	end

	local offerId = "ArenaOffer_" .. HttpService:GenerateGUID(false)
	session.PendingUpgradeOffer = {
		OfferId = offerId,
		Source = source or "LevelUp",
		ArenaLevel = session.ArenaLevel,
		Choices = choices,
	}
	session.PendingUpgradeOfferId = offerId
	session.PendingUpgradeOfferSource = source or "LevelUp"
	publishSessionAttributes(session)
	fireUpgradeOffer(session)

	return true
end

local function ensurePendingLevelOffer(session)
	if session == nil or session.PendingUpgradeOffer ~= nil then
		return
	end

	if (session.UnclaimedLevelUpOffers or 0) <= 0 then
		return
	end

	if not createUpgradeOffer(session, "LevelUp") then
		session.UnclaimedLevelUpOffers = 0
		publishSessionAttributes(session)
	end
end

local function addArenaXP(session, amount, reason)
	if session == nil or session.IsBotSession == true then
		return false
	end

	local xpAmount = math.max(0, math.floor(tonumber(amount) or 0))

	if xpAmount <= 0 then
		return false
	end

	session.ArenaXP += xpAmount

	local maxLevel = getMaxArenaLevel()

	while session.ArenaLevel < maxLevel do
		local nextThreshold = getNextLevelThreshold(session.ArenaLevel)

		if nextThreshold == nil or session.ArenaXP < nextThreshold then
			break
		end

		session.ArenaLevel += 1

		if shouldGrantLevelUpgradeOffer(session.ArenaLevel) then
			session.UnclaimedLevelUpOffers += 1
		end
	end

	updateNextLevelXP(session)
	publishSessionAttributes(session)
	ensurePendingLevelOffer(session)

	if BattleArenaConfig.Debug == true then
		local playerName = session.Player ~= nil and session.Player.Name or "Unknown"
		print(
			("[ARENA XP] player=%s amount=%d reason=%s xp=%d level=%d"):format(
				playerName,
				xpAmount,
				tostring(reason or "Unknown"),
				session.ArenaXP,
				session.ArenaLevel
			)
		)
	end

	return true
end

local function applyRepairUpgrade(session)
	local participant = session.Participant

	if participant == nil then
		return
	end

	local currentHealth = TankParticipantRegistry.getParticipantHealth(participant)
	local maxHealth = TankParticipantRegistry.getParticipantMaxHealth(participant)
	local healAmount = math.max(0, tonumber(BattleArenaConfig.RepairHealAmount) or 30)

	TankParticipantRegistry.setParticipantHealth(participant, math.min(maxHealth, currentHealth + healAmount))
end

local function grantReflectShieldUpgradeCharge(session)
	if session == nil then
		return
	end

	local grantCharges = math.max(0, math.floor(tonumber(getReflectShieldConfig().UpgradeGrantCharges) or 1))

	session.ReflectShieldCharges = math.clamp(
		(tonumber(session.ReflectShieldCharges) or 0) + grantCharges,
		0,
		getReflectShieldMaxCharges()
	)
end

local function applyChosenUpgrade(session, upgradeId)
	if upgradeId == "Repair" then
		applyRepairUpgrade(session)
		publishSessionAttributes(session)
		return true
	end

	table.insert(session.UpgradeIds, upgradeId)

	if upgradeId == "ReflectShield" then
		grantReflectShieldUpgradeCharge(session)
	end

	applySessionUpgrades(session)

	return true
end

local function resetArenaRun(session)
	if session == nil then
		return
	end

	session.ArenaXP = 0
	session.ArenaLevel = 1
	updateNextLevelXP(session)
	session.Streak = 0
	session.UpgradeIds = {}
	session.ForcedUpgrades = {}
	session.UnclaimedLevelUpOffers = 0
	resetReviveRunState(session)
	session.ReflectShieldCharges = 0
	session.SpawnShieldUntil = 0
	session.ShieldToken = (session.ShieldToken or 0) + 1
	clearPendingUpgradeOffer(session)
	resetParticipantArenaModifiers(session.Participant)
	applySessionUpgrades(session)
end

local function makeSession(player, participant)
	local startedAt = getServerTimeNow()

	return {
		Player = player,
		Participant = participant,
		SessionId = "Arena_" .. tostring(player.UserId) .. "_" .. tostring(math.floor(os.clock() * 1000)),
		RespawnToken = 0,
		ShieldToken = 0,
		StartedAt = startedAt,
		SoftEndsAt = getSessionSoftEndAt(startedAt),
		Score = 0,
		ArenaXP = 0,
		ArenaLevel = 1,
		NextLevelXP = getNextLevelThreshold(1),
		Kills = 0,
		Deaths = 0,
		Streak = 0,
		EarnedBolts = 0,
		LastSummary = "",
		UpgradeIds = {},
		ForcedUpgrades = {},
		UnclaimedLevelUpOffers = 0,
		PendingUpgradeOffer = nil,
		PendingUpgradeOfferId = "",
		PendingUpgradeOfferSource = "",
		ReviveCount = 0,
		RevivePending = false,
		ReviveCost = 0,
		ReviveLastError = "",
		FreeRespawnPending = false,
		FreeRespawnLastError = "",
		DamageMultiplier = 1,
		FireRateMultiplier = 1,
		MoveSpeedMultiplier = 1,
		ProjectileCount = 1,
		SpreadDegrees = 0,
		DoubleShotLateralOffset = 0,
		RicochetBonus = 0,
		ReflectShieldCharges = 0,
		SpawnShieldUntil = 0,
	}
end

local function makeBotSession(participant)
	return {
		Player = nil,
		Participant = participant,
		SessionId = "ArenaBot_" .. tostring(participant ~= nil and participant.TankId or "Unknown"),
		RespawnToken = 0,
		ShieldToken = 0,
		StartedAt = 0,
		SoftEndsAt = 0,
		Score = 0,
		ArenaXP = 0,
		ArenaLevel = 1,
		NextLevelXP = getNextLevelThreshold(1),
		Kills = 0,
		Deaths = 0,
		Streak = 0,
		EarnedBolts = 0,
		LastSummary = "",
		UpgradeIds = {},
		ForcedUpgrades = {},
		UnclaimedLevelUpOffers = 0,
		PendingUpgradeOffer = nil,
		PendingUpgradeOfferId = "",
		PendingUpgradeOfferSource = "",
		ReviveCount = 0,
		RevivePending = false,
		ReviveCost = 0,
		ReviveLastError = "",
		FreeRespawnPending = false,
		FreeRespawnLastError = "",
		DamageMultiplier = 1,
		FireRateMultiplier = 1,
		MoveSpeedMultiplier = 1,
		ProjectileCount = 1,
		SpreadDegrees = 0,
		DoubleShotLateralOffset = 0,
		RicochetBonus = 0,
		ReflectShieldCharges = 0,
		SpawnShieldUntil = 0,
		IsBotSession = true,
	}
end

function ArenaCombatService.init(options)
	options = options or {}
	root = options.root
	tankSpawnResetService = options.tankSpawnResetService
	playerWalletService = options.playerWalletService
	upgradeChoiceEvent = options.upgradeChoiceEvent
	reviveRequestEvent = options.reviveRequestEvent
	freeRespawnRequestEvent = options.freeRespawnRequestEvent
	callbacks.setPlayerMode = options.setPlayerMode
	callbacks.clearPlayerInput = options.clearPlayerInput
	callbacks.restoreTankColors = options.restoreTankColors

	if upgradeChoiceConnection ~= nil then
		upgradeChoiceConnection:Disconnect()
		upgradeChoiceConnection = nil
	end

	if reviveRequestConnection ~= nil then
		reviveRequestConnection:Disconnect()
		reviveRequestConnection = nil
	end

	if freeRespawnRequestConnection ~= nil then
		freeRespawnRequestConnection:Disconnect()
		freeRespawnRequestConnection = nil
	end

	if upgradeChoiceEvent ~= nil then
		upgradeChoiceConnection = upgradeChoiceEvent.OnServerEvent:Connect(function(player, payload)
			ArenaCombatService.HandleUpgradeChoice(player, payload)
		end)
	end

	if reviveRequestEvent ~= nil then
		reviveRequestConnection = reviveRequestEvent.OnServerEvent:Connect(function(player)
			ArenaCombatService.HandleReviveRequest(player)
		end)
	end

	if freeRespawnRequestEvent ~= nil then
		freeRespawnRequestConnection = freeRespawnRequestEvent.OnServerEvent:Connect(function(player)
			ArenaCombatService.HandleFreeRespawnRequest(player)
		end)
	end
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
	grantSpawnReflectShield(session, "EnterArena")
	print("[ARENA] player entered battle arena " .. player.Name .. " -> " .. participant.TankId)

	return true
end

function ArenaCombatService.ResetArenaSession(player)
	local session = sessionsByPlayer[player]

	if session ~= nil then
		local startedAt = getServerTimeNow()
		session.Score = 0
		session.Kills = 0
		session.Deaths = 0
		session.EarnedBolts = 0
		session.StartedAt = startedAt
		session.SoftEndsAt = getSessionSoftEndAt(startedAt)
		session.LastSummary = ""
		session.RespawnToken += 1
		resetArenaRun(session)
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

local function getParticipantModel(participant)
	if participant == nil then
		return nil
	end

	return TankParticipantRegistry.getParticipantPhysicalModel(participant) or participant.Model
end

local function getParticipantPosition(participant)
	local model = getParticipantModel(participant)

	if model == nil then
		return nil
	end

	local body = model:FindFirstChild("Body", true)
		or model:FindFirstChild("Hull", true)
		or model.PrimaryPart

	if body ~= nil and body:IsA("BasePart") then
		return body.Position
	end

	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)

	if ok then
		return pivot.Position
	end

	return nil
end

local function isParticipantAlive(participant)
	return participant ~= nil
		and participant.IsActive == true
		and TankParticipantRegistry.getParticipantIsDead(participant) ~= true
end

local function getPoiBounds(instance)
	if instance == nil then
		return nil, nil
	end

	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	elseif instance:IsA("Model") then
		local ok, cframe, size = pcall(function()
			return instance:GetBoundingBox()
		end)

		if ok then
			return cframe, size
		end
	end

	return nil, nil
end

local function isPositionInsidePoi(instance, position)
	local cframe, size = getPoiBounds(instance)

	if cframe == nil or size == nil or typeof(position) ~= "Vector3" then
		return false
	end

	local localPosition = cframe:PointToObjectSpace(position)
	local verticalHalfSize = math.max(size.Y * 0.5 + 6, 8)

	return math.abs(localPosition.X) <= size.X * 0.5
		and math.abs(localPosition.Z) <= size.Z * 0.5
		and math.abs(localPosition.Y) <= verticalHalfSize
end

local function collectPoiParts(instance)
	local parts = {}

	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	else
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end

	return parts
end

local function getPoiState(instance)
	local state = poiStateByInstance[instance]

	if state ~= nil then
		return state
	end

	state = {
		InactiveUntil = 0,
		LastUserId = nil,
		OriginalParts = {},
	}

	for _, part in ipairs(collectPoiParts(instance)) do
		state.OriginalParts[part] = {
			Transparency = part.Transparency,
			CanQuery = part.CanQuery,
			CanTouch = part.CanTouch,
		}
	end

	poiStateByInstance[instance] = state
	return state
end

local function setPoiActive(instance, isActive)
	local state = getPoiState(instance)

	for part, original in pairs(state.OriginalParts) do
		if part.Parent ~= nil then
			if isActive then
				part.Transparency = original.Transparency
				part.CanQuery = original.CanQuery
				part.CanTouch = original.CanTouch
			else
				part.Transparency = 1
				part.CanQuery = false
				part.CanTouch = false
			end
		end
	end
end

local function getPoiChildren(folderName)
	local folder = getArenaChild(folderName)
	local children = {}

	if folder == nil then
		return children
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("Model") then
			table.insert(children, child)
		end
	end

	return children
end

local function getParticipantInsidePoi(instance, playersOnly)
	for participant, session in pairs(sessionsByParticipant) do
		if isParticipantAlive(participant)
			and (playersOnly ~= true or session.Player ~= nil)
			and isPositionInsidePoi(instance, getParticipantPosition(participant))
		then
			return participant, session
		end
	end

	return nil, nil
end

local function reactivatePoiIfReady(instance, state, now)
	if (state.InactiveUntil or 0) <= 0 or now < state.InactiveUntil then
		return false
	end

	state.InactiveUntil = 0
	state.LastUserId = nil
	setPoiActive(instance, true)

	return true
end

local function processMedkits(now)
	for _, medkit in ipairs(getPoiChildren(BattleArenaConfig.MedkitFolderName or "Medkits")) do
		local state = getPoiState(medkit)
		reactivatePoiIfReady(medkit, state, now)

		if (state.InactiveUntil or 0) > 0 then
			continue
		end

		local participant = getParticipantInsidePoi(medkit, false)

		if participant == nil then
			continue
		end

		local currentHealth = TankParticipantRegistry.getParticipantHealth(participant)
		local maxHealth = TankParticipantRegistry.getParticipantMaxHealth(participant)

		if currentHealth >= maxHealth then
			continue
		end

		local healAmount = math.max(0, tonumber(BattleArenaConfig.MedkitHealAmount) or 40)
		TankParticipantRegistry.setParticipantHealth(participant, math.min(maxHealth, currentHealth + healAmount))
		state.InactiveUntil = now + math.max(0, tonumber(BattleArenaConfig.MedkitRespawnTime) or 30)
		setPoiActive(medkit, false)
	end
end

local function processSupplyCrates(now)
	for _, crate in ipairs(getPoiChildren(BattleArenaConfig.SupplyCrateFolderName or "SupplyCrates")) do
		local state = getPoiState(crate)
		reactivatePoiIfReady(crate, state, now)

		if (state.InactiveUntil or 0) > 0 then
			continue
		end

		local _, session = getParticipantInsidePoi(crate, true)
		local player = session ~= nil and session.Player or nil

		if player == nil
			or session.PendingUpgradeOffer ~= nil
			or state.LastUserId == player.UserId
		then
			continue
		end

		if createUpgradeOffer(session, "SupplyCrate") then
			addArenaXP(session, BattleArenaConfig.XPPerSupplyCrateUse, "SupplyCrate")
			state.LastUserId = player.UserId
			state.InactiveUntil = now + math.max(0, tonumber(BattleArenaConfig.CrateRespawnTime) or 60)
			setPoiActive(crate, false)
		end
	end
end

local function processControlZone()
	local controlZone = getArenaChild(BattleArenaConfig.ControlZoneName or "ControlZone")

	if controlZone == nil or not (controlZone:IsA("BasePart") or controlZone:IsA("Model")) then
		return
	end

	for participant, session in pairs(sessionsByParticipant) do
		if session.Player ~= nil
			and isParticipantAlive(participant)
			and isPositionInsidePoi(controlZone, getParticipantPosition(participant))
		then
			addArenaXP(session, BattleArenaConfig.XPPerControlZoneTick, "ControlZone")
		end
	end
end

local function processSurvivalXP()
	local xpPerTick = math.max(0, tonumber(BattleArenaConfig.XPPerSurvivalTick) or 0)

	if xpPerTick <= 0 then
		return
	end

	for participant, session in pairs(sessionsByParticipant) do
		if session.Player ~= nil and isParticipantAlive(participant) then
			addArenaXP(session, xpPerTick, "Survival")
		end
	end
end

function ArenaCombatService.ApplyUpgrade(player, upgradeId)
	local session = sessionsByPlayer[player]

	if session == nil or typeof(upgradeId) ~= "string" then
		return false
	end

	if isUpgradeChoiceValid(session, upgradeId) then
		return applyChosenUpgrade(session, upgradeId)
	end

	return false
end

function ArenaCombatService.HandleUpgradeChoice(player, payload)
	local session = sessionsByPlayer[player]

	if session == nil or session.PendingUpgradeOffer == nil or typeof(payload) ~= "table" then
		return false
	end

	local offerId = payload.OfferId
	local upgradeId = payload.UpgradeId

	if typeof(offerId) ~= "string"
		or typeof(upgradeId) ~= "string"
		or offerId ~= session.PendingUpgradeOfferId
	then
		return false
	end

	local selectedWasOffered = false

	for _, choice in ipairs(session.PendingUpgradeOffer.Choices or {}) do
		if choice.Id == upgradeId then
			selectedWasOffered = true
			break
		end
	end

	if not selectedWasOffered or not isUpgradeChoiceValid(session, upgradeId) then
		return false
	end

	local source = session.PendingUpgradeOfferSource
	clearPendingUpgradeOffer(session)

	if source == "LevelUp" then
		session.UnclaimedLevelUpOffers = math.max(0, (session.UnclaimedLevelUpOffers or 0) - 1)
	end

	applyChosenUpgrade(session, upgradeId)
	ensurePendingLevelOffer(session)

	return true
end

function ArenaCombatService.RespawnPlayer(player, options)
	options = options or {}
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

	local restoreHpPercent = tonumber(options.RestoreHpPercent)

	if restoreHpPercent ~= nil then
		local maxHealth = TankParticipantRegistry.getParticipantMaxHealth(participant)
		local restoredHealth = math.max(1, math.floor(maxHealth * math.clamp(restoreHpPercent, 0.05, 1) + 0.5))
		TankParticipantRegistry.setParticipantHealth(participant, restoredHealth)
	end

	if callbacks.restoreTankColors ~= nil then
		callbacks.restoreTankColors(participant)
	end

	tankSpawnResetService.applySpawnToParticipant(participant, getArenaSpawnTransform(player))
	setPlayerMode(player, participant, ArenaCombatService.MODE_IN_BATTLE_ARENA)
	player:SetAttribute("ArenaRespawnAt", 0)
	player:SetAttribute("ArenaStatus", "Active")
	clearRevivePending(session)
	clearFreeRespawnPending(session)
	clearPlayerInput(player)
	applySessionUpgrades(session)
	grantSpawnReflectShield(session, "Respawn")
	publishSessionAttributes(session)
	print("[ARENA] respawned " .. player.Name)

	return true
end

function ArenaCombatService.HandleReviveRequest(player)
	local session = sessionsByPlayer[player]

	if session == nil
		or player == nil
		or player.Parent ~= Players
		or session.Player ~= player
		or session.IsBotSession == true
	then
		return false
	end

	if session.RevivePending ~= true then
		session.ReviveLastError = "NotPending"
		publishSessionAttributes(session)
		return false
	end

	if session.Participant == nil or player:GetAttribute("PlayerMode") ~= ArenaCombatService.MODE_ARENA_RESPAWNING then
		session.ReviveLastError = "InvalidState"
		publishSessionAttributes(session)
		return false
	end

	if not canOfferRevive(session) then
		session.ReviveLastError = "LimitReached"
		publishSessionAttributes(session)
		return false
	end

	if playerWalletService == nil or playerWalletService.trySpendBolts == nil then
		session.ReviveLastError = "WalletUnavailable"
		publishSessionAttributes(session)
		return false
	end

	local cost = getReviveCost(session)
	local spent = playerWalletService.trySpendBolts(player, cost, "BattleArenaRevive")

	if not spent then
		session.ReviveLastError = "NotEnoughBolts"
		session.ReviveCost = cost
		publishSessionAttributes(session)
		return false
	end

	session.ReviveCount = math.max(0, math.floor(tonumber(session.ReviveCount) or 0)) + 1
	session.ReviveCost = 0
	session.ReviveLastError = ""

	return ArenaCombatService.RespawnPlayer(player, {
		RestoreHpPercent = getReviveRestoreHpPercent(),
	})
end

function ArenaCombatService.HandleFreeRespawnRequest(player)
	local session = sessionsByPlayer[player]

	if session == nil
		or player == nil
		or player.Parent ~= Players
		or session.Player ~= player
		or session.IsBotSession == true
	then
		return false
	end

	if session.FreeRespawnPending ~= true
		or session.Participant == nil
		or player:GetAttribute("PlayerMode") ~= ArenaCombatService.MODE_ARENA_RESPAWNING
	then
		session.FreeRespawnLastError = "InvalidState"
		publishSessionAttributes(session)
		return false
	end

	if not canOfferFreeRespawn(session) then
		session.FreeRespawnLastError = "Unavailable"
		publishSessionAttributes(session)
		return false
	end

	if shouldFreeRespawnResetRun() then
		resetArenaRun(session)
	else
		clearRevivePending(session)
		clearFreeRespawnPending(session)
	end

	return ArenaCombatService.RespawnPlayer(player, {
		RestoreHpPercent = getFreeRespawnRestoreHpPercent(),
	})
end

local function updateArenaSummary(session)
	if session == nil or session.IsBotSession == true then
		return
	end

	session.LastSummary = ("Run: %d kills / %d deaths / +%d Bolts"):format(
		math.floor(session.Kills or 0),
		math.floor(session.Deaths or 0),
		math.floor(session.EarnedBolts or 0)
	)
end

local function getPlayerKillScore(killerSession, victimSession, sourceProjectile)
	local defaultKillScore = math.max(0, math.floor(tonumber(BattleArenaConfig.KillScore) or 0))

	if killerSession == nil or killerSession.IsBotSession == true then
		return 0
	end

	if victimSession == nil or victimSession.IsBotSession ~= true or not isLoopV02Enabled() then
		return defaultKillScore
	end

	local score = math.max(0, math.floor(getLoopNumber("Score", "PlayerKillBot", defaultKillScore)))

	if hasProjectileRicochet(sourceProjectile) then
		score += math.max(0, math.floor(getLoopNumber("Score", "RicochetKillBonus", 0)))
	end

	return score
end

local function awardArenaKillCurrency(killerSession, victimSession, sourceProjectile)
	if killerSession == nil
		or killerSession.IsBotSession == true
		or killerSession.Player == nil
		or victimSession == nil
		or victimSession.IsBotSession ~= true
		or playerWalletService == nil
		or playerWalletService.addBolts == nil
		or not isLoopV02Enabled()
	then
		return
	end

	local rewardAmount = math.max(0, math.floor(getLoopNumber("Rewards", "BoltsPerBotKill", 0)))
	local reason = "BattleArenaBotKill"

	if hasProjectileRicochet(sourceProjectile) then
		rewardAmount += math.max(0, math.floor(getLoopNumber("Rewards", "BoltsPerRicochetKillBonus", 0)))
		reason = "BattleArenaRicochetKill"
	end

	if rewardAmount <= 0 then
		return
	end

	local awarded = playerWalletService.addBolts(killerSession.Player, rewardAmount, reason)

	if awarded then
		killerSession.EarnedBolts += rewardAmount
	end
end

function ArenaCombatService.OnParticipantKilled(killerParticipant, victimParticipant, sourceProjectile)
	local victimSession = sessionsByParticipant[victimParticipant]

	if victimSession == nil then
		return
	end

	local victimPlayer = victimSession.Player
	victimSession.Deaths += 1
	local revivePending = beginRevivePending(victimSession)
	local freeRespawnPending = beginFreeRespawnPending(victimSession)

	if not revivePending and not freeRespawnPending then
		resetArenaRun(victimSession)
	end

	local killerSession = nil

	if killerParticipant ~= nil and killerParticipant ~= victimParticipant then
		killerSession = sessionsByParticipant[killerParticipant]
	end

	if killerSession ~= nil and killerSession.IsBotSession ~= true then
		killerSession.Score += getPlayerKillScore(killerSession, victimSession, sourceProjectile)
		awardArenaKillCurrency(killerSession, victimSession, sourceProjectile)
		addArenaXP(killerSession, BattleArenaConfig.XPPerKill, "Kill")
		killerSession.Kills += 1
		killerSession.Streak += 1
		updateArenaSummary(killerSession)
		applySessionUpgrades(killerSession)
	end

	updateArenaSummary(victimSession)
	publishSessionAttributes(victimSession)

	if victimPlayer == nil or victimPlayer.Parent ~= Players then
		return
	end

	victimSession.RespawnToken += 1
	local token = victimSession.RespawnToken
	local deathChoicePending = revivePending or freeRespawnPending
	local respawnDelay = deathChoicePending and 0 or math.max(0, tonumber(BattleArenaConfig.RespawnDelay) or 0)
	local respawnAt = deathChoicePending and 0 or getServerTimeNow() + respawnDelay

	setPlayerMode(victimPlayer, victimParticipant, ArenaCombatService.MODE_ARENA_RESPAWNING)
	victimPlayer:SetAttribute("ArenaStatus", "Destroyed")
	victimPlayer:SetAttribute("ArenaRespawnDelay", respawnDelay)
	victimPlayer:SetAttribute("ArenaRespawnAt", respawnAt)
	clearPlayerInput(victimPlayer)

	if deathChoicePending then
		publishSessionAttributes(victimSession)
		return
	end

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

function ArenaCombatService.TryConsumeReflectShield(projectile, targetParticipant)
	if projectile == nil or targetParticipant == nil or projectile.NoDamage == true then
		return false, nil
	end

	local ownerSession = sessionsByParticipant[projectile.OwnerParticipant]
	local targetSession = sessionsByParticipant[targetParticipant]

	if ownerSession == nil or targetSession == nil then
		return false, nil
	end

	local reflectConfig = getReflectShieldConfig()
	local maxReflectsPerProjectile = math.max(
		0,
		math.floor(tonumber(reflectConfig.MaxReflectsPerProjectile) or 1)
	)

	if (tonumber(projectile.ShieldReflectCount) or 0) >= maxReflectsPerProjectile then
		return false, nil
	end

	local now = getServerTimeNow()

	if (tonumber(targetSession.SpawnShieldUntil) or 0) > 0
		and (tonumber(targetSession.SpawnShieldUntil) or 0) <= now
	then
		targetSession.SpawnShieldUntil = 0
	end

	local spawnShieldActive = isSpawnShieldActive(targetSession, now)
	local shieldCharges = math.clamp(
		math.floor(tonumber(targetSession.ReflectShieldCharges) or 0),
		0,
		getReflectShieldMaxCharges()
	)

	if not spawnShieldActive and not hasReflectShieldCharge(targetSession) then
		publishShieldAttributes(targetSession, now)
		return false, nil
	end

	if spawnShieldActive then
		targetSession.SpawnShieldUntil = 0
	else
		targetSession.ReflectShieldCharges = math.max(0, shieldCharges - 1)
	end

	publishShieldAttributes(targetSession, now)

	return true, {
		Text = tostring(reflectConfig.ReflectText or "REFLECT"),
		Color = Color3.fromRGB(116, 210, 255),
		Lifetime = 0.6,
		RiseDistance = 2.2,
	}
end

function ArenaCombatService.IsArenaProjectile(projectile)
	return projectile ~= nil and sessionsByParticipant[projectile.OwnerParticipant] ~= nil
end

function ArenaCombatService.GetControlZonePosition()
	local controlZone = getArenaChild(BattleArenaConfig.ControlZoneName or "ControlZone")

	if controlZone == nil or not (controlZone:IsA("BasePart") or controlZone:IsA("Model")) then
		return nil
	end

	local cframe = getPoiBounds(controlZone)

	return cframe ~= nil and cframe.Position or nil
end

function ArenaCombatService.update(deltaTime)
	local dt = math.max(0, tonumber(deltaTime) or 0)
	local now = getServerTimeNow()

	pickupAccumulator += dt
	if pickupAccumulator >= math.max(0.05, tonumber(BattleArenaConfig.PickupCheckInterval) or 0.25) then
		pickupAccumulator = 0
		processMedkits(now)
		processSupplyCrates(now)
	end

	controlZoneAccumulator += dt
	if controlZoneAccumulator >= math.max(1, tonumber(BattleArenaConfig.ControlZoneTickInterval) or 5) then
		controlZoneAccumulator = 0
		processControlZone()
	end

	survivalAccumulator += dt
	if survivalAccumulator >= math.max(1, tonumber(BattleArenaConfig.SurvivalTickInterval) or 10) then
		survivalAccumulator = 0
		processSurvivalXP()
	end
end

function ArenaCombatService.PlayerRemoving(player)
	ArenaCombatService.LeaveArena(player)
end

return ArenaCombatService
