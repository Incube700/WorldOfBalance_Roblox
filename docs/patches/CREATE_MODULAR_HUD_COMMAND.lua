-- One-time Roblox Studio Command Bar setup for editable modular HUD panels.
-- Run outside Play Mode. It creates only missing UI objects under StarterGui/HUD/Root.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB HUD] Run this command outside Play Mode.")
	return
end

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
			warn(("[WOB HUD] %s exists but is %s, expected %s. Leaving it unchanged."):format(
				existing:GetFullName(),
				existing.ClassName,
				className
			))
		end

		print("[WOB HUD] Kept existing " .. existing:GetFullName())
		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	print("[WOB HUD] Created " .. instance:GetFullName())

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

local function stylePanel(panel, created, position, size)
	if not panel:IsA("Frame") then
		return
	end

	if created then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = position
		panel.Size = size
		panel.BackgroundColor3 = Color3.fromRGB(9, 12, 15)
		panel.BackgroundTransparency = 0.12
		panel.BorderSizePixel = 0
		addOrUpdateCorner(panel, UDim.new(0, 6))
		addOrUpdateStroke(panel, Color3.fromRGB(70, 96, 92), 0.35, 1)
	end

	lockGuiObject(panel)
end

local function styleTextLabel(label, created, text, position, size, textSize, font, color)
	if not label:IsA("TextLabel") then
		return
	end

	if created then
		label.Position = position
		label.Size = size
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Font = font
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0.55
		label.TextSize = textSize
		label.TextWrapped = false
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
	end

	lockGuiObject(label)
end

local function styleBarBack(frame, created, position, size)
	if not frame:IsA("Frame") then
		return
	end

	if created then
		frame.Position = position
		frame.Size = size
		frame.BackgroundColor3 = Color3.fromRGB(34, 40, 44)
		frame.BackgroundTransparency = 0
		frame.BorderSizePixel = 0
		addOrUpdateCorner(frame, UDim.new(0, 3))
	end

	lockGuiObject(frame)
end

local function styleBarFill(frame, created, color)
	if not frame:IsA("Frame") then
		return
	end

	if created then
		frame.Position = UDim2.new(0, 0, 0, 0)
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = 0
		frame.BorderSizePixel = 0
		addOrUpdateCorner(frame, UDim.new(0, 3))
	end

	lockGuiObject(frame)
end

local function addStatusBar(panel, labelName, backName, fillName, labelText, fillColor)
	local label, labelCreated = getOrCreate(panel, "TextLabel", labelName)
	styleTextLabel(
		label,
		labelCreated,
		labelText,
		UDim2.new(0, 12, 0, 8),
		UDim2.new(1, -24, 0, 24),
		17,
		Enum.Font.GothamBold,
		Color3.fromRGB(235, 255, 244)
	)

	local back, backCreated = getOrCreate(panel, "Frame", backName)
	styleBarBack(back, backCreated, UDim2.new(0, 12, 0, 40), UDim2.new(1, -24, 0, 13))

	if back:IsA("Frame") then
		local fill, fillCreated = getOrCreate(back, "Frame", fillName)
		styleBarFill(fill, fillCreated, fillColor)
	end
end

local hud, _ = getOrCreate(StarterGui, "ScreenGui", "HUD")

if hud:IsA("ScreenGui") then
	hud.ResetOnSpawn = false
	hud.IgnoreGuiInset = false
	hud.DisplayOrder = math.max(hud.DisplayOrder, 10)
	hud.Enabled = false
	hud:SetAttribute("WOBDisabledByDefaultOutsideMatch", true)
end

local root, rootCreated = getOrCreate(hud, "Frame", "Root")

if root:IsA("Frame") then
	if rootCreated then
		root.AnchorPoint = Vector2.new(0, 0)
		root.Position = UDim2.new(0, 0, 0, 0)
		root.Size = UDim2.new(1, 0, 1, 0)
		root.BackgroundTransparency = 1
		root.BorderSizePixel = 0
	end

	lockGuiObject(root)
end

local enemyPanel, enemyCreated = getOrCreate(root, "Frame", "EnemyStatusPanel")
stylePanel(enemyPanel, enemyCreated, UDim2.new(0, 18, 0, 18), UDim2.new(0, 280, 0, 70))
addStatusBar(enemyPanel, "EnemyHpLabel", "EnemyHpBack", "EnemyHpFill", "Opponent HP: 100 / 100", Color3.fromRGB(235, 90, 80))
if enemyPanel:IsA("GuiObject") then
	enemyPanel.Visible = false
end

local weaponPanel, weaponCreated = getOrCreate(root, "Frame", "WeaponStatusPanel")
stylePanel(weaponPanel, weaponCreated, UDim2.new(0, 18, 0, 96), UDim2.new(0, 280, 0, 70))
addStatusBar(weaponPanel, "ReloadLabel", "ReloadBack", "ReloadFill", "Reload: READY", Color3.fromRGB(95, 180, 255))
if weaponPanel:IsA("GuiObject") then
	weaponPanel.Visible = false
end

local playerPanel, playerCreated = getOrCreate(root, "Frame", "PlayerStatusPanel")
stylePanel(playerPanel, playerCreated, UDim2.new(0, 18, 0, 174), UDim2.new(0, 280, 0, 70))
addStatusBar(playerPanel, "PlayerHpLabel", "PlayerHpBack", "PlayerHpFill", "You HP: 100 / 100", Color3.fromRGB(80, 220, 135))
if playerPanel:IsA("GuiObject") then
	playerPanel.Visible = false
end

local roundPanel, roundCreated = getOrCreate(root, "Frame", "RoundStatusPanel")
stylePanel(roundPanel, roundCreated, UDim2.new(0.5, -140, 0, 18), UDim2.new(0, 280, 0, 78))

if roundPanel:IsA("Frame") then
	roundPanel.Visible = false
end

local roundResultLabel, roundResultCreated = getOrCreate(roundPanel, "TextLabel", "RoundResultLabel")
styleTextLabel(
	roundResultLabel,
	roundResultCreated,
	"",
	UDim2.new(0, 12, 0, 8),
	UDim2.new(1, -24, 0, 32),
	24,
	Enum.Font.GothamBlack,
	Color3.fromRGB(105, 235, 145)
)

if roundResultLabel:IsA("GuiObject") then
	roundResultLabel.Visible = false
end

local restartHintLabel, restartHintCreated = getOrCreate(roundPanel, "TextLabel", "RestartHintLabel")
styleTextLabel(
	restartHintLabel,
	restartHintCreated,
	"",
	UDim2.new(0, 12, 0, 42),
	UDim2.new(1, -24, 0, 24),
	15,
	Enum.Font.GothamBold,
	Color3.fromRGB(230, 235, 220)
)

if restartHintLabel:IsA("GuiObject") then
	restartHintLabel.Visible = false
end

local matchPanel, matchCreated = getOrCreate(root, "Frame", "MatchSeriesPanel")
stylePanel(matchPanel, matchCreated, UDim2.new(1, -338, 0, 18), UDim2.new(0, 320, 0, 112))

local roundLabel, roundLabelCreated = getOrCreate(matchPanel, "TextLabel", "RoundLabel")
styleTextLabel(
	roundLabel,
	roundLabelCreated,
	"Round: 1",
	UDim2.new(0, 12, 0, 8),
	UDim2.new(1, -24, 0, 22),
	16,
	Enum.Font.GothamBold,
	Color3.fromRGB(235, 255, 244)
)

local scoreLabel, scoreLabelCreated = getOrCreate(matchPanel, "TextLabel", "ScoreLabel")
styleTextLabel(
	scoreLabel,
	scoreLabelCreated,
	"Score: You 0 / Opponent 0",
	UDim2.new(0, 12, 0, 32),
	UDim2.new(1, -24, 0, 22),
	16,
	Enum.Font.GothamBold,
	Color3.fromRGB(235, 255, 244)
)

local targetWinsLabel, targetWinsCreated = getOrCreate(matchPanel, "TextLabel", "TargetWinsLabel")
styleTextLabel(
	targetWinsLabel,
	targetWinsCreated,
	"First to 3",
	UDim2.new(0, 12, 0, 56),
	UDim2.new(1, -24, 0, 22),
	16,
	Enum.Font.GothamBold,
	Color3.fromRGB(235, 255, 244)
)

local matchResultLabel, matchResultCreated = getOrCreate(matchPanel, "TextLabel", "MatchResultLabel")
styleTextLabel(
	matchResultLabel,
	matchResultCreated,
	"",
	UDim2.new(0, 12, 0, 80),
	UDim2.new(1, -24, 0, 24),
	20,
	Enum.Font.GothamBlack,
	Color3.fromRGB(105, 235, 145)
)

print("[WOB] Modular HUD ready at StarterGui/HUD/Root. Legacy HP/reload panels are hidden by default; runtime scripts show only needed panels. File -> Save to File.")
