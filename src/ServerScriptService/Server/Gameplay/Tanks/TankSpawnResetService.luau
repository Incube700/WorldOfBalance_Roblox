local TankSpawnResetService = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankConfig = require(configs:WaitForChild("TankConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local TankArmorPartsService = require(script.Parent:WaitForChild("TankArmorPartsService"))
local TankRole = require(script.Parent:WaitForChild("TankRole"))

local PLAYER_INITIAL_POSITION = TankConfig.PlayerInitialState.Position
local DUMMY_INITIAL_POSITION = TankConfig.DummyInitialState.Position
local PLAYER2_INITIAL_POSITION = DUMMY_INITIAL_POSITION
local DEFAULT_LOBBY_SPAWN_Y = 46.35

local map = nil
local tankColors = {}
local missingLayoutWarningByModel = {}
local DEBUG_SPAWN = false

function TankSpawnResetService.init(gameMap)
	map = gameMap
end

local function getYawFromFlatDirection(direction, fallbackYaw)
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.001 then
		return fallbackYaw
	end

	local unit = flat.Unit

	return math.atan2(-unit.X, -unit.Z)
end

local function computeFacingYaw(fromPosition, toPosition, fallbackYaw)
	return getYawFromFlatDirection(toPosition - fromPosition, fallbackYaw)
end

local function getSpawnPart(spawnName)
	local root = map ~= nil and map.Parent or nil
	local spawnPointsFolder = root ~= nil and root:FindFirstChild("SpawnPoints") or nil

	if spawnPointsFolder == nil and map ~= nil then
		spawnPointsFolder = map:FindFirstChild("SpawnPoints")
	end

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

local function faceSpawnTransformAt(spawnTransform, targetPosition)
	local yaw = computeFacingYaw(spawnTransform.Position, targetPosition, spawnTransform.BodyYaw or 0)

	return makeSpawnTransform(spawnTransform.Position, yaw, spawnTransform.Source)
end

local function isLobbySpawnSource(source)
	return typeof(source) == "string"
		and (string.match(source, "^LobbySpawn%d+$") ~= nil or source == "LobbyFallback")
end

local function getLobbySpawnY(source)
	local root = Workspace:FindFirstChild("WOB_Generated")
	local lobby = root ~= nil and root:FindFirstChild("Lobby") or nil
	local spawnPoints = lobby ~= nil and lobby:FindFirstChild("SpawnPoints") or nil
	local spawnPart = spawnPoints ~= nil and spawnPoints:FindFirstChild(tostring(source)) or nil

	if spawnPart ~= nil and spawnPart:IsA("BasePart") then
		return spawnPart.Position.Y
	end

	local configuredY = lobby ~= nil and lobby:GetAttribute("LobbySpawnY") or nil

	if typeof(configuredY) == "number" then
		return configuredY
	end

	return DEFAULT_LOBBY_SPAWN_Y
end

local function normalizeSpawnStateHeight(spawnState)
	if spawnState == nil or not isLobbySpawnSource(spawnState.Source) then
		return spawnState
	end

	local position = spawnState.Position
	local lobbyY = getLobbySpawnY(spawnState.Source)

	return makeSpawnTransform(
		Vector3.new(position.X, lobbyY, position.Z),
		spawnState.BodyYaw,
		spawnState.Source
	)
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

function TankSpawnResetService.getSpawnTransform(spawnName, fallbackPosition, fallbackTargetPosition)
	local label = getSpawnLabel(spawnName)
	local fallbackYaw = getYawFromFlatDirection(fallbackTargetPosition - fallbackPosition, 0)
	local spawnPart = getSpawnPart(spawnName)

	if spawnPart == nil then
		local fallbackTransform = makeSpawnTransform(fallbackPosition, fallbackYaw, "Fallback")

		warn(
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

	if DEBUG_SPAWN then
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
	end

	return transform
end

function TankSpawnResetService.getAllSpawnTransforms()
	local playerTransform = TankSpawnResetService.getSpawnTransform("PlayerSpawn", PLAYER_INITIAL_POSITION, DUMMY_INITIAL_POSITION)
	local dummyTransform = TankSpawnResetService.getSpawnTransform("DummySpawn", DUMMY_INITIAL_POSITION, PLAYER_INITIAL_POSITION)
	local player2Transform = TankSpawnResetService.getSpawnTransform("Player2Spawn", PLAYER2_INITIAL_POSITION, PLAYER_INITIAL_POSITION)

	return {
		Player = faceSpawnTransformAt(playerTransform, dummyTransform.Position),
		Dummy = faceSpawnTransformAt(dummyTransform, playerTransform.Position),
		Player2 = faceSpawnTransformAt(player2Transform, playerTransform.Position),
	}
end

local function findBasePart(model, partName)
	local directChild = model:FindFirstChild(partName)

	if directChild ~= nil and directChild:IsA("BasePart") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function findTankFolder(model, folderName)
	local directChild = model:FindFirstChild(folderName)

	if directChild ~= nil and directChild:IsA("Folder") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == folderName and descendant:IsA("Folder") then
			return descendant
		end
	end

	return nil
end

-- Returns the armor hitbox folder used for projectile collision.
-- Prefers "ArmorZones" (BaseTankTemplate) over legacy "Hitboxes".
local function findArmorHitboxFolder(model)
	if model == nil then
		return nil
	end

	local armorZones = findTankFolder(model, "ArmorZones")

	if armorZones ~= nil then
		return armorZones
	end

	return findTankFolder(model, "Hitboxes")
end

local function assignPrimaryPart(model)
	local primaryPart = findBasePart(model, "Body") or findBasePart(model, "Hull")

	if primaryPart == nil then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				primaryPart = descendant
				break
			end
		end
	end

	if primaryPart ~= nil then
		model.PrimaryPart = primaryPart
	end

	return primaryPart
end

function TankSpawnResetService.layoutTank(tank, position, bodyYaw, turretYaw)
	local tankBody = findBasePart(tank, "Body")
	local tankTurret = findBasePart(tank, "Turret")
	local tankBarrel = findBasePart(tank, "Barrel")
	local tankShootPoint = findBasePart(tank, "ShootPoint")

	if tankBody == nil or tankTurret == nil or tankBarrel == nil or tankShootPoint == nil then
		if missingLayoutWarningByModel[tank] ~= true then
			missingLayoutWarningByModel[tank] = true
			warn("[TANK] warning " .. tank:GetFullName() .. " cannot layout: Body/Turret/Barrel/ShootPoint missing")
		end
		return
	end

	assignPrimaryPart(tank)

	local bodyCFrame = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, bodyYaw, 0)
	local turretCFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, turretYaw, 0)

	tankBody.CFrame = bodyCFrame
	tankTurret.CFrame = turretCFrame
	tankBarrel.CFrame = turretCFrame * CFrame.new(0, 0, -5.8)
	tankShootPoint.CFrame = turretCFrame * CFrame.new(0, 0, -10)
	TankArmorPartsService.Configure(tank)
end

function TankSpawnResetService.captureTankColors(participantId, model)
	local colorsByPart = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			colorsByPart[descendant] = descendant.Color
		end
	end

	tankColors[participantId] = colorsByPart
end

function TankSpawnResetService.restoreTankColors(participantId)
	local colorsByPart = tankColors[participantId]
	if not colorsByPart then return end

	for part, color in pairs(colorsByPart) do
		if part.Parent ~= nil then
			part.Color = color
		end
	end
end

function TankSpawnResetService.restoreAllTankColors()
	for id, _ in pairs(tankColors) do
		TankSpawnResetService.restoreTankColors(id)
	end
end

function TankSpawnResetService.darkenTank(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = Color3.fromRGB(30, 30, 30)
		end
	end
end

function TankSpawnResetService.applySpawnToParticipant(participant, spawnState)
	spawnState = normalizeSpawnStateHeight(spawnState)
	participant.SpawnTransform = spawnState
	participant.Model = TankParticipantRegistry.getParticipantPhysicalModel(participant)
	participant.PrimaryPart = assignPrimaryPart(participant.Model)
	participant.Body = findBasePart(participant.Model, "Body")
	participant.Turret = findBasePart(participant.Model, "Turret")
	participant.Barrel = findBasePart(participant.Model, "Barrel")
	participant.ShootPoint = findBasePart(participant.Model, "ShootPoint")
	participant.Hitboxes = findArmorHitboxFolder(participant.Model)

	if participant.ControlState == nil then
		participant.ControlState = {}
	end

	participant.ControlState.Position = spawnState.Position
	participant.ControlState.BodyYaw = spawnState.BodyYaw
	participant.ControlState.TurretYaw = spawnState.TurretYaw
	
	-- Reset weapon state
	participant.LastShotTime = 0
	participant.WeaponReadyAt = 0
	if participant.WeaponState then
		participant.WeaponState.LastShotTime = 0
		participant.WeaponState.WeaponReadyAt = 0
	end
	
	TankSpawnResetService.layoutTank(participant.Model, spawnState.Position, spawnState.BodyYaw, spawnState.TurretYaw)
end

function TankSpawnResetService.configureActiveParticipants(matchMode, player2HasOwner, activeParticipants)
	if activeParticipants ~= nil then
		local activeByParticipant = {}

		for _, participant in ipairs(activeParticipants) do
			activeByParticipant[participant] = true
		end

		for _, participant in ipairs(TankParticipantRegistry.getParticipants()) do
			if participant.IsPlayerTank == true then
				TankParticipantRegistry.setParticipantModelVisible(participant, participant.OwnerPlayer ~= nil)
			elseif participant.Role == TankRole.Dummy then
				TankParticipantRegistry.setParticipantModelVisible(
					participant,
					matchMode == "Training" and activeByParticipant[participant] == true
				)
			end
		end

		return
	end

	for _, participant in ipairs(TankParticipantRegistry.getParticipants()) do
		if participant.IsPlayerTank == true then
			local isDuelOpponent = participant.Role == TankRole.DuelOpponent
			-- DuelOpponent slots are visible only in PvP with a second player present.
			-- All other player-role tanks (including Startup_Player) are visible only
			-- when they have an assigned owner. Unowned startup tanks stay hidden.
			local isVisible
			if isDuelOpponent then
				isVisible = matchMode == "PvP" and player2HasOwner
			else
				isVisible = participant.OwnerPlayer ~= nil
			end

			TankParticipantRegistry.setParticipantModelVisible(participant, isVisible)
		elseif participant.Role == TankRole.Dummy then
			TankParticipantRegistry.setParticipantModelVisible(participant, matchMode == "Training")
		end
	end
end

return TankSpawnResetService
