local TankFactory = {}
TankFactory.__index = TankFactory

local PlayerTankSpawner = require(script.Parent.Parent:WaitForChild("PlayerTankSpawner"))
local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local TankCustomizationService = require(script.Parent:WaitForChild("TankCustomizationService"))
local TankArmorPartsService = require(script.Parent:WaitForChild("TankArmorPartsService"))
local TankSkinApplier = require(script.Parent:WaitForChild("TankSkinApplier"))
local TankRole = require(script.Parent:WaitForChild("TankRole"))
local TankSpawnRequest = require(script.Parent:WaitForChild("TankSpawnRequest"))
local TankStatsProvider = require(script.Parent:WaitForChild("TankStatsProvider"))

local function findOptionalTankChild(model, childName)
	local child = model:FindFirstChild(childName, true) or model:WaitForChild(childName, 5)

	if child == nil then
		warn("[TANK FACTORY] " .. model.Name .. "." .. childName .. " missing; continuing without blocking startup")
	end

	return child
end

local function getRoleDefaults(role)
	if role == TankRole.Dummy then
		return true, false, "Dummy"
	elseif role == TankRole.Bot or role == TankRole.ArenaBot then
		return true, false, "Bot"
	end

	return false, true, "Player"
end

local function setModelAttribute(model, attributeName, value)
	if model ~= nil then
		model:SetAttribute(attributeName, value)
	end
end

local function setParticipantModelsAttribute(participant, attributeName, value)
	setModelAttribute(participant.Model, attributeName, value)

	if participant.PhysicalModel ~= nil and participant.PhysicalModel ~= participant.Model then
		setModelAttribute(participant.PhysicalModel, attributeName, value)
	end
end

local function setOwnerPlayerAttribute(participant, attributeName, value)
	if participant.OwnerPlayer ~= nil then
		participant.OwnerPlayer:SetAttribute(attributeName, value)
	end
end

local function applyFactoryAttributes(model, participant, request, loadout, statsProfileId)
	setModelAttribute(model, "TankRole", participant.Role)
	setModelAttribute(model, "StatsProfileId", statsProfileId)
	setModelAttribute(model, "WeaponId", participant.WeaponTypeId)
	setModelAttribute(model, "SkinId", loadout.SkinId)
	setModelAttribute(model, "LoadoutSkinId", loadout.SkinId)

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

local function getParticipantPhysicalModel(participant)
	if participant == nil then
		return nil
	end

	return participant.PhysicalModel or participant.Model
end

local function makeSpawnResult(participant, created, templateModel)
	return {
		TankModel = getParticipantPhysicalModel(participant),
		Participant = participant,
		BodyPart = participant ~= nil and participant.Body or nil,
		Role = participant ~= nil and participant.Role or nil,
		Created = created == true,
		TemplateModel = templateModel,
	}
end

function TankFactory.new(dependencies)
	dependencies = dependencies or {}

	return setmetatable({
		PlayerTankSpawner = dependencies.PlayerTankSpawner or PlayerTankSpawner,
		TankParticipantRegistry = dependencies.TankParticipantRegistry or TankParticipantRegistry,
		TankCustomizationService = dependencies.TankCustomizationService or TankCustomizationService,
		TankStatsProvider = dependencies.TankStatsProvider or TankStatsProvider.new(),
		TemplateProvider = dependencies.TemplateProvider,
		DefaultWeaponConfig = dependencies.DefaultWeaponConfig,
		SpawnParent = dependencies.SpawnParent,
	}, TankFactory)
end

function TankFactory:_getExistingModel(tankId, parent)
	if tankId == nil or parent == nil then
		return nil
	end

	local existing = parent:FindFirstChild(tankId)

	if existing ~= nil and existing:IsA("Model") then
		return existing
	end

	return nil
end

function TankFactory:_getRequestModel(request)
	if request.ExistingModel ~= nil then
		return request.ExistingModel, false, nil
	end

	local parent = request.Parent or self.SpawnParent
	local existing = self:_getExistingModel(request.TankId or request.Name, parent)

	if existing ~= nil then
		return existing, false, nil
	end

	local templateModel = request.TemplateModel

	if templateModel == nil and self.TemplateProvider ~= nil then
		templateModel = self.TemplateProvider:GetTemplateForRole(request.Role)
	end

	if templateModel == nil or not templateModel:IsA("Model") then
		return nil, false, nil
	end

	local clone = templateModel:Clone()
	clone.Name = request.TankId or request.Name or templateModel.Name
	clone.Parent = parent or templateModel.Parent

	return clone, true, templateModel
end

function TankFactory:_applyRegisteredStats(participant, stats)
	participant.MaxHealth = stats.MaxHealth
	participant.DefaultMaxHealth = stats.MaxHealth
	participant.Health = stats.Health
	participant.IsAlive = stats.Health > 0
	participant.IsDead = stats.Health <= 0

	setParticipantModelsAttribute(participant, "MaxHealth", stats.MaxHealth)
	setParticipantModelsAttribute(participant, "DefaultMaxHealth", stats.MaxHealth)
	setOwnerPlayerAttribute(participant, "MaxHealth", stats.MaxHealth)

	self.TankParticipantRegistry.setParticipantHealth(participant, stats.Health)
	self.TankParticipantRegistry.setParticipantIsDead(participant, stats.Health <= 0)
end

function TankFactory:SpawnTank(request)
	request = TankSpawnRequest.Normalize(request)

	if request.TankId ~= nil then
		local existingParticipant = self.TankParticipantRegistry.getParticipantById(request.TankId)

		if existingParticipant ~= nil then
			return makeSpawnResult(existingParticipant, false, nil)
		end
	end

	local role = request.Role
	local model, created, templateModel = self:_getRequestModel(request)

	if model == nil or not model:IsA("Model") then
		error("[TANK FACTORY] SpawnTank failed: missing model for role=" .. tostring(role), 2)
	end

	local loadout = request.Loadout
	local statsProfileId = request.StatsProfileId
	local defaultIsBot, defaultIsPlayerTank, defaultControllerType = getRoleDefaults(role)
	local ownerPlayer = request.OwnerPlayer
	local ownerUserId = request.OwnerUserId or (ownerPlayer ~= nil and ownerPlayer.UserId or nil)
	local ownerName = request.OwnerName or (ownerPlayer ~= nil and ownerPlayer.Name or nil)
	local weaponConfig = request.WeaponConfig or self.DefaultWeaponConfig

	self.PlayerTankSpawner.ensurePhysicalTankModel(model)
	self.TankCustomizationService.applySkin(model, loadout.SkinId)
	TankArmorPartsService.Configure(model)
	TankSkinApplier.Apply(model, loadout)

	local tankParts = self.PlayerTankSpawner.getTankParts(model)
	local stats = self.TankStatsProvider:GetStats(statsProfileId, request, model)
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
		WeaponTypeId = request.WeaponTypeId or loadout.WeaponId or stats.WeaponId or (weaponConfig ~= nil and weaponConfig.Id or "PrototypeCannon"),
		WeaponConfig = weaponConfig,
		LastShotTime = 0,
		WeaponReadyAt = 0,
		WeaponState = { LastShotTime = 0, WeaponReadyAt = 0 },
		Health = stats.Health,
		MaxHealth = stats.MaxHealth,
		DefaultMaxHealth = stats.MaxHealth,
		IsAlive = stats.Health > 0,
		IsDead = stats.Health <= 0,
		IsControllable = request.IsControllable ~= false,
		CanMove = request.CanMove ~= false,
		CanShoot = request.CanShoot ~= false,
		IsActive = request.IsActive ~= false,
		StatsProfileId = statsProfileId,
		Loadout = loadout,
	}

	applyFactoryAttributes(model, participant, request, loadout, statsProfileId)

	local registeredParticipant = self.TankParticipantRegistry.registerTankParticipant(participant)
	self:_applyRegisteredStats(registeredParticipant, stats)

	return makeSpawnResult(registeredParticipant, created, templateModel)
end

return TankFactory
