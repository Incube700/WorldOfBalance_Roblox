-- Run this in Studio Command Bar outside Play Mode.
-- Rebuilds ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard with a clean, editable hierarchy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function makeFrame(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.Rotation = 0
	frame.Parent = parent

	return frame
end

local function makeLabel(parent, name)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Rotation = 0
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent

	return label
end

local shared = getOrCreateFolder(ReplicatedStorage, "Shared")
local assets = getOrCreateFolder(shared, "Assets")
local ui = getOrCreateFolder(assets, "UI")
local template = ui:FindFirstChild(TEMPLATE_NAME)

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

clearChildren(template)

template.AlwaysOnTop = true
template.LightInfluence = 0
template.MaxDistance = 180
template.Size = UDim2.fromOffset(68, 14)
template.StudsOffset = Vector3.zero
template.Enabled = true

local root = makeFrame(template, "Root")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1

local playerName = makeLabel(root, "PlayerName")
playerName.AnchorPoint = Vector2.new(0.5, 0.5)
playerName.Position = UDim2.fromScale(0.5, 0.5)
playerName.Size = UDim2.fromScale(1, 1)
playerName.BackgroundTransparency = 1
playerName.Text = "TANK"
playerName.TextColor3 = Color3.fromRGB(255, 255, 255)
playerName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
playerName.TextStrokeTransparency = 0.25
playerName.Visible = false
playerName.ZIndex = 3

local barsRoot = makeFrame(root, "BarsRoot")
barsRoot.AnchorPoint = Vector2.new(0, 0)
barsRoot.Position = UDim2.fromOffset(0, 0)
barsRoot.Size = UDim2.fromScale(1, 1)
barsRoot.BackgroundTransparency = 1
barsRoot.ZIndex = 1

local barBack = makeFrame(barsRoot, "BarBack")
barBack.AnchorPoint = Vector2.new(0, 0)
barBack.Position = UDim2.fromOffset(0, 0)
barBack.Size = UDim2.new(1, 0, 0, 8)
barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
barBack.BackgroundTransparency = 0.15
barBack.ClipsDescendants = true
barBack.ZIndex = 1

local redBar = makeFrame(barBack, "RedBar")
redBar.AnchorPoint = Vector2.new(0, 0.5)
redBar.Position = UDim2.new(0, 0, 0.5, 0)
redBar.Size = UDim2.new(1, 0, 1, 0)
redBar.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
redBar.BackgroundTransparency = 0
redBar.ZIndex = 1

local greenBar = makeFrame(barBack, "GreenBar")
greenBar.AnchorPoint = Vector2.new(0, 0.5)
greenBar.Position = UDim2.new(0, 0, 0.5, 0)
greenBar.Size = UDim2.new(1, 0, 1, 0)
greenBar.BackgroundColor3 = Color3.fromRGB(90, 225, 115)
greenBar.BackgroundTransparency = 0
greenBar.ZIndex = 2

local hpText = makeLabel(barBack, "HpText")
hpText.AnchorPoint = Vector2.new(0.5, 0.5)
hpText.Position = UDim2.fromScale(0.5, 0.5)
hpText.Size = UDim2.fromScale(1, 1)
hpText.BackgroundTransparency = 1
hpText.Text = "100/100"
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hpText.TextStrokeTransparency = 0.2
hpText.Visible = false
hpText.ZIndex = 3

local reloadBack = makeFrame(barsRoot, "ReloadBack")
reloadBack.AnchorPoint = Vector2.new(0, 0)
reloadBack.Position = UDim2.new(0, 0, 0, 10)
reloadBack.Size = UDim2.new(1, 0, 0, 4)
reloadBack.BackgroundColor3 = Color3.fromRGB(8, 16, 28)
reloadBack.BackgroundTransparency = 0.12
reloadBack.ClipsDescendants = true
reloadBack.ZIndex = 1

local reloadBar = makeFrame(reloadBack, "ReloadBar")
reloadBar.AnchorPoint = Vector2.new(0, 0.5)
reloadBar.Position = UDim2.new(0, 0, 0.5, 0)
reloadBar.Size = UDim2.new(1, 0, 1, 0)
reloadBar.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
reloadBar.BackgroundTransparency = 0
reloadBar.ZIndex = 2

print("[WOB] TankHealthBillboard rebuilt:", template:GetFullName())
print("[WOB] Rojo guard: default.project.json must keep ReplicatedStorage.Shared.Assets.UI with $ignoreUnknownInstances=true.")
