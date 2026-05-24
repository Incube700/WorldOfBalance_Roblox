local ArenaUpgradeEffectApplier = {}
ArenaUpgradeEffectApplier.__index = ArenaUpgradeEffectApplier

function ArenaUpgradeEffectApplier.new(config, upgradeOfferService, tankParticipantRegistry)
	return setmetatable({
		_config = config or {},
		_upgradeOfferService = upgradeOfferService,
		_tankParticipantRegistry = tankParticipantRegistry,
	}, ArenaUpgradeEffectApplier)
end

local function setAttributeOnParticipantModels(tankParticipantRegistry, participant, attributeName, value)
	if participant == nil then
		return
	end

	local physicalModel = tankParticipantRegistry.getParticipantPhysicalModel(participant)

	if participant.Model ~= nil then
		participant.Model:SetAttribute(attributeName, value)
	end

	if physicalModel ~= nil and physicalModel ~= participant.Model then
		physicalModel:SetAttribute(attributeName, value)
	end
end

local function setArenaModifier(tankParticipantRegistry, participant, attributeName, value)
	if participant == nil then
		return
	end

	participant[attributeName] = value
	setAttributeOnParticipantModels(tankParticipantRegistry, participant, attributeName, value)
end

function ArenaUpgradeEffectApplier:GetReflectShieldConfig()
	return self._config.ReflectShield or {}
end

function ArenaUpgradeEffectApplier:GetReflectShieldMaxCharges()
	return math.max(0, math.floor(tonumber(self:GetReflectShieldConfig().MaxCharges) or 3))
end

function ArenaUpgradeEffectApplier:ResetParticipantArenaModifiers(participant)
	if participant == nil then
		return
	end

	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaDamageMultiplier", 1)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaFireRateMultiplier", 1)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaMoveSpeedMultiplier", 1)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaProjectileCount", 1)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaSpreadDegrees", 0)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaDoubleShotLateralOffset", 0)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaRicochetBonus", 0)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaUpgradeIds", "")
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaReflectShieldCharges", 0)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaSpawnShieldUntil", 0)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaShieldActive", false)
end

function ArenaUpgradeEffectApplier:ApplySessionUpgrades(session)
	if session == nil then
		return false
	end

	local participant = session.Participant
	local damageStacks = self._upgradeOfferService:CountUpgradeStacks(session, "DamageUp")
	local moveSpeedStacks = self._upgradeOfferService:CountUpgradeStacks(session, "MoveSpeedUp")
	local damageStep = (tonumber(self._config.DamageUpMultiplier) or 1.2) - 1
	local moveSpeedStep = (tonumber(self._config.MoveSpeedMultiplier) or 1.1) - 1

	session.DamageMultiplier = 1 + damageStep * damageStacks
	session.FireRateMultiplier = self._upgradeOfferService:HasUpgrade(session, "FireRateUp")
			and self._config.FireRateMultiplier
		or 1
	session.MoveSpeedMultiplier = 1 + moveSpeedStep * moveSpeedStacks
	session.RicochetBonus = self._upgradeOfferService:HasUpgrade(session, "RicochetUp")
			and (tonumber(self._config.RicochetUpBonus) or 1)
		or 0

	if self._upgradeOfferService:HasUpgrade(session, "TripleSpread") then
		session.ProjectileCount = 3
		session.SpreadDegrees = self._config.MultiShotSpreadDegrees
		session.DoubleShotLateralOffset = 0
	elseif self._upgradeOfferService:HasUpgrade(session, "DoubleShot") then
		session.ProjectileCount = 2
		session.SpreadDegrees = 0
		session.DoubleShotLateralOffset = self._config.DoubleShotLateralOffset
	else
		session.ProjectileCount = 1
		session.SpreadDegrees = 0
		session.DoubleShotLateralOffset = 0
	end

	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaDamageMultiplier", session.DamageMultiplier)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaFireRateMultiplier", session.FireRateMultiplier)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaMoveSpeedMultiplier", session.MoveSpeedMultiplier)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaProjectileCount", session.ProjectileCount)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaSpreadDegrees", session.SpreadDegrees)
	setArenaModifier(
		self._tankParticipantRegistry,
		participant,
		"ArenaDoubleShotLateralOffset",
		session.DoubleShotLateralOffset
	)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaRicochetBonus", session.RicochetBonus)
	setArenaModifier(
		self._tankParticipantRegistry,
		participant,
		"ArenaUpgradeIds",
		table.concat(session.UpgradeIds, ",")
	)

	if self._config.Debug == true then
		local ownerName = session.Player ~= nil
			and session.Player.Name
			or tostring(participant ~= nil and participant.TankId or "Bot")
		print("[ARENA] upgrades " .. ownerName .. " -> " .. table.concat(session.UpgradeIds, ","))
	end

	return true
end

function ArenaUpgradeEffectApplier:ApplyRepairUpgrade(session)
	if session == nil then
		return false
	end

	if session.Participant == nil then
		return true
	end

	local participant = session.Participant
	local currentHealth = self._tankParticipantRegistry.getParticipantHealth(participant)
	local maxHealth = self._tankParticipantRegistry.getParticipantMaxHealth(participant)
	local healAmount = math.max(0, tonumber(self._config.RepairHealAmount) or 30)

	self._tankParticipantRegistry.setParticipantHealth(participant, math.min(maxHealth, currentHealth + healAmount))

	return true
end

function ArenaUpgradeEffectApplier:GrantReflectShieldUpgradeCharge(session)
	if session == nil then
		return false
	end

	local grantCharges = math.max(0, math.floor(tonumber(self:GetReflectShieldConfig().UpgradeGrantCharges) or 1))

	session.ReflectShieldCharges = math.clamp(
		(tonumber(session.ReflectShieldCharges) or 0) + grantCharges,
		0,
		self:GetReflectShieldMaxCharges()
	)

	return true
end

function ArenaUpgradeEffectApplier:ApplyChosenUpgrade(session, upgradeId)
	if session == nil or typeof(upgradeId) ~= "string" then
		return false
	end

	if upgradeId == "Repair" then
		return self:ApplyRepairUpgrade(session)
	end

	table.insert(session.UpgradeIds, upgradeId)

	if upgradeId == "ReflectShield" then
		self:GrantReflectShieldUpgradeCharge(session)
	end

	return self:ApplySessionUpgrades(session)
end

return ArenaUpgradeEffectApplier
