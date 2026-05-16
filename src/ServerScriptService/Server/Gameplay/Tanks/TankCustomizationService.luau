local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local SkinCatalog = require(configs:WaitForChild("SkinCatalog"))

local TankCustomizationService = {}

local BODY_VISUAL_NAMES = {
	BodyVisual = true,
	HullVisual = true,
	Hull = true,
	TrackLeft = true,
	TrackRight = true,
	Tracks = true,
}

local TURRET_VISUAL_NAMES = {
	TurretVisual = true,
	TurretMesh = true,
}

local BARREL_VISUAL_NAMES = {
	BarrelVisual = true,
	BarrelMesh = true,
}

local FALLBACK_GAMEPLAY_PARTS = {
	Body = "BodyColor",
	Turret = "TurretColor",
	Barrel = "BarrelColor",
}

local function findBasePart(model, partName)
	if model == nil then
		return nil
	end

	local child = model:FindFirstChild(partName)

	if child ~= nil and child:IsA("BasePart") then
		return child
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function applyPartVisual(part, color, material)
	if part == nil or not part:IsA("BasePart") then
		return
	end

	if typeof(color) == "Color3" then
		part.Color = color
	end

	if typeof(material) == "EnumItem" and material.EnumType == Enum.Material then
		part.Material = material
	end
end

function TankCustomizationService.getSkin(skinId)
	local skins = SkinCatalog.Skins or {}
	local defaultSkinId = SkinCatalog.DefaultSkinId or "Default"

	if skinId ~= nil and skins[skinId] ~= nil then
		return skins[skinId], skinId
	end

	return skins[defaultSkinId], defaultSkinId
end

local function getVisualColorKey(partName)
	if BODY_VISUAL_NAMES[partName] == true then
		return "BodyColor"
	elseif TURRET_VISUAL_NAMES[partName] == true then
		return "TurretColor"
	elseif BARREL_VISUAL_NAMES[partName] == true then
		return "BarrelColor"
	end

	return "BodyColor"
end

local function applySkinToVisualFolder(visual, skin)
	local applied = false

	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local colorKey = getVisualColorKey(descendant.Name)
			applyPartVisual(descendant, skin[colorKey], skin.Material)
			applied = true
		end
	end

	return applied
end

local function applySkinToFallbackParts(model, skin)
	for partName, colorKey in pairs(FALLBACK_GAMEPLAY_PARTS) do
		local part = findBasePart(model, partName)
		applyPartVisual(part, skin[colorKey], skin.Material)
	end
end

function TankCustomizationService.applySkin(model, skinId)
	if model == nil or not model:IsA("Model") then
		return false
	end

	local skin, resolvedSkinId = TankCustomizationService.getSkin(skinId)

	if skin == nil then
		return false
	end

	local visual = model:FindFirstChild("Visual")

	if visual ~= nil and applySkinToVisualFolder(visual, skin) then
		model:SetAttribute("SkinId", resolvedSkinId)
		return true
	end

	applySkinToFallbackParts(model, skin)
	model:SetAttribute("SkinId", resolvedSkinId)
	return true
end

function TankCustomizationService.applyDefaultSkin(model)
	return TankCustomizationService.applySkin(model, SkinCatalog.DefaultSkinId)
end

return TankCustomizationService
