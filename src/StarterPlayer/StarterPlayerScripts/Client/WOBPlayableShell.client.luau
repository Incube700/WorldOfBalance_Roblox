local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local root = Workspace:WaitForChild("WOB_Generated")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local HudConfig = require(configs:WaitForChild("HudConfig"))
local MobileControlsConfig = require(configs:WaitForChild("MobileControlsConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startMatchRequestEvent = remotes:WaitForChild("StartMatchRequestEvent")
local returnToMenuRequestEvent = remotes:WaitForChild("ReturnToMenuRequestEvent")
local rematchRequestEvent = remotes:WaitForChild("RematchRequestEvent")

local GUI_NAME = "WOBPlayableShellGui"
local MAIN_MENU_PANEL_NAME = "MainMenuPanel"
local RESULT_PANEL_NAME = "ResultScreenPanel"
local STATS_PANEL_NAME = "StatsPanel"
local SETTINGS_PANEL_NAME = "SettingsPanel"
local GAME_STATE_MENU = "Menu"
local GAME_STATE_PLAYING = "Playing"
local GAME_STATE_RESULT = "Result"
local SHELL_PANEL_MENU = "Menu"
local SHELL_PANEL_STATS = "Stats"
local SHELL_PANEL_SETTINGS = "Settings"
local SHELL_PANEL_HIDDEN = "Hidden"
local PLAYER_MODE_LOBBY = "Lobby"
local PLAYER_MODE_QUEUED = "QueuedForDuel"
local PLAYER_MODE_IN_MATCH = "InMatch"
local PLAYER_MODE_IN_BATTLE_ARENA = "InBattleArena"
local PLAYER_MODE_ARENA_RESPAWNING = "ArenaRespawning"
local PLAYER_MODE_RESULT = "Result"
local LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE = "LastCrystalsRewardAmount"
local LAST_CRYSTALS_REWARD_REASON_ATTRIBUTE = "LastCrystalsRewardReason"
local LAST_CRYSTALS_REWARD_MATCH_ID_ATTRIBUTE = "LastCrystalsRewardMatchId"

local HUD_GUI_NAMES = {
	"HUD",
	"WOBRoundStatusEmergencyGui",
	"WOBRoundStatusOverlayGui",
	"WOBSeriesStatusRuntimeGui",
}

local PERSISTENT_HUD_PANEL_NAMES = {
	"EnemyStatusPanel",
	"WeaponStatusPanel",
	"PlayerStatusPanel",
	"MatchSeriesPanel",
}

local ALL_HUD_PANEL_NAMES = {
	"EnemyStatusPanel",
	"WeaponStatusPanel",
	"PlayerStatusPanel",
	"MatchSeriesPanel",
	"RoundStatusPanel",
}

local STAT_ATTRIBUTES = {
	"StatsShotsFired",
	"StatsHits",
	"StatsRicochets",
	"StatsRicochetHits",
	"StatsSelfHits",
	"StatsDamageDealt",
	"StatsDamageTaken",
	"StatsRoundsWon",
	"StatsRoundsLost",
	"StatsMatchResult",
	"MatchResult",
}

local RESULT_STAT_KEYS = {
	"MatchResult",
	"RoundsWon",
	"RoundsLost",
	"ShotsFired",
	"Hits",
	"Accuracy",
	"Ricochets",
	"RicochetHits",
	"SelfHits",
	"DamageDealt",
	"DamageTaken",
}

local TOTAL_STAT_ROWS = {
	{ Key = "TotalMatches", Label = "Total matches" },
	{ Key = "TotalWins", Label = "Total wins" },
	{ Key = "TotalLosses", Label = "Total losses" },
	{ Key = "WinRate", Label = "Win rate" },
	{ Key = "TotalShotsFired", Label = "Total shots fired" },
	{ Key = "TotalHits", Label = "Total hits" },
	{ Key = "Accuracy", Label = "Accuracy" },
	{ Key = "TotalRicochets", Label = "Total ricochets" },
	{ Key = "TotalRicochetHits", Label = "Total ricochet hits" },
	{ Key = "TotalSelfHits", Label = "Total self hits" },
	{ Key = "TotalDamageDealt", Label = "Total damage dealt" },
	{ Key = "TotalDamageTaken", Label = "Total damage taken" },
}

local TOTAL_STAT_KEYS = {
	"TotalMatches",
	"TotalWins",
	"TotalLosses",
	"TotalShotsFired",
	"TotalHits",
	"TotalRicochets",
	"TotalRicochetHits",
	"TotalSelfHits",
	"TotalDamageDealt",
	"TotalDamageTaken",
}

local statValueLabels = {}
local totalStatValueLabels = {}
local connectedButtons = {}
local animatedButtons = {}
local activeShellPanel = SHELL_PANEL_HIDDEN
local resultPanelWasVisible = false
local DEBUG_SHELL = false

local COLORS = {
	Overlay = Color3.fromRGB(7, 9, 13),
	Panel = Color3.fromRGB(13, 17, 23),
	PanelSoft = Color3.fromRGB(17, 24, 39),
	Border = Color3.fromRGB(31, 41, 55),
	Text = Color3.fromRGB(226, 232, 240),
	Muted = Color3.fromRGB(148, 163, 184),
	Yellow = Color3.fromRGB(250, 204, 21),
	Blue = Color3.fromRGB(59, 130, 246),
	Teal = Color3.fromRGB(45, 212, 191),
	Purple = Color3.fromRGB(168, 85, 247),
	Disabled = Color3.fromRGB(48, 55, 68),
}

local function findDescendant(parent, name)
	local directChild = parent:FindFirstChild(name)

	if directChild ~= nil then
		return directChild
	end

	return parent:FindFirstChild(name, true)
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent

	return instance
end

local function isShellScreenGui(instance)
	return instance:IsA("ScreenGui")
		and (
			instance.Name == GUI_NAME
			or instance:FindFirstChild(MAIN_MENU_PANEL_NAME) ~= nil
			or instance:FindFirstChild(RESULT_PANEL_NAME) ~= nil
			or instance:FindFirstChild(STATS_PANEL_NAME) ~= nil
			or instance:FindFirstChild(SETTINGS_PANEL_NAME) ~= nil
		)
end

local function getShellScreenGuis()
	local screenGuis = {}

	for _, child in ipairs(playerGui:GetChildren()) do
		if isShellScreenGui(child) then
			table.insert(screenGuis, child)
		end
	end

	return screenGuis
end

local function findPrimaryShellGui()
	local firstShellGui = nil

	for _, screenGui in ipairs(getShellScreenGuis()) do
		if firstShellGui == nil then
			firstShellGui = screenGui
		end

		if screenGui.Name == GUI_NAME then
			return screenGui
		end
	end

	return firstShellGui
end

local function addCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function getShellMobileLayout()
	return UserInputService.TouchEnabled == true or MobileControlsConfig.ForceEnabledInStudio == true
end

local function addPadding(parent, padding)
	local uiPadding = parent:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	uiPadding.PaddingTop = UDim.new(0, padding)
	uiPadding.PaddingBottom = UDim.new(0, padding)
	uiPadding.PaddingLeft = UDim.new(0, padding)
	uiPadding.PaddingRight = UDim.new(0, padding)
	uiPadding.Parent = parent
end

local function addSizeConstraint(parent, minSize, maxSize)
	local constraint = parent:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	constraint.MinSize = minSize
	constraint.MaxSize = maxSize
	constraint.Parent = parent
end

local function ensureButtonScale(button)
	local scale = button:FindFirstChild("ShellButtonScale")

	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Name = "ShellButtonScale"
		scale.Parent = button
	end

	return scale
end

local function animateButtonScale(button, scaleValue, duration)
	local scale = ensureButtonScale(button)
	TweenService:Create(scale, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = scaleValue,
	}):Play()
end

local function bindButtonAnimation(button)
	if animatedButtons[button] == true then
		return
	end

	animatedButtons[button] = true
	ensureButtonScale(button)

	button.MouseEnter:Connect(function()
		if button.Active then
			animateButtonScale(button, 1.025, 0.1)
		end
	end)

	button.MouseLeave:Connect(function()
		animateButtonScale(button, 1, 0.1)
	end)

	button.InputBegan:Connect(function(input)
		if not button.Active then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			animateButtonScale(button, 0.97, 0.06)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			animateButtonScale(button, 1, 0.08)
		end
	end)
end

local function styleLabel(label, text, textSize, color)
	if not label:IsA("TextLabel") then
		return
	end

	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function styleButton(button, text, enabled, accentColor)
	if not button:IsA("TextButton") then
		return
	end

	accentColor = accentColor or COLORS.Yellow
	button.BackgroundColor3 = enabled and COLORS.PanelSoft or COLORS.Disabled
	button.BackgroundTransparency = enabled and 0.04 or 0.24
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = enabled and COLORS.Text or COLORS.Muted
	button.TextSize = 20
	button.TextWrapped = true
	button.AutoButtonColor = enabled
	button.Active = enabled

	pcall(function()
		button.Selectable = enabled
	end)

	addCorner(button, UDim.new(0, 8))
	addStroke(button, enabled and accentColor or COLORS.Border, enabled and 0.22 or 0.55, 1)
	bindButtonAnimation(button)
end

local function styleOverlayPanel(panel)
	if not panel:IsA("Frame") then
		return
	end

	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.Position = UDim2.new(0, 0, 0, 0)
	panel.BackgroundColor3 = COLORS.Overlay
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
end

local function createMenu(screenGui)
	local panel = getOrCreate(screenGui, "Frame", MAIN_MENU_PANEL_NAME)
	styleOverlayPanel(panel)

	local content = getOrCreate(panel, "Frame", "MenuContent")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.new(0.5, 0, 0.52, 0)
	content.Size = UDim2.new(0.9, 0, 0, 360)
	content.BackgroundColor3 = COLORS.Panel
	content.BackgroundTransparency = 0.08
	content.BorderSizePixel = 0
	addCorner(content, UDim.new(0, 8))
	addStroke(content, COLORS.Border, 0.22, 1)
	addPadding(content, 20)
	addSizeConstraint(content, Vector2.new(300, 330), Vector2.new(460, 390))

	for _, obsoleteName in ipairs({ "PlayButton", "DuelButton", "ArenaButton", "CloseButton" }) do
		local obsoleteButton = content:FindFirstChild(obsoleteName)

		if obsoleteButton ~= nil then
			obsoleteButton:Destroy()
		end
	end

	local title = getOrCreate(content, "TextLabel", "TitleLabel")
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 70)
	styleLabel(title, "WORLD OF BALANCE", 32, COLORS.Text)
	title.Font = Enum.Font.GothamBlack

	local subtitle = getOrCreate(content, "TextLabel", "SubtitleLabel")
	subtitle.Position = UDim2.new(0, 0, 0, 68)
	subtitle.Size = UDim2.new(1, 0, 0, 34)
	styleLabel(subtitle, "RICOCHET TANKS", 17, COLORS.Yellow)
	subtitle.Font = Enum.Font.GothamBold

	local buttonNames = {
		{ Name = "TrainingButton", Text = "TRAINING", Enabled = true, Y = 130, Accent = COLORS.Yellow },
		{ Name = "StatsButton", Text = "STATS", Enabled = true, Y = 198, Accent = COLORS.Blue },
		{ Name = "SettingsButton", Text = "SETTINGS", Enabled = true, Y = 266, Accent = COLORS.Teal },
	}

	for _, data in ipairs(buttonNames) do
		local button = getOrCreate(content, "TextButton", data.Name)
		button.Position = UDim2.new(0.08, 0, 0, data.Y)
		button.Size = UDim2.new(0.84, 0, 0, data.Name == "TrainingButton" and 58 or 52)
		styleButton(button, data.Text, data.Enabled, data.Accent)
	end

	return panel
end

local function createResultStatRow(parent, key, labelText, order)
	local row = getOrCreate(parent, "Frame", key .. "Row")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0

	local label = getOrCreate(row, "TextLabel", key .. "Label")
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0.55, 0, 1, 0)
	styleLabel(label, labelText, 16, Color3.fromRGB(198, 213, 208))
	label.TextXAlignment = Enum.TextXAlignment.Left

	local value = getOrCreate(row, "TextLabel", key .. "Value")
	value.Position = UDim2.new(0.58, 0, 0, 0)
	value.Size = UDim2.new(0.42, 0, 1, 0)
	styleLabel(value, "-", 16, Color3.fromRGB(244, 255, 248))
	value.TextXAlignment = Enum.TextXAlignment.Right
	statValueLabels[key] = value
end

local function createTotalStatRow(parent, key, labelText, order)
	local row = getOrCreate(parent, "Frame", key .. "Row")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0

	local label = getOrCreate(row, "TextLabel", key .. "NameLabel")
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0.58, 0, 1, 0)
	styleLabel(label, labelText, 16, Color3.fromRGB(198, 213, 208))
	label.TextXAlignment = Enum.TextXAlignment.Left

	local value = getOrCreate(row, "TextLabel", key .. "Label")
	value.Position = UDim2.new(0.6, 0, 0, 0)
	value.Size = UDim2.new(0.4, 0, 1, 0)
	styleLabel(value, "-", 16, Color3.fromRGB(244, 255, 248))
	value.TextXAlignment = Enum.TextXAlignment.Right
	totalStatValueLabels[key] = value
end

local function createResultScreen(screenGui)
	local panel = getOrCreate(screenGui, "Frame", RESULT_PANEL_NAME)
	styleOverlayPanel(panel)

	local content = getOrCreate(panel, "Frame", "ResultContent")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.Size = UDim2.new(0, 560, 0, 630)
	content.BackgroundColor3 = Color3.fromRGB(12, 16, 18)
	content.BackgroundTransparency = 0.08
	content.BorderSizePixel = 0
	addCorner(content, UDim.new(0, 8))
	addStroke(content, Color3.fromRGB(75, 115, 104), 0.25, 1)

	local title = getOrCreate(content, "TextLabel", "ResultTitleLabel")
	title.Position = UDim2.new(0.08, 0, 0, 24)
	title.Size = UDim2.new(0.84, 0, 0, 52)
	styleLabel(title, "Your Match Result", 30, Color3.fromRGB(241, 255, 247))
	title.Font = Enum.Font.GothamBold

	local list = getOrCreate(content, "Frame", "StatsList")
	list.Position = UDim2.new(0.1, 0, 0, 96)
	list.Size = UDim2.new(0.8, 0, 0, 370)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0

	local layout = list:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local rows = {
		{ Key = "MatchResult", Label = "Match result" },
		{ Key = "RoundsWon", Label = "Rounds won" },
		{ Key = "RoundsLost", Label = "Rounds lost" },
		{ Key = "ShotsFired", Label = "Shots fired" },
		{ Key = "Hits", Label = "Hits" },
		{ Key = "Accuracy", Label = "Accuracy" },
		{ Key = "Ricochets", Label = "Ricochets" },
		{ Key = "RicochetHits", Label = "Ricochet hits" },
		{ Key = "SelfHits", Label = "Self hits" },
		{ Key = "DamageDealt", Label = "Damage dealt" },
		{ Key = "DamageTaken", Label = "Damage taken" },
	}

	for index, row in ipairs(rows) do
		createResultStatRow(list, row.Key, row.Label, index)
	end

	local playAgainButton = getOrCreate(content, "TextButton", "PlayAgainButton")
	playAgainButton.Position = UDim2.new(0.1, 0, 1, -128)
	playAgainButton.Size = UDim2.new(0.38, 0, 0, 52)
	styleButton(playAgainButton, "Rematch", true)

	local menuButton = getOrCreate(content, "TextButton", "BackToMenuButton")
	menuButton.Position = UDim2.new(0.52, 0, 1, -128)
	menuButton.Size = UDim2.new(0.38, 0, 0, 52)
	styleButton(menuButton, "Return to Lobby", true)

	return panel
end

local function createStatsPanel(screenGui)
	local panel = getOrCreate(screenGui, "Frame", STATS_PANEL_NAME)
	styleOverlayPanel(panel)

	local content = getOrCreate(panel, "Frame", "StatsContent")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.Size = UDim2.new(0.9, 0, 0, 610)
	content.BackgroundColor3 = COLORS.Panel
	content.BackgroundTransparency = 0.08
	content.BorderSizePixel = 0
	addCorner(content, UDim.new(0, 8))
	addStroke(content, COLORS.Border, 0.22, 1)
	addSizeConstraint(content, Vector2.new(300, 430), Vector2.new(560, 630))

	local title = getOrCreate(content, "TextLabel", "StatsTitleLabel")
	title.Position = UDim2.new(0.08, 0, 0, 24)
	title.Size = UDim2.new(0.84, 0, 0, 52)
	styleLabel(title, "STATS", 30, COLORS.Text)
	title.Font = Enum.Font.GothamBlack

	local list = getOrCreate(content, "Frame", "StatsList")
	list.Position = UDim2.new(0.1, 0, 0, 96)
	list.Size = UDim2.new(0.8, 0, 0, 410)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0

	local layout = list:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, row in ipairs(TOTAL_STAT_ROWS) do
		createTotalStatRow(list, row.Key, row.Label, index)
	end

	local emptyLabel = getOrCreate(content, "TextLabel", "StatsEmptyLabel")
	emptyLabel.Position = UDim2.new(0.1, 0, 0, 104)
	emptyLabel.Size = UDim2.new(0.8, 0, 0, 70)
	styleLabel(emptyLabel, "No stats yet", 18, COLORS.Muted)
	emptyLabel.Font = Enum.Font.GothamBold
	emptyLabel.Visible = false

	local backButton = getOrCreate(content, "TextButton", "StatsBackButton")
	backButton.Position = UDim2.new(0.28, 0, 1, -88)
	backButton.Size = UDim2.new(0.44, 0, 0, 52)
	styleButton(backButton, "BACK", true, COLORS.Yellow)

	return panel
end

local function createSettingsPanel(screenGui)
	local panel = getOrCreate(screenGui, "Frame", SETTINGS_PANEL_NAME)
	styleOverlayPanel(panel)

	local content = getOrCreate(panel, "Frame", "SettingsContent")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.Size = UDim2.new(0.9, 0, 0, 340)
	content.BackgroundColor3 = COLORS.Panel
	content.BackgroundTransparency = 0.08
	content.BorderSizePixel = 0
	addCorner(content, UDim.new(0, 8))
	addStroke(content, COLORS.Border, 0.22, 1)
	addPadding(content, 18)
	addSizeConstraint(content, Vector2.new(300, 300), Vector2.new(500, 360))

	local title = getOrCreate(content, "TextLabel", "SettingsTitleLabel")
	title.Position = UDim2.new(0.08, 0, 0, 22)
	title.Size = UDim2.new(0.84, 0, 0, 44)
	styleLabel(title, "SETTINGS", 28, COLORS.Text)
	title.Font = Enum.Font.GothamBlack

	local body = getOrCreate(content, "TextLabel", "SettingsBodyLabel")
	body.Position = UDim2.new(0.1, 0, 0, 86)
	body.Size = UDim2.new(0.8, 0, 0, 118)
	styleLabel(body, "Settings coming soon\nAudio and controls toggles are not wired yet.", 17, COLORS.Muted)
	body.Font = Enum.Font.GothamBold

	local backButton = getOrCreate(content, "TextButton", "SettingsBackButton")
	backButton.Position = UDim2.new(0.28, 0, 1, -76)
	backButton.Size = UDim2.new(0.44, 0, 0, 52)
	styleButton(backButton, "BACK", true, COLORS.Yellow)

	return panel
end

local function createLobbyControls(screenGui)
	local menuButton = getOrCreate(screenGui, "TextButton", "LobbyMenuButton")
	local isMobile = getShellMobileLayout()
	menuButton.AnchorPoint = isMobile and Vector2.new(1, 0) or Vector2.new(1, 1)
	menuButton.Position = isMobile and UDim2.new(1, -18, 0, 96) or UDim2.new(1, -22, 1, -22)
	menuButton.Size = isMobile and UDim2.new(0, 76, 0, 34) or UDim2.new(0, 118, 0, 42)
	styleButton(menuButton, "MENU", true, COLORS.Yellow)
	menuButton.TextSize = isMobile and 14 or 18

	local hintLabel = getOrCreate(screenGui, "TextLabel", "LobbyHintLabel")
	hintLabel.AnchorPoint = Vector2.new(0.5, 0)
	hintLabel.Position = UDim2.new(0.5, 0, 0, 18)
	hintLabel.Size = UDim2.new(0, 520, 0, 40)
	styleLabel(hintLabel, "Choose TRAINING from MENU to start.", 17, COLORS.Text)
	hintLabel.BackgroundColor3 = COLORS.Panel
	hintLabel.BackgroundTransparency = 0.28
	hintLabel.BorderSizePixel = 0
	addCorner(hintLabel, UDim.new(0, 8))
	addStroke(hintLabel, COLORS.Border, 0.35, 1)

	return menuButton, hintLabel
end

local function bindResultStatLabels(resultPanel)
	table.clear(statValueLabels)

	for _, key in ipairs(RESULT_STAT_KEYS) do
		local valueLabel = findDescendant(resultPanel, key .. "Value")

		if valueLabel ~= nil and valueLabel:IsA("TextLabel") then
			statValueLabels[key] = valueLabel
		end
	end
end

local function bindTotalStatLabels(statsPanel)
	table.clear(totalStatValueLabels)

	for _, key in ipairs(TOTAL_STAT_KEYS) do
		local valueLabel = findDescendant(statsPanel, key .. "Label")

		if valueLabel ~= nil and valueLabel:IsA("TextLabel") then
			totalStatValueLabels[key] = valueLabel
		end
	end

	local winRateLabel = findDescendant(statsPanel, "WinRateLabel")
	local accuracyLabel = findDescendant(statsPanel, "AccuracyLabel")

	if winRateLabel ~= nil and winRateLabel:IsA("TextLabel") then
		totalStatValueLabels.WinRate = winRateLabel
	end

	if accuracyLabel ~= nil and accuracyLabel:IsA("TextLabel") then
		totalStatValueLabels.Accuracy = accuracyLabel
	end
end

local function hasAllResultStatLabels()
	for _, key in ipairs(RESULT_STAT_KEYS) do
		if statValueLabels[key] == nil then
			return false
		end
	end

	return true
end

local function hasAllTotalStatLabels()
	for _, row in ipairs(TOTAL_STAT_ROWS) do
		if totalStatValueLabels[row.Key] == nil then
			return false
		end
	end

	return true
end

local function updateStaticShellText()
	for _, screenGui in ipairs(getShellScreenGuis()) do
		local resultTitleLabel = findDescendant(screenGui, "ResultTitleLabel")

		if resultTitleLabel ~= nil and resultTitleLabel:IsA("TextLabel") then
			resultTitleLabel.Text = "Your Match Result"
		end

		local statsTitleLabel = findDescendant(screenGui, "StatsTitleLabel")

		if statsTitleLabel ~= nil and statsTitleLabel:IsA("TextLabel") then
			statsTitleLabel.Text = "STATS"
		end

		local settingsTitleLabel = findDescendant(screenGui, "SettingsTitleLabel")

		if settingsTitleLabel ~= nil and settingsTitleLabel:IsA("TextLabel") then
			settingsTitleLabel.Text = "SETTINGS"
		end

		local playAgainButton = findDescendant(screenGui, "PlayAgainButton")

		if playAgainButton ~= nil and playAgainButton:IsA("TextButton") then
			playAgainButton.Text = "Rematch"
		end

		local backToMenuButton = findDescendant(screenGui, "BackToMenuButton") or findDescendant(screenGui, "MenuButton")

		if backToMenuButton ~= nil and backToMenuButton:IsA("TextButton") then
			backToMenuButton.Text = "Return to Lobby"
		end
	end
end

local function createShellGui()
	local screenGui = findPrimaryShellGui()

	if screenGui == nil then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = GUI_NAME
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 80
		screenGui.Parent = playerGui
	end

	screenGui.Name = GUI_NAME
	screenGui.Enabled = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	for _, otherGui in ipairs(getShellScreenGuis()) do
		if otherGui ~= screenGui then
			otherGui:Destroy()
		end
	end

	local menuPanel = screenGui:FindFirstChild(MAIN_MENU_PANEL_NAME)

	if menuPanel == nil or not menuPanel:IsA("Frame") then
		menuPanel = createMenu(screenGui)
	end

	local resultPanel = screenGui:FindFirstChild(RESULT_PANEL_NAME)

	if resultPanel == nil or not resultPanel:IsA("Frame") then
		resultPanel = createResultScreen(screenGui)
	end

	local statsPanel = screenGui:FindFirstChild(STATS_PANEL_NAME)

	if statsPanel == nil or not statsPanel:IsA("Frame") then
		statsPanel = createStatsPanel(screenGui)
	end

	local settingsPanel = screenGui:FindFirstChild(SETTINGS_PANEL_NAME)

	if settingsPanel == nil or not settingsPanel:IsA("Frame") then
		settingsPanel = createSettingsPanel(screenGui)
	end

	local lobbyMenuButton = findDescendant(screenGui, "LobbyMenuButton")
	local lobbyHintLabel = findDescendant(screenGui, "LobbyHintLabel")

	lobbyMenuButton, lobbyHintLabel = createLobbyControls(screenGui)

	bindResultStatLabels(resultPanel)
	bindTotalStatLabels(statsPanel)
	updateStaticShellText()

	local trainingButton = findDescendant(menuPanel, "TrainingButton")
	local statsButton = findDescendant(menuPanel, "StatsButton")
	local settingsButton = findDescendant(menuPanel, "SettingsButton")
	local menuCloseButton = findDescendant(menuPanel, "CloseButton")
	local playAgainButton = findDescendant(resultPanel, "PlayAgainButton")
	local backToMenuButton = findDescendant(resultPanel, "BackToMenuButton") or findDescendant(resultPanel, "MenuButton")
	local statsBackButton = findDescendant(statsPanel, "StatsBackButton")
	local settingsBackButton = findDescendant(settingsPanel, "SettingsBackButton")

	if trainingButton == nil or not trainingButton:IsA("TextButton") then
		menuPanel = createMenu(screenGui)
		trainingButton = findDescendant(menuPanel, "TrainingButton")
		statsButton = findDescendant(menuPanel, "StatsButton")
		settingsButton = findDescendant(menuPanel, "SettingsButton")
		menuCloseButton = findDescendant(menuPanel, "CloseButton")
	end

	if playAgainButton == nil
		or not playAgainButton:IsA("TextButton")
		or backToMenuButton == nil
		or not backToMenuButton:IsA("TextButton")
		or not hasAllResultStatLabels()
	then
		resultPanel = createResultScreen(screenGui)
		bindResultStatLabels(resultPanel)
		playAgainButton = findDescendant(resultPanel, "PlayAgainButton")
		backToMenuButton = findDescendant(resultPanel, "BackToMenuButton") or findDescendant(resultPanel, "MenuButton")
	end

	if statsBackButton == nil or not statsBackButton:IsA("TextButton") or not hasAllTotalStatLabels() then
		statsPanel = createStatsPanel(screenGui)
		bindTotalStatLabels(statsPanel)
		statsBackButton = findDescendant(statsPanel, "StatsBackButton")
	end

	if settingsBackButton == nil or not settingsBackButton:IsA("TextButton") then
		settingsPanel = createSettingsPanel(screenGui)
		settingsBackButton = findDescendant(settingsPanel, "SettingsBackButton")
	end

	if trainingButton == nil or not trainingButton:IsA("TextButton") then
		warn("[SHELL] TrainingButton not found under " .. menuPanel:GetFullName())
	elseif DEBUG_SHELL then
		print("[SHELL] bound main menu")
	end

	if playAgainButton == nil or not playAgainButton:IsA("TextButton") then
		warn("[SHELL] PlayAgainButton not found under " .. resultPanel:GetFullName())
	end

	if backToMenuButton == nil or not backToMenuButton:IsA("TextButton") then
		warn("[SHELL] BackToMenuButton/MenuButton not found under " .. resultPanel:GetFullName())
	end

	if statsButton == nil or not statsButton:IsA("TextButton") then
		warn("[SHELL] StatsButton not found under " .. menuPanel:GetFullName())
	end

	if settingsButton == nil or not settingsButton:IsA("TextButton") then
		warn("[SHELL] SettingsButton not found under " .. menuPanel:GetFullName())
	end

	if statsBackButton == nil or not statsBackButton:IsA("TextButton") then
		warn("[SHELL] StatsBackButton not found under " .. statsPanel:GetFullName())
	end

	if settingsBackButton == nil or not settingsBackButton:IsA("TextButton") then
		warn("[SHELL] SettingsBackButton not found under " .. settingsPanel:GetFullName())
	end

	return {
		ScreenGui = screenGui,
		MenuPanel = menuPanel,
		ResultPanel = resultPanel,
		StatsPanel = statsPanel,
		SettingsPanel = settingsPanel,
		TrainingButton = trainingButton,
		StatsButton = statsButton,
		SettingsButton = settingsButton,
		MenuCloseButton = menuCloseButton,
		LobbyMenuButton = lobbyMenuButton,
		LobbyHintLabel = lobbyHintLabel,
		PlayAgainButton = playAgainButton,
		BackToMenuButton = backToMenuButton,
		StatsBackButton = statsBackButton,
		SettingsBackButton = settingsBackButton,
	}
end

local shell = createShellGui()

local function getLocalPlayerMode()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode ~= nil and mode ~= "" then
		return mode
	end

	local gameState = root:GetAttribute("GameState")

	if gameState == GAME_STATE_PLAYING then
		return PLAYER_MODE_IN_MATCH
	elseif gameState == GAME_STATE_RESULT then
		return PLAYER_MODE_RESULT
	end

	return PLAYER_MODE_LOBBY
end

local function isScriptedDuelHudActive()
	return ((HudConfig.CombatHud or {}).UseScriptedDuelHud == true)
		and getLocalPlayerMode() == PLAYER_MODE_IN_MATCH
		and root:GetAttribute("GameState") == GAME_STATE_PLAYING
		and root:GetAttribute("MatchMode") == "PvP"
end

local function isLobbyMode(mode)
	return mode == PLAYER_MODE_LOBBY or mode == PLAYER_MODE_QUEUED
end

local function runtimeAttribute(attributeName)
	local value = localPlayer:GetAttribute(attributeName)

	if value ~= nil then
		return value
	end

	return root:GetAttribute(attributeName)
end

local function runtimeNumber(attributeName)
	local value = runtimeAttribute(attributeName)

	if typeof(value) == "number" then
		return value
	end

	return tonumber(value) or 0
end

local function runtimeIntText(attributeName)
	return tostring(math.floor(runtimeNumber(attributeName)))
end

local function playerAttributeNumber(attributeName)
	local value = localPlayer:GetAttribute(attributeName)

	if typeof(value) == "number" then
		return value
	end

	return tonumber(value) or 0
end

local function formatPercent(numerator, denominator)
	if denominator <= 0 then
		return "0%"
	end

	return tostring(math.floor((numerator / denominator) * 100 + 0.5)) .. "%"
end

local function hasAnyPersistentTotal()
	for _, key in ipairs(TOTAL_STAT_KEYS) do
		if playerAttributeNumber("Persistent" .. key) > 0 then
			return true
		end
	end

	return false
end

local function getAccumulatedTotals()
	local totals = {}
	local persistentStatsLoaded = localPlayer:GetAttribute("PersistentStatsLoaded") == true
	local lastSaveSucceeded = localPlayer:GetAttribute("PersistentStatsLastSaveSucceeded") == true
	local usePersistent = persistentStatsLoaded and hasAnyPersistentTotal()

	for _, key in ipairs(TOTAL_STAT_KEYS) do
		local persistentValue = playerAttributeNumber("Persistent" .. key)
		local sessionValue = playerAttributeNumber("Session" .. key)
		local unsavedValue = playerAttributeNumber("Unsaved" .. key)

		if usePersistent then
			if lastSaveSucceeded then
				totals[key] = persistentValue
			else
				totals[key] = persistentValue + unsavedValue
			end
		else
			totals[key] = sessionValue
		end
	end

	return totals
end

local function formatMatchResult(result)
	if result == "Win" or result == "PlayerMatchWin" then
		return "Victory"
	elseif result == "Lose" or result == "Loss" or result == "DummyMatchWin" then
		return "Defeat"
	elseif result == "" or result == nil then
		return "-"
	end

	return tostring(result)
end

local function getCurrentMatchCrystalRewardText()
	if tostring(localPlayer:GetAttribute(LAST_CRYSTALS_REWARD_REASON_ATTRIBUTE) or "") ~= "DuelWin" then
		return ""
	end

	local matchId = tostring(localPlayer:GetAttribute("MatchId") or "")
	local rewardMatchId = tostring(localPlayer:GetAttribute(LAST_CRYSTALS_REWARD_MATCH_ID_ATTRIBUTE) or "")

	if matchId == "" or rewardMatchId ~= matchId then
		return ""
	end

	local amount = math.max(0, math.floor(tonumber(localPlayer:GetAttribute(LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE)) or 0))

	if amount <= 0 then
		return ""
	end

	return "+" .. tostring(amount) .. " Crystal" .. (amount == 1 and "" or "s")
end

local function updateResultStats()
	local shots = runtimeNumber("StatsShotsFired")
	local hits = runtimeNumber("StatsHits")
	local accuracy = 0

	if shots > 0 then
		accuracy = math.floor((hits / shots) * 100 + 0.5)
	end

	local result = runtimeAttribute("StatsMatchResult")

	if result == nil or result == "" then
		result = root:GetAttribute("MatchResult")
	end

	local values = {
		MatchResult = formatMatchResult(result),
		RoundsWon = runtimeIntText("StatsRoundsWon"),
		RoundsLost = runtimeIntText("StatsRoundsLost"),
		ShotsFired = runtimeIntText("StatsShotsFired"),
		Hits = runtimeIntText("StatsHits"),
		Accuracy = tostring(accuracy) .. "%",
		Ricochets = runtimeIntText("StatsRicochets"),
		RicochetHits = runtimeIntText("StatsRicochetHits"),
		SelfHits = runtimeIntText("StatsSelfHits"),
		DamageDealt = runtimeIntText("StatsDamageDealt"),
		DamageTaken = runtimeIntText("StatsDamageTaken"),
	}
	local rewardText = values.MatchResult == "Victory" and getCurrentMatchCrystalRewardText() or ""

	for key, text in pairs(values) do
		local label = statValueLabels[key]

		if label ~= nil then
			label.Text = text
		end

		for _, screenGui in ipairs(getShellScreenGuis()) do
			local resultPanel = findDescendant(screenGui, RESULT_PANEL_NAME)
			local duplicateLabel = resultPanel ~= nil and findDescendant(resultPanel, key .. "Value") or nil

			if duplicateLabel ~= nil and duplicateLabel:IsA("TextLabel") then
				duplicateLabel.Text = text
			end
		end
	end

	for _, screenGui in ipairs(getShellScreenGuis()) do
		local resultTitleLabel = findDescendant(screenGui, "ResultTitleLabel")

		if resultTitleLabel ~= nil and resultTitleLabel:IsA("TextLabel") then
			resultTitleLabel.Text = rewardText ~= "" and ("Victory " .. rewardText) or "Your Match Result"
		end
	end
end

local function updateStatsPanel()
	local totals = getAccumulatedTotals()
	local hasAnyStats = false
	local values = {
		TotalMatches = tostring(math.floor(totals.TotalMatches or 0)),
		TotalWins = tostring(math.floor(totals.TotalWins or 0)),
		TotalLosses = tostring(math.floor(totals.TotalLosses or 0)),
		WinRate = formatPercent(totals.TotalWins or 0, totals.TotalMatches or 0),
		TotalShotsFired = tostring(math.floor(totals.TotalShotsFired or 0)),
		TotalHits = tostring(math.floor(totals.TotalHits or 0)),
		Accuracy = formatPercent(totals.TotalHits or 0, totals.TotalShotsFired or 0),
		TotalRicochets = tostring(math.floor(totals.TotalRicochets or 0)),
		TotalRicochetHits = tostring(math.floor(totals.TotalRicochetHits or 0)),
		TotalSelfHits = tostring(math.floor(totals.TotalSelfHits or 0)),
		TotalDamageDealt = tostring(math.floor(totals.TotalDamageDealt or 0)),
		TotalDamageTaken = tostring(math.floor(totals.TotalDamageTaken or 0)),
	}

	for _, value in pairs(totals) do
		if tonumber(value) ~= nil and tonumber(value) > 0 then
			hasAnyStats = true
			break
		end
	end

	for key, text in pairs(values) do
		local label = totalStatValueLabels[key]

		if label ~= nil then
			label.Text = text
		end

		for _, screenGui in ipairs(getShellScreenGuis()) do
			local statsPanel = findDescendant(screenGui, STATS_PANEL_NAME)
			local duplicateLabel = statsPanel ~= nil and findDescendant(statsPanel, key .. "Label") or nil

			if duplicateLabel ~= nil and duplicateLabel:IsA("TextLabel") then
				duplicateLabel.Text = text
			end
		end
	end

	for _, screenGui in ipairs(getShellScreenGuis()) do
		local statsPanel = findDescendant(screenGui, STATS_PANEL_NAME)
		local emptyLabel = statsPanel ~= nil and findDescendant(statsPanel, "StatsEmptyLabel") or nil
		local statsList = statsPanel ~= nil and findDescendant(statsPanel, "StatsList") or nil

		if emptyLabel ~= nil and emptyLabel:IsA("TextLabel") then
			emptyLabel.Visible = not hasAnyStats
		end

		if statsList ~= nil and statsList:IsA("GuiObject") then
			statsList.Visible = hasAnyStats
		end
	end
end

local function animateResultPanel(resultPanel)
	if resultPanel == nil or not resultPanel:IsA("GuiObject") then
		return
	end

	local content = findDescendant(resultPanel, "ResultContent")
	local title = findDescendant(resultPanel, "ResultTitleLabel")
	local statsList = findDescendant(resultPanel, "StatsList")
	local playAgainButton = findDescendant(resultPanel, "PlayAgainButton")
	local backToMenuButton = findDescendant(resultPanel, "BackToMenuButton") or findDescendant(resultPanel, "MenuButton")

	resultPanel.BackgroundTransparency = 1
	TweenService:Create(resultPanel, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.08,
	}):Play()

	if content ~= nil and content:IsA("GuiObject") then
		local scale = content:FindFirstChild("ResultEntranceScale")

		if scale == nil then
			scale = Instance.new("UIScale")
			scale.Name = "ResultEntranceScale"
			scale.Parent = content
		end

		scale.Scale = 0.9
		content.BackgroundTransparency = 1
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		TweenService:Create(content, TweenInfo.new(0.22), {
			BackgroundTransparency = 0.08,
		}):Play()
	end

	if title ~= nil and title:IsA("TextLabel") then
		title.TextTransparency = 1
		TweenService:Create(title, TweenInfo.new(0.2), {
			TextTransparency = 0,
		}):Play()
	end

	if statsList ~= nil and statsList:IsA("GuiObject") then
		statsList.Visible = false
		task.delay(0.12, function()
			if resultPanel.Visible then
				statsList.Visible = true
			end
		end)
	end

	for _, button in ipairs({ playAgainButton, backToMenuButton }) do
		if button ~= nil and button:IsA("TextButton") then
			button.BackgroundTransparency = 1
			button.TextTransparency = 1
			task.delay(0.22, function()
				if not resultPanel.Visible then
					return
				end

				TweenService:Create(button, TweenInfo.new(0.18), {
					BackgroundTransparency = 0,
					TextTransparency = 0,
				}):Play()
			end)
		end
	end
end

local function isMobileLayout()
	return getShellMobileLayout()
end

local function shouldHideTopHpPanels()
	local worldHealthBarsConfig = HudConfig.WorldHealthBars or {}

	if worldHealthBarsConfig.Enabled ~= true then
		return false
	end

	local mode = getLocalPlayerMode()

	if mode == PLAYER_MODE_IN_BATTLE_ARENA or mode == PLAYER_MODE_ARENA_RESPAWNING then
		return worldHealthBarsConfig.HideTopHpPanelsInBattleArena == true
	end

	if isMobileLayout() and worldHealthBarsConfig.HideTopHpPanelsOnMobile == true then
		return true
	end

	local matchMode = root:GetAttribute("MatchMode")

	if matchMode == "Training" then
		return worldHealthBarsConfig.HideTopHpPanelsInTraining == true
	elseif matchMode == "PvP" then
		return worldHealthBarsConfig.HideTopHpPanelsInDuel == true
	end

	return false
end

local function shouldHideLargeReloadPanel()
	local combatHudConfig = HudConfig.CombatHud or {}
	local worldHealthBarsConfig = HudConfig.WorldHealthBars or {}

	if worldHealthBarsConfig.Enabled ~= true then
		return false
	end

	if combatHudConfig.CompactReload ~= true then
		return false
	end

	local mode = getLocalPlayerMode()

	if mode == PLAYER_MODE_IN_BATTLE_ARENA or mode == PLAYER_MODE_ARENA_RESPAWNING then
		return true
	end

	if isMobileLayout() then
		return true
	end

	return false
end

local function shouldShowGameplayHudPanel(panelName, isVisible)
	if not isVisible then
		return false
	end

	local combatHudConfig = HudConfig.CombatHud or {}
	local hideTopHpPanels = shouldHideTopHpPanels()

	if panelName == "EnemyStatusPanel" then
		return not (hideTopHpPanels and combatHudConfig.HideEnemyHpPanelWhenWorldBarsEnabled ~= false)
	elseif panelName == "PlayerStatusPanel" then
		return not (hideTopHpPanels and combatHudConfig.HidePlayerHpPanelWhenWorldBarsEnabled ~= false)
	elseif panelName == "WeaponStatusPanel" then
		return not shouldHideLargeReloadPanel()
	end

	return true
end

local function setGameplayHudVisible(isVisible)
	local legacyHudVisible = isVisible and not isScriptedDuelHudActive()

	for _, guiName in ipairs(HUD_GUI_NAMES) do
		local gui = playerGui:FindFirstChild(guiName)

		if gui ~= nil and gui:IsA("ScreenGui") then
			gui.Enabled = legacyHudVisible
		end
	end

	local hud = playerGui:FindFirstChild("HUD")
	local rootFrame = hud ~= nil and hud:FindFirstChild("Root") or nil

	if rootFrame == nil then
		return
	end

	local panelNames = legacyHudVisible and PERSISTENT_HUD_PANEL_NAMES or ALL_HUD_PANEL_NAMES

	for _, panelName in ipairs(panelNames) do
		local panel = rootFrame:FindFirstChild(panelName)

		if panel ~= nil and panel:IsA("GuiObject") then
			panel.Visible = shouldShowGameplayHudPanel(panelName, legacyHudVisible)
		end
	end
end

local function applyShellState(state)
	local mode = getLocalPlayerMode()
	local isLobby = isLobbyMode(mode)
	local isMenuOpen = isLobby and activeShellPanel == SHELL_PANEL_MENU
	local isPlaying = mode == PLAYER_MODE_IN_MATCH and state == GAME_STATE_PLAYING
	local isResult = mode == PLAYER_MODE_RESULT
	local isStatsOpen = isLobby and activeShellPanel == SHELL_PANEL_STATS
	local isSettingsOpen = isLobby and activeShellPanel == SHELL_PANEL_SETTINGS
	local showLobbyControls = isLobby and not isMenuOpen and not isStatsOpen and not isSettingsOpen
	local shouldAnimateResultPanel = isResult and not resultPanelWasVisible

	for _, screenGui in ipairs(getShellScreenGuis()) do
		screenGui.Enabled = true

		local menuPanel = findDescendant(screenGui, MAIN_MENU_PANEL_NAME)
		local resultPanel = findDescendant(screenGui, RESULT_PANEL_NAME)
		local statsPanel = findDescendant(screenGui, STATS_PANEL_NAME)
		local settingsPanel = findDescendant(screenGui, SETTINGS_PANEL_NAME)
		local lobbyMenuButton = findDescendant(screenGui, "LobbyMenuButton")
		local lobbyHintLabel = findDescendant(screenGui, "LobbyHintLabel")

		if menuPanel ~= nil and menuPanel:IsA("GuiObject") then
			menuPanel.Visible = isMenuOpen
		end

		if resultPanel ~= nil and resultPanel:IsA("GuiObject") then
			resultPanel.Visible = isResult

			if shouldAnimateResultPanel then
				animateResultPanel(resultPanel)
			end
		end

		if statsPanel ~= nil and statsPanel:IsA("GuiObject") then
			statsPanel.Visible = isStatsOpen
		end

		if settingsPanel ~= nil and settingsPanel:IsA("GuiObject") then
			settingsPanel.Visible = isSettingsOpen
		end

		if lobbyMenuButton ~= nil and lobbyMenuButton:IsA("GuiObject") then
			lobbyMenuButton.Visible = showLobbyControls
		end

		if lobbyHintLabel ~= nil and lobbyHintLabel:IsA("GuiObject") then
			lobbyHintLabel.Visible = showLobbyControls and not isMobileLayout()
		end
	end

	setGameplayHudVisible(isPlaying)

	if isResult then
		updateResultStats()
	end

	if isStatsOpen then
		updateStatsPanel()
	end

	resultPanelWasVisible = isResult
end

local function updateShell()
	local state = root:GetAttribute("GameState") or GAME_STATE_MENU
	local mode = getLocalPlayerMode()

	if mode == PLAYER_MODE_IN_MATCH or mode == PLAYER_MODE_RESULT then
		activeShellPanel = SHELL_PANEL_HIDDEN
	end

	applyShellState(state)
end

local function connectActionButton(button, logMessage, callback)
	if button == nil or not button:IsA("TextButton") or connectedButtons[button] == true then
		return
	end

	connectedButtons[button] = true
	button.Active = true
	button.AutoButtonColor = true
	bindButtonAnimation(button)

	pcall(function()
		button.Selectable = true
	end)

	button.Activated:Connect(function()
		if DEBUG_SHELL then
			print(logMessage)
		end
		callback()
	end)
end

local function connectRemoteButton(button, logMessage, requestedState, remoteEvent)
	connectActionButton(button, logMessage, function()
		activeShellPanel = SHELL_PANEL_HIDDEN
		applyShellState(root:GetAttribute("GameState") or requestedState)
		remoteEvent:FireServer()
	end)
end

local function openStatsPanel()
	activeShellPanel = SHELL_PANEL_STATS
	updateStatsPanel()
	print("[STATS] panel showing userId=" .. tostring(localPlayer.UserId))
	applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
end

local function openSettingsPanel()
	activeShellPanel = SHELL_PANEL_SETTINGS
	applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
end

local function closeLobbyMenu()
	activeShellPanel = SHELL_PANEL_HIDDEN
	applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
end

local function openLobbyMenu()
	activeShellPanel = SHELL_PANEL_MENU
	applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
end

local function requestRematch()
	localPlayer:SetAttribute("RematchStatus", "Waiting")
	rematchRequestEvent:FireServer()
end

local function updateRematchButton()
	local waiting = localPlayer:GetAttribute("RematchStatus") == "Waiting"

	for _, screenGui in ipairs(getShellScreenGuis()) do
		local resultPanel = findDescendant(screenGui, RESULT_PANEL_NAME)
		local button = resultPanel ~= nil and findDescendant(resultPanel, "PlayAgainButton") or nil

		if button ~= nil and button:IsA("TextButton") then
			styleButton(button, waiting and "Waiting for opponent..." or "Rematch", not waiting)
		end
	end
end

local function bindShellButtons(screenGui)
	local menuPanel = findDescendant(screenGui, MAIN_MENU_PANEL_NAME)
	local resultPanel = findDescendant(screenGui, RESULT_PANEL_NAME)
	local statsPanel = findDescendant(screenGui, STATS_PANEL_NAME)
	local settingsPanel = findDescendant(screenGui, SETTINGS_PANEL_NAME)

	if menuPanel ~= nil then
		connectRemoteButton(findDescendant(menuPanel, "TrainingButton"), "[SHELL] Training clicked", GAME_STATE_PLAYING, startMatchRequestEvent)
		connectActionButton(findDescendant(menuPanel, "StatsButton"), "[SHELL] Stats clicked", openStatsPanel)
		connectActionButton(findDescendant(menuPanel, "SettingsButton"), "[SHELL] Settings clicked", openSettingsPanel)
		connectActionButton(findDescendant(menuPanel, "CloseButton"), "[SHELL] Close clicked", closeLobbyMenu)
	end

	if resultPanel ~= nil then
		connectActionButton(
			findDescendant(resultPanel, "PlayAgainButton"),
			"[SHELL] PlayAgain clicked",
			requestRematch
		)
		connectRemoteButton(
			findDescendant(resultPanel, "BackToMenuButton") or findDescendant(resultPanel, "MenuButton"),
			"[SHELL] BackToMenu clicked",
			GAME_STATE_MENU,
			returnToMenuRequestEvent
		)
	end

	if statsPanel ~= nil then
		connectActionButton(findDescendant(statsPanel, "StatsBackButton"), "[SHELL] StatsBack clicked", function()
			activeShellPanel = SHELL_PANEL_HIDDEN
			applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
		end)
	end

	if settingsPanel ~= nil then
		connectActionButton(findDescendant(settingsPanel, "SettingsBackButton"), "[SHELL] SettingsBack clicked", function()
			activeShellPanel = SHELL_PANEL_HIDDEN
			applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
		end)
	end

	connectActionButton(findDescendant(screenGui, "LobbyMenuButton"), "[SHELL] LobbyMenu clicked", openLobbyMenu)
end

local function bindAllShellButtons()
	for _, screenGui in ipairs(getShellScreenGuis()) do
		bindShellButtons(screenGui)
	end
end

bindAllShellButtons()

if shell.TrainingButton ~= nil and shell.TrainingButton:IsA("TextButton") then
	connectRemoteButton(shell.TrainingButton, "[SHELL] Training clicked", GAME_STATE_PLAYING, startMatchRequestEvent)
end

if shell.StatsButton ~= nil and shell.StatsButton:IsA("TextButton") then
	connectActionButton(shell.StatsButton, "[SHELL] Stats clicked", openStatsPanel)
end

if shell.SettingsButton ~= nil and shell.SettingsButton:IsA("TextButton") then
	connectActionButton(shell.SettingsButton, "[SHELL] Settings clicked", openSettingsPanel)
end

if shell.MenuCloseButton ~= nil and shell.MenuCloseButton:IsA("TextButton") then
	connectActionButton(shell.MenuCloseButton, "[SHELL] Close clicked", closeLobbyMenu)
end

if shell.LobbyMenuButton ~= nil and shell.LobbyMenuButton:IsA("TextButton") then
	connectActionButton(shell.LobbyMenuButton, "[SHELL] LobbyMenu clicked", openLobbyMenu)
end

if shell.PlayAgainButton ~= nil and shell.PlayAgainButton:IsA("TextButton") then
	connectActionButton(shell.PlayAgainButton, "[SHELL] PlayAgain clicked", requestRematch)
end

if shell.BackToMenuButton ~= nil and shell.BackToMenuButton:IsA("TextButton") then
	connectRemoteButton(shell.BackToMenuButton, "[SHELL] BackToMenu clicked", GAME_STATE_MENU, returnToMenuRequestEvent)
end

if shell.StatsBackButton ~= nil and shell.StatsBackButton:IsA("TextButton") then
	connectActionButton(shell.StatsBackButton, "[SHELL] StatsBack clicked", function()
		activeShellPanel = SHELL_PANEL_HIDDEN
		applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
	end)
end

if shell.SettingsBackButton ~= nil and shell.SettingsBackButton:IsA("TextButton") then
	connectActionButton(shell.SettingsBackButton, "[SHELL] SettingsBack clicked", function()
		activeShellPanel = SHELL_PANEL_HIDDEN
		applyShellState(root:GetAttribute("GameState") or GAME_STATE_MENU)
	end)
end

root:GetAttributeChangedSignal("GameState"):Connect(function()
	if DEBUG_SHELL then
		print("[SHELL] GameState changed -> " .. tostring(root:GetAttribute("GameState")))
	end

	updateShell()
end)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(updateShell)
root:GetAttributeChangedSignal("MatchMode"):Connect(updateShell)
localPlayer:GetAttributeChangedSignal("RematchStatus"):Connect(function()
	updateRematchButton()
	updateShell()
end)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE):Connect(updateResultStats)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_REASON_ATTRIBUTE):Connect(updateResultStats)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_MATCH_ID_ATTRIBUTE):Connect(updateResultStats)

for _, attributeName in ipairs(STAT_ATTRIBUTES) do
	root:GetAttributeChangedSignal(attributeName):Connect(updateResultStats)
	localPlayer:GetAttributeChangedSignal(attributeName):Connect(updateResultStats)
end

for _, key in ipairs(TOTAL_STAT_KEYS) do
	localPlayer:GetAttributeChangedSignal("Persistent" .. key):Connect(updateStatsPanel)
	localPlayer:GetAttributeChangedSignal("Session" .. key):Connect(updateStatsPanel)
	localPlayer:GetAttributeChangedSignal("Unsaved" .. key):Connect(updateStatsPanel)
end

localPlayer:GetAttributeChangedSignal("PersistentStatsLoaded"):Connect(updateStatsPanel)
localPlayer:GetAttributeChangedSignal("PersistentStatsLastSaveSucceeded"):Connect(updateStatsPanel)

playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		if isShellScreenGui(child) then
			task.defer(function()
				bindShellButtons(child)
				updateStaticShellText()
			end)
		end

		task.defer(updateShell)
	end
end)

updateResultStats()
updateStatsPanel()
updateRematchButton()
updateShell()
