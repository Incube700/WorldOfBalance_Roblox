-- Runtime catalog of VFX templates that actually exist next to this ModuleScript.
-- This module never declares a template available unless a real child object is
-- present under ReplicatedStorage/Shared/Assets/VFX in the current DataModel.
-- TemplateName values in VfxConfig should refer to object names in this folder,
-- not raw asset ids. TextureId/SoundId are the fields for asset ids.

local VFX_FOLDER = script.Parent

-- Type hints only for real discovered child instances. This is not inventory.
local TYPE_BY_EXACT_TEMPLATE_NAME = {
	TankExplosionTemplate = "TankDeathExplosion",
	TankBurningTemplate = "BurningTank",
	MuzzleFlashTemplate = "MuzzleFlash",
	MuzzleBlastTemplate = "MuzzleBlast",
	SmokeTemplate = "Smoke",
	ImpactFlashTemplate = "ImpactFlash",
	ImpactSparksTemplate = "ImpactSparks",
	RicochetTemplate = "Ricochet",
}

local function inferTemplateType(templateName)
	local knownType = TYPE_BY_EXACT_TEMPLATE_NAME[templateName]

	if knownType ~= nil then
		return knownType
	end

	local lowerName = string.lower(templateName)

	if string.find(lowerName, "burn") ~= nil or string.find(lowerName, "fire") ~= nil then
		return "BurningTank"
	elseif string.find(lowerName, "explosion") ~= nil then
		return "TankDeathExplosion"
	elseif string.find(lowerName, "ricochet") ~= nil then
		return "Ricochet"
	elseif string.find(lowerName, "spark") ~= nil or string.find(lowerName, "impact") ~= nil then
		return "Impact"
	elseif string.find(lowerName, "smoke") ~= nil then
		return "Smoke"
	elseif string.find(lowerName, "muzzle") ~= nil then
		return "Muzzle"
	end

	return "Unknown"
end

local function isTemplateInstance(instance)
	if instance == script then
		return false
	end

	if not instance.Archivable then
		return false
	end

	return instance:IsA("Folder")
		or instance:IsA("Model")
		or instance:IsA("BasePart")
		or instance:IsA("Attachment")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Sound")
end

local function discoverTemplates()
	local templates = {}

	for _, child in ipairs(VFX_FOLDER:GetChildren()) do
		if isTemplateInstance(child) then
			templates[child.Name] = table.freeze({
				Name = child.Name,
				Type = child:GetAttribute("VfxTemplateType")
					or child:GetAttribute("VfxType")
					or inferTemplateType(child.Name),
				Path = child:GetFullName(),
			})
		end
	end

	return table.freeze(templates)
end

local VfxTemplateCatalog = {}

function VfxTemplateCatalog.getAvailableTemplates()
	return discoverTemplates()
end

function VfxTemplateCatalog.hasTemplate(templateName)
	return discoverTemplates()[templateName] ~= nil
end

function VfxTemplateCatalog.getTemplateType(templateName)
	local templateInfo = discoverTemplates()[templateName]

	return templateInfo ~= nil and templateInfo.Type or nil
end

VfxTemplateCatalog.AvailableTemplates = discoverTemplates()

return table.freeze(VfxTemplateCatalog)
