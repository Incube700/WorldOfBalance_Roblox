local TankSpawnResetService = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankConfig = require(configs:WaitForChild("TankConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local TankArmorPartsService = require(script.Parent:WaitForChild("TankArmorPartsService"))
local TankRole = require(script.Parent:WaitForChild("TankRole"))
-- Update 0.2: clear any temporary pickup weapon when a tank respawns/resets.
local TemporaryWeaponService = require(script.Parent.Parent:WaitForChild("Weapons"):WaitForChild("TemporaryWeaponService"))

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

-- Training dummy spawn resolution, scoped to the Training field (the "Map" container) ONLY.
-- Unlike getSpawnPart (which prefers the generic top-level WOB_Generated/SpawnPoints and is
-- still used by Player/Player2 so Duel stays unchanged), this looks exclusively inside
-- Map/SpawnPoints and accepts DummySpawn / TrainingDummySpawn / TrainingSpawn1. No global
-- scan, no first-found folder, no hardcoded near-Duel fallback: if nothing is authored it
-- falls back to the Training floor centre and warns. Throttled spawn log included.
local TRAINING_DUMMY_SPAWN_NAMES = { "DummySpawn", "TrainingDummySpawn", "TrainingSpawn1" }
local lastTrainingSpawnLogAt = 0

local function getTrainingFloorCentre()
	if map == nil then
		return nil
	end

	local floor = map:FindFirstChild("Floor")
	if floor == nil or not floor:IsA("BasePart") then
		for _, descendant in ipairs(map:GetDescendants()) do
			if descendant.Name == "Floor" and descendant:IsA("BasePart") then
				floor = descendant
				break
			end
		end
	end

	if floor ~= nil and floor:IsA("BasePart") then
		return Vector3.new(floor.Position.X, 0, floor.Position.Z)
	end

	if map:IsA("Model") then
		local okCenter, cf = pcall(function()
			return (map:GetBoundingBox())
		end)
		if okCenter and typeof(cf) == "CFrame" then
			return Vector3.new(cf.Position.X, 0, cf.Position.Z)
		end
	end

	return nil
end

function TankSpawnResetService.getTrainingDummySpawnTransform(fallbackTargetPosition)
	local fallbackYaw = getYawFromFlatDirection(fallbackTargetPosition - DUMMY_INITIAL_POSITION, 0)

	-- Candidate spawn folders for the TRAINING field, in priority order (matches how the
	-- working PlayerSpawn resolves -- top-level WOB_Generated/SpawnPoints FIRST):
	--   1. WOB_Generated/SpawnPoints (shared top-level field folder; this is where the
	--      authored DummySpawn / PlayerSpawn live)
	--   2. Map/SpawnPoints (explicit Training/Duel field container, if used)
	-- We deliberately do NOT look inside BattleArena/Lobby (those have their own routing) and
	-- we only ever match an explicitly-named Training spawn part -- never "first part found".
	local generatedRoot = map ~= nil and map.Parent or nil
	local candidateFolders = {}

	if generatedRoot ~= nil then
		local topSpawns = generatedRoot:FindFirstChild("SpawnPoints")
		if topSpawns ~= nil then
			table.insert(candidateFolders, topSpawns)
		end
	end

	if map ~= nil then
		local mapSpawns = map:FindFirstChild("SpawnPoints")
		if mapSpawns ~= nil then
			table.insert(candidateFolders, mapSpawns)
		end
	end

	local spawnPart = nil
	for _, folder in ipairs(candidateFolders) do
		for _, spawnName in ipairs(TRAINING_DUMMY_SPAWN_NAMES) do
			local candidate = folder:FindFirstChild(spawnName)
			if candidate ~= nil and candidate:IsA("BasePart") then
				spawnPart = candidate
				break
			end
		end
		if spawnPart ~= nil then
			break
		end
	end

	local now = os.clock()
	local shouldLog = now - lastTrainingSpawnLogAt > 1
	if shouldLog then
		lastTrainingSpawnLogAt = now
	end

	if spawnPart ~= nil then
		local position = Vector3.new(spawnPart.Position.X, 0, spawnPart.Position.Z)
		local yaw = getYawFromFlatDirection(spawnPart.CFrame.LookVector, fallbackYaw)
		if shouldLog then
			print(("[TRAINING SPAWN] Bot Training_Dummy spawn=%s pos=%s container=%s"):format(
				spawnPart:GetFullName(),
				formatVector3(position),
				spawnPart.Parent ~= nil and spawnPart.Parent:GetFullName() or "?"))
		end
		return makeSpawnTransform(position, yaw, spawnPart:GetFullName())
	end

	-- No authored Training spawn: fall back to the Training floor centre, never near Duel.
	local floorCentre = getTrainingFloorCentre()
	if floorCentre ~= nil then
		warn(("[TRAINING SPAWN] No DummySpawn/TrainingSpawn in %s/SpawnPoints; using Training floor centre %s as last-resort fallback."):format(
			map ~= nil and map:GetFullName() or "Map", formatVector3(floorCentre)))
		return makeSpawnTransform(floorCentre, fallbackYaw, "TrainingFloorCentreFallback")
	end

	warn("[TRAINING SPAWN] No Training spawn point and no Training floor found; cannot place dummy safely. Author Workspace.WOB_Generated.Map.SpawnPoints.DummySpawn.")
	return makeSpawnTransform(DUMMY_INITIAL_POSITION, fallbackYaw, "TrainingFallback")
end

function TankSpawnResetService.getAllSpawnTransforms()
	local playerTransform = TankSpawnResetService.getSpawnTransform("PlayerSpawn", PLAYER_INITIAL_POSITION, DUMMY_INITIAL_POSITION)
	local dummyTransform = TankSpawnResetService.getTrainingDummySpawnTransform(playerTransform.Position)
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

-- Attaches the movement trail (TankTrailVFX) behind the tank body, once per model. The body
-- parts are anchored and moved by CFrame every frame, so a separate clone Part would fall and
-- emit while standing still. Instead we copy any ParticleEmitter/Trail/Beam from the template
-- onto an ATTACHMENT inside the Body (attachments follow the part for free), start them
-- DISABLED, and store them so setTrailActive() can turn them on only while the tank moves.
function TankSpawnResetService.ensureMovementTrail(participant)
	if participant == nil then
		return
	end
	local body = participant.Body or findBasePart(participant.Model, "Body")
	if body == nil then
		return
	end

	-- Two trails — one under each track (left/right), so it reads as tank treads kicking up.
	local existingLeft = body:FindFirstChild("WOBTankTrailAttachment_L")
	if existingLeft == nil then
		local vfxFolder = ReplicatedStorage:FindFirstChild("Shared")
		vfxFolder = vfxFolder and vfxFolder:FindFirstChild("Assets")
		vfxFolder = vfxFolder and vfxFolder:FindFirstChild("VFX")
		local template = vfxFolder and vfxFolder:FindFirstChild("TankTrailVFX")

		local emitters = {}

		-- Builds one exhaust attachment at a side offset and copies the template emitters
		-- (or a fallback smoke) onto it. Side = -1 (left) or +1 (right).
		local function buildSide(side, suffix)
			local attachment = Instance.new("Attachment")
			attachment.Name = "WOBTankTrailAttachment_" .. suffix
			attachment.Position = Vector3.new(
				side * body.Size.X * 0.42, -- out to the track
				-body.Size.Y * 0.25,
				body.Size.Z * 0.5 -- behind
			)
			attachment.Parent = body

			local added = 0
			local function collect(inst)
				if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
					local copy = inst:Clone()
					copy.Enabled = false
					copy.Parent = attachment
					table.insert(emitters, copy)
					added += 1
				end
			end
			if template ~= nil then
				collect(template)
				for _, d in ipairs(template:GetDescendants()) do
					collect(d)
				end
			end

			if added == 0 then
				-- Fallback dust puff so the feature works even without the template.
				local smoke = Instance.new("ParticleEmitter")
				smoke.Name = "TankExhaust"
				smoke.Texture = "rbxassetid://243660364"
				smoke.Rate = 14
				smoke.Lifetime = NumberRange.new(0.4, 0.8)
				smoke.Speed = NumberRange.new(1, 3)
				smoke.Size = NumberSequence.new(1.3)
				smoke.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.45),
					NumberSequenceKeypoint.new(1, 1),
				})
				smoke.Enabled = false
				smoke.Parent = attachment
				table.insert(emitters, smoke)
			end
		end

		buildSide(-1, "L")
		buildSide(1, "R")
		participant.TrailEmitters = emitters
	elseif participant.TrailEmitters == nil then
		-- Re-link emitters after a respawn that reused the model (both side attachments).
		local emitters = {}
		for _, suffix in ipairs({ "L", "R" }) do
			local att = body:FindFirstChild("WOBTankTrailAttachment_" .. suffix)
			if att ~= nil then
				for _, d in ipairs(att:GetChildren()) do
					if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
						table.insert(emitters, d)
					end
				end
			end
		end
		participant.TrailEmitters = emitters
	end
end

-- Enables/disables the movement-trail emitters. Called from the movement loop with the
-- tank's current speed so the trail only shows when the tank is actually driving.
function TankSpawnResetService.setTrailActive(participant, active)
	if participant == nil or participant.TrailEmitters == nil then
		return
	end
	for _, emitter in ipairs(participant.TrailEmitters) do
		if emitter ~= nil and emitter.Parent ~= nil then
			emitter.Enabled = active == true
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
	participant.ControlState.CurrentSpeed = 0
	participant.ControlState.CurrentTurnRate = 0
	participant.ControlState.RecoilVelocity = Vector3.zero
	
	-- Reset weapon state
	participant.LastShotTime = 0
	participant.WeaponReadyAt = 0
	if participant.WeaponState then
		participant.WeaponState.LastShotTime = 0
		participant.WeaponState.WeaponReadyAt = 0
	end
	-- Update 0.2: revert to the default cannon on respawn / run reset / lobby exit.
	TemporaryWeaponService.resetParticipant(participant, "Respawn")

	TankSpawnResetService.layoutTank(participant.Model, spawnState.Position, spawnState.BodyYaw, spawnState.TurretYaw)
	TankSpawnResetService.ensureMovementTrail(participant)

	-- Diagnostic trace for the Training dummy ONLY (no spam: fires per placement, plus one
	-- delayed sample to catch anything that moves it afterwards).
	if participant.Role == TankRole.Dummy and participant.Model ~= nil then
		local expected = spawnState.Position
		local afterPivot = participant.Model:GetPivot().Position
		print(("[TRAINING TRACE] selected spawn=%s cf=%s"):format(tostring(spawnState.Source), formatVector3(expected)))
		print(("[TRAINING TRACE] after layoutTank pivot=%s"):format(formatVector3(afterPivot)))

		local model = participant.Model
		task.delay(0.1, function()
			if model == nil or model.Parent == nil then
				return
			end
			local finalPivot = model:GetPivot().Position
			local delta = (Vector3.new(finalPivot.X, 0, finalPivot.Z) - Vector3.new(expected.X, 0, expected.Z)).Magnitude
			print(("[TRAINING SPAWN FINAL] Bot Training_Dummy spawn=%s finalPivot=%s expected=%s delta=%.1f"):format(
				tostring(spawnState.Source), formatVector3(finalPivot), formatVector3(expected), delta))
			if delta > 12 then
				warn(("[TRAINING SPAWN WARNING] Training_Dummy moved after spawn by %.1f studs."):format(delta))
			end
		end)
	end
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
			-- Dummy is only visible during an actively running Training match.
			-- The with-active-match path handles that case; without an active match
			-- (lobby / free drive / between rounds) the dummy must stay hidden, even
			-- if matchMode is still "Training" leftover from a previous match.
			TankParticipantRegistry.setParticipantModelVisible(participant, false)
		end
	end
end

return TankSpawnResetService
