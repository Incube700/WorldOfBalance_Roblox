local TankParticipantRegistry = {}

local tankParticipants = {}
local tankParticipantsById = {}
local tankParticipantsByModel = {}
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

function TankParticipantRegistry.registerTankParticipant(participant)
	table.insert(tankParticipants, participant)
	tankParticipantsById[participant.TankId] = participant
	tankParticipantsByModel[participant.Model] = participant
	
	if participant.IsPlayerTank then
		table.insert(playerParticipants, participant)
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
	return tankParticipantsByModel[model]
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
	
	local model = participant.Model
	model:SetAttribute("TankId", participant.TankId)
	model:SetAttribute("IsActive", participant.IsActive)
	model:SetAttribute("TeamId", participant.TeamId)
	model:SetAttribute("IsBot", participant.IsBot)
	model:SetAttribute("IsPlayerTank", participant.IsPlayerTank == true)
	model:SetAttribute("ControllerType", participant.ControllerType)

	if participant.OwnerUserId == nil then
		model:SetAttribute("OwnerUserId", nil)
		model:SetAttribute("OwnerName", nil)
	else
		model:SetAttribute("OwnerUserId", participant.OwnerUserId)
		model:SetAttribute("OwnerName", participant.OwnerName)
	end

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
	participant.Model:SetAttribute("TankId", participant.TankId)
	participant.Model:SetAttribute("OwnerUserId", player.UserId)
	participant.Model:SetAttribute("OwnerName", player.Name)
	participant.Model:SetAttribute("TeamId", participant.TeamId)
	participant.Model:SetAttribute("IsBot", participant.IsBot)
	participant.Model:SetAttribute("IsPlayerTank", participant.IsPlayerTank == true)
	participant.Model:SetAttribute("ControllerType", participant.ControllerType)
end

function TankParticipantRegistry.clearParticipantOwner(participant)
	participant.OwnerPlayer = nil
	participant.OwnerUserId = nil
	participant.LastShotTime = 0
	participant.WeaponReadyAt = 0
	participant.WeaponState.LastShotTime = 0
	participant.WeaponState.WeaponReadyAt = 0
	participant.Model:SetAttribute("OwnerUserId", nil)
	participant.Model:SetAttribute("OwnerName", nil)
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
	participant.Model:SetAttribute("Health", health)
end

function TankParticipantRegistry.getParticipantIsDead(participant)
	local isDead = participant.Model:GetAttribute("IsDead") == true
	participant.IsDead = isDead

	return isDead
end

function TankParticipantRegistry.setParticipantIsDead(participant, isDead)
	participant.IsDead = isDead == true
	participant.Model:SetAttribute("IsDead", participant.IsDead)
end

function TankParticipantRegistry.resetParticipantHealth(participant)
	participant.MaxHealth = participant.DefaultMaxHealth
	participant.Model:SetAttribute("MaxHealth", participant.MaxHealth)
	TankParticipantRegistry.setParticipantHealth(participant, participant.MaxHealth)
	TankParticipantRegistry.setParticipantIsDead(participant, false)
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
