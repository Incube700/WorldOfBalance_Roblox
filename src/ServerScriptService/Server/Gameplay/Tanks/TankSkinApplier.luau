-- TankSkinApplier
-- Applies a visual skin to a tank model after clone/reuse.
-- Responsibilities:
--   - Configure parts inside the Visuals folder (CanQuery=false, CanCollide=false, etc.)
--   - Apply base color/material to visual parts for the requested SkinId.
--   - Does NOT touch armor stats, armor zone sizes, collision on Body, or gameplay logic.
--
-- Called by TankFactory after clone:
--   TankSkinApplier.Apply(tankModel, loadout)
--
-- Future skins: add new SkinId entries to SKIN_CONFIGS below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankFactoryConfig = require(configs:WaitForChild("TankFactoryConfig"))
local SkinCatalog = require(configs:WaitForChild("SkinCatalog"))

local TankSkinApplier = {}
local findVisualsFolder

-- Part name → which skin color key to use.
local VISUAL_PART_COLOR_MAP = {
	BodyVisual    = "BodyColor",
	HullVisual    = "BodyColor",
	TrackLeft     = "BodyColor",
	TrackRight    = "BodyColor",
	Tracks        = "BodyColor",
	TurretVisual  = "TurretColor",
	TurretMesh    = "TurretColor",
	BarrelVisual  = "BarrelColor",
	BarrelMesh    = "BarrelColor",
}

local VISUAL_WELD_NAME = "WOBVisualFollowWeld"
local VISUAL_OFFSET_NAME = "WOBVisualAnchorOffset"

local TURRET_KEYWORDS = {
	"turret",
	"cupola",
	"mantlet",
	"hatch",
	"barrel",
	"cannon",
	"gun",
	"muzzle",
}

local BARREL_KEYWORDS = {
	"barrel",
	"cannon",
	"gun",
	"muzzle",
}

local BODY_KEYWORDS = {
	"body",
	"hull",
	"track",
	"tread",
	"wheel",
	"visual",
}

local function getLowerNameLine(instance, stopAt)
	local names = {}
	local current = instance

	while current ~= nil and current ~= stopAt do
		table.insert(names, string.lower(current.Name))
		current = current.Parent
	end

	return table.concat(names, " ")
end

local function containsAnyKeyword(text, keywords)
	for _, keyword in ipairs(keywords) do
		if string.find(text, keyword, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function getVisualColorKey(part, visualsFolder)
	local exactColorKey = VISUAL_PART_COLOR_MAP[part.Name]

	if exactColorKey ~= nil then
		return exactColorKey
	end

	local nameLine = getLowerNameLine(part, visualsFolder)

	if containsAnyKeyword(nameLine, BARREL_KEYWORDS) then
		return "BarrelColor"
	end

	if containsAnyKeyword(nameLine, TURRET_KEYWORDS) then
		return "TurretColor"
	end

	if containsAnyKeyword(nameLine, BODY_KEYWORDS) then
		return "BodyColor"
	end

	return "BodyColor"
end

local function colorToVertexColor(color)
	return Vector3.new(color.R, color.G, color.B)
end

local function applyVisualsProperties(part)
	if part == nil or not part:IsA("BasePart") then
		return
	end

	-- Visual parts must never block projectile raycasts or physical collision.
	part.CanCollide  = false
	part.CanTouch    = false
	part.CanQuery    = false
	part.Massless    = true
	part.Anchored    = false
	part.CastShadow  = false
end

local function applyColor(part, skinConfig, visualsFolder)
	if part == nil or not part:IsA("BasePart") then
		return
	end

	local colorKey = getVisualColorKey(part, visualsFolder)
	local skinColor = skinConfig[colorKey]

	if skinColor ~= nil then
		part.Color = skinColor

		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("SpecialMesh") then
				child.VertexColor = colorToVertexColor(skinColor)
			end
		end
	end

	if skinConfig.Material ~= nil then
		pcall(function()
			part.Material = skinConfig.Material
		end)
	end
end

local function processVisualsFolder(visualsFolder, skinConfig)
	if visualsFolder == nil then
		return
	end

	for _, child in ipairs(visualsFolder:GetDescendants()) do
		if child:IsA("BasePart") then
			applyVisualsProperties(child)
			applyColor(child, skinConfig, visualsFolder)
		end
	end
end

local function findGameplayPart(tankModel, name)
	local part = tankModel:FindFirstChild(name, true)

	if part ~= nil and part:IsA("BasePart") then
		return part
	end

	return nil
end

local function getVisualAnchorPart(tankModel, visualsFolder, visualPart)
	local nameLine = getLowerNameLine(visualPart, visualsFolder)

	if containsAnyKeyword(nameLine, TURRET_KEYWORDS) then
		return findGameplayPart(tankModel, "Turret"), "Turret"
	end

	return findGameplayPart(tankModel, "Body"), "Body"
end

local function removeVisualWelds(visualPart)
	for _, child in ipairs(visualPart:GetChildren()) do
		if child:IsA("WeldConstraint") and child.Name == VISUAL_WELD_NAME then
			child:Destroy()
		end
	end
end

local function getOrCreateOffset(visualPart, anchorPart)
	local offsetValue = visualPart:FindFirstChild(VISUAL_OFFSET_NAME)

	if offsetValue ~= nil and not offsetValue:IsA("CFrameValue") then
		offsetValue:Destroy()
		offsetValue = nil
	end

	if offsetValue == nil then
		offsetValue = Instance.new("CFrameValue")
		offsetValue.Name = VISUAL_OFFSET_NAME
		offsetValue.Value = anchorPart.CFrame:ToObjectSpace(visualPart.CFrame)
		offsetValue.Parent = visualPart
	end

	return offsetValue
end

local function pinVisualPart(tankModel, visualsFolder, visualPart)
	local anchorPart, anchorName = getVisualAnchorPart(tankModel, visualsFolder, visualPart)

	if anchorPart == nil or anchorPart == visualPart then
		return
	end

	local previousAnchorName = visualPart:GetAttribute("WOBVisualAnchorName")
	local offsetValue = getOrCreateOffset(visualPart, anchorPart)

	if previousAnchorName ~= nil and previousAnchorName ~= anchorName then
		offsetValue.Value = anchorPart.CFrame:ToObjectSpace(visualPart.CFrame)
	end

	visualPart:SetAttribute("WOBVisualAnchorName", anchorName)
	visualPart.CFrame = anchorPart.CFrame * offsetValue.Value
	removeVisualWelds(visualPart)

	local weld = Instance.new("WeldConstraint")
	weld.Name = VISUAL_WELD_NAME
	weld.Part0 = anchorPart
	weld.Part1 = visualPart
	weld.Parent = visualPart
end

function TankSkinApplier.PinVisuals(tankModel)
	local visualsFolder = findVisualsFolder(tankModel)

	if visualsFolder == nil then
		return
	end

	for _, child in ipairs(visualsFolder:GetDescendants()) do
		if child:IsA("BasePart") then
			applyVisualsProperties(child)
			pinVisualPart(tankModel, visualsFolder, child)
		end
	end
end

findVisualsFolder = function(tankModel)
	if tankModel == nil then
		return nil
	end

	local direct = tankModel:FindFirstChild("Visuals")

	if direct ~= nil and direct:IsA("Folder") then
		return direct
	end

	for _, descendant in ipairs(tankModel:GetDescendants()) do
		if descendant.Name == "Visuals" and descendant:IsA("Folder") then
			return descendant
		end
	end

	return nil
end

local function getSkinConfig(skinId)
	local skins = SkinCatalog.Skins or {}
	local defaultSkinId = SkinCatalog.DefaultSkinId or TankFactoryConfig.DefaultLoadout.SkinId or "Default"
	local requestedSkin = skins[skinId]

	if requestedSkin ~= nil and typeof(requestedSkin.AliasOf) == "string" and skins[requestedSkin.AliasOf] ~= nil then
		return skins[requestedSkin.AliasOf], requestedSkin.AliasOf
	end

	if requestedSkin ~= nil then
		return requestedSkin, skinId
	end

	return skins[defaultSkinId] or skins.Default, defaultSkinId
end

-- Apply skin to the tank model.
-- loadout: table with optional SkinId field.
-- Falls back to "Default" if SkinId is nil or unknown.
function TankSkinApplier.Apply(tankModel, loadout)
	if tankModel == nil then
		return
	end

	local skinId = "Default"

	if loadout ~= nil and loadout.SkinId ~= nil then
		skinId = loadout.SkinId
	end

	local skinConfig, resolvedSkinId = getSkinConfig(skinId)

	if skinConfig == nil then
		warn("[TANK SKIN APPLIER] No skin config found for SkinId=" .. tostring(skinId) .. "; skipping.")
		return
	end

	tankModel:SetAttribute("SkinId", resolvedSkinId)

	local visualsFolder = findVisualsFolder(tankModel)

	if visualsFolder ~= nil then
		processVisualsFolder(visualsFolder, skinConfig)
		TankSkinApplier.PinVisuals(tankModel)
	end
	-- Note: if the tank has no Visuals folder (legacy prototypes), this is a no-op.
	-- TankCustomizationService.applySkin handles legacy visual parts separately.
end

return TankSkinApplier
