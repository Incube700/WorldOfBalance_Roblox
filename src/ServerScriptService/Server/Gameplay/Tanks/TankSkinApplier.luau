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

local TankSkinApplier = {}

-- Default skin visual configuration.
-- Extend this table to add more skins; do not change stats/armor here.
local SKIN_CONFIGS = {
	Default = {
		BodyColor    = Color3.fromRGB(55, 185, 255),
		TurretColor  = Color3.fromRGB(80, 220, 160),
		BarrelColor  = Color3.fromRGB(35, 40, 42),
		Material     = Enum.Material.SmoothPlastic,
	},
}

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

local function applyColor(part, skinConfig)
	if part == nil or not part:IsA("BasePart") then
		return
	end

	local colorKey = VISUAL_PART_COLOR_MAP[part.Name]

	if colorKey ~= nil and skinConfig[colorKey] ~= nil then
		part.Color = skinConfig[colorKey]
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
			applyColor(child, skinConfig)
		end
	end
end

local function findVisualsFolder(tankModel)
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

	local skinConfig = SKIN_CONFIGS[skinId] or SKIN_CONFIGS[TankFactoryConfig.DefaultLoadout.SkinId] or SKIN_CONFIGS.Default

	if skinConfig == nil then
		warn("[TANK SKIN APPLIER] No skin config found for SkinId=" .. tostring(skinId) .. "; skipping.")
		return
	end

	local visualsFolder = findVisualsFolder(tankModel)

	if visualsFolder ~= nil then
		processVisualsFolder(visualsFolder, skinConfig)
	end
	-- Note: if the tank has no Visuals folder (legacy prototypes), this is a no-op.
	-- TankCustomizationService.applySkin handles legacy visual parts separately.
end

return TankSkinApplier
