local TankSpawnResetService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankConfig = require(configs:WaitForChild("TankConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))

local primaryWeaponConfig = WeaponConfig.PrimaryWeapon

local PLAYER_INITIAL_POSITION = TankConfig.PlayerInitialState.Position
local DUMMY_INITIAL_POSITION = TankConfig.DummyInitialState.Position
local PLAYER2_INITIAL_POSITION = DUMMY_INITIAL_POSITION

local TANK_ARMOR = TankConfig.Armor
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

local map = nil
local tankColors = {}
local resolvedArmorHitboxMaterial = nil

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

function TankSpawnResetService.getSpawnTransform(spawnName, fallbackPosition, fallbackTargetPosition)
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

function TankSpawnResetService.getAllSpawnTransforms()
	return {
		Player = TankSpawnResetService.getSpawnTransform("PlayerSpawn", PLAYER_INITIAL_POSITION, DUMMY_INITIAL_POSITION),
		Dummy = TankSpawnResetService.getSpawnTransform("DummySpawn", DUMMY_INITIAL_POSITION, PLAYER_INITIAL_POSITION),
		Player2 = TankSpawnResetService.getSpawnTransform("Player2Spawn", PLAYER2_INITIAL_POSITION, PLAYER_INITIAL_POSITION),
	}
end

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

function TankSpawnResetService.layoutTank(tank, position, bodyYaw, turretYaw)
	local tankBody = tank:FindFirstChild("Body")
	local tankTurret = tank:FindFirstChild("Turret")
	local tankBarrel = tank:FindFirstChild("Barrel")
	local tankShootPoint = tank:FindFirstChild("ShootPoint")
	local tankHitboxes = tank:FindFirstChild("Hitboxes")

	if tankBody == nil or tankTurret == nil or tankBarrel == nil or tankShootPoint == nil then
		return
	end

	-- Обеспечиваем наличие PrimaryPart для камеры и других систем
	if not tank.PrimaryPart then
		local body = tank:FindFirstChild("Body", true)
		if body and body:IsA("BasePart") then
			tank.PrimaryPart = body
		else
			-- Если Body не найден, ищем любой BasePart
			for _, child in ipairs(tank:GetDescendants()) do
				if child:IsA("BasePart") then
					tank.PrimaryPart = child
					break
				end
			end
		end
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
	participant.SpawnTransform = spawnState

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

function TankSpawnResetService.configureActiveParticipants(matchMode, player2HasOwner)
	local playerParticipant = TankParticipantRegistry.getParticipantById("PlayerTankPrototype")
	local player2Participant = TankParticipantRegistry.getParticipantById("Player2TankPrototype")
	local dummyParticipant = TankParticipantRegistry.getParticipantById("DummyTank")

	if playerParticipant then
		TankParticipantRegistry.setParticipantModelVisible(playerParticipant, true)
	end
	
	if player2Participant then
		TankParticipantRegistry.setParticipantModelVisible(player2Participant, matchMode == "PvP" and player2HasOwner)
	end
	
	if dummyParticipant then
		TankParticipantRegistry.setParticipantModelVisible(dummyParticipant, matchMode == "Training")
	end
end

return TankSpawnResetService
