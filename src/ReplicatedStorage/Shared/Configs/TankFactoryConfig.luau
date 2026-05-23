local TankFactoryConfig = {}

TankFactoryConfig.LegacyTankIds = table.freeze({
	Player = "PlayerTankPrototype",
	DuelOpponent = "Player2TankPrototype",
	Dummy = "DummyTank",
})

TankFactoryConfig.DynamicPlayerTankPrefix = "PlayerTank_"

-- BaseTankTemplate: user-created editable template in Studio.
-- Preferred home is ServerStorage.<TemplateStorageFolderName> (out of the world,
-- so it never interferes with duels/arena). TankTemplateProvider looks there
-- first, then falls back to Workspace.WOB_Generated.TestObjects.
-- If not present in either, falls back to LegacyTankIds per-role.
-- Do not create this in code; place it manually in Studio.
TankFactoryConfig.BaseTankTemplateName = "BaseTankTemplate"

-- ServerStorage folder that holds out-of-world tank prefabs.
TankFactoryConfig.TemplateStorageFolderName = "TankTemplates"

-- Documented canonical path for the base template once moved to ServerStorage.
TankFactoryConfig.FutureBaseTemplatePath = "ServerStorage.TankTemplates.BaseTankTemplate"

-- Startup static participant IDs.
-- Used for the 3 scene-level static participants (IsActive=false) created at server start.
-- Names intentionally do NOT match legacy prototype names so TankFactory
-- selects BaseTankTemplate (or role-specific legacy fallback) via GetTemplateForRole
-- instead of finding the raw prototype model by name.
TankFactoryConfig.StartupParticipantIds = table.freeze({
	Player  = "Startup_Player",
	Dummy   = "Startup_Dummy",
	Player2 = "Startup_Player2",
})

TankFactoryConfig.TrainingParticipantIds = table.freeze({
	Dummy = "Training_Dummy",
})

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
