-- Scripted, animated duel HUD that replaces the legacy on-screen duel panels.
-- Built entirely in Lua (no Studio HUD template dependency) and wired to real
-- gameplay data: tank Health/MaxHealth, server reload attributes, series score,
-- and the player's Bolts wallet. Visual language follows the "Ricochet Tanks"
-- UI concept (dark sci-fi panels, blue/red sides, yellow accents).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local HudConfig = require(configs:WaitForChild("HudConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))

local clientFolder = script.Parent
local HudDeviceUtils = require(clientFolder:WaitForChild("Hud"):WaitForChild("HudDeviceUtils"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatFeedbackEvent = remotes:WaitForChild("CombatFeedbackEvent")
local returnToMenuRequestEvent = remotes:WaitForChild("ReturnToMenuRequestEvent")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local root = Workspace:WaitForChild("WOB_Generated")

------------------------------------------------------------------------
-- Palette (from the UI concept)
------------------------------------------------------------------------
local COLORS = {
	Panel = Color3.fromRGB(13, 17, 23),
	Border = Color3.fromRGB(31, 41, 55),
	BarTrack = Color3.fromRGB(31, 41, 55),
	Blue = Color3.fromRGB(59, 130, 246),
	BlueLight = Color3.fromRGB(96, 165, 250),
	BlueDark = Color3.fromRGB(29, 78, 216),
	Red = Color3.fromRGB(239, 68, 68),
	RedLight = Color3.fromRGB(248, 113, 113),
	RedDark = Color3.fromRGB(185, 28, 28),
	Yellow = Color3.fromRGB(250, 204, 21),
	Green = Color3.fromRGB(34, 197, 94),
	GreenLight = Color3.fromRGB(74, 222, 128),
	GreenDark = Color3.fromRGB(22, 163, 74),
	Orange = Color3.fromRGB(249, 115, 22),
	Text = Color3.fromRGB(226, 232, 240),
	Muted = Color3.fromRGB(100, 116, 139),
}

local PANEL_TRANSPARENCY = 0.1
local TITLE_FONT = Enum.Font.GothamBlack
local LABEL_FONT = Enum.Font.GothamBold
local MONO_FONT = Enum.Font.Code

local RELOAD_FALLBACK_DURATION = math.max(0.05, (WeaponConfig.PrimaryWeapon or {}).ShootCooldown or 0.45)
local SCRIPTED_DUEL_HUD_ENABLED = ((HudConfig.CombatHud or {}).UseScriptedDuelHud == true)
local SCRIPTED_TRAINING_HUD_ENABLED = ((HudConfig.CombatHud or {}).UseScriptedTrainingHud == true)
local TRAINING_COMPACT_HUD = ((HudConfig.CombatHud or {}).TrainingCompactHud == true)
local MAX_FEEDBACK = 4

------------------------------------------------------------------------
-- Small UI builders
------------------------------------------------------------------------
local function lock(guiObject)
	guiObject.Active = false
	pcall(function()
		guiObject.Selectable = false
	end)
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function makePanel(name, parent)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = PANEL_TRANSPARENCY
	panel.BorderSizePixel = 0
	panel.Parent = parent
	addCorner(panel, 8)
	addStroke(panel, COLORS.Border, 0.25, 1)
	lock(panel)
	return panel
end

local function makeAccent(parent, color, side)
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = color
	accent.Size = UDim2.new(0, 2, 1, -10)
	accent.Position = UDim2.new(0, 0, 0, 5)
	accent.AnchorPoint = Vector2.new(0, 0)

	if side == "right" then
		accent.AnchorPoint = Vector2.new(1, 0)
		accent.Position = UDim2.new(1, 0, 0, 5)
	end

	addCorner(accent, 2)
	accent.Parent = parent
	lock(accent)
	return accent
end

local function makeLabel(name, parent, font, size, color, xAlign)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	label.Parent = parent
	lock(label)
	return label
end

-- A track + fill bar. Returns the fill frame.
local function makeBar(parent, position, size, fillColor)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = COLORS.BarTrack
	track.BorderSizePixel = 0
	track.Position = position
	track.Size = size
	track.Parent = parent
	addCorner(track, 99)
	lock(track)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	addCorner(fill, 99)
	lock(fill)

	return fill, track
end

local function setZIndexTree(instance, zIndex)
	if instance:IsA("GuiObject") then
		instance.ZIndex = zIndex
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex
		end
	end
end

local function tweenButtonVisual(button, scale, pressed, normalColor)
	local targetColor = pressed and COLORS.Orange or normalColor
	local targetScale = pressed and 0.96 or 1

	TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = targetColor,
	}):Play()
	TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = targetScale,
	}):Play()
end

local function makeButton(name, parent, text, accentColor)
	local normalColor = accentColor or COLORS.Yellow
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = normalColor
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = TITLE_FONT
	button.Text = text
	button.TextColor3 = COLORS.Panel
	button.TextSize = 13
	button.TextWrapped = true
	button.AutoButtonColor = false
	button.Active = true
	button.Parent = parent
	addCorner(button, 8)
	addStroke(button, COLORS.Orange, 0.35, 1)

	local scale = Instance.new("UIScale")
	scale.Parent = button

	button.MouseEnter:Connect(function()
		tweenButtonVisual(button, scale, false, normalColor)
	end)
	button.MouseButton1Down:Connect(function()
		tweenButtonVisual(button, scale, true, normalColor)
	end)
	button.MouseButton1Up:Connect(function()
		tweenButtonVisual(button, scale, false, normalColor)
	end)
	button.MouseLeave:Connect(function()
		tweenButtonVisual(button, scale, false, normalColor)
	end)

	return button, scale
end

------------------------------------------------------------------------
-- Build the HUD tree
------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "WOBDuelHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Enabled = false
gui.Parent = playerGui

local rootFrame = Instance.new("Frame")
rootFrame.Name = "Root"
rootFrame.Size = UDim2.fromScale(1, 1)
rootFrame.BackgroundTransparency = 1
rootFrame.Parent = gui
lock(rootFrame)

local function makeGradientShade(name, position, size, rotation)
	local shade = Instance.new("Frame")
	shade.Name = name
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0
	shade.BorderSizePixel = 0
	shade.Position = position
	shade.Size = size
	shade.ZIndex = 0
	shade.Parent = rootFrame
	lock(shade)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = shade

	return shade
end

local topShade = makeGradientShade("TopShade", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 110), 90)
local bottomShade = makeGradientShade("BottomShade", UDim2.new(0, 0, 1, -96), UDim2.new(1, 0, 0, 96), -90)

-- ---- Top bar -------------------------------------------------------
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 72)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundTransparency = 1
topBar.Parent = rootFrame
lock(topBar)

-- Player panel (top-left)
local playerPanel = makePanel("PlayerPanel", topBar)
playerPanel.AnchorPoint = Vector2.new(0, 0)
playerPanel.Position = UDim2.new(0, 16, 0, 12)
playerPanel.Size = UDim2.fromOffset(208, 56)
makeAccent(playerPanel, COLORS.Blue, "left")
local playerStroke = playerPanel:FindFirstChildOfClass("UIStroke")

local playerName = makeLabel("Name", playerPanel, MONO_FONT, 11, COLORS.BlueLight, Enum.TextXAlignment.Left)
playerName.Position = UDim2.new(0, 12, 0, 5)
playerName.Size = UDim2.new(1, -24, 0, 12)
playerName.Text = "YOU"

local playerHpFill = makeBar(
	playerPanel,
	UDim2.new(0, 12, 0, 22),
	UDim2.new(1, -64, 0, 8),
	COLORS.GreenLight
)
local playerHpValue = makeLabel("HpValue", playerPanel, MONO_FONT, 12, COLORS.GreenLight, Enum.TextXAlignment.Right)
playerHpValue.Position = UDim2.new(1, -50, 0, 20)
playerHpValue.Size = UDim2.fromOffset(40, 12)
playerHpValue.Text = "--"

local playerReloadFill, playerReloadTrack = makeBar(
	playerPanel,
	UDim2.new(0, 12, 0, 38),
	UDim2.new(1, -64, 0, 5),
	COLORS.BlueLight
)
local playerReloadLabel = makeLabel("ReloadTag", playerPanel, LABEL_FONT, 9, COLORS.Muted, Enum.TextXAlignment.Right)
playerReloadLabel.Position = UDim2.new(1, -50, 0, 35)
playerReloadLabel.Size = UDim2.fromOffset(40, 11)
playerReloadLabel.Text = "RELOAD"

-- Enemy panel (top-right)
local enemyPanel = makePanel("EnemyPanel", topBar)
enemyPanel.AnchorPoint = Vector2.new(1, 0)
enemyPanel.Position = UDim2.new(1, -16, 0, 12)
enemyPanel.Size = UDim2.fromOffset(208, 56)
makeAccent(enemyPanel, COLORS.Red, "right")

local enemyName = makeLabel("Name", enemyPanel, MONO_FONT, 11, COLORS.RedLight, Enum.TextXAlignment.Right)
enemyName.Position = UDim2.new(0, 12, 0, 5)
enemyName.Size = UDim2.new(1, -24, 0, 12)
enemyName.Text = "ENEMY"

local enemyHpValue = makeLabel("HpValue", enemyPanel, MONO_FONT, 12, COLORS.RedLight, Enum.TextXAlignment.Left)
enemyHpValue.Position = UDim2.new(0, 12, 0, 24)
enemyHpValue.Size = UDim2.fromOffset(40, 12)
enemyHpValue.Text = "--"

local enemyHpFill = makeBar(
	enemyPanel,
	UDim2.new(0, 56, 0, 26),
	UDim2.new(1, -68, 0, 8),
	COLORS.RedLight
)

-- Score box (top-center)
local scoreBox = makePanel("ScoreBox", topBar)
scoreBox.AnchorPoint = Vector2.new(0.5, 0)
scoreBox.Position = UDim2.new(0.5, 0, 0, 10)
scoreBox.Size = UDim2.fromOffset(168, 50)

local scoreBoxScale = Instance.new("UIScale")
scoreBoxScale.Parent = scoreBox

local youNum = makeLabel("You", scoreBox, TITLE_FONT, 24, COLORS.Blue, Enum.TextXAlignment.Center)
youNum.Position = UDim2.new(0, 12, 0, 4)
youNum.Size = UDim2.fromOffset(50, 28)
youNum.Text = "0"
local youNumScale = Instance.new("UIScale")
youNumScale.Parent = youNum

local youSub = makeLabel("YouSub", scoreBox, LABEL_FONT, 9, COLORS.Muted, Enum.TextXAlignment.Center)
youSub.Position = UDim2.new(0, 12, 0, 33)
youSub.Size = UDim2.fromOffset(50, 12)
youSub.Text = "YOU"

local divider = makeLabel("Divider", scoreBox, TITLE_FONT, 16, COLORS.Border, Enum.TextXAlignment.Center)
divider.Position = UDim2.new(0.5, -10, 0, 8)
divider.Size = UDim2.fromOffset(20, 24)
divider.Text = "—"

local oppNum = makeLabel("Opp", scoreBox, TITLE_FONT, 24, COLORS.Red, Enum.TextXAlignment.Center)
oppNum.Position = UDim2.new(1, -62, 0, 4)
oppNum.Size = UDim2.fromOffset(50, 28)
oppNum.Text = "0"
local oppNumScale = Instance.new("UIScale")
oppNumScale.Parent = oppNum

local oppSub = makeLabel("OppSub", scoreBox, LABEL_FONT, 9, COLORS.Muted, Enum.TextXAlignment.Center)
oppSub.Position = UDim2.new(1, -62, 0, 33)
oppSub.Size = UDim2.fromOffset(50, 12)
oppSub.Text = "ENEMY"

local trainingTitle = makeLabel("TrainingTitle", scoreBox, TITLE_FONT, 16, COLORS.Yellow, Enum.TextXAlignment.Center)
trainingTitle.Position = UDim2.new(0, 12, 0, 6)
trainingTitle.Size = UDim2.new(1, -24, 0, 20)
trainingTitle.Text = "TRAINING"
trainingTitle.Visible = false

local trainingHint = makeLabel("TrainingHint", scoreBox, LABEL_FONT, 10, COLORS.Muted, Enum.TextXAlignment.Center)
trainingHint.Position = UDim2.new(0, 10, 0, 28)
trainingHint.Size = UDim2.new(1, -20, 0, 16)
trainingHint.Text = "DESTROY TARGETS - PRACTICE RICOCHETS"
trainingHint.TextTruncate = Enum.TextTruncate.AtEnd
trainingHint.Visible = false

-- ---- Bottom bar ----------------------------------------------------
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.AnchorPoint = Vector2.new(0, 1)
bottomBar.Size = UDim2.new(1, 0, 0, 60)
bottomBar.Position = UDim2.new(0, 0, 1, 0)
bottomBar.BackgroundTransparency = 1
bottomBar.Parent = rootFrame
lock(bottomBar)

local reloadPanel = makePanel("ReloadPanel", bottomBar)
reloadPanel.AnchorPoint = Vector2.new(0, 1)
reloadPanel.Position = UDim2.new(0, 16, 1, -12)
reloadPanel.Size = UDim2.fromOffset(210, 44)

local reloadIcon = makeLabel("Icon", reloadPanel, LABEL_FONT, 16, COLORS.BlueLight, Enum.TextXAlignment.Center)
reloadIcon.Position = UDim2.new(0, 8, 0, 0)
reloadIcon.Size = UDim2.new(0, 22, 1, 0)
reloadIcon.Text = "⟳"

local reloadTitle = makeLabel("Title", reloadPanel, LABEL_FONT, 9, COLORS.Muted, Enum.TextXAlignment.Left)
reloadTitle.Position = UDim2.new(0, 36, 0, 7)
reloadTitle.Size = UDim2.new(1, -46, 0, 12)
reloadTitle.Text = "RELOAD"

local reloadBarFill = makeBar(
	reloadPanel,
	UDim2.new(0, 36, 0, 24),
	UDim2.new(1, -48, 0, 6),
	COLORS.BlueLight
)

local boltsPanel = makePanel("BoltsPanel", bottomBar)
boltsPanel.AnchorPoint = Vector2.new(0, 1)
boltsPanel.Position = UDim2.new(0, 236, 1, -12)
boltsPanel.Size = UDim2.fromOffset(104, 44)

local boltIcon = Instance.new("Frame")
boltIcon.Name = "BoltIcon"
boltIcon.BackgroundColor3 = COLORS.Orange
boltIcon.Size = UDim2.fromOffset(18, 18)
boltIcon.Position = UDim2.new(0, 10, 0.5, -9)
boltIcon.BorderSizePixel = 0
boltIcon.Parent = boltsPanel
addCorner(boltIcon, 99)
lock(boltIcon)
local boltGlyph = makeLabel("B", boltIcon, TITLE_FONT, 10, COLORS.Panel, Enum.TextXAlignment.Center)
boltGlyph.Size = UDim2.fromScale(1, 1)
boltGlyph.Text = "B"

local boltsValue = makeLabel("Value", boltsPanel, MONO_FONT, 14, COLORS.Orange, Enum.TextXAlignment.Left)
boltsValue.Position = UDim2.new(0, 34, 0, 0)
boltsValue.Size = UDim2.new(1, -40, 1, 0)
boltsValue.Text = "0"

local boltsReward = makeLabel("Reward", boltsPanel, LABEL_FONT, 11, COLORS.Green, Enum.TextXAlignment.Center)
boltsReward.AnchorPoint = Vector2.new(0.5, 1)
boltsReward.Position = UDim2.new(0.5, 0, 0, 0)
boltsReward.Size = UDim2.fromOffset(96, 16)
boltsReward.TextTransparency = 1
boltsReward.Text = ""

-- ---- Feedback layer (RICOCHET / NO PEN / HIT) ----------------------
local feedbackLayer = Instance.new("Frame")
feedbackLayer.Name = "FeedbackLayer"
feedbackLayer.Size = UDim2.fromScale(1, 1)
feedbackLayer.BackgroundTransparency = 1
feedbackLayer.Parent = rootFrame
lock(feedbackLayer)

local feedbackPool = {}

for index = 1, MAX_FEEDBACK do
	local label = Instance.new("TextLabel")
	label.Name = "FeedbackLabel" .. tostring(index)
	label.BackgroundTransparency = 1
	label.Font = TITLE_FONT
	label.TextSize = 22
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(260, 40)
	label.Visible = false
	label.Parent = feedbackLayer
	lock(label)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.7
	scale.Parent = label

	feedbackPool[index] = {
		Label = label,
		Scale = scale,
		InUse = false,
		Token = 0,
	}
end

-- ---- Round/match result overlay -----------------------------------
local resultOverlay = Instance.new("Frame")
resultOverlay.Name = "ResultOverlay"
resultOverlay.Size = UDim2.fromScale(1, 1)
resultOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
resultOverlay.BackgroundTransparency = 1
resultOverlay.Visible = false
resultOverlay.Parent = rootFrame
lock(resultOverlay)

local resultContent = Instance.new("Frame")
resultContent.Name = "ResultContent"
resultContent.AnchorPoint = Vector2.new(0.5, 0.5)
resultContent.Position = UDim2.fromScale(0.5, 0.5)
resultContent.Size = UDim2.fromOffset(420, 170)
resultContent.BackgroundTransparency = 1
resultContent.Parent = resultOverlay
lock(resultContent)

local resultTitle = makeLabel("Title", resultContent, TITLE_FONT, 34, COLORS.Yellow, Enum.TextXAlignment.Center)
resultTitle.Position = UDim2.new(0, 0, 0, 0)
resultTitle.Size = UDim2.new(1, 0, 0, 52)
resultTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
resultTitle.TextStrokeTransparency = 0.28

local resultTitleScale = Instance.new("UIScale")
resultTitleScale.Scale = 0.78
resultTitleScale.Parent = resultTitle

local resultSubtitle = makeLabel("Subtitle", resultContent, LABEL_FONT, 13, COLORS.Muted, Enum.TextXAlignment.Center)
resultSubtitle.Position = UDim2.new(0, 0, 0, 58)
resultSubtitle.Size = UDim2.new(1, 0, 0, 24)

local resultButtonLike = makeLabel("ButtonLike", resultContent, TITLE_FONT, 12, COLORS.Panel, Enum.TextXAlignment.Center)
resultButtonLike.AnchorPoint = Vector2.new(0.5, 0)
resultButtonLike.Position = UDim2.new(0.5, 0, 0, 98)
resultButtonLike.Size = UDim2.fromOffset(170, 34)
resultButtonLike.BackgroundColor3 = COLORS.Yellow
resultButtonLike.BackgroundTransparency = 0
resultButtonLike.BorderSizePixel = 0
resultButtonLike.Text = ""
addCorner(resultButtonLike, 6)
addStroke(resultButtonLike, COLORS.Orange, 0.35, 1)

-- Gameplay layout convention:
-- mobile Move/REV live bottom-left, Aim/Fire live lower-right, and Menu/Pause
-- lives top-right below the safe-area HUD. Keep upgrade and pause overlays away
-- from the bottom control clusters.
local trainingMenuButton = makeButton("TrainingMenuButton", rootFrame, "MENU", COLORS.Yellow)
trainingMenuButton.AnchorPoint = Vector2.new(1, 0)
trainingMenuButton.Position = UDim2.new(1, -18, 0, 84)
trainingMenuButton.Size = UDim2.fromOffset(76, 34)
trainingMenuButton.Visible = false
trainingMenuButton.ZIndex = 30

local trainingPauseRoot = Instance.new("Frame")
trainingPauseRoot.Name = "TrainingPauseRoot"
trainingPauseRoot.Size = UDim2.fromScale(1, 1)
trainingPauseRoot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
trainingPauseRoot.BackgroundTransparency = 1
trainingPauseRoot.BorderSizePixel = 0
trainingPauseRoot.Visible = false
trainingPauseRoot.Active = true
trainingPauseRoot.ZIndex = 80
trainingPauseRoot.Parent = rootFrame

local trainingPausePanel = makePanel("TrainingPausePanel", trainingPauseRoot)
trainingPausePanel.AnchorPoint = Vector2.new(0.5, 0.5)
trainingPausePanel.Position = UDim2.fromScale(0.5, 0.5)
trainingPausePanel.Size = UDim2.fromOffset(300, 214)
trainingPausePanel.BackgroundTransparency = 0.06
trainingPausePanel.Active = true
setZIndexTree(trainingPausePanel, 82)

local trainingPauseScale = Instance.new("UIScale")
trainingPauseScale.Parent = trainingPausePanel

local trainingPauseTitle = makeLabel(
	"Title",
	trainingPausePanel,
	TITLE_FONT,
	22,
	COLORS.Yellow,
	Enum.TextXAlignment.Center
)
trainingPauseTitle.Position = UDim2.new(0, 18, 0, 18)
trainingPauseTitle.Size = UDim2.new(1, -36, 0, 28)
trainingPauseTitle.Text = "TRAINING MENU"
trainingPauseTitle.ZIndex = 83

local trainingPauseSubtitle = makeLabel(
	"Subtitle",
	trainingPausePanel,
	LABEL_FONT,
	12,
	COLORS.Muted,
	Enum.TextXAlignment.Center
)
trainingPauseSubtitle.Position = UDim2.new(0, 18, 0, 50)
trainingPauseSubtitle.Size = UDim2.new(1, -36, 0, 24)
trainingPauseSubtitle.Text = "Practice stays active until you exit."
trainingPauseSubtitle.ZIndex = 83

local trainingResumeButton = makeButton("ResumeButton", trainingPausePanel, "RESUME", COLORS.BlueLight)
trainingResumeButton.Position = UDim2.new(0, 28, 0, 92)
trainingResumeButton.Size = UDim2.new(1, -56, 0, 42)
trainingResumeButton.ZIndex = 83

local trainingExitButton = makeButton("ExitToMenuButton", trainingPausePanel, "EXIT TO MENU", COLORS.Yellow)
trainingExitButton.Position = UDim2.new(0, 28, 0, 146)
trainingExitButton.Size = UDim2.new(1, -56, 0, 42)
trainingExitButton.ZIndex = 83

------------------------------------------------------------------------
-- State helpers
------------------------------------------------------------------------
local currentPlayerTank = nil
local currentEnemyTank = nil
local elapsedSinceRefresh = 0
local displayedBolts = nil
local lastRewardSequence = tonumber(localPlayer:GetAttribute("LastBoltsRewardSequence")) or 0
local rewardToken = 0
local lowHpPulseActive = false
local lowHpTween = nil
local fillTweenState = {}
local resultVisible = false
local trainingMenuOpen = false
local trainingMenuToken = 0

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function isMobile()
	return HudDeviceUtils.IsMobileLayout()
end

local function getSafeTopOffset()
	local ok, topLeftInset = pcall(function()
		local topLeft = GuiService:GetGuiInset()
		return topLeft
	end)

	if ok and typeof(topLeftInset) == "Vector2" then
		return math.clamp(topLeftInset.Y, 0, 44)
	end

	return 0
end

local function getTopBarTargetPosition()
	return UDim2.new(0, 0, 0, getSafeTopOffset())
end

local function getMatchMode()
	return root:GetAttribute("MatchMode")
end

local function isDuelHudMode()
	return getMatchMode() == "PvP" and SCRIPTED_DUEL_HUD_ENABLED
end

local function isTrainingHudMode()
	return getMatchMode() == "Training" and SCRIPTED_TRAINING_HUD_ENABLED
end

local function isHudVisible()
	if not (isDuelHudMode() or isTrainingHudMode()) then
		return false
	end

	local mode = localPlayer:GetAttribute("PlayerMode")
	return mode == "InMatch"
		and root:GetAttribute("GameState") == "Playing"
end

local function updateTrainingMenuLayout()
	local topOffset = getSafeTopOffset()
	trainingMenuButton.Position = UDim2.new(1, -18, 0, topOffset + 84)
	trainingMenuButton.Size = isMobile() and UDim2.fromOffset(76, 34) or UDim2.fromOffset(82, 36)
	trainingPausePanel.Size = isMobile() and UDim2.fromOffset(286, 206) or UDim2.fromOffset(300, 214)
end

local function setTrainingMenuOpen(open)
	if open and not (isHudVisible() and isTrainingHudMode()) then
		open = false
	end

	if trainingMenuOpen == open and trainingPauseRoot.Visible == open then
		return
	end

	trainingMenuOpen = open
	trainingMenuToken += 1
	local token = trainingMenuToken

	if open then
		updateTrainingMenuLayout()
		trainingPauseRoot.Visible = true
		trainingPauseRoot.BackgroundTransparency = 1
		trainingPauseScale.Scale = 0.94

		TweenService:Create(trainingPauseRoot, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.42,
		}):Play()
		TweenService:Create(trainingPauseScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		TweenService:Create(trainingPauseRoot, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(trainingPauseScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.96,
		}):Play()

		task.delay(0.16, function()
			if token == trainingMenuToken and not trainingMenuOpen then
				trainingPauseRoot.Visible = false
			end
		end)
	end
end

local function updateTrainingMenuVisibility()
	updateTrainingMenuLayout()

	local visible = isHudVisible() and isTrainingHudMode()
	trainingMenuButton.Visible = visible

	if not visible then
		setTrainingMenuOpen(false)
	end
end

local function getServerTimeNow()
	local ok, value = pcall(function()
		return Workspace:GetServerTimeNow()
	end)

	if ok and typeof(value) == "number" then
		return value
	end

	return os.clock()
end

local function refreshTanks()
	currentPlayerTank = TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
	currentEnemyTank = TankModelResolver.findEnemyTank(root, localPlayer.UserId)
end

local function getTankId(model)
	if model == nil or model.Parent == nil then
		return nil
	end

	return model:GetAttribute("TankId") or model.Name
end

local function getTankHealth(model, fallbackMax)
	if model == nil or model.Parent == nil then
		return nil, fallbackMax
	end

	local maxHealth = tonumber(model:GetAttribute("MaxHealth"))
	local health = tonumber(model:GetAttribute("Health"))

	if maxHealth == nil and health == nil then
		return nil, fallbackMax
	end

	if maxHealth == nil then
		maxHealth = math.max(1, health or fallbackMax)
	end

	if health == nil then
		health = maxHealth
	end

	return health, maxHealth
end

------------------------------------------------------------------------
-- Health bars
------------------------------------------------------------------------
local function hpColor(ratio, friendly)
	if ratio <= 0.3 then
		return COLORS.Red
	elseif ratio <= 0.6 then
		return COLORS.Yellow
	end

	return friendly and COLORS.GreenLight or COLORS.RedLight
end

local function tweenFill(fill, ratio, color)
	local clampedRatio = clamp01(ratio)
	local state = fillTweenState[fill]

	if state ~= nil
		and math.abs((state.Ratio or 0) - clampedRatio) < 0.005
		and state.Color == color
	then
		return
	end

	if state == nil then
		state = {}
		fillTweenState[fill] = state
	end

	if state.SizeTween ~= nil then
		state.SizeTween:Cancel()
	end

	if state.ColorTween ~= nil then
		state.ColorTween:Cancel()
	end

	state.Ratio = clampedRatio
	state.Color = color
	state.SizeTween = TweenService:Create(fill, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(clampedRatio, 0, 1, 0),
	})
	state.ColorTween = TweenService:Create(fill, TweenInfo.new(0.28), {
		BackgroundColor3 = color,
	})
	state.SizeTween:Play()
	state.ColorTween:Play()
end

local function setFillImmediate(fill, ratio, color)
	local clampedRatio = clamp01(ratio)
	local state = fillTweenState[fill]

	if state ~= nil then
		if state.SizeTween ~= nil then
			state.SizeTween:Cancel()
		end

		if state.ColorTween ~= nil then
			state.ColorTween:Cancel()
		end

		state.Ratio = clampedRatio
		state.Color = color
	end

	fill.Size = UDim2.new(clampedRatio, 0, 1, 0)
	fill.BackgroundColor3 = color
end

local function setLowHpPulse(active)
	if active == lowHpPulseActive then
		return
	end

	lowHpPulseActive = active

	if playerStroke == nil then
		return
	end

	if lowHpTween ~= nil then
		lowHpTween:Cancel()
		lowHpTween = nil
	end

	if active then
		playerStroke.Color = COLORS.Red
		lowHpTween = TweenService:Create(playerStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0,
		})
		lowHpTween:Play()
	else
		playerStroke.Color = COLORS.Border
		TweenService:Create(playerStroke, TweenInfo.new(0.25), { Transparency = 0.25 }):Play()
	end
end

local function updatePlayerHealth()
	local health, maxHealth = getTankHealth(currentPlayerTank, 100)

	if health == nil then
		playerHpValue.Text = "--"
		tweenFill(playerHpFill, 0, COLORS.Muted)
		setLowHpPulse(false)
		return
	end

	local ratio = clamp01(health / math.max(1, maxHealth))
	playerHpValue.Text = tostring(math.floor(health + 0.5))
	playerHpValue.TextColor3 = hpColor(ratio, true)
	tweenFill(playerHpFill, ratio, hpColor(ratio, true))
	setLowHpPulse(ratio > 0 and ratio <= 0.3)
end

local function updateEnemyHealth()
	local health, maxHealth = getTankHealth(currentEnemyTank, 100)

	if health == nil then
		enemyHpValue.Text = "--"
		tweenFill(enemyHpFill, 0, COLORS.Muted)
		return
	end

	local ratio = clamp01(health / math.max(1, maxHealth))
	enemyHpValue.Text = tostring(math.floor(health + 0.5))
	enemyHpValue.TextColor3 = hpColor(ratio, false)
	tweenFill(enemyHpFill, ratio, hpColor(ratio, false))
end

------------------------------------------------------------------------
-- Reload (driven by server attributes on the player's tank)
------------------------------------------------------------------------
local reloadWasReady = true

local function getReloadState()
	local model = currentPlayerTank

	if model == nil or model.Parent == nil then
		return {
			Progress = 0,
			Ready = false,
			HasTank = false,
			HasPresentationData = false,
		}
	end

	if model:GetAttribute("ReloadReady") == true then
		return {
			Progress = 1,
			Ready = true,
			HasTank = true,
			HasPresentationData = true,
		}
	end

	local lastShot = model:GetAttribute("LastShotAtServerTime")
	local duration = model:GetAttribute("ReloadDuration") or RELOAD_FALLBACK_DURATION

	if typeof(lastShot) ~= "number" or duration <= 0 then
		local ready = model:GetAttribute("CanShoot") ~= false

		return {
			Progress = ready and 1 or 0,
			Ready = ready,
			HasTank = true,
			HasPresentationData = false,
		}
	end

	local progress = clamp01((getServerTimeNow() - lastShot) / duration)

	return {
		Progress = progress,
		Ready = progress >= 1,
		HasTank = true,
		HasPresentationData = true,
	}
end

local function updateReload()
	local reloadState = getReloadState()
	local progress = reloadState.Progress
	reloadBarFill.Size = UDim2.new(progress, 0, 1, 0)

	local ready = reloadState.Ready

	if reloadState.HasTank == false then
		reloadBarFill.BackgroundColor3 = COLORS.Muted
		reloadTitle.Text = "WAITING"
		reloadTitle.TextColor3 = COLORS.Muted
		playerReloadLabel.Visible = false
		playerReloadTrack.Visible = false
		setFillImmediate(playerReloadFill, 0, COLORS.Muted)
	elseif ready then
		reloadBarFill.BackgroundColor3 = COLORS.GreenLight
		reloadTitle.Text = "READY"
		reloadTitle.TextColor3 = COLORS.GreenLight
		playerReloadLabel.Text = "READY"
		playerReloadLabel.TextColor3 = COLORS.GreenLight
		setFillImmediate(playerReloadFill, 1, COLORS.GreenLight)
	else
		reloadBarFill.BackgroundColor3 = COLORS.BlueLight
		reloadTitle.Text = "RELOAD"
		reloadTitle.TextColor3 = COLORS.Muted
		playerReloadLabel.Text = math.floor(progress * 100) .. "%"
		playerReloadLabel.TextColor3 = COLORS.Muted
		setFillImmediate(playerReloadFill, progress, COLORS.BlueLight)
	end

	if reloadState.HasTank ~= false then
		playerReloadTrack.Visible = reloadState.HasPresentationData
		playerReloadLabel.Visible = reloadState.HasPresentationData
	end

	if ready and not reloadWasReady then
		-- Brief "ready" punch.
		reloadIcon.TextColor3 = COLORS.GreenLight
		TweenService:Create(reloadIcon, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = reloadIcon.Rotation + 180,
		}):Play()
		task.delay(0.4, function()
			reloadIcon.TextColor3 = COLORS.BlueLight
		end)
	end

	reloadWasReady = ready
end

------------------------------------------------------------------------
-- Series score
------------------------------------------------------------------------
local lastYouScore = nil
local lastOppScore = nil

local function getLocalSeriesScore()
	local playerSide = root:GetAttribute("PlayerSideScore")
	local opponentSide = root:GetAttribute("OpponentSideScore")
	local you = playerSide or root:GetAttribute("PlayerWins") or 0
	local opp = opponentSide or root:GetAttribute("DummyWins") or 0

	if root:GetAttribute("MatchMode") == "PvP" then
		local tankId = getTankId(currentPlayerTank)
		if tankId ~= nil and tankId == root:GetAttribute("OpponentSideTankId") then
			you, opp = opp, you
		end
	end

	return you, opp
end

local function updateModeContent()
	local trainingMode = isTrainingHudMode()
	-- In Training compact mode, top player/enemy panels and the long hint text are
	-- suppressed — world bars under tanks carry that info instead.
	local compact = TRAINING_COMPACT_HUD and trainingMode

	playerName.Text = "YOU"
	enemyName.Text = trainingMode and "TARGET" or "ENEMY"
	scoreBox.Size = trainingMode and UDim2.fromOffset(260, 50) or UDim2.fromOffset(168, 50)

	for _, label in ipairs({ youNum, youSub, divider, oppNum, oppSub }) do
		label.Visible = not trainingMode
	end

	trainingTitle.Visible = trainingMode
	trainingHint.Visible = trainingMode and not compact
	playerPanel.Visible = not compact
	enemyPanel.Visible = not compact
end

local function punchScale(scale)
	scale.Scale = 1
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.4,
	}):Play()
	task.delay(0.13, function()
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
end

local function updateScore()
	updateModeContent()

	if isTrainingHudMode() then
		return
	end

	local you, opp = getLocalSeriesScore()
	you = math.floor(you)
	opp = math.floor(opp)

	if you ~= lastYouScore then
		youNum.Text = tostring(you)
		if lastYouScore ~= nil and you > lastYouScore then
			punchScale(youNumScale)
		end
		lastYouScore = you
	end

	if opp ~= lastOppScore then
		oppNum.Text = tostring(opp)
		if lastOppScore ~= nil and opp > lastOppScore then
			punchScale(oppNumScale)
		end
		lastOppScore = opp
	end
end

------------------------------------------------------------------------
-- Round/match result overlay
------------------------------------------------------------------------
local function getLocalRoundResult(globalResult)
	local tankId = getTankId(currentPlayerTank)
	local winnerTankId = root:GetAttribute("RoundWinnerTankId")
	local loserTankId = root:GetAttribute("RoundLoserTankId")

	if tankId ~= nil and winnerTankId == tankId then
		return "Win"
	end

	if tankId ~= nil and loserTankId == tankId then
		return "Lose"
	end

	return globalResult
end

local function getLocalMatchResult(matchResult)
	local tankId = getTankId(currentPlayerTank)
	local winnerTankId = root:GetAttribute("MatchWinnerTankId")
	local loserTankId = root:GetAttribute("MatchLoserTankId")

	if tankId ~= nil and winnerTankId == tankId then
		return "Win"
	end

	if tankId ~= nil and loserTankId == tankId then
		return "Loss"
	end

	if matchResult == "PlayerMatchWin" then
		return tankId == root:GetAttribute("OpponentSideTankId") and "Loss" or "Win"
	elseif matchResult == "DummyMatchWin" then
		return tankId == root:GetAttribute("OpponentSideTankId") and "Win" or "Loss"
	end

	return ""
end

local function getCountdownSeconds(deadlineAttributeName, fallbackRemainingAttributeName)
	local deadline = root:GetAttribute(deadlineAttributeName)

	if typeof(deadline) == "number" and deadline > 0 then
		return math.max(0, math.ceil(deadline - getServerTimeNow()))
	end

	local fallbackRemaining = root:GetAttribute(fallbackRemainingAttributeName)

	if typeof(fallbackRemaining) == "number" then
		return math.max(0, math.ceil(fallbackRemaining))
	end

	return 0
end

local function hideResultOverlay()
	if not resultVisible then
		return
	end

	resultVisible = false
	TweenService:Create(resultOverlay, TweenInfo.new(0.16), {
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.18, function()
		if not resultVisible then
			resultOverlay.Visible = false
		end
	end)
end

local function showResultOverlay(title, subtitle, titleColor, buttonText)
	resultTitle.Text = title
	resultTitle.TextColor3 = titleColor
	resultSubtitle.Text = subtitle
	resultButtonLike.Text = buttonText

	if resultVisible then
		return
	end

	resultVisible = true
	resultOverlay.Visible = true
	resultOverlay.BackgroundTransparency = 1
	resultTitle.TextTransparency = 0
	resultTitle.TextStrokeTransparency = 0.28
	resultTitleScale.Scale = 0.78
	resultSubtitle.TextTransparency = 1
	resultButtonLike.TextTransparency = 1
	resultButtonLike.BackgroundTransparency = 1

	TweenService:Create(resultOverlay, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.38,
	}):Play()
	TweenService:Create(resultTitleScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(0.16, function()
		if not resultVisible then
			return
		end

		TweenService:Create(resultSubtitle, TweenInfo.new(0.18), {
			TextTransparency = 0,
		}):Play()
	end)

	task.delay(0.28, function()
		if not resultVisible then
			return
		end

		TweenService:Create(resultButtonLike, TweenInfo.new(0.2), {
			BackgroundTransparency = 0,
			TextTransparency = 0,
		}):Play()
	end)
end

local function updateResultOverlay()
	if not isHudVisible() then
		hideResultOverlay()
		return
	end

	local roundResult = getLocalRoundResult(root:GetAttribute("RoundResult") or "Playing")
	local roundEnded = root:GetAttribute("RoundEnded") == true or roundResult == "Win" or roundResult == "Lose"
	local matchEnded = root:GetAttribute("MatchEnded") == true
	local roundState = root:GetAttribute("RoundState")
	local youWins, oppWins = getLocalSeriesScore()

	if isTrainingHudMode() then
		if matchEnded and roundState == "MatchEnd" then
			local seconds = getCountdownSeconds("MatchResultAt", "ResultStartsIn")
			showResultOverlay(
				"TRAINING DONE",
				"TARGET PRACTICE COMPLETE  ·  RESULT IN " .. seconds,
				COLORS.Yellow,
				"RESULT"
			)
		elseif roundEnded and not matchEnded and roundState == "RoundEnd" then
			local seconds = getCountdownSeconds("RoundResetAt", "NextRoundStartsIn")
			local title = roundResult == "Win" and "TARGET DESTROYED" or "ROUND ENDED"
			local color = roundResult == "Win" and COLORS.GreenLight or COLORS.Yellow
			showResultOverlay(
				title,
				"PRACTICE RICOCHETS  ·  NEXT TARGET IN " .. seconds,
				color,
				"NEXT TARGET"
			)
		else
			hideResultOverlay()
		end
	elseif matchEnded and roundState == "MatchEnd" then
		local localMatchResult = getLocalMatchResult(root:GetAttribute("MatchResult") or "")
		local title = "MATCH ENDED"
		local color = COLORS.Yellow

		if localMatchResult == "Win" then
			title = "VICTORY"
			color = COLORS.GreenLight
		elseif localMatchResult == "Loss" then
			title = "DEFEAT"
			color = COLORS.RedLight
		end

		local seconds = getCountdownSeconds("MatchResultAt", "ResultStartsIn")
		showResultOverlay(
			title,
			"FINAL " .. math.floor(youWins) .. " : " .. math.floor(oppWins) .. "  ·  RESULT IN " .. seconds,
			color,
			"RESULT"
		)
	elseif roundEnded and not matchEnded and roundState == "RoundEnd" then
		local title = "ROUND ENDED"
		local color = COLORS.Yellow

		if roundResult == "Win" then
			title = "ROUND WON"
			color = COLORS.GreenLight
		elseif roundResult == "Lose" then
			title = "ROUND LOST"
			color = COLORS.RedLight
		end

		local seconds = getCountdownSeconds("RoundResetAt", "NextRoundStartsIn")
		showResultOverlay(
			title,
			"SCORE " .. math.floor(youWins) .. " : " .. math.floor(oppWins) .. "  ·  NEXT ROUND IN " .. seconds,
			color,
			"NEXT ROUND"
		)
	else
		hideResultOverlay()
	end
end

------------------------------------------------------------------------
-- Bolts wallet
------------------------------------------------------------------------
local function getVisibleBolts()
	local persistentAttribute = localPlayer:GetAttribute("PersistentBolts")
	local unsavedAttribute = localPlayer:GetAttribute("UnsavedBolts")

	if persistentAttribute == nil and unsavedAttribute == nil then
		return nil
	end

	local persistent = tonumber(persistentAttribute)
	if persistent ~= nil then
		return math.max(0, math.floor(persistent))
	end

	return math.max(0, math.floor(tonumber(unsavedAttribute) or 0))
end

local function tweenBoltsCount(target)
	if target == nil then
		boltsPanel.Visible = false
		displayedBolts = nil
		return
	end

	boltsPanel.Visible = true

	if displayedBolts == nil then
		displayedBolts = target
		boltsValue.Text = tostring(target)
		return
	end

	local start = displayedBolts
	displayedBolts = target

	if start == target then
		return
	end

	local startClock = os.clock()
	local duration = 0.45
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = clamp01((os.clock() - startClock) / duration)
		local value = math.floor(start + (target - start) * alpha + 0.5)
		boltsValue.Text = tostring(value)
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

local function updateBolts()
	if isDuelHudMode() then
		boltsPanel.Visible = false
		displayedBolts = nil
		return
	end

	tweenBoltsCount(getVisibleBolts())
end

local function showBoltsReward()
	if isDuelHudMode() then
		return
	end

	if getVisibleBolts() == nil then
		return
	end

	local amount = math.max(0, math.floor(tonumber(localPlayer:GetAttribute("LastBoltsRewardAmount")) or 0))
	if amount <= 0 then
		return
	end

	rewardToken += 1
	local token = rewardToken

	boltsReward.Text = "+" .. amount
	boltsReward.TextColor3 = COLORS.Green
	boltsReward.TextTransparency = 0
	boltsReward.Position = UDim2.new(0.5, 0, 0, 0)

	TweenService:Create(boltsReward, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, -22),
		TextTransparency = 1,
	}):Play()

	task.delay(0.9, function()
		if token == rewardToken then
			boltsReward.Text = ""
		end
	end)
end

local function onRewardSequenceChanged()
	local sequence = tonumber(localPlayer:GetAttribute("LastBoltsRewardSequence")) or 0
	if sequence == lastRewardSequence then
		return
	end

	lastRewardSequence = sequence
	showBoltsReward()
	updateBolts()
end

------------------------------------------------------------------------
-- Screen-space combat feedback (RICOCHET / NO PEN / HIT)
------------------------------------------------------------------------
local function spawnFeedback(text, color)
	local slot = nil

	for _, candidate in ipairs(feedbackPool) do
		if candidate.InUse ~= true then
			slot = candidate
			break
		end
	end

	if slot == nil then
		return
	end

	slot.InUse = true
	slot.Token += 1
	local token = slot.Token

	local label = slot.Label
	local scale = slot.Scale

	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.4
	label.Position = UDim2.new(0.5, math.random(-60, 60), 0.45, math.random(-30, 30))
	label.Visible = true

	scale.Scale = 0.7

	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.1,
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 26),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(0.95, function()
		if token ~= slot.Token then
			return
		end

		slot.InUse = false
		label.Visible = false
		label.Text = ""
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
	end)
end

local function onCombatFeedback(payload)
	if not isHudVisible() then
		return
	end

	if typeof(payload) ~= "table" or payload.AudioOnly == true then
		return
	end

	local text = tostring(payload.Text or payload.Type or "")
	if text == "" then
		return
	end

	local upper = string.upper(text)
	-- Only surface the readable "wow" moments on-screen; numeric hits stay as
	-- world billboards handled by WOBCombatFeedbackOverlay.
	local color
	if string.find(upper, "RICOCHET") then
		color = COLORS.Yellow
	elseif string.find(upper, "NO PEN") or string.find(upper, "NOPEN") or string.find(upper, "BLOCK") then
		color = COLORS.Muted
	else
		return
	end

	spawnFeedback(upper, color)
end

------------------------------------------------------------------------
-- Visibility + entrance animation
------------------------------------------------------------------------
local wasVisible = false

local function applyMobileLayout()
	-- On phones the bottom-left is occupied by the movement joystick, so the
	-- reload/bolts bar is hidden there (reload is still shown in the player
	-- panel mini bar) and the top panels are nudged inward.
	-- In Training compact mode the bottom bar is also hidden (world bars carry
	-- reload state; bolts panel is not needed during training).
	local mobile = isMobile()
	local hideBottom = mobile or (TRAINING_COMPACT_HUD and isTrainingHudMode())
	bottomBar.Visible = not hideBottom
	updateTrainingMenuLayout()

	if wasVisible then
		topBar.Position = getTopBarTargetPosition()
	end
end

local function playEntrance()
	local topTarget = getTopBarTargetPosition()
	topBar.Position = UDim2.new(0, 0, 0, topTarget.Y.Offset - 80)
	bottomBar.Position = UDim2.new(0, 0, 1, 80)
	scoreBoxScale.Scale = 0.88
	topShade.BackgroundTransparency = 1
	bottomShade.BackgroundTransparency = 1

	for _, panel in ipairs({ playerPanel, enemyPanel, scoreBox, reloadPanel, boltsPanel }) do
		panel.BackgroundTransparency = 1

		local stroke = panel:FindFirstChildOfClass("UIStroke")
		local shouldFadeStroke = stroke ~= nil and not (panel == playerPanel and lowHpPulseActive)
		if shouldFadeStroke then
			stroke.Transparency = 1
		end

		TweenService:Create(panel, TweenInfo.new(0.24), {
			BackgroundTransparency = PANEL_TRANSPARENCY,
		}):Play()

		if shouldFadeStroke then
			TweenService:Create(stroke, TweenInfo.new(0.24), {
				Transparency = 0.25,
			}):Play()
		end
	end

	TweenService:Create(topBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = topTarget,
	}):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 1, 0),
	}):Play()
	TweenService:Create(scoreBoxScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(topShade, TweenInfo.new(0.25), {
		BackgroundTransparency = 0,
	}):Play()
	TweenService:Create(bottomShade, TweenInfo.new(0.25), {
		BackgroundTransparency = 0,
	}):Play()
end

local function refreshAll()
	refreshTanks()
	updatePlayerHealth()
	updateEnemyHealth()
	updateScore()
	updateBolts()
	updateResultOverlay()
	updateTrainingMenuVisibility()
end

local function applyVisibility()
	local visible = isHudVisible()
	applyMobileLayout()

	if visible and not wasVisible then
		gui.Enabled = true
		refreshAll()
		playEntrance()
	elseif not visible and wasVisible then
		gui.Enabled = false
		setLowHpPulse(false)
		hideResultOverlay()
	elseif visible then
		gui.Enabled = true
	end

	updateTrainingMenuVisibility()
	wasVisible = visible
end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------
trainingMenuButton.Activated:Connect(function()
	setTrainingMenuOpen(not trainingMenuOpen)
end)

trainingResumeButton.Activated:Connect(function()
	setTrainingMenuOpen(false)
end)

trainingExitButton.Activated:Connect(function()
	setTrainingMenuOpen(false)
	returnToMenuRequestEvent:FireServer()
end)

combatFeedbackEvent.OnClientEvent:Connect(onCombatFeedback)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(function()
	refreshAll()
	applyVisibility()
end)
localPlayer:GetAttributeChangedSignal("PersistentBolts"):Connect(updateBolts)
localPlayer:GetAttributeChangedSignal("UnsavedBolts"):Connect(updateBolts)
localPlayer:GetAttributeChangedSignal("LastBoltsRewardSequence"):Connect(onRewardSequenceChanged)

root:GetAttributeChangedSignal("GameState"):Connect(function()
	refreshAll()
	applyVisibility()
end)
root:GetAttributeChangedSignal("MatchMode"):Connect(function()
	refreshAll()
	applyVisibility()
end)
root:GetAttributeChangedSignal("PlayerWins"):Connect(updateScore)
root:GetAttributeChangedSignal("DummyWins"):Connect(updateScore)
root:GetAttributeChangedSignal("PlayerSideScore"):Connect(updateScore)
root:GetAttributeChangedSignal("OpponentSideScore"):Connect(updateScore)
root:GetAttributeChangedSignal("RoundResult"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("RoundEnded"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("RoundState"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("RoundWinnerTankId"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("RoundLoserTankId"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("RoundResetAt"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("NextRoundStartsIn"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("MatchEnded"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("MatchResult"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("MatchWinnerTankId"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("MatchLoserTankId"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("MatchResultAt"):Connect(updateResultOverlay)
root:GetAttributeChangedSignal("ResultStartsIn"):Connect(updateResultOverlay)

root.DescendantAdded:Connect(function()
	if isHudVisible() then
		refreshTanks()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not gui.Enabled then
		return
	end

	updateReload()

	elapsedSinceRefresh += deltaTime
	if elapsedSinceRefresh >= 0.15 then
		elapsedSinceRefresh = 0
		refreshTanks()
		updatePlayerHealth()
		updateEnemyHealth()
		updateScore()
		updateResultOverlay()
	end
end)

refreshAll()
applyVisibility()

print("[WOB] Scripted duel/training HUD initialised")
