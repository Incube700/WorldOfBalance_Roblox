local TankFactoryConfig = {}

TankFactoryConfig.LegacyTankIds = table.freeze({
	Player = "PlayerTankPrototype",
	DuelOpponent = "Player2TankPrototype",
	Dummy = "DummyTank",
})

TankFactoryConfig.DynamicPlayerTankPrefix = "PlayerTank_"
TankFactoryConfig.FutureBaseTemplatePath = "ServerStorage.TankTemplates.BaseTankTemplate"

TankFactoryConfig.DefaultLoadout = table.freeze({
	SkinId = "Default",
	WeaponId = "PrototypeCannon",
	UpgradeLevels = table.freeze({}),
})

TankFactoryConfig.DefaultStats = table.freeze({
	MaxHealth = 100,
	Health = 100,
})

function TankFactoryConfig.GetDynamicPlayerTankId(playerOrUserId)
	local userId = playerOrUserId

	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		userId = playerOrUserId.UserId
	end

	return TankFactoryConfig.DynamicPlayerTankPrefix .. tostring(userId)
end

return table.freeze(TankFactoryConfig)
