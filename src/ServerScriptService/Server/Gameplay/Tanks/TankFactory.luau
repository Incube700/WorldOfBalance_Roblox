local TankFactory = {}
TankFactory.__index = TankFactory

local PlayerTankSpawner = require(script.Parent.Parent:WaitForChild("PlayerTankSpawner"))
local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local TankCustomizationService = require(script.Parent:WaitForChild("TankCustomizationService"))

local DEFAULT_HEALTH = 100

local function findOptionalTankChild(model, childName)
	local child = model:FindFirstChild(childName, true) or model:WaitForChild(childName, 5)

	if child == nil then
		warn("[TANK FACTORY] " .. model.Name .. "." .. childName .. " missing; continuing without blocking startup")
	end

	return child
end

local function getRoleDefaults(role)
	if role == "Dummy" then
		return true, false, "Dummy"
	elseif role == "Bot" then
		return true, false, "Bot"
	end

	return false, true, "Player"
end

local function getRequestModel(request)
	if request.ExistingModel ~= nil then
		return request.ExistingModel, false
	end

	local templateModel = request.TemplateModel

	if templateModel == nil then
		return nil, false
	end

	local clone = templateModel:Clone()
	clone.Name = request.TankId or request.Name or templateModel.Name
	clone.Parent = request.Parent or templateModel.Parent

	return clone, true
end

local function setModelAttribute(model, attributeName, value)
	if model ~= nil then
		model:SetAttribute(attributeName, value)
	end
end

local function applyFactoryAttributes(model, participant, request, loadout, statsProfileId)
	setModelAttribute(model, "TankRole", participant.Role)
	setModelAttribute(model, "StatsProfileId", statsProfileId)
	setModelAttribute(model, "WeaponId", participant.WeaponTypeId)
	setModelAttribute(model, "LoadoutSkinId", loadout.SkinId or request.SkinId or "Default")

	if loadout.UpgradeLevels ~= nil then
		setModelAttribute(model, "HasUpgradeLevels", true)
	end
end

local function getYawFromLookVector(lookVector)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLook.Magnitude < 0.001 then
		return 0
	end

	local unit = flatLook.Unit
	return math.atan2(-unit.X, -unit.Z)
end

local function getSpawnTransform(request)
	if request.SpawnTransform ~= nil then
		return request.SpawnTransform
	end

	if typeof(request.SpawnCFrame) ~= "CFrame" then
		return nil
	end

	local yaw = getYawFromLookVector(request.SpawnCFrame.LookVector)

	return {
		Position = request.SpawnCFrame.Position,
		BodyYaw = yaw,
		TurretYaw = yaw,
		Source = "TankFactorySpawnCFrame",
	}
end

local function resolveBoolean(value, fallback)
	if value ~= nil then
		return value == true
	end

	return fallback == true
end

function TankFactory.new(dependencies)
	dependencies = dependencies or {}

	return setmetatable({
		PlayerTankSpawner = dependencies.PlayerTankSpawner or PlayerTankSpawner,
		TankParticipantRegistry = dependencies.TankParticipantRegistry or TankParticipantRegistry,
		TankCustomizationService = dependencies.TankCustomizationService or TankCustomizationService,
		DefaultWeaponConfig = dependencies.DefaultWeaponConfig,
	}, TankFactory)
end

function TankFactory:SpawnTank(request)
	request = request or {}

	local role = request.Role or "Player"
	local model, created = getRequestModel(request)

	if model == nil or not model:IsA("Model") then
		warn("[TANK FACTORY] SpawnTank ignored: missing Model for role=" .. tostring(role))
		return nil, false
	end

	local loadout = request.Loadout or {}
	local statsProfileId = request.StatsProfileId or (role == "Dummy" and "TrainingDummy" or "DuelNormalized")
	local defaultIsBot, defaultIsPlayerTank, defaultControllerType = getRoleDefaults(role)
	local ownerPlayer = request.OwnerPlayer
	local ownerUserId = request.OwnerUserId or (ownerPlayer ~= nil and ownerPlayer.UserId or nil)
	local ownerName = ownerPlayer ~= nil and ownerPlayer.Name or nil
	local weaponConfig = request.WeaponConfig or self.DefaultWeaponConfig

	self.PlayerTankSpawner.ensurePhysicalTankModel(model)
	self.TankCustomizationService.applySkin(model, loadout.SkinId or request.SkinId)

	local tankParts = self.PlayerTankSpawner.getTankParts(model)
	local maxHealth = math.max(1, tonumber(request.MaxHealth) or DEFAULT_HEALTH)
	local health = math.clamp(tonumber(request.Health) or maxHealth, 0, maxHealth)
	local participant = {
		TankId = request.TankId or model.Name,
		Model = tankParts.Model,
		PhysicalModel = tankParts.Model,
		Body = tankParts.Body or findOptionalTankChild(model, "Body"),
		Turret = tankParts.Turret or findOptionalTankChild(model, "Turret"),
		Barrel = tankParts.Barrel or findOptionalTankChild(model, "Barrel"),
		ShootPoint = tankParts.ShootPoint or findOptionalTankChild(model, "ShootPoint"),
		Hitboxes = tankParts.Hitboxes or findOptionalTankChild(model, "Hitboxes"),
		OwnerPlayer = ownerPlayer,
		OwnerUserId = ownerUserId,
		OwnerName = ownerName,
		TeamId = request.TeamId,
		IsBot = resolveBoolean(request.IsBot, defaultIsBot),
		IsPlayerTank = resolveBoolean(request.IsPlayerTank, defaultIsPlayerTank),
		ControllerType = request.ControllerType or defaultControllerType,
		Role = role,
		SpawnName = request.SpawnName,
		SpawnTransform = getSpawnTransform(request),
		WeaponTypeId = request.WeaponTypeId or loadout.WeaponId or (weaponConfig ~= nil and weaponConfig.Id or "PrototypeCannon"),
		WeaponConfig = weaponConfig,
		LastShotTime = 0,
		WeaponReadyAt = 0,
		WeaponState = { LastShotTime = 0, WeaponReadyAt = 0 },
		Health = health,
		MaxHealth = maxHealth,
		DefaultMaxHealth = maxHealth,
		IsAlive = health > 0,
		IsDead = health <= 0,
		IsControllable = request.IsControllable ~= false,
		CanMove = request.CanMove ~= false,
		CanShoot = request.CanShoot ~= false,
		IsActive = request.IsActive ~= false,
		StatsProfileId = statsProfileId,
		Loadout = loadout,
	}

	applyFactoryAttributes(model, participant, request, loadout, statsProfileId)

	return self.TankParticipantRegistry.registerTankParticipant(participant), created
end

return TankFactory
