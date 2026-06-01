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
	-- Etap 1 new modifiers.
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaPierceEnemies", 0)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaLifestealPerKill", 0)
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
	local offer = self._upgradeOfferService
	local damageStacks = offer:CountUpgradeStacks(session, "DamageUp")
	local moveSpeedStacks = offer:CountUpgradeStacks(session, "MoveSpeedUp")
	local fireRateStacks = offer:CountUpgradeStacks(session, "FireRateUp")
	local ricochetStacks = offer:CountUpgradeStacks(session, "RicochetUp")
	local overchargeStacks = offer:CountUpgradeStacks(session, "Overcharge")
	local piercingStacks = offer:CountUpgradeStacks(session, "Piercing")
	local lifestealStacks = offer:CountUpgradeStacks(session, "Lifesteal")

	local damageStep = (tonumber(self._config.DamageUpMultiplier) or 1.2) - 1
	local moveSpeedStep = (tonumber(self._config.MoveSpeedMultiplier) or 1.1) - 1
	-- FireRateMultiplier is a per-stack COOLDOWN multiplier (<1 = faster). Multiplying it per
	-- stack compounds the speed-up; Overcharge adds a per-stack penalty multiplier (>1 = slower).
	local fireRatePerStack = tonumber(self._config.FireRateMultiplier) or 0.88
	local overchargeDamageBonus = tonumber(self._config.OverchargeDamageBonus) or 0.18
	local overchargeFirePenalty = tonumber(self._config.OverchargeFireRatePenalty) or 0.12
	local pierceePerStack = math.max(0, math.floor(tonumber(self._config.PiercingEnemiesPerStack) or 1))
	local lifestealPerStack = math.max(0, tonumber(self._config.LifestealHealPerKill) or 0)

	-- Damage: DamageUp stacks + Overcharge bonus (additive).
	session.DamageMultiplier = 1 + damageStep * damageStacks + overchargeDamageBonus * overchargeStacks

	-- Fire rate cooldown: faster per FireRateUp stack, slower per Overcharge stack.
	local cooldownMultiplier = (fireRatePerStack ^ fireRateStacks) * ((1 + overchargeFirePenalty) ^ overchargeStacks)
	session.FireRateMultiplier = math.clamp(cooldownMultiplier, 0.2, 3)

	session.MoveSpeedMultiplier = 1 + moveSpeedStep * moveSpeedStacks
	session.RicochetBonus = (tonumber(self._config.RicochetUpBonus) or 1) * ricochetStacks
	session.PierceEnemies = pierceePerStack * piercingStacks
	session.LifestealPerKill = lifestealPerStack * lifestealStacks

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
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaPierceEnemies", session.PierceEnemies)
	setArenaModifier(self._tankParticipantRegistry, participant, "ArenaLifestealPerKill", session.LifestealPerKill)
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
