local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TankFactoryConfig = require(configs:WaitForChild("TankFactoryConfig"))

local TankRole = require(script.Parent:WaitForChild("TankRole"))

local TankTemplateProvider = {}
TankTemplateProvider.__index = TankTemplateProvider

local TEMPLATE_NAMES_BY_ROLE = table.freeze({
	[TankRole.Player] = table.freeze({ TankFactoryConfig.LegacyTankIds.Player }),
	[TankRole.ArenaPlayer] = table.freeze({ TankFactoryConfig.LegacyTankIds.Player }),
	[TankRole.DuelOpponent] = table.freeze({
		TankFactoryConfig.LegacyTankIds.DuelOpponent,
		TankFactoryConfig.LegacyTankIds.Player,
	}),
	[TankRole.Dummy] = table.freeze({
		TankFactoryConfig.LegacyTankIds.Dummy,
		TankFactoryConfig.LegacyTankIds.Player,
	}),
	[TankRole.Bot] = table.freeze({
		TankFactoryConfig.LegacyTankIds.DuelOpponent,
		TankFactoryConfig.LegacyTankIds.Player,
	}),
	[TankRole.ArenaBot] = table.freeze({
		TankFactoryConfig.LegacyTankIds.DuelOpponent,
		TankFactoryConfig.LegacyTankIds.Player,
	}),
})

function TankTemplateProvider.new(testObjectsRoot)
	return setmetatable({
		TestObjectsRoot = testObjectsRoot,
	}, TankTemplateProvider)
end

function TankTemplateProvider:GetLegacyTankIdForRole(role)
	if role == TankRole.DuelOpponent then
		return TankFactoryConfig.LegacyTankIds.DuelOpponent
	elseif role == TankRole.Dummy then
		return TankFactoryConfig.LegacyTankIds.Dummy
	end

	return TankFactoryConfig.LegacyTankIds.Player
end

function TankTemplateProvider:GetTemplateForRole(role)
	if self.TestObjectsRoot == nil then
		error("[TANK TEMPLATE] Missing TestObjects root for role=" .. tostring(role), 2)
	end

	local templateNames = TEMPLATE_NAMES_BY_ROLE[role] or TEMPLATE_NAMES_BY_ROLE[TankRole.Player]

	for _, templateName in ipairs(templateNames) do
		local template = self.TestObjectsRoot:FindFirstChild(templateName)

		if template ~= nil and template:IsA("Model") then
			return template, templateName
		end
	end

	error("[TANK TEMPLATE] No usable tank template for role=" .. tostring(role), 2)
end

return TankTemplateProvider
