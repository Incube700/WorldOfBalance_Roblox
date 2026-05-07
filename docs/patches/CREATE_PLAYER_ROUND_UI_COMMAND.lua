-- One-time Roblox Studio Command Bar setup for editable Player round UI.
-- Run outside Play Mode. It creates only missing UI objects under StarterGui/HUD/MainPanel.

local StarterGui = game:GetService("StarterGui")

local function setPropertyIfPossible(instance, propertyName, value)
	pcall(function()
		instance[propertyName] = value
	end)
end

local function lockGuiObject(guiObject)
	if not guiObject:IsA("GuiObject") then
		return
	end

	guiObject.Active = false
	setPropertyIfPossible(guiObject, "Selectable", false)
	setPropertyIfPossible(guiObject, "Draggable", false)
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB UI SETUP] %s exists but is %s, expected %s. Leaving it unchanged."):format(existing:GetFullName(), existing.ClassName, className))
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent

	return instance, true
end

local function addOrUpdateCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner")

	if corner == nil then
		corner = Instance.new("UICorner")
		corner.Parent = parent
	end

	corner.CornerRadius = radius
end

local function addOrUpdateStroke(parent, color, transparency, thickness)
	local stroke = parent:FindFirstChildOfClass("UIStroke")

	if stroke == nil then
		stroke = Instance.new("UIStroke")
		stroke.Parent = parent
	end

	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
end

local function styleTextLabel(label, text, position, size, textSize, font, color)
	if not label:IsA("TextLabel") then
		return
	end

	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.TextSize = textSize
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	lockGuiObject(label)
end

local hud, hudCreated = getOrCreate(StarterGui, "ScreenGui", "HUD")

if hud:IsA("ScreenGui") then
	hud.ResetOnSpawn = false
	hud.IgnoreGuiInset = false
	hud.DisplayOrder = math.max(hud.DisplayOrder, 10)
end

local mainPanel, mainPanelCreated = getOrCreate(hud, "Frame", "MainPanel")

if mainPanel:IsA("Frame") then
	if mainPanelCreated then
		mainPanel.AnchorPoint = Vector2.new(0, 0)
		mainPanel.Position = UDim2.new(0, 18, 0, 18)
		mainPanel.Size = UDim2.new(0, 280, 0, 180)
		mainPanel.BackgroundColor3 = Color3.fromRGB(10, 14, 18)
		mainPanel.BackgroundTransparency = 0.08
		mainPanel.BorderSizePixel = 0
		addOrUpdateCorner(mainPanel, UDim.new(0, 6))
		addOrUpdateStroke(mainPanel, Color3.fromRGB(70, 96, 92), 0.25, 1)
	elseif mainPanel.Size.Y.Scale == 0 and mainPanel.Size.Y.Offset < 180 then
		mainPanel.Size = UDim2.new(mainPanel.Size.X.Scale, mainPanel.Size.X.Offset, 0, 180)
	end

	lockGuiObject(mainPanel)
end

local playerHpLabel = getOrCreate(mainPanel, "TextLabel", "PlayerHpLabel")
styleTextLabel(
	playerHpLabel,
	"Player HP: 100 / 100",
	UDim2.new(0, 12, 0, 78),
	UDim2.new(1, -24, 0, 24),
	18,
	Enum.Font.GothamBold,
	Color3.fromRGB(235, 255, 244)
)

local playerHpBack = getOrCreate(mainPanel, "Frame", "PlayerHpBack")

if playerHpBack:IsA("Frame") then
	playerHpBack.Position = UDim2.new(0, 12, 0, 106)
	playerHpBack.Size = UDim2.new(1, -24, 0, 13)
	playerHpBack.BackgroundColor3 = Color3.fromRGB(33, 39, 43)
	playerHpBack.BackgroundTransparency = 0
	playerHpBack.BorderSizePixel = 0
	addOrUpdateCorner(playerHpBack, UDim.new(0, 3))
	lockGuiObject(playerHpBack)
end

if playerHpBack:IsA("Frame") then
	local playerHpFill = getOrCreate(playerHpBack, "Frame", "PlayerHpFill")

	if playerHpFill:IsA("Frame") then
		playerHpFill.Position = UDim2.new(0, 0, 0, 0)
		playerHpFill.Size = UDim2.new(1, 0, 1, 0)
		playerHpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
		playerHpFill.BackgroundTransparency = 0
		playerHpFill.BorderSizePixel = 0
		addOrUpdateCorner(playerHpFill, UDim.new(0, 3))
		lockGuiObject(playerHpFill)
	end
end

local roundResultLabel = getOrCreate(mainPanel, "TextLabel", "RoundResultLabel")
styleTextLabel(
	roundResultLabel,
	"",
	UDim2.new(0, 12, 0, 126),
	UDim2.new(1, -24, 0, 26),
	22,
	Enum.Font.GothamBlack,
	Color3.fromRGB(105, 235, 145)
)
roundResultLabel.Visible = false

local restartHintLabel = getOrCreate(mainPanel, "TextLabel", "RestartHintLabel")
styleTextLabel(
	restartHintLabel,
	"Press R to restart",
	UDim2.new(0, 12, 0, 152),
	UDim2.new(1, -24, 0, 20),
	15,
	Enum.Font.GothamBold,
	Color3.fromRGB(230, 235, 220)
)
restartHintLabel.Visible = false

print("[WOB UI SETUP] Editable Player round UI is ready at StarterGui/HUD/MainPanel.")
