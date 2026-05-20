local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local DebugCombatConfig = require(configs:WaitForChild("DebugCombatConfig"))
local TankConfig = require(configs:WaitForChild("TankConfig"))

local TankArmorPartsService = {}

local ARMOR_PART_NAMES = table.freeze({
	"FrontArmor",
	"RearArmor",
	"LeftArmor",
	"RightArmor",
})

local ARMOR_ZONE_BY_PART = table.freeze({
	FrontArmor = "Front",
	RearArmor = "Rear",
	LeftArmor = "Side",
	RightArmor = "Side",
})

local TANK_ARMOR = TankConfig.Armor or {}
local ARMOR_HITBOX_PADDING = TANK_ARMOR.ArmorHitboxPadding or 0.75
local ARMOR_HITBOX_THICKNESS = TANK_ARMOR.ArmorHitboxThickness or 1.2
local ARMOR_HITBOX_HEIGHT = TANK_ARMOR.ArmorHitboxHeight or 5.4
local ARMOR_HITBOX_Y_OFFSET = TANK_ARMOR.ArmorHitboxYOffset or 1.4
local ARMOR_HITBOX_TRANSPARENCY = TANK_ARMOR.ArmorHitboxTransparency or 0.4
local ARMOR_HITBOX_MATERIAL = TANK_ARMOR.ArmorHitboxMaterial or Enum.Material.SmoothPlastic
local FRONT_ARMOR_COLOR = TANK_ARMOR.FrontArmorColor or Color3.fromRGB(80, 255, 120)
local REAR_ARMOR_COLOR = TANK_ARMOR.RearArmorColor or Color3.fromRGB(255, 90, 90)
local SIDE_ARMOR_COLOR = TANK_ARMOR.SideArmorColor or Color3.fromRGB(255, 220, 80)

local resolvedArmorHitboxMaterial = nil

local function findBasePart(model, partName)
	if model == nil then
		return nil
	end

	local directChild = model:FindFirstChild(partName)

	if directChild ~= nil and directChild:IsA("BasePart") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function findStableBodyPart(model)
	return findBasePart(model, "Body")
		or findBasePart(model, "Hull")
		or (model ~= nil and model.PrimaryPart or nil)
end

local function findHitboxesFolder(model)
	if model == nil then
		return nil
	end

	local directChild = model:FindFirstChild("Hitboxes")

	if directChild ~= nil and directChild:IsA("Folder") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == "Hitboxes" and descendant:IsA("Folder") then
			return descendant
		end
	end

	return nil
end

local function getArmorHitboxMaterial()
	if resolvedArmorHitboxMaterial ~= nil then
		return resolvedArmorHitboxMaterial
	end

	if typeof(ARMOR_HITBOX_MATERIAL) == "EnumItem"
		and ARMOR_HITBOX_MATERIAL.EnumType == Enum.Material
	then
		resolvedArmorHitboxMaterial = ARMOR_HITBOX_MATERIAL
		return resolvedArmorHitboxMaterial
	end

	if typeof(ARMOR_HITBOX_MATERIAL) == "string" then
		local success, material = pcall(function()
			return Enum.Material[ARMOR_HITBOX_MATERIAL]
		end)

		if success and material ~= nil then
			resolvedArmorHitboxMaterial = material
			return resolvedArmorHitboxMaterial
		end
	end

	resolvedArmorHitboxMaterial = Enum.Material.SmoothPlastic
	return resolvedArmorHitboxMaterial
end

local function shouldShowDebugArmor()
	return DebugCombatConfig.ArmorDebugVisuals == true or TANK_ARMOR.ArmorHitboxesVisible == true
end

local function getArmorSpec(body, armorPartName)
	local frontRearSize = Vector3.new(
		body.Size.X + ARMOR_HITBOX_PADDING * 2,
		ARMOR_HITBOX_HEIGHT,
		ARMOR_HITBOX_THICKNESS
	)
	local sideSize = Vector3.new(
		ARMOR_HITBOX_THICKNESS,
		ARMOR_HITBOX_HEIGHT,
		body.Size.Z + ARMOR_HITBOX_PADDING * 2
	)
	local frontZ = -(body.Size.Z * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5)
	local rearZ = body.Size.Z * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5
	local leftX = -(body.Size.X * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5)
	local rightX = body.Size.X * 0.5 + ARMOR_HITBOX_THICKNESS * 0.5

	if armorPartName == "FrontArmor" then
		return frontRearSize, CFrame.new(0, ARMOR_HITBOX_Y_OFFSET, frontZ), FRONT_ARMOR_COLOR
	elseif armorPartName == "RearArmor" then
		return frontRearSize, CFrame.new(0, ARMOR_HITBOX_Y_OFFSET, rearZ), REAR_ARMOR_COLOR
	elseif armorPartName == "LeftArmor" then
		return sideSize, CFrame.new(leftX, ARMOR_HITBOX_Y_OFFSET, 0), SIDE_ARMOR_COLOR
	elseif armorPartName == "RightArmor" then
		return sideSize, CFrame.new(rightX, ARMOR_HITBOX_Y_OFFSET, 0), SIDE_ARMOR_COLOR
	end

	return nil, nil, nil
end

local function getOrCreateBodyWeld(body, armorPart)
	local weld = armorPart:FindFirstChild("WOBArmorBodyWeld")

	if weld ~= nil and not weld:IsA("WeldConstraint") then
		weld:Destroy()
		weld = nil
	end

	if weld ~= nil and (weld.Part0 ~= body or weld.Part1 ~= armorPart) then
		weld:Destroy()
		weld = nil
	end

	if weld == nil then
		weld = Instance.new("WeldConstraint")
		weld.Name = "WOBArmorBodyWeld"
		weld.Part0 = body
		weld.Part1 = armorPart
		weld.Parent = armorPart
	end

	return weld
end

local function configureArmorPart(body, armorPart)
	if armorPart == nil or not armorPart:IsA("BasePart") then
		return false
	end

	local size, localOffset, color = getArmorSpec(body, armorPart.Name)

	if size == nil then
		return false
	end

	local weld = armorPart:FindFirstChild("WOBArmorBodyWeld")
	local needsPoseRefresh = weld == nil
		or armorPart:GetAttribute("WOBArmorConfigured") ~= true
		or armorPart:GetAttribute("WOBArmorBodyName") ~= body.Name

	armorPart.Size = size

	if needsPoseRefresh then
		armorPart.CFrame = body.CFrame * localOffset
	end

	armorPart.Anchored = false
	armorPart.Massless = true
	armorPart.CanCollide = false
	armorPart.CanTouch = false
	armorPart.CanQuery = true
	armorPart.CastShadow = false
	armorPart.Material = getArmorHitboxMaterial()
	armorPart.Color = color
	armorPart.Transparency = shouldShowDebugArmor() and ARMOR_HITBOX_TRANSPARENCY or 1
	armorPart:SetAttribute("WOBArmorHitbox", true)
	armorPart:SetAttribute("ArmorZone", ARMOR_ZONE_BY_PART[armorPart.Name])
	armorPart:SetAttribute("WOBArmorConfigured", true)
	armorPart:SetAttribute("WOBArmorBodyName", body.Name)

	getOrCreateBodyWeld(body, armorPart)

	return true
end

function TankArmorPartsService.Configure(tankModel)
	local body = findStableBodyPart(tankModel)
	local hitboxes = findHitboxesFolder(tankModel)

	if body == nil or hitboxes == nil then
		return false
	end

	local configuredCount = 0

	for _, armorPartName in ipairs(ARMOR_PART_NAMES) do
		local armorPart = hitboxes:FindFirstChild(armorPartName)

		if configureArmorPart(body, armorPart) then
			configuredCount += 1
		end
	end

	return configuredCount > 0
end

return TankArmorPartsService
