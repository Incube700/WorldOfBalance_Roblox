local TankParticipantRegistry = {}

local tankParticipants = {}
local tankParticipantsById = {}
local tankParticipantsByModel = {}
local tankParticipantsByPhysicalModel = {}
local playerParticipants = {}
local playerParticipantByPlayer = {}

local config = {
	armorHitboxNames = {},
	ARMOR_HITBOXES_VISIBLE = false,
	ARMOR_HITBOX_TRANSPARENCY = 0.4,
}

function TankParticipantRegistry.init(initialConfig)
	if initialConfig then
		for k, v in pairs(initialConfig) do
			config[k] = v
		end
	end
end

local function findNamedBasePart(model, partName)
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

local function findPrimaryPart(model)
	local body = findNamedBasePart(model, "Body")

	if body ~= nil then
		return body
	end

	local hull = findNamedBasePart(model, "Hull")

	if hull ~= nil then
		return hull
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function countBaseParts(model)
	local count = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

local function assignPrimaryPart(model)
	local primaryPart = findPrimaryPart(model)

	if primaryPart ~= nil then
		model.PrimaryPart = primaryPart
	end

	return primaryPart
end

local function setParticipantAttributesOnModel(model, participant)
	model:SetAttribute("TankId", participant.TankId)
	model:SetAttribute("IsActive", participant.IsActive ~= false)
	model:SetAttribute("IsAlive", participant.IsAlive ~= false)
	model:SetAttribute("IsDead", participant.IsDead == true)
	model:SetAttribute("IsControllable", participant.IsControllable ~= false)
	model:SetAttribute("CanMove", participant.CanMove ~= false)
	model:SetAttribute("CanShoot", participant.CanShoot ~= false)
	model:SetAttribute("TeamId", participant.TeamId)
	model:SetAttribute("IsBot", participant.IsBot)
	model:SetAttribute("IsPlayerTank", participant.IsPlayerTank == true)
	model:SetAttribute("ControllerType", participant.ControllerType)
	model:SetAttribute("PhysicalModelPath", participant.PhysicalModel:GetFullName())
	model:SetAttribute("ParticipantState", participant.ParticipantState)
	model:SetAttribute("MatchId", participant.MatchId)
	model:SetAttribute("OpponentTankId", participant.OpponentTankId)

	if participant.OwnerUserId == nil then
		model:SetAttribute("OwnerUserId", nil)
		model:SetAttribute("OwnerName", nil)
	else
		model:SetAttribute("OwnerUserId", participant.OwnerUserId)
		model:SetAttribute("OwnerName", participant.OwnerName)
	end
end

local function setParticipantAttributes(participant)
	setParticipantAttributesOnModel(participant.Model, participant)

	if participant.PhysicalModel ~= participant.Model then
		setParticipantAttributesOnModel(participant.PhysicalModel, participant)
	end
end

local function setAttributeOnParticipantModels(participant, attributeName, value)
	participant.Model:SetAttribute(attributeName, value)

	if participant.PhysicalModel ~= nil and participant.PhysicalModel ~= participant.Model then
		participant.PhysicalModel:SetAttribute(attributeName, value)
	end
end

function TankParticipantRegistry.registerTankParticipant(participant)
	participant.PhysicalModel = participant.PhysicalModel or participant.Model
	participant.Model = participant.PhysicalModel or participant.Model

	local primaryPart = assignPrimaryPart(participant.PhysicalModel)
	local basePartCount = countBaseParts(participant.PhysicalModel)

	table.insert(tankParticipants, participant)
	tankParticipantsById[participant.TankId] = participant
	tankParticipantsByModel[participant.Model] = participant
	tankParticipantsByPhysicalModel[participant.PhysicalModel] = participant
	
	if participant.IsPlayerTank then
		table.insert(playerParticipants, participant)
	end

	setParticipantAttributes(participant)

	if primaryPart == nil or basePartCount <= 0 then
		warn(
			"[TANK] CRITICAL "
				.. participant.TankId
				.. " has no BasePart model="
				.. participant.PhysicalModel:GetFullName()
				.. " primaryPart=nil baseParts="
				.. tostring(basePartCount)
		)
	else
		print(
			"[TANK] registered "
				.. participant.TankId
				.. " model="
				.. participant.PhysicalModel:GetFullName()
				.. " primaryPart="
				.. primaryPart.Name
				.. " baseParts="
				.. tostring(basePartCount)
		)
	end

	return participant
end

function TankParticipantRegistry.getParticipants()
	return tankParticipants
end

function TankParticipantRegistry.getPlayerParticipants()
	return playerParticipants
end

function TankParticipantRegistry.getParticipantById(tankId)
	return tankParticipantsById[tankId]
end

function TankParticipantRegistry.getParticipantFromModel(model)
	return tankParticipantsByPhysicalModel[model] or tankParticipantsByModel[model]
end

function TankParticipantRegistry.getParticipantPhysicalModel(participant)
	return participant.PhysicalModel or participant.Model
end

function TankParticipantRegistry.getParticipantFromArmorHitbox(hitInstance)
	if hitInstance == nil
		or not hitInstance:IsA("BasePart")
		or config.armorHitboxNames[hitInstance.Name] ~= true
	then
		return nil
	end

	local participant = TankParticipantRegistry.getParticipantFromModel(hitInstance:FindFirstAncestorWhichIsA("Model"))

	if participant ~= nil
		and participant.Hitboxes ~= nil
		and hitInstance:IsDescendantOf(participant.Hitboxes)
	then
		return participant
	end

	return nil
end

function TankParticipantRegistry.isArmorHitbox(instance)
	return TankParticipantRegistry.getParticipantFromArmorHitbox(instance) ~= nil
end

function TankParticipantRegistry.getArmorZoneFromHitbox(hitInstance)
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

function TankParticipantRegistry.setParticipantModelVisible(participant, isVisible)
	participant.IsActive = isVisible == true
	
	local model = TankParticipantRegistry.getParticipantPhysicalModel(participant)
	setParticipantAttributes(participant)
	assignPrimaryPart(model)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if participant.IsActive then
				if config.armorHitboxNames[descendant.Name] == true then
					descendant.CanQuery = true
					descendant.Transparency = config.ARMOR_HITBOXES_VISIBLE and config.ARMOR_HITBOX_TRANSPARENCY or 1
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

function TankParticipantRegistry.setParticipantOwner(participant, player)
	participant.OwnerPlayer = player
	participant.OwnerUserId = player.UserId
	participant.OwnerName = player.Name
	setParticipantAttributes(participant)
end

function TankParticipantRegistry.clearParticipantOwner(participant)
	participant.OwnerPlayer = nil
	participant.OwnerUserId = nil
	participant.OwnerName = nil
	participant.LastShotTime = 0
	participant.WeaponReadyAt = 0
	participant.WeaponState.LastShotTime = 0
	participant.WeaponState.WeaponReadyAt = 0
	setParticipantAttributes(participant)
end

function TankParticipantRegistry.getParticipantMaxHealth(participant)
	local maxHealth = participant.Model:GetAttribute("MaxHealth")

	if typeof(maxHealth) == "number" then
		participant.MaxHealth = maxHealth
		return maxHealth
	end

	return participant.MaxHealth
end

function TankParticipantRegistry.getParticipantHealth(participant)
	local health = participant.Model:GetAttribute("Health")

	if typeof(health) == "number" then
		participant.Health = health
		return health
	end

	return participant.Health or TankParticipantRegistry.getParticipantMaxHealth(participant)
end

function TankParticipantRegistry.setParticipantHealth(participant, health)
	participant.Health = health
	setAttributeOnParticipantModels(participant, "Health", health)
end

function TankParticipantRegistry.getParticipantIsDead(participant)
	local isDead = participant.Model:GetAttribute("IsDead") == true
	participant.IsDead = isDead
	participant.IsAlive = not isDead

	return isDead
end

function TankParticipantRegistry.setParticipantControllable(participant, isControllable)
	if participant == nil then
		return
	end

	local canControl = isControllable == true
	participant.IsControllable = canControl
	participant.CanMove = canControl
	participant.CanShoot = canControl
	setAttributeOnParticipantModels(participant, "IsControllable", participant.IsControllable)
	setAttributeOnParticipantModels(participant, "CanMove", participant.CanMove)
	setAttributeOnParticipantModels(participant, "CanShoot", participant.CanShoot)
end

function TankParticipantRegistry.setParticipantIsDead(participant, isDead)
	participant.IsDead = isDead == true
	participant.IsAlive = not participant.IsDead
	setAttributeOnParticipantModels(participant, "IsDead", participant.IsDead)
	setAttributeOnParticipantModels(participant, "IsAlive", participant.IsAlive)

	if participant.IsDead then
		TankParticipantRegistry.setParticipantControllable(participant, false)
	end
end

function TankParticipantRegistry.resetParticipantHealth(participant)
	participant.MaxHealth = participant.DefaultMaxHealth
	setAttributeOnParticipantModels(participant, "MaxHealth", participant.MaxHealth)
	TankParticipantRegistry.setParticipantHealth(participant, participant.MaxHealth)
	TankParticipantRegistry.setParticipantIsDead(participant, false)
	TankParticipantRegistry.setParticipantControllable(participant, true)
end

function TankParticipantRegistry.setParticipantMatchState(participant, participantState, matchId, opponentTankId)
	if participant == nil then
		return
	end

	participant.ParticipantState = participantState
	participant.MatchId = matchId
	participant.OpponentTankId = opponentTankId
	setAttributeOnParticipantModels(participant, "ParticipantState", participant.ParticipantState)
	setAttributeOnParticipantModels(participant, "MatchId", participant.MatchId)
	setAttributeOnParticipantModels(participant, "OpponentTankId", participant.OpponentTankId)
end

function TankParticipantRegistry.getPlayerParticipant(player)
	return playerParticipantByPlayer[player]
end

function TankParticipantRegistry.setPlayerParticipant(player, participant)
	playerParticipantByPlayer[player] = participant
end

function TankParticipantRegistry.getAvailablePlayerParticipant()
	for _, participant in ipairs(playerParticipants) do
		if participant.OwnerPlayer == nil then
			return participant
		end
	end

	return nil
end

return TankParticipantRegistry
