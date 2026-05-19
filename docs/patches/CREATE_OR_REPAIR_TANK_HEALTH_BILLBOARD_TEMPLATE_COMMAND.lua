-- Run this in Studio Command Bar outside Play Mode.
-- Creates or repairs ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TEMPLATE_NAME = "TankHealthBillboard"

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		error(parent:GetFullName() .. "." .. name .. " exists but is " .. folder.ClassName .. ", expected Folder")
	end

	return folder
end

local function sanitize(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
			or descendant:IsA("ClickDetector")
		then
			print("[WOB] Removing unsafe descendant from HP billboard template:", descendant:GetFullName())
			descendant:Destroy()
		end
	end
end

local function getOrCreateDirectChild(parent, name, className)
	local child = parent:FindFirstChild(name)

	if child ~= nil and child.ClassName ~= className then
		print("[WOB] Replacing", child:GetFullName(), "class", child.ClassName, "with", className)
		child:Destroy()
		child = nil
	end

	if child == nil then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end

	return child
end

local function addOrRepairCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner")

	if corner == nil then
		corner = Instance.new("UICorner")
		corner.Parent = parent
	end

	corner.CornerRadius = radius
end

local function addOrRepairStroke(parent, color, transparency, thickness)
	local stroke = parent:FindFirstChildOfClass("UIStroke")

	if stroke == nil then
		stroke = Instance.new("UIStroke")
		stroke.Parent = parent
	end

	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
end

local function styleText(label, text, textSize, color)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.45
	label.TextWrapped = true
end

local function findDonorHealthBillboard()
	local donor = Workspace:FindFirstChild("Health", true)

	if donor ~= nil and donor:IsA("BillboardGui") then
		return donor
	end

	if donor ~= nil
		and donor:FindFirstChild("RedBar", true) ~= nil
		and donor:FindFirstChild("GreenBar", true) ~= nil
		and donor:FindFirstChild("PlayerName", true) ~= nil
	then
		local ancestorBillboard = donor:FindFirstAncestorWhichIsA("BillboardGui")

		if ancestorBillboard ~= nil then
			return ancestorBillboard
		end

		local childBillboard = donor:FindFirstChildWhichIsA("BillboardGui", true)

		if childBillboard ~= nil then
			return childBillboard
		end
	end

	return nil
end

local shared = getOrCreateFolder(ReplicatedStorage, "Shared")
local assets = getOrCreateFolder(shared, "Assets")
local ui = getOrCreateFolder(assets, "UI")
local donor = findDonorHealthBillboard()
local template = ui:FindFirstChild(TEMPLATE_NAME)

if template == nil and donor ~= nil then
	template = donor:Clone()
	template.Name = TEMPLATE_NAME
	template.Parent = ui
	print("[WOB] Cloned Workspace donor Health BillboardGui into", template:GetFullName())
end

if template ~= nil and not template:IsA("BillboardGui") then
	print("[WOB] Replacing", template:GetFullName(), "because it is", template.ClassName, "not BillboardGui")
	template:Destroy()
	template = nil
end

if template == nil then
	template = Instance.new("BillboardGui")
	template.Name = TEMPLATE_NAME
	template.Parent = ui
end

sanitize(template)

template.AlwaysOnTop = true
template.LightInfluence = 0
template.MaxDistance = 220
template.Size = UDim2.fromOffset(130, 38)
template.StudsOffset = Vector3.new(0, 5, 0)
template.Enabled = true

local background = getOrCreateDirectChild(template, "Background", "Frame")
background.AnchorPoint = Vector2.new(0.5, 0.5)
background.Position = UDim2.fromScale(0.5, 0.5)
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(9, 12, 15)
background.BackgroundTransparency = 0.18
background.BorderSizePixel = 0
background.ZIndex = 1
addOrRepairCorner(background, UDim.new(0, 6))
addOrRepairStroke(background, Color3.fromRGB(255, 245, 180), 0.45, 1)

local playerName = getOrCreateDirectChild(template, "PlayerName", "TextLabel")
playerName.Position = UDim2.new(0, 6, 0, 2)
playerName.Size = UDim2.new(1, -12, 0, 16)
playerName.ZIndex = 3
styleText(playerName, "TANK", 13, Color3.fromRGB(245, 255, 250))

local redBar = getOrCreateDirectChild(template, "RedBar", "Frame")
redBar.Position = UDim2.new(0, 8, 0, 21)
redBar.Size = UDim2.new(1, -16, 0, 9)
redBar.BackgroundColor3 = Color3.fromRGB(165, 45, 45)
redBar.BorderSizePixel = 0
redBar.ZIndex = 2
addOrRepairCorner(redBar, UDim.new(0, 4))

local greenBar = getOrCreateDirectChild(redBar, "GreenBar", "Frame")
greenBar.Position = UDim2.fromScale(0, 0)
greenBar.Size = UDim2.fromScale(1, 1)
greenBar.BackgroundColor3 = Color3.fromRGB(90, 225, 115)
greenBar.BorderSizePixel = 0
greenBar.ZIndex = 3
addOrRepairCorner(greenBar, UDim.new(0, 4))

for _, descendant in ipairs(template:GetDescendants()) do
	if descendant.Name == "GreenBar" and descendant ~= greenBar then
		print("[WOB] Removing duplicate GreenBar from HP billboard template:", descendant:GetFullName())
		descendant:Destroy()
	end
end

local hpText = getOrCreateDirectChild(template, "HpText", "TextLabel")
hpText.Position = UDim2.new(0, 8, 0, 27)
hpText.Size = UDim2.new(1, -16, 0, 10)
hpText.ZIndex = 4
styleText(hpText, "100/100", 10, Color3.fromRGB(255, 245, 180))

print("[WOB] TankHealthBillboard ready:", template:GetFullName())
print("[WOB] Rojo guard: default.project.json maps ReplicatedStorage.Shared.Assets.UI with $ignoreUnknownInstances=true.")
