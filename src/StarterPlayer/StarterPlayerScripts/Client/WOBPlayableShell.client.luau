local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local root = Workspace:WaitForChild("WOB_Generated")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startMatchRequestEvent = remotes:WaitForChild("StartMatchRequestEvent")
local returnToMenuRequestEvent = remotes:WaitForChild("ReturnToMenuRequestEvent")

local GUI_NAME = "WOBPlayableShellGui"
local MAIN_MENU_PANEL_NAME = "MainMenuPanel"
local RESULT_PANEL_NAME = "ResultScreenPanel"
local STATS_PANEL_NAME = "StatsPanel"
local GAME_STATE_MENU = "Menu"
local GAME_STATE_PLAYING = "Playing"
local GAME_STATE_RESULT = "Result"
local SHELL_PANEL_MENU = "Menu"
local SHELL_PANEL_STATS = "Stats"

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
local activeShellPanel = SHELL_PANEL_MENU

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

local function styleLabel(label, text, textSize, color)
	if not label:IsA("TextLabel") then
		return
	end

	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function styleButton(button, text, enabled)
	if not button:IsA("TextButton") then
		return
	end

	button.BackgroundColor3 = enabled and Color3.fromRGB(56, 168, 118) or Color3.fromRGB(48, 55, 58)
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = enabled and Color3.fromRGB(248, 255, 248) or Color3.fromRGB(158, 170, 166)
	button.TextSize = 20
	button.TextWrapped = true
	button.AutoButtonColor = enabled
	button.Active = enabled

	pcall(function()
		button.Selectable = enabled
	end)

	addCorner(button, UDim.new(0, 8))
	addStroke(button, enabled and Color3.fromRGB(132, 242, 180) or Color3.fromRGB(76, 86, 86), 0.3, 1)
end

local function styleOverlayPanel(panel)
	if not panel:IsA("Frame") then
		return
	end

	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.Position = UDim2.new(0, 0, 0, 0)
	panel.BackgroundColor3 = Color3.fromRGB(7, 9, 11)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
end

local function createMenu(screenGui)
	local panel = getOrCreate(screenGui, "Frame", MAIN_MENU_PANEL_NAME)
	styleOverlayPanel(panel)

	local content = getOrCreate(panel, "Frame", "MenuContent")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.Size = UDim2.new(0, 420, 0, 420)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0

	local title = getOrCreate(content, "TextLabel", "TitleLabel")
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 82)
	styleLabel(title, "World of Balance", 38, Color3.fromRGB(241, 255, 247))
	title.Font = Enum.Font.GothamBold

	local subtitle = getOrCreate(content, "TextLabel", "SubtitleLabel")
	subtitle.Position = UDim2.new(0, 0, 0, 84)
	subtitle.Size = UDim2.new(1, 0, 0, 42)
	styleLabel(subtitle, "Ricochet Tanks", 22, Color3.fromRGB(139, 224, 190))

	local buttonNames = {
		{ Name = "PlayButton", Text = "Play", Enabled = true, Y = 158 },
		{ Name = "TrainingButton", Text = "Training", Enabled = false, Y = 224 },
		{ Name = "StatsButton", Text = "Stats", Enabled = true, Y = 290 },
		{ Name = "SettingsButton", Text = "Settings", Enabled = false, Y = 356 },
	}

	for _, data in ipairs(buttonNames) do
		local button = getOrCreate(content, "TextButton", data.Name)
		button.Position = UDim2.new(0.13, 0, 0, data.Y)
		button.Size = UDim2.new(0.74, 0, 0, 50)
		styleButton(button, data.Text, data.Enabled)
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
	styleLabel(title, "Match Result", 30, Color3.fromRGB(241, 255, 247))
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
	styleButton(playAgainButton, "Play Again", true)

	local menuButton = getOrCreate(content, "TextButton", "BackToMenuButton")
	menuButton.Position = UDim2.new(0.52, 0, 1, -128)
	menuButton.Size = UDim2.new(0.38, 0, 0, 52)
	styleButton(menuButton, "Back to Menu", true)

	return panel
end

local function createStatsPanel(screenGui)
	local panel = getOrCreate(screenGui, "Frame", STATS_PANEL_NAME)
	styleOverlayPanel(panel)

	local content = getOrCreate(panel, "Frame", "StatsContent")
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.Size = UDim2.new(0, 560, 0, 630)
	content.BackgroundColor3 = Color3.fromRGB(12, 16, 18)
	content.BackgroundTransparency = 0.08
	content.BorderSizePixel = 0
	addCorner(content, UDim.new(0, 8))
	addStroke(content, Color3.fromRGB(75, 115, 104), 0.25, 1)

	local title = getOrCreate(content, "TextLabel", "StatsTitleLabel")
	title.Position = UDim2.new(0.08, 0, 0, 24)
	title.Size = UDim2.new(0.84, 0, 0, 52)
	styleLabel(title, "Player Stats", 30, Color3.fromRGB(241, 255, 247))
	title.Font = Enum.Font.GothamBold

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

	local backButton = getOrCreate(content, "TextButton", "StatsBackButton")
	backButton.Position = UDim2.new(0.28, 0, 1, -88)
	backButton.Size = UDim2.new(0.44, 0, 0, 52)
	styleButton(backButton, "Back", true)

	return panel
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

	screenGui.Enabled = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

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

	bindResultStatLabels(resultPanel)
	bindTotalStatLabels(statsPanel)

	local playButton = findDescendant(menuPanel, "PlayButton")
	local statsButton = findDescendant(menuPanel, "StatsButton")
	local playAgainButton = findDescendant(resultPanel, "PlayAgainButton")
	local backToMenuButton = findDescendant(resultPanel, "BackToMenuButton") or findDescendant(resultPanel, "MenuButton")
	local statsBackButton = findDescendant(statsPanel, "StatsBackButton")

	if playButton == nil or not playButton:IsA("TextButton") then
		menuPanel = createMenu(screenGui)
		playButton = findDescendant(menuPanel, "PlayButton")
		statsButton = findDescendant(menuPanel, "StatsButton")
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

	if playButton == nil or not playButton:IsA("TextButton") then
		warn("[SHELL] PlayButton not found under " .. menuPanel:GetFullName())
	else
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

	if statsBackButton == nil or not statsBackButton:IsA("TextButton") then
		warn("[SHELL] StatsBackButton not found under " .. statsPanel:GetFullName())
	end

	return {
		ScreenGui = screenGui,
		MenuPanel = menuPanel,
		ResultPanel = resultPanel,
		StatsPanel = statsPanel,
		PlayButton = playButton,
		StatsButton = statsButton,
		PlayAgainButton = playAgainButton,
		BackToMenuButton = backToMenuButton,
		StatsBackButton = statsBackButton,
	}
end

local shell = createShellGui()

local function asNumber(attributeName)
	local value = root:GetAttribute(attributeName)

	if typeof(value) == "number" then
		return value
	end

	return tonumber(value) or 0
end

local function asIntText(attributeName)
	return tostring(math.floor(asNumber(attributeName)))
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
	if result == "PlayerMatchWin" then
		return "Victory"
	elseif result == "DummyMatchWin" then
		return "Defeat"
	elseif result == "" or result == nil then
		return "-"
	end

	return tostring(result)
end

local function updateResultStats()
	local shots = asNumber("StatsShotsFired")
	local hits = asNumber("StatsHits")
	local accuracy = 0

	if shots > 0 then
		accuracy = math.floor((hits / shots) * 100 + 0.5)
	end

	local result = root:GetAttribute("StatsMatchResult")

	if result == nil or result == "" then
		result = root:GetAttribute("MatchResult")
	end

	local values = {
		MatchResult = formatMatchResult(result),
		RoundsWon = asIntText("StatsRoundsWon"),
		RoundsLost = asIntText("StatsRoundsLost"),
		ShotsFired = asIntText("StatsShotsFired"),
		Hits = asIntText("StatsHits"),
		Accuracy = tostring(accuracy) .. "%",
		Ricochets = asIntText("StatsRicochets"),
		RicochetHits = asIntText("StatsRicochetHits"),
		SelfHits = asIntText("StatsSelfHits"),
		DamageDealt = asIntText("StatsDamageDealt"),
		DamageTaken = asIntText("StatsDamageTaken"),
	}

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
end

local function updateStatsPanel()
	local totals = getAccumulatedTotals()
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
end

local function setGameplayHudVisible(isVisible)
	for _, guiName in ipairs(HUD_GUI_NAMES) do
		local gui = playerGui:FindFirstChild(guiName)

		if gui ~= nil and gui:IsA("ScreenGui") then
			gui.Enabled = isVisible
		end
	end

	local hud = playerGui:FindFirstChild("HUD")
	local rootFrame = hud ~= nil and hud:FindFirstChild("Root") or nil

	if rootFrame == nil then
		return
	end

	local panelNames = isVisible and PERSISTENT_HUD_PANEL_NAMES or ALL_HUD_PANEL_NAMES

	for _, panelName in ipairs(panelNames) do
		local panel = rootFrame:FindFirstChild(panelName)

		if panel ~= nil and panel:IsA("GuiObject") then
			panel.Visible = isVisible
		end
	end
end

local function applyShellState(state)
	local isMenu = state == GAME_STATE_MENU
	local isPlaying = state == GAME_STATE_PLAYING
	local isResult = state == GAME_STATE_RESULT
	local isStatsOpen = isMenu and activeShellPanel == SHELL_PANEL_STATS

	for _, screenGui in ipairs(getShellScreenGuis()) do
		screenGui.Enabled = true

		local menuPanel = findDescendant(screenGui, MAIN_MENU_PANEL_NAME)
		local resultPanel = findDescendant(screenGui, RESULT_PANEL_NAME)
		local statsPanel = findDescendant(screenGui, STATS_PANEL_NAME)

		if menuPanel ~= nil and menuPanel:IsA("GuiObject") then
			menuPanel.Visible = isMenu and not isStatsOpen
		end

		if resultPanel ~= nil and resultPanel:IsA("GuiObject") then
			resultPanel.Visible = isResult
		end

		if statsPanel ~= nil and statsPanel:IsA("GuiObject") then
			statsPanel.Visible = isStatsOpen
		end
	end

	setGameplayHudVisible(isPlaying)

	if isResult then
		updateResultStats()
	end

	if isStatsOpen then
		updateStatsPanel()
	end
end

local function updateShell()
	local state = root:GetAttribute("GameState") or GAME_STATE_MENU

	if state ~= GAME_STATE_MENU then
		activeShellPanel = SHELL_PANEL_MENU
	end

	applyShellState(state)
end

local function connectActionButton(button, logMessage, callback)
	if button == nil or not button:IsA("TextButton") or connectedButtons[button] == true then
		return
	end

	connectedButtons[button] = true
	styleButton(button, button.Text, true)
	button.Active = true
	button.AutoButtonColor = true

	pcall(function()
		button.Selectable = true
	end)

	button.Activated:Connect(function()
		print(logMessage)
		callback()
	end)
end

local function connectRemoteButton(button, logMessage, requestedState, remoteEvent)
	connectActionButton(button, logMessage, function()
		activeShellPanel = SHELL_PANEL_MENU
		applyShellState(requestedState)
		remoteEvent:FireServer()
	end)
end

local function bindShellButtons(screenGui)
	local menuPanel = findDescendant(screenGui, MAIN_MENU_PANEL_NAME)
	local resultPanel = findDescendant(screenGui, RESULT_PANEL_NAME)
	local statsPanel = findDescendant(screenGui, STATS_PANEL_NAME)

	if menuPanel ~= nil then
		connectRemoteButton(findDescendant(menuPanel, "PlayButton"), "[SHELL] Play clicked", GAME_STATE_PLAYING, startMatchRequestEvent)
		connectActionButton(findDescendant(menuPanel, "StatsButton"), "[SHELL] Stats clicked", function()
			activeShellPanel = SHELL_PANEL_STATS
			updateStatsPanel()
			applyShellState(GAME_STATE_MENU)
		end)
	end

	if resultPanel ~= nil then
		connectRemoteButton(
			findDescendant(resultPanel, "PlayAgainButton"),
			"[SHELL] PlayAgain clicked",
			GAME_STATE_PLAYING,
			startMatchRequestEvent
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
			activeShellPanel = SHELL_PANEL_MENU
			applyShellState(GAME_STATE_MENU)
		end)
	end
end

local function bindAllShellButtons()
	for _, screenGui in ipairs(getShellScreenGuis()) do
		bindShellButtons(screenGui)
	end
end

bindAllShellButtons()

if shell.PlayButton ~= nil and shell.PlayButton:IsA("TextButton") then
	connectRemoteButton(shell.PlayButton, "[SHELL] Play clicked", GAME_STATE_PLAYING, startMatchRequestEvent)
end

if shell.StatsButton ~= nil and shell.StatsButton:IsA("TextButton") then
	connectActionButton(shell.StatsButton, "[SHELL] Stats clicked", function()
		activeShellPanel = SHELL_PANEL_STATS
		updateStatsPanel()
		applyShellState(GAME_STATE_MENU)
	end)
end

if shell.PlayAgainButton ~= nil and shell.PlayAgainButton:IsA("TextButton") then
	connectRemoteButton(shell.PlayAgainButton, "[SHELL] PlayAgain clicked", GAME_STATE_PLAYING, startMatchRequestEvent)
end

if shell.BackToMenuButton ~= nil and shell.BackToMenuButton:IsA("TextButton") then
	connectRemoteButton(shell.BackToMenuButton, "[SHELL] BackToMenu clicked", GAME_STATE_MENU, returnToMenuRequestEvent)
end

if shell.StatsBackButton ~= nil and shell.StatsBackButton:IsA("TextButton") then
	connectActionButton(shell.StatsBackButton, "[SHELL] StatsBack clicked", function()
		activeShellPanel = SHELL_PANEL_MENU
		applyShellState(GAME_STATE_MENU)
	end)
end

root:GetAttributeChangedSignal("GameState"):Connect(function()
	print("[SHELL] GameState changed -> " .. tostring(root:GetAttribute("GameState")))
	updateShell()
end)

for _, attributeName in ipairs(STAT_ATTRIBUTES) do
	root:GetAttributeChangedSignal(attributeName):Connect(updateResultStats)
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
			end)
		end

		task.defer(updateShell)
	end
end)

updateResultStats()
updateStatsPanel()
updateShell()
