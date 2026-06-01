local ArenaCombatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local BattleArenaConfig = require(configs:WaitForChild("BattleArenaConfig"))
local BattleArenaLoopConfig = require(configs:WaitForChild("BattleArenaLoopConfig"))
local GameplayCombatFXService = require(shared:WaitForChild("FX"):WaitForChild("CombatFXService"))

local ArenaLevelService = require(script.Parent:WaitForChild("ArenaLevelService"))
local ArenaReviveService = require(script.Parent:WaitForChild("ArenaReviveService"))
local ArenaRewardService = require(script.Parent:WaitForChild("ArenaRewardService"))
local ArenaSessionRepository = require(script.Parent:WaitForChild("ArenaSessionRepository"))
local ArenaUpgradeEffectApplier = require(script.Parent:WaitForChild("ArenaUpgradeEffectApplier"))
local ArenaUpgradeOfferService = require(script.Parent:WaitForChild("ArenaUpgradeOfferService"))
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

local sessionRepository = ArenaSessionRepository.new()
local levelService = ArenaLevelService.new(BattleArenaConfig)
local reviveService = ArenaReviveService.new(BattleArenaConfig)
local rewardService = ArenaRewardService.new(BattleArenaConfig, BattleArenaLoopConfig)
local upgradeOfferService = ArenaUpgradeOfferService.new(BattleArenaConfig, levelService)
local upgradeEffectApplier = ArenaUpgradeEffectApplier.new(
	BattleArenaConfig,
	upgradeOfferService,
	TankParticipantRegistry
)
local nextSpawnIndex = 1
local poiStateByInstance = {}
local pickupAccumulator = 0
local controlZoneAccumulator = 0
local survivalAccumulator = 0
local getParticipantPosition = nil
local playArenaGameplayFX = nil
local shieldVisualBySession = setmetatable({}, { __mode = "k" })

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

local function getShieldAnchorPart(participant)
	if participant == nil then
		return nil
	end

	local model = TankParticipantRegistry.getParticipantPhysicalModel(participant) or participant.Model

	if model == nil then
		return nil
	end

	local body = model:FindFirstChild("Body", true)
		or model:FindFirstChild("Hull", true)
		or model.PrimaryPart

	if body ~= nil and body:IsA("BasePart") then
		return body
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function destroyShieldVisual(session)
	local visual = shieldVisualBySession[session]
	shieldVisualBySession[session] = nil

	if visual ~= nil and visual.Parent ~= nil then
		visual:Destroy()
	end
end

local function createFallbackShieldVisual(anchorPart)
	local maxAxis = math.max(anchorPart.Size.X, anchorPart.Size.Y, anchorPart.Size.Z)
	local diameter = math.max(4.5, maxAxis * 1.75)
	local shield = Instance.new("Part")
	shield.Name = "ArenaReflectShieldVisual"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(diameter, diameter, diameter)
	shield.CFrame = anchorPart.CFrame
	shield.Anchored = false
	shield.CanCollide = false
	shield.CanTouch = false
	shield.CanQuery = false
	shield.Massless = true
	shield.CastShadow = false
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(92, 225, 255)
	shield.Transparency = 0.42
	shield.Parent = anchorPart

	local weld = Instance.new("WeldConstraint")
	weld.Name = "ArenaReflectShieldVisualWeld"
	weld.Part0 = anchorPart
	weld.Part1 = shield
	weld.Parent = shield

	local highlight = Instance.new("Highlight")
	highlight.Name = "ArenaReflectShieldVisualHighlight"
	highlight.Adornee = shield
	highlight.FillColor = Color3.fromRGB(92, 225, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 245, 160)
	highlight.FillTransparency = 0.82
	highlight.OutlineTransparency = 0.08
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = shield

	return shield
end

local function updateShieldVisual(session, shieldActive)
	if shieldActive ~= true then
		destroyShieldVisual(session)
		return
	end

	local participant = session ~= nil and session.Participant or nil

	if participant == nil
		or participant.IsActive ~= true
		or TankParticipantRegistry.getParticipantIsDead(participant) == true
	then
		destroyShieldVisual(session)
		return
	end

	local anchorPart = getShieldAnchorPart(participant)

	if anchorPart == nil then
		destroyShieldVisual(session)
		return
	end

	local existingVisual = shieldVisualBySession[session]
	if existingVisual ~= nil
		and existingVisual.Parent ~= nil
		and existingVisual.Name == "ArenaReflectShieldVisual"
		and existingVisual:IsDescendantOf(anchorPart)
	then
		return
	end

	destroyShieldVisual(session)
	shieldVisualBySession[session] = createFallbackShieldVisual(anchorPart)
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

	updateShieldVisual(session, shieldActive)
end

local function republishShieldAttributesSoon(session)
	task.defer(function()
		local currentSession = sessionRepository:GetCurrentForSession(session)

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

		local currentSession = sessionRepository:GetCurrentForSession(session)

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
	upgradeEffectApplier:ResetParticipantArenaModifiers(participant)
end

local function setPlayerArenaDefaults(player)
	if player == nil then
		return
	end

	player:SetAttribute("ArenaScore", 0)
	player:SetAttribute("ArenaXP", 0)
	player:SetAttribute("ArenaLevel", 1)
	player:SetAttribute("ArenaNextLevelXP", levelService:GetNextLevelThreshold(1))
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
	player:SetAttribute("ArenaMaxRevives", reviveService:GetMaxRevivesPerRun())
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
	player:SetAttribute("ArenaReviveCost", session.RevivePending == true and reviveService:GetReviveCost(session) or 0)
	player:SetAttribute("ArenaRevivesUsed", math.max(0, math.floor(tonumber(session.ReviveCount) or 0)))
	player:SetAttribute("ArenaMaxRevives", reviveService:GetMaxRevivesPerRun())
	player:SetAttribute("ArenaCanRevive", session.RevivePending == true and reviveService:CanAffordRevive(session))
	player:SetAttribute("ArenaReviveLastError", tostring(session.ReviveLastError or ""))
	player:SetAttribute("ArenaFreeRespawnAvailable", session.FreeRespawnPending == true)
	player:SetAttribute("ArenaDamageMultiplier", session.DamageMultiplier)
	player:SetAttribute("ArenaFireRateMultiplier", session.FireRateMultiplier)
	player:SetAttribute("ArenaMoveSpeedMultiplier", session.MoveSpeedMultiplier)
	player:SetAttribute("ArenaProjectileCount", session.ProjectileCount)
	player:SetAttribute("ArenaRicochetBonus", session.RicochetBonus)
	publishShieldAttributes(session)
end

local function isUpgradeChoiceValid(session, upgradeId)
	return upgradeOfferService:IsUpgradeChoiceValid(session, upgradeId)
end

local function applySessionUpgrades(session)
	if upgradeEffectApplier:ApplySessionUpgrades(session) then
		publishSessionAttributes(session)
	end
end

local function clearPendingUpgradeOffer(session)
	upgradeOfferService:ClearPendingUpgradeOffer(session)
	publishSessionAttributes(session)
end

local function fireUpgradeOffer(session)
	if upgradeChoiceEvent == nil or session.Player == nil or session.PendingUpgradeOffer == nil then
		return
	end

	upgradeChoiceEvent:FireClient(session.Player, session.PendingUpgradeOffer)
end

local function createUpgradeOffer(session, source)
	local created = upgradeOfferService:CreateUpgradeOffer(session, source)

	if not created then
		return false
	end

	publishSessionAttributes(session)
	fireUpgradeOffer(session)

	if source == "LevelUp" and playArenaGameplayFX ~= nil then
		playArenaGameplayFX(session, "LevelUp")
	end

	return true
end

local function ensurePendingLevelOffer(session)
	local result = upgradeOfferService:EnsurePendingLevelOffer(session)

	if result.StateChanged == true then
		publishSessionAttributes(session)
	end

	if result.Created == true then
		fireUpgradeOffer(session)

		if playArenaGameplayFX ~= nil then
			playArenaGameplayFX(session, "LevelUp")
		end
	end
end

local function addArenaXP(session, amount, reason)
	local levelBefore = session ~= nil and (tonumber(session.ArenaLevel) or 1) or 1
	local result = levelService:AddXP(session, amount)

	if result.Added ~= true then
		return false
	end

	publishSessionAttributes(session)
	ensurePendingLevelOffer(session)

	-- Etap 4: notify achievements when the arena level actually increased (human players).
	local levelAfter = tonumber(session.ArenaLevel) or levelBefore
	if levelAfter > levelBefore
		and callbacks.onArenaLevel ~= nil
		and session.IsBotSession ~= true
		and session.Player ~= nil
	then
		callbacks.onArenaLevel(session.Player, levelAfter)
	end

	if BattleArenaConfig.Debug == true then
		local playerName = session.Player ~= nil and session.Player.Name or "Unknown"
		print(
			("[ARENA XP] player=%s amount=%d reason=%s xp=%d level=%d"):format(
				playerName,
				result.Amount,
				tostring(reason or "Unknown"),
				session.ArenaXP,
				session.ArenaLevel
			)
		)
	end

	return true
end

local function applyChosenUpgrade(session, upgradeId)
	local beforeHealth = nil

	if upgradeId == "Repair" and session ~= nil and session.Participant ~= nil then
		beforeHealth = TankParticipantRegistry.getParticipantHealth(session.Participant)
	end

	if upgradeEffectApplier:ApplyChosenUpgrade(session, upgradeId) then
		publishSessionAttributes(session)

		if playArenaGameplayFX ~= nil then
			playArenaGameplayFX(session, "UpgradeSelect")

			if upgradeId == "Repair" and beforeHealth ~= nil then
				local afterHealth = TankParticipantRegistry.getParticipantHealth(session.Participant)

				if afterHealth > beforeHealth then
					playArenaGameplayFX(session, "Repair")
				end
			end
		end

		return true
	end

	return false
end

local function resetArenaRun(session)
	if session == nil then
		return
	end

	levelService:ResetRunProgress(session)
	session.Streak = 0
	session.UpgradeIds = {}
	session.ForcedUpgrades = {}
	reviveService:ResetRunState(session)
	session.ReflectShieldCharges = 0
	session.SpawnShieldUntil = 0
	session.ShieldToken = (session.ShieldToken or 0) + 1
	destroyShieldVisual(session)
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
		NextLevelXP = levelService:GetNextLevelThreshold(1),
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
		PierceEnemies = 0,
		LifestealPerKill = 0,
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
		NextLevelXP = levelService:GetNextLevelThreshold(1),
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
		PierceEnemies = 0,
		LifestealPerKill = 0,
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
	reviveService:SetWalletService(playerWalletService)
	rewardService:SetWalletService(playerWalletService)
	upgradeChoiceEvent = options.upgradeChoiceEvent
	reviveRequestEvent = options.reviveRequestEvent
	freeRespawnRequestEvent = options.freeRespawnRequestEvent
	callbacks.setPlayerMode = options.setPlayerMode
	callbacks.clearPlayerInput = options.clearPlayerInput
	callbacks.restoreTankColors = options.restoreTankColors
	-- Update 0.2: arena session lifecycle. Fires once per new session entry / exit.
	-- Optional; nil-safe at every call site.
	callbacks.arenaSessionStarted = options.arenaSessionStarted
	callbacks.arenaSessionEnded = options.arenaSessionEnded
	-- Etap 2: optional kill-feed broadcaster (killerParticipant, victimParticipant, weaponId).
	callbacks.broadcastKill = options.broadcastKill
	-- Etap 4: optional achievement hooks. onArenaKill(context), onArenaLevel(player, level).
	callbacks.onArenaKill = options.onArenaKill
	callbacks.onArenaLevel = options.onArenaLevel

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
	return sessionRepository:Has(player)
end

function ArenaCombatService.IsParticipantInArena(participant)
	return sessionRepository:HasParticipant(participant)
end

function ArenaCombatService.GetSession(player)
	return sessionRepository:Get(player)
end

function ArenaCombatService.GetActivePlayerCount()
	local count = 0

	sessionRepository:ForEach(function(player, _session)
		if player ~= nil and player.Parent == Players then
			count += 1
		end
	end)

	return count
end

function ArenaCombatService.GetActiveParticipants()
	local participants = {}

	sessionRepository:ForEachParticipant(function(participant, _session)
		if participant ~= nil then
			table.insert(participants, participant)
		end
	end)

	return participants
end

-- Etap 5: Shield pickup. Grants +N ReflectShield charges to the participant's arena session
-- (clamped to MaxCharges). Returns true if at least one charge was actually added (so the
-- pickup is only consumed when it does something). Used by ArenaPickupService.
function ArenaCombatService.GrantReflectShieldCharges(participant, amount)
	if participant == nil then
		return false
	end

	local session = sessionRepository:GetByParticipant(participant)
	if session == nil then
		return false
	end

	local maxCharges = getReflectShieldMaxCharges()
	local current = math.floor(tonumber(session.ReflectShieldCharges) or 0)

	if current >= maxCharges then
		return false -- already full; don't waste the pickup
	end

	local add = math.max(1, math.floor(tonumber(amount) or 1))
	session.ReflectShieldCharges = math.clamp(current + add, 0, maxCharges)
	publishShieldAttributes(session)
	return true
end

function ArenaCombatService.RegisterBotParticipant(participant)
	if participant == nil then
		return nil
	end

	local existingSession = sessionRepository:GetByParticipant(participant)

	if existingSession ~= nil then
		return existingSession
	end

	local session = makeBotSession(participant)
	sessionRepository:SetByParticipant(participant, session)
	resetParticipantArenaModifiers(participant)
	TankParticipantRegistry.setParticipantMatchState(participant, ArenaCombatService.MODE_IN_BATTLE_ARENA, nil, nil)

	return session
end

function ArenaCombatService.UnregisterBotParticipant(participant)
	local session = sessionRepository:GetByParticipant(participant)

	if session == nil or session.IsBotSession ~= true then
		return nil
	end

	sessionRepository:RemoveByParticipant(participant)
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

	local existingSession = sessionRepository:Get(player)

	if existingSession ~= nil then
		ArenaCombatService.RespawnPlayer(player)
		return true
	end

	local session = makeSession(player, participant)
	sessionRepository:Set(player, session)

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

	-- Update 0.2: signal arena runtime so the maze/pickups/breakables spawn now.
	if callbacks.arenaSessionStarted ~= nil then
		callbacks.arenaSessionStarted(player)
	end

	return true
end

function ArenaCombatService.ResetArenaSession(player)
	local session = sessionRepository:Get(player)

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
	local session = sessionRepository:Get(player)

	if session == nil then
		setPlayerArenaDefaults(player)
		return nil
	end

	session.RespawnToken += 1
	sessionRepository:Remove(player)
	resetParticipantArenaModifiers(session.Participant)
	setPlayerArenaDefaults(player)
	player:SetAttribute("ArenaSessionId", nil)
	clearPlayerInput(player)
	print("[ARENA] left " .. player.Name)

	-- Update 0.2: signal arena runtime so it cleans up if no players remain.
	if callbacks.arenaSessionEnded ~= nil then
		callbacks.arenaSessionEnded(player)
	end

	return session.Participant
end

function ArenaCombatService.GetArenaScore(player)
	local session = sessionRepository:Get(player)

	return session ~= nil and session.Score or 0
end

local function getParticipantModel(participant)
	if participant == nil then
		return nil
	end

	return TankParticipantRegistry.getParticipantPhysicalModel(participant) or participant.Model
end

getParticipantPosition = function(participant)
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

playArenaGameplayFX = function(session, effectKey, options)
	if session == nil or session.Participant == nil then
		return
	end

	local position = getParticipantPosition(session.Participant)

	if typeof(position) ~= "Vector3" then
		return
	end

	GameplayCombatFXService.PlayAt(effectKey, position, options)
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
	local insideParticipant = nil
	local insideSession = nil

	sessionRepository:ForEachParticipant(function(participant, session)
		if insideParticipant ~= nil then
			return
		end

		if isParticipantAlive(participant)
			and (playersOnly ~= true or session.Player ~= nil)
			and isPositionInsidePoi(instance, getParticipantPosition(participant))
		then
			insideParticipant = participant
			insideSession = session
		end
	end)

	return insideParticipant, insideSession
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

	sessionRepository:ForEachParticipant(function(participant, session)
		if session.Player ~= nil
			and isParticipantAlive(participant)
			and isPositionInsidePoi(controlZone, getParticipantPosition(participant))
		then
			addArenaXP(session, BattleArenaConfig.XPPerControlZoneTick, "ControlZone")
		end
	end)
end

local function processSurvivalXP()
	local xpPerTick = math.max(0, tonumber(BattleArenaConfig.XPPerSurvivalTick) or 0)

	if xpPerTick <= 0 then
		return
	end

	sessionRepository:ForEachParticipant(function(participant, session)
		if session.Player ~= nil and isParticipantAlive(participant) then
			addArenaXP(session, xpPerTick, "Survival")
		end
	end)
end

function ArenaCombatService.ApplyUpgrade(player, upgradeId)
	local session = sessionRepository:Get(player)

	if session == nil or typeof(upgradeId) ~= "string" then
		return false
	end

	if isUpgradeChoiceValid(session, upgradeId) then
		return applyChosenUpgrade(session, upgradeId)
	end

	return false
end

function ArenaCombatService.HandleUpgradeChoice(player, payload)
	local session = sessionRepository:Get(player)

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

	if not upgradeOfferService:HasOfferedChoice(session, upgradeId)
		or not isUpgradeChoiceValid(session, upgradeId)
	then
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
	local session = sessionRepository:Get(player)

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
	reviveService:ClearRevivePending(session)
	reviveService:ClearFreeRespawnPending(session)
	clearPlayerInput(player)
	applySessionUpgrades(session)
	grantSpawnReflectShield(session, "Respawn")
	publishSessionAttributes(session)
	print("[ARENA] respawned " .. player.Name)

	return true
end

function ArenaCombatService.HandleReviveRequest(player)
	local session = sessionRepository:Get(player)
	local result = reviveService:TryConsumeRevive(session, player, ArenaCombatService.MODE_ARENA_RESPAWNING)

	if result.Success ~= true then
		if result.Publish == true and session ~= nil then
			publishSessionAttributes(session)
		end

		return false
	end

	return ArenaCombatService.RespawnPlayer(player, {
		RestoreHpPercent = result.RestoreHpPercent,
	})
end

function ArenaCombatService.HandleFreeRespawnRequest(player)
	local session = sessionRepository:Get(player)
	local result = reviveService:TryConsumeFreeRespawn(session, player, ArenaCombatService.MODE_ARENA_RESPAWNING)

	if result.Success ~= true then
		if result.Publish == true and session ~= nil then
			publishSessionAttributes(session)
		end

		return false
	end

	if result.ResetRun == true then
		resetArenaRun(session)
	else
		reviveService:ClearRevivePending(session)
		reviveService:ClearFreeRespawnPending(session)
	end

	return ArenaCombatService.RespawnPlayer(player, {
		RestoreHpPercent = result.RestoreHpPercent,
	})
end

function ArenaCombatService.OnParticipantKilled(killerParticipant, victimParticipant, sourceProjectile)
	local victimSession = sessionRepository:GetByParticipant(victimParticipant)

	if victimSession == nil then
		return
	end

	local victimPlayer = victimSession.Player
	victimSession.Deaths += 1
	destroyShieldVisual(victimSession)
	local revivePending = reviveService:BeginRevivePending(victimSession)
	local freeRespawnPending = reviveService:BeginFreeRespawnPending(victimSession)

	if not revivePending and not freeRespawnPending then
		resetArenaRun(victimSession)
	end

	local killerSession = nil

	if killerParticipant ~= nil and killerParticipant ~= victimParticipant then
		killerSession = sessionRepository:GetByParticipant(killerParticipant)
	end

	if killerSession ~= nil and killerSession.IsBotSession ~= true then
		rewardService:ApplyKillRewards(killerSession, victimSession, sourceProjectile)
		addArenaXP(killerSession, BattleArenaConfig.XPPerKill, "Kill")
		killerSession.Kills += 1
		killerSession.Streak += 1

		-- Etap 1 Lifesteal upgrade: heal the killer per kill (0 if not taken).
		local lifesteal = math.max(0, tonumber(killerSession.LifestealPerKill) or 0)
		if lifesteal > 0 and killerParticipant ~= nil then
			local hp = TankParticipantRegistry.getParticipantHealth(killerParticipant)
			local maxHp = TankParticipantRegistry.getParticipantMaxHealth(killerParticipant)
			if hp ~= nil and maxHp ~= nil then
				TankParticipantRegistry.setParticipantHealth(killerParticipant, math.min(maxHp, hp + lifesteal))
			end
		end

		rewardService:UpdateRunSummary(killerSession)
		applySessionUpgrades(killerSession)
	end

	-- Etap 2/4: kill-feed broadcast + achievement hook (display/economy only).
	local killWeaponId = nil
	local killRicochet = false
	if sourceProjectile ~= nil then
		killWeaponId = sourceProjectile.WeaponOverrideId or "DefaultCannon"
		killRicochet = (tonumber(sourceProjectile.BounceCount) or 0) > 0
	end

	if callbacks.broadcastKill ~= nil then
		callbacks.broadcastKill(killerParticipant, victimParticipant, killWeaponId)
	end

	-- Etap 4: feed achievements for human killers only.
	if callbacks.onArenaKill ~= nil
		and killerSession ~= nil
		and killerSession.IsBotSession ~= true
		and killerSession.Player ~= nil
	then
		callbacks.onArenaKill({
			Killer = killerSession.Player,
			KillsInSession = tonumber(killerSession.Kills) or 0,
			ArenaLevel = tonumber(killerSession.ArenaLevel) or 1,
			RicochetKill = killRicochet,
			WeaponId = killWeaponId,
		})
	end

	rewardService:UpdateRunSummary(victimSession)
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
		local currentSession = sessionRepository:Get(victimPlayer)

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

	local ownerSession = sessionRepository:GetByParticipant(projectile.OwnerParticipant)
	local targetSession = sessionRepository:GetByParticipant(targetParticipant)

	return ownerSession ~= nil and targetSession ~= nil
end

function ArenaCombatService.TryConsumeReflectShield(projectile, targetParticipant)
	if projectile == nil or targetParticipant == nil or projectile.NoDamage == true then
		return false, nil
	end

	local ownerSession = sessionRepository:GetByParticipant(projectile.OwnerParticipant)
	local targetSession = sessionRepository:GetByParticipant(targetParticipant)

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
	return projectile ~= nil and sessionRepository:HasParticipant(projectile.OwnerParticipant)
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
