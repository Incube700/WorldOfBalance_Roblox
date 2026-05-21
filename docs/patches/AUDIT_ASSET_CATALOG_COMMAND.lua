-- Audit-only command. Run in Roblox Studio Command Bar outside Play Mode.
-- This script does not Destroy, Move, Clone, or reparent anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function logInfo(message)
	print("[ASSET CATALOG AUDIT] " .. message)
end

local function logWarning(message)
	warn("[ASSET CATALOG WARNING] " .. message)
end

local function getChild(parent, childName)
	if parent == nil then
		return nil
	end

	return parent:FindFirstChild(childName)
end

local shared = getChild(ReplicatedStorage, "Shared")
local configs = getChild(shared, "Configs")
local assets = getChild(shared, "Assets")
local vfxFolder = getChild(assets, "VFX")

if shared == nil then
	logWarning("ReplicatedStorage.Shared is missing.")
	return
end

if configs == nil then
	logWarning("ReplicatedStorage.Shared.Configs is missing.")
	return
end

if vfxFolder == nil then
	logWarning("ReplicatedStorage.Shared.Assets.VFX is missing.")
	return
end

local cosmeticCatalog = require(configs:WaitForChild("CosmeticCatalog"))
local vfxConfig = require(configs:WaitForChild("VfxConfig"))
local vfxTemplateCatalog = require(vfxFolder:WaitForChild("VfxTemplateCatalog"))

local function hasTemplate(templateName)
	if type(templateName) ~= "string" or templateName == "" then
		return false
	end

	if vfxTemplateCatalog.hasTemplate ~= nil then
		return vfxTemplateCatalog.hasTemplate(templateName)
	end

	return vfxFolder:FindFirstChild(templateName) ~= nil
end

local cosmeticItemCount = 0
local cosmeticWarningCount = 0

for itemId, item in pairs(cosmeticCatalog.Items or {}) do
	cosmeticItemCount += 1

	local templateName = item.TemplateName

	if type(templateName) == "string" and templateName ~= "" and not hasTemplate(templateName) then
		if item.MissingTemplate == true then
			logInfo("Cosmetic item " .. tostring(itemId) .. " references planned missing template " .. templateName .. ".")
		else
			cosmeticWarningCount += 1
			logWarning("Cosmetic item " .. tostring(itemId) .. " references missing template " .. templateName .. ".")
		end
	end
end

local vfxTemplateCount = 0
local vfxWarningCount = 0

local function isOptionalTemplateConfig(config)
	if type(config) ~= "table" then
		return false
	end

	return config.WarnIfMissingTemplate == false
		or config.UseProceduralFallback == true
		or config.UseImpactFallback == true
		or config.UseFlashFallback == true
		or config.TemplateFallbackNames ~= nil
end

local function auditVfxConfigTable(path, value)
	if type(value) ~= "table" then
		return
	end

	local templateName = value.TemplateName

	if type(templateName) == "string" and templateName ~= "" then
		vfxTemplateCount += 1

		if not hasTemplate(templateName) then
			local message = path .. ".TemplateName references missing template " .. templateName .. "."

			if isOptionalTemplateConfig(value) then
				logInfo(message .. " Fallback/optional config is present.")
			else
				vfxWarningCount += 1
				logWarning(message)
			end
		end
	end

	for key, child in pairs(value) do
		if type(child) == "table" then
			auditVfxConfigTable(path .. "." .. tostring(key), child)
		end
	end
end

auditVfxConfigTable("VfxConfig", vfxConfig)

local discoveredTemplates = vfxTemplateCatalog.getAvailableTemplates ~= nil
	and vfxTemplateCatalog.getAvailableTemplates()
	or vfxTemplateCatalog.AvailableTemplates
	or {}

local discoveredCount = 0

for templateName, templateInfo in pairs(discoveredTemplates) do
	discoveredCount += 1
	logInfo(
		"Template "
			.. tostring(templateName)
			.. " type="
			.. tostring(templateInfo.Type or "Unknown")
			.. " path="
			.. tostring(templateInfo.Path or "unknown")
	)
end

logInfo("Cosmetic items checked: " .. cosmeticItemCount .. "; warnings: " .. cosmeticWarningCount .. ".")
logInfo("VfxConfig template refs checked: " .. vfxTemplateCount .. "; warnings: " .. vfxWarningCount .. ".")
logInfo("Discovered VFX templates: " .. discoveredCount .. ".")
