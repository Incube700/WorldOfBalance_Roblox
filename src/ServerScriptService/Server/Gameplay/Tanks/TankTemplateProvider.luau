local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

-- Returns the BaseTankTemplate (priority 1 for all roles). Not created by code.
-- Preferred home is ServerStorage.<TemplateStorageFolderName> so the prefab lives
-- out of the world and never interferes with duels/arena. Falls back to
-- Workspace.WOB_Generated.TestObjects so the project keeps working if the prefab
-- has not been moved yet.
function TankTemplateProvider:GetBaseTankTemplate()
	local baseName = TankFactoryConfig.BaseTankTemplateName
	local folderName = TankFactoryConfig.TemplateStorageFolderName

	if folderName ~= nil then
		local storage = ServerStorage:FindFirstChild(folderName)

		if storage ~= nil then
			local stored = storage:FindFirstChild(baseName)

			if stored ~= nil and stored:IsA("Model") then
				return stored, baseName
			end
		end
	end

	if self.TestObjectsRoot ~= nil then
		local base = self.TestObjectsRoot:FindFirstChild(baseName)

		if base ~= nil and base:IsA("Model") then
			return base, baseName
		end
	end

	return nil
end

function TankTemplateProvider:GetTemplateForRole(role)
	if self.TestObjectsRoot == nil then
		error("[TANK TEMPLATE] Missing TestObjects root for role=" .. tostring(role), 2)
	end

	-- Priority 1: BaseTankTemplate (user-placed, editable in Studio).
	-- Used for all roles when present.
	local base, baseName = self:GetBaseTankTemplate()

	if base ~= nil then
		return base, baseName
	end

	-- Priority 2+: role-specific legacy fallback chain.
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
