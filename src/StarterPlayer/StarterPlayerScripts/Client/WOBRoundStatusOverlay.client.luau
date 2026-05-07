local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local playerTank = testObjects:WaitForChild("PlayerTankPrototype")

local LEGACY_RUNTIME_GUI_NAME = "WOBRoundStatusOverlayGui"
local EMERGENCY_GUI_NAME = "WOBRoundStatusEmergencyGui"

local legacyGui = playerGui:FindFirstChild(LEGACY_RUNTIME_GUI_NAME)

if legacyGui ~= nil then
	legacyGui:Destroy()
end

local function lockGuiObject(guiObject)
	if not guiObject:IsA("GuiObject") then
		return
	end

	guiObject.Active = false

	pcall(function()
		guiObject.Selectable = false
	end)

	pcall(function()
		guiObject.Draggable = false
	end)
end

local function lockUiTree(rootObject)
	for _, descendant in ipairs(rootObject:GetDescendants()) do
		lockGuiObject(descendant)
	end

	lockGuiObject(rootObject)
end

local function waitForStudioRoundUi()
	local hud = playerGui:WaitForChild("HUD", 8)

	if hud == nil then
		return nil, "PlayerGui/HUD was not found"
	end

	if not hud:IsA("ScreenGui") then
		return nil, "PlayerGui/HUD is " .. hud.ClassName .. ", expected ScreenGui"
	end

	local mainPanel = hud:WaitForChild("MainPanel", 8)

	if mainPanel == nil then
		return nil, "PlayerGui/HUD/MainPanel was not found"
	end

	if not mainPanel:IsA("Frame") then
		return nil, "PlayerGui/HUD/MainPanel is " .. mainPanel.ClassName .. ", expected Frame"
	end

	local playerHpLabel = mainPanel:FindFirstChild("PlayerHpLabel")
	local playerHpBack = mainPanel:FindFirstChild("PlayerHpBack")
	local playerHpFill = nil

	if playerHpBack ~= nil then
		playerHpFill = playerHpBack:FindFirstChild("PlayerHpFill")
	end

	local resultLabel = mainPanel:FindFirstChild("RoundResultLabel")
	local restartHintLabel = mainPanel:FindFirstChild("RestartHintLabel")

	local missing = {}

	if playerHpLabel == nil then
		table.insert(missing, "PlayerHpLabel")
	elseif not playerHpLabel:IsA("TextLabel") then
		table.insert(missing, "PlayerHpLabel TextLabel")
	end

	if playerHpBack == nil then
		table.insert(missing, "PlayerHpBack")
	elseif not playerHpBack:IsA("Frame") then
		table.insert(missing, "PlayerHpBack Frame")
	end

	if playerHpFill == nil then
		table.insert(missing, "PlayerHpBack/PlayerHpFill")
	elseif not playerHpFill:IsA("Frame") then
		table.insert(missing, "PlayerHpBack/PlayerHpFill Frame")
	end

	if resultLabel == nil then
		table.insert(missing, "RoundResultLabel")
	elseif not resultLabel:IsA("TextLabel") then
		table.insert(missing, "RoundResultLabel TextLabel")
	end

	if restartHintLabel == nil then
		table.insert(missing, "RestartHintLabel")
	elseif not restartHintLabel:IsA("TextLabel") then
		table.insert(missing, "RestartHintLabel TextLabel")
	end

	if #missing > 0 then
		return nil, "missing editable HUD elements: " .. table.concat(missing, ", ")
	end

	lockUiTree(mainPanel)

	return {
		Source = "Studio HUD",
		PlayerHpLabel = playerHpLabel,
		PlayerHpBack = playerHpBack,
		PlayerHpFill = playerHpFill,
		RoundResultLabel = resultLabel,
		RestartHintLabel = restartHintLabel,
	}, nil
end

local function createEmergencyLabel(name, parent, position, size, textSize, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = Color3.fromRGB(245, 255, 250)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	label.Parent = parent
	lockGuiObject(label)

	return label
end

local function createEmergencyRoundUi(reason)
	warn("[WOB] Editable round HUD not found (" .. reason .. "). Using emergency runtime UI. Run docs/patches/CREATE_PLAYER_ROUND_UI_COMMAND.lua in Studio Command Bar.")

	local existingEmergencyGui = playerGui:FindFirstChild(EMERGENCY_GUI_NAME)

	if existingEmergencyGui ~= nil then
		existingEmergencyGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = EMERGENCY_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "EmergencyPanel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 18, 1, -18)
	panel.Size = UDim2.new(0, 280, 0, 118)
	panel.BackgroundColor3 = Color3.fromRGB(9, 12, 15)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	lockGuiObject(panel)

	local playerHpLabel = createEmergencyLabel(
		"PlayerHpLabel",
		panel,
		UDim2.new(0, 14, 0, 10),
		UDim2.new(1, -28, 0, 28),
		20,
		Enum.Font.GothamBold
	)

	local playerHpBack = Instance.new("Frame")
	playerHpBack.Name = "PlayerHpBack"
	playerHpBack.Position = UDim2.new(0, 14, 0, 46)
	playerHpBack.Size = UDim2.new(1, -28, 0, 14)
	playerHpBack.BackgroundColor3 = Color3.fromRGB(35, 42, 45)
	playerHpBack.BorderSizePixel = 0
	playerHpBack.Parent = panel
	lockGuiObject(playerHpBack)

	local playerHpFill = Instance.new("Frame")
	playerHpFill.Name = "PlayerHpFill"
	playerHpFill.Size = UDim2.new(1, 0, 1, 0)
	playerHpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
	playerHpFill.BorderSizePixel = 0
	playerHpFill.Parent = playerHpBack
	lockGuiObject(playerHpFill)

	local resultLabel = createEmergencyLabel(
		"RoundResultLabel",
		panel,
		UDim2.new(0, 14, 0, 68),
		UDim2.new(1, -28, 0, 24),
		20,
		Enum.Font.GothamBlack
	)
	resultLabel.Visible = false

	local restartHintLabel = createEmergencyLabel(
		"RestartHintLabel",
		panel,
		UDim2.new(0, 14, 0, 92),
		UDim2.new(1, -28, 0, 20),
		15,
		Enum.Font.GothamBold
	)
	restartHintLabel.Text = "Press R to restart"
	restartHintLabel.Visible = false

	return {
		Source = "Emergency runtime UI",
		PlayerHpLabel = playerHpLabel,
		PlayerHpBack = playerHpBack,
		PlayerHpFill = playerHpFill,
		RoundResultLabel = resultLabel,
		RestartHintLabel = restartHintLabel,
	}
end

local roundUi, bindError = waitForStudioRoundUi()

if roundUi == nil then
	roundUi = createEmergencyRoundUi(bindError or "unknown reason")
end

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function updateHealth()
	local maxHealth = playerTank:GetAttribute("MaxHealth") or 100
	local health = playerTank:GetAttribute("Health") or maxHealth
	local normalizedHealth = clamp01(health / math.max(1, maxHealth))

	roundUi.PlayerHpLabel.Text = "Player HP: " .. math.floor(health) .. " / " .. math.floor(maxHealth)
	roundUi.PlayerHpFill.Size = UDim2.new(normalizedHealth, 0, 1, 0)

	if normalizedHealth <= 0.3 then
		roundUi.PlayerHpFill.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
	elseif normalizedHealth <= 0.6 then
		roundUi.PlayerHpFill.BackgroundColor3 = Color3.fromRGB(240, 190, 80)
	else
		roundUi.PlayerHpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
	end
end

local function updateRoundResult()
	local result = root:GetAttribute("RoundResult") or "Playing"
	local roundEnded = root:GetAttribute("RoundEnded") == true or result == "Win" or result == "Lose"

	if result == "Win" then
		roundUi.RoundResultLabel.Text = "WIN"
		roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(105, 235, 145)
		roundUi.RoundResultLabel.Visible = true
	elseif result == "Lose" then
		roundUi.RoundResultLabel.Text = "LOSE"
		roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(245, 95, 80)
		roundUi.RoundResultLabel.Visible = true
	else
		roundUi.RoundResultLabel.Text = ""
		roundUi.RoundResultLabel.Visible = false
	end

	roundUi.RestartHintLabel.Text = "Press R to restart"
	roundUi.RestartHintLabel.Visible = roundEnded
end

playerTank:GetAttributeChangedSignal("Health"):Connect(updateHealth)
playerTank:GetAttributeChangedSignal("MaxHealth"):Connect(updateHealth)
root:GetAttributeChangedSignal("RoundResult"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("RoundEnded"):Connect(updateRoundResult)

updateHealth()
updateRoundResult()

print("[WOB] Round status overlay bound to " .. roundUi.Source)
