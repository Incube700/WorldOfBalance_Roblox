local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local HudConfig = require(configs:WaitForChild("HudConfig"))
local MatchConfig = require(configs:WaitForChild("MatchConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetDummyRequestEvent = remotes:WaitForChild("ResetDummyRequestEvent")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
testObjects:WaitForChild("PlayerTankPrototype")

local LEGACY_RUNTIME_GUI_NAME = "WOBRoundStatusOverlayGui"
local EMERGENCY_GUI_NAME = "WOBRoundStatusEmergencyGui"
local SERIES_RUNTIME_GUI_NAME = "WOBSeriesStatusRuntimeGui"
local RELOAD_DISPLAY_COOLDOWN = math.max(
	0.01,
	WeaponConfig.PrimaryWeapon.ShootCooldown or HudConfig.Reload.DisplayCooldown or 0.45
)
local RELOAD_READY_TEXT = HudConfig.Reload.ReadyText or "Reload: READY"
local RELOAD_PREFIX = HudConfig.Reload.Prefix or "Reload: "
local RELOAD_SUFFIX = HudConfig.Reload.Suffix or "%"
local OPPONENT_HP_PREFIX = "Opponent HP: "
local PLAYER_HP_PREFIX = "You HP: "
local HEALTH_SEPARATOR = HudConfig.DummyHealth.Separator or " / "
local SHOW_SMALL_ROUND_RESULT_OVERLAY = MatchConfig.ShowSmallRoundResultOverlay ~= false
local SHOW_SMALL_MATCH_RESULT_BEFORE_FULL_RESULT = MatchConfig.ShowSmallMatchResultBeforeFullResult ~= false
local LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE = "LastCrystalsRewardAmount"
local LAST_CRYSTALS_REWARD_REASON_ATTRIBUTE = "LastCrystalsRewardReason"
local LAST_CRYSTALS_REWARD_MATCH_ID_ATTRIBUTE = "LastCrystalsRewardMatchId"

local lastShotTime = -100
local currentPlayerTank = nil
local currentEnemyTank = nil
local elapsedSinceTankRefresh = 0

for _, guiName in ipairs({
	LEGACY_RUNTIME_GUI_NAME,
	SERIES_RUNTIME_GUI_NAME,
}) do
	local runtimeGui = playerGui:FindFirstChild(guiName)

	if runtimeGui ~= nil then
		runtimeGui:Destroy()
	end
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

local function getNamedChild(parent, name, className, missing)
	local child = parent:FindFirstChild(name)

	if child == nil then
		table.insert(missing, parent:GetFullName() .. "/" .. name)
		return nil
	end

	if not child:IsA(className) then
		table.insert(missing, child:GetFullName() .. " " .. className)
		return nil
	end

	return child
end

local function getBarFill(panel, backName, fillName, missing)
	local back = getNamedChild(panel, backName, "Frame", missing)

	if back == nil then
		return nil
	end

	return getNamedChild(back, fillName, "Frame", missing)
end

local function waitForModularHud()
	local hud = playerGui:WaitForChild("HUD", 8)

	if hud == nil then
		return nil, "PlayerGui/HUD was not found"
	end

	if not hud:IsA("ScreenGui") then
		return nil, "PlayerGui/HUD is " .. hud.ClassName .. ", expected ScreenGui"
	end

	local hudRoot = hud:WaitForChild("Root", 8)

	if hudRoot == nil then
		return nil, "PlayerGui/HUD/Root was not found"
	end

	if not hudRoot:IsA("Frame") then
		return nil, "PlayerGui/HUD/Root is " .. hudRoot.ClassName .. ", expected Frame"
	end

	local missing = {}
	local enemyStatusPanel = getNamedChild(hudRoot, "EnemyStatusPanel", "Frame", missing)
	local weaponStatusPanel = getNamedChild(hudRoot, "WeaponStatusPanel", "Frame", missing)
	local playerStatusPanel = getNamedChild(hudRoot, "PlayerStatusPanel", "Frame", missing)
	local roundStatusPanel = getNamedChild(hudRoot, "RoundStatusPanel", "Frame", missing)
	local matchSeriesPanel = getNamedChild(hudRoot, "MatchSeriesPanel", "Frame", missing)

	if enemyStatusPanel == nil
		or weaponStatusPanel == nil
		or playerStatusPanel == nil
		or roundStatusPanel == nil
		or matchSeriesPanel == nil
	then
		return nil, "missing modular HUD panels: " .. table.concat(missing, ", ")
	end

	local enemyHpLabel = getNamedChild(enemyStatusPanel, "EnemyHpLabel", "TextLabel", missing)
	local enemyHpFill = getBarFill(enemyStatusPanel, "EnemyHpBack", "EnemyHpFill", missing)
	local reloadLabel = getNamedChild(weaponStatusPanel, "ReloadLabel", "TextLabel", missing)
	local reloadFill = getBarFill(weaponStatusPanel, "ReloadBack", "ReloadFill", missing)
	local playerHpLabel = getNamedChild(playerStatusPanel, "PlayerHpLabel", "TextLabel", missing)
	local playerHpFill = getBarFill(playerStatusPanel, "PlayerHpBack", "PlayerHpFill", missing)
	local roundResultLabel = getNamedChild(roundStatusPanel, "RoundResultLabel", "TextLabel", missing)
	local restartHintLabel = getNamedChild(roundStatusPanel, "RestartHintLabel", "TextLabel", missing)
	local roundLabel = getNamedChild(matchSeriesPanel, "RoundLabel", "TextLabel", missing)
	local scoreLabel = getNamedChild(matchSeriesPanel, "ScoreLabel", "TextLabel", missing)
	local targetWinsLabel = getNamedChild(matchSeriesPanel, "TargetWinsLabel", "TextLabel", missing)
	local matchResultLabel = getNamedChild(matchSeriesPanel, "MatchResultLabel", "TextLabel", missing)

	if #missing > 0 then
		return nil, "missing modular HUD elements: " .. table.concat(missing, ", ")
	end

	roundStatusPanel.Visible = false
	lockUiTree(hudRoot)

	return {
		Source = "Modular Studio HUD",
		ScreenGui = hud,
		RoundStatusPanel = roundStatusPanel,
		EnemyHpLabel = enemyHpLabel,
		EnemyHpFill = enemyHpFill,
		ReloadLabel = reloadLabel,
		ReloadFill = reloadFill,
		PlayerHpLabel = playerHpLabel,
		PlayerHpFill = playerHpFill,
		RoundResultLabel = roundResultLabel,
		RestartHintLabel = restartHintLabel,
		RoundLabel = roundLabel,
		ScoreLabel = scoreLabel,
		TargetWinsLabel = targetWinsLabel,
		MatchResultLabel = matchResultLabel,
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

local function createEmergencyPanel(parent, name, position, size)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(9, 12, 15)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = parent
	lockGuiObject(panel)

	return panel
end

local function createEmergencyBar(parent, backName, fillName, position, size, fillColor)
	local back = Instance.new("Frame")
	back.Name = backName
	back.Position = position
	back.Size = size
	back.BackgroundColor3 = Color3.fromRGB(35, 42, 45)
	back.BorderSizePixel = 0
	back.Parent = parent
	lockGuiObject(back)

	local fill = Instance.new("Frame")
	fill.Name = fillName
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	lockGuiObject(fill)

	return fill
end

local function createEmergencyRoundUi(reason)
	warn("[WOB] Modular HUD not found (" .. reason .. "). Using emergency runtime UI. Run docs/patches/CREATE_MODULAR_HUD_COMMAND.lua in Studio Command Bar.")

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

	local hudRoot = Instance.new("Frame")
	hudRoot.Name = "Root"
	hudRoot.Size = UDim2.new(1, 0, 1, 0)
	hudRoot.BackgroundTransparency = 1
	hudRoot.BorderSizePixel = 0
	hudRoot.Parent = screenGui
	lockGuiObject(hudRoot)

	local enemyPanel = createEmergencyPanel(
		hudRoot,
		"EnemyStatusPanel",
		UDim2.new(0, 18, 0, 18),
		UDim2.new(0, 280, 0, 70)
	)
	local enemyHpLabel = createEmergencyLabel(
		"EnemyHpLabel",
		enemyPanel,
		UDim2.new(0, 14, 0, 8),
		UDim2.new(1, -28, 0, 26),
		18,
		Enum.Font.GothamBold
	)
	local enemyHpFill = createEmergencyBar(
		enemyPanel,
		"EnemyHpBack",
		"EnemyHpFill",
		UDim2.new(0, 14, 0, 42),
		UDim2.new(1, -28, 0, 14),
		Color3.fromRGB(235, 90, 80)
	)

	local weaponPanel = createEmergencyPanel(
		hudRoot,
		"WeaponStatusPanel",
		UDim2.new(0, 18, 0, 96),
		UDim2.new(0, 280, 0, 70)
	)
	local reloadLabel = createEmergencyLabel(
		"ReloadLabel",
		weaponPanel,
		UDim2.new(0, 14, 0, 8),
		UDim2.new(1, -28, 0, 26),
		18,
		Enum.Font.GothamBold
	)
	local reloadFill = createEmergencyBar(
		weaponPanel,
		"ReloadBack",
		"ReloadFill",
		UDim2.new(0, 14, 0, 42),
		UDim2.new(1, -28, 0, 14),
		Color3.fromRGB(95, 180, 255)
	)

	local playerPanel = createEmergencyPanel(
		hudRoot,
		"PlayerStatusPanel",
		UDim2.new(0, 18, 1, -88),
		UDim2.new(0, 280, 0, 70)
	)
	local playerHpLabel = createEmergencyLabel(
		"PlayerHpLabel",
		playerPanel,
		UDim2.new(0, 14, 0, 8),
		UDim2.new(1, -28, 0, 26),
		18,
		Enum.Font.GothamBold
	)
	local playerHpFill = createEmergencyBar(
		playerPanel,
		"PlayerHpBack",
		"PlayerHpFill",
		UDim2.new(0, 14, 0, 42),
		UDim2.new(1, -28, 0, 14),
		Color3.fromRGB(80, 220, 135)
	)

	local roundPanel = createEmergencyPanel(
		hudRoot,
		"RoundStatusPanel",
		UDim2.new(0.5, -140, 0, 18),
		UDim2.new(0, 280, 0, 78)
	)
	roundPanel.Visible = false

	local roundResultLabel = createEmergencyLabel(
		"RoundResultLabel",
		roundPanel,
		UDim2.new(0, 14, 0, 8),
		UDim2.new(1, -28, 0, 32),
		24,
		Enum.Font.GothamBlack
	)
	roundResultLabel.Visible = false

	local restartHintLabel = createEmergencyLabel(
		"RestartHintLabel",
		roundPanel,
		UDim2.new(0, 14, 0, 42),
		UDim2.new(1, -28, 0, 24),
		15,
		Enum.Font.GothamBold
	)
	restartHintLabel.Visible = false

	local matchPanel = createEmergencyPanel(
		hudRoot,
		"MatchSeriesPanel",
		UDim2.new(1, -338, 0, 18),
		UDim2.new(0, 320, 0, 112)
	)
	local roundLabel = createEmergencyLabel(
		"RoundLabel",
		matchPanel,
		UDim2.new(0, 14, 0, 8),
		UDim2.new(1, -28, 0, 22),
		16,
		Enum.Font.GothamBold
	)
	local scoreLabel = createEmergencyLabel(
		"ScoreLabel",
		matchPanel,
		UDim2.new(0, 14, 0, 32),
		UDim2.new(1, -28, 0, 22),
		16,
		Enum.Font.GothamBold
	)
	local targetWinsLabel = createEmergencyLabel(
		"TargetWinsLabel",
		matchPanel,
		UDim2.new(0, 14, 0, 56),
		UDim2.new(1, -28, 0, 22),
		16,
		Enum.Font.GothamBold
	)
	local matchResultLabel = createEmergencyLabel(
		"MatchResultLabel",
		matchPanel,
		UDim2.new(0, 14, 0, 80),
		UDim2.new(1, -28, 0, 24),
		20,
		Enum.Font.GothamBlack
	)
	matchResultLabel.Visible = false

	return {
		Source = "Emergency modular runtime UI",
		ScreenGui = screenGui,
		RoundStatusPanel = roundPanel,
		EnemyHpLabel = enemyHpLabel,
		EnemyHpFill = enemyHpFill,
		ReloadLabel = reloadLabel,
		ReloadFill = reloadFill,
		PlayerHpLabel = playerHpLabel,
		PlayerHpFill = playerHpFill,
		RoundResultLabel = roundResultLabel,
		RestartHintLabel = restartHintLabel,
		RoundLabel = roundLabel,
		ScoreLabel = scoreLabel,
		TargetWinsLabel = targetWinsLabel,
		MatchResultLabel = matchResultLabel,
	}
end

local roundUi, bindError = waitForModularHud()

if roundUi == nil then
	roundUi = createEmergencyRoundUi(bindError or "unknown reason")
end

local function isCombatHudVisible()
	local mode = localPlayer:GetAttribute("PlayerMode")

	return mode == "InMatch" and root:GetAttribute("GameState") == "Playing"
end

local function applyCombatHudVisibility()
	local isVisible = isCombatHudVisible()

	if roundUi.ScreenGui ~= nil then
		roundUi.ScreenGui.Enabled = isVisible
	end

	if not isVisible then
		roundUi.RoundStatusPanel.Visible = false
		roundUi.RoundResultLabel.Visible = false
		roundUi.RestartHintLabel.Visible = false
		roundUi.MatchResultLabel.Visible = false
	end
end

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function getServerTimeNow()
	local success, serverTime = pcall(function()
		return Workspace:GetServerTimeNow()
	end)

	if success and typeof(serverTime) == "number" then
		return serverTime
	end

	return os.clock()
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

local function refreshTankTargets()
	currentPlayerTank = TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
	currentEnemyTank = TankModelResolver.findEnemyTank(root, localPlayer.UserId)
end

local function getCurrentPlayerTankId()
	if currentPlayerTank == nil or currentPlayerTank.Parent == nil then
		refreshTankTargets()
	end

	if currentPlayerTank == nil then
		return nil
	end

	return currentPlayerTank:GetAttribute("TankId") or currentPlayerTank.Name
end

local function getLocalRoundResult(globalResult)
	local tankId = getCurrentPlayerTankId()
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

local function getLocalSeriesScore(playerSideWins, opponentSideWins)
	local currentTankId = getCurrentPlayerTankId()
	local opponentSideTankId = root:GetAttribute("OpponentSideTankId")

	if root:GetAttribute("MatchMode") == "PvP" and currentTankId == opponentSideTankId then
		return opponentSideWins, playerSideWins
	end

	return playerSideWins, opponentSideWins
end

local function getLocalMatchResult(matchResult)
	local tankId = getCurrentPlayerTankId()
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

local function getTankHealth(model, fallbackMaxHealth)
	if model == nil then
		return nil, fallbackMaxHealth
	end

	local maxHealth = model:GetAttribute("MaxHealth") or fallbackMaxHealth
	local health = model:GetAttribute("Health") or maxHealth

	return health, maxHealth
end

local function setUnknownHealth(label, fill, prefix)
	label.Text = prefix .. "-- / --"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(95, 105, 110)
end

local function updateEnemyHealth()
	local health, maxHealth = getTankHealth(currentEnemyTank, HudConfig.DummyHealth.MaxHealthDisplay or 100)

	if health == nil then
		setUnknownHealth(roundUi.EnemyHpLabel, roundUi.EnemyHpFill, OPPONENT_HP_PREFIX)
		return
	end

	local normalizedHealth = clamp01(health / math.max(1, maxHealth))

	roundUi.EnemyHpLabel.Text = OPPONENT_HP_PREFIX .. math.floor(health) .. HEALTH_SEPARATOR .. math.floor(maxHealth)
	roundUi.EnemyHpFill.Size = UDim2.new(normalizedHealth, 0, 1, 0)

	if normalizedHealth <= 0.3 then
		roundUi.EnemyHpFill.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
	elseif normalizedHealth <= 0.6 then
		roundUi.EnemyHpFill.BackgroundColor3 = Color3.fromRGB(240, 190, 80)
	else
		roundUi.EnemyHpFill.BackgroundColor3 = Color3.fromRGB(235, 90, 80)
	end
end

local function updateHealth()
	local health, maxHealth = getTankHealth(currentPlayerTank, 100)

	if health == nil then
		setUnknownHealth(roundUi.PlayerHpLabel, roundUi.PlayerHpFill, PLAYER_HP_PREFIX)
		return
	end

	local normalizedHealth = clamp01(health / math.max(1, maxHealth))

	roundUi.PlayerHpLabel.Text = PLAYER_HP_PREFIX .. math.floor(health) .. " / " .. math.floor(maxHealth)
	roundUi.PlayerHpFill.Size = UDim2.new(normalizedHealth, 0, 1, 0)

	if normalizedHealth <= 0.3 then
		roundUi.PlayerHpFill.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
	elseif normalizedHealth <= 0.6 then
		roundUi.PlayerHpFill.BackgroundColor3 = Color3.fromRGB(240, 190, 80)
	else
		roundUi.PlayerHpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
	end
end

local function updateReloadStatus()
	local reloadProgress = clamp01((os.clock() - lastShotTime) / RELOAD_DISPLAY_COOLDOWN)

	roundUi.ReloadFill.Size = UDim2.new(reloadProgress, 0, 1, 0)

	if reloadProgress >= 1 then
		roundUi.ReloadLabel.Text = RELOAD_READY_TEXT
	else
		roundUi.ReloadLabel.Text = RELOAD_PREFIX .. math.floor(reloadProgress * 100) .. RELOAD_SUFFIX
	end
end

local function updateRoundResult()
	if not isCombatHudVisible() then
		applyCombatHudVisibility()
		return
	end

	local result = getLocalRoundResult(root:GetAttribute("RoundResult") or "Playing")
	local roundEnded = root:GetAttribute("RoundEnded") == true or result == "Win" or result == "Lose"
	local matchEnded = root:GetAttribute("MatchEnded") == true
	local roundFlowState = root:GetAttribute("RoundState")
	local showRoundEnd = SHOW_SMALL_ROUND_RESULT_OVERLAY
		and roundEnded
		and matchEnded ~= true
		and roundFlowState == "RoundEnd"
	local showMatchEnd = SHOW_SMALL_MATCH_RESULT_BEFORE_FULL_RESULT
		and matchEnded
		and roundFlowState == "MatchEnd"
	local shouldShow = showRoundEnd or showMatchEnd

	if not shouldShow then
		roundUi.RoundResultLabel.Text = ""
		roundUi.RoundResultLabel.Visible = false
		roundUi.RestartHintLabel.Text = ""
		roundUi.RestartHintLabel.Visible = false
		roundUi.RoundStatusPanel.Visible = false
		return
	end

	local playerWins = root:GetAttribute("PlayerSideScore") or root:GetAttribute("PlayerWins") or 0
	local opponentWins = root:GetAttribute("OpponentSideScore") or root:GetAttribute("DummyWins") or 0
	local youWins, opponentSideWins = getLocalSeriesScore(playerWins, opponentWins)
	local localMatchResult = getLocalMatchResult(root:GetAttribute("MatchResult") or "")

	if showMatchEnd then
		if localMatchResult == "Win" then
			roundUi.RoundResultLabel.Text = "MATCH WON"
			roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(105, 235, 145)
		elseif localMatchResult == "Loss" then
			roundUi.RoundResultLabel.Text = "MATCH LOST"
			roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(245, 95, 80)
		else
			roundUi.RoundResultLabel.Text = "MATCH ENDED"
			roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(245, 255, 250)
		end

		local seconds = getCountdownSeconds("MatchResultAt", "ResultStartsIn")
		local rewardText = localMatchResult == "Win" and getCurrentMatchCrystalRewardText() or ""

		if rewardText ~= "" then
			roundUi.RestartHintLabel.Text = rewardText .. " - Final " .. youWins .. " / " .. opponentSideWins .. " - Result in " .. seconds
		else
			roundUi.RestartHintLabel.Text = "Final " .. youWins .. " / " .. opponentSideWins .. " - Result in " .. seconds
		end
	elseif result == "Win" then
		roundUi.RoundResultLabel.Text = "ROUND WON"
		roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(105, 235, 145)
		local seconds = getCountdownSeconds("RoundResetAt", "NextRoundStartsIn")
		roundUi.RestartHintLabel.Text = "Score " .. youWins .. " / " .. opponentSideWins .. " - Next round in " .. seconds
	elseif result == "Lose" then
		roundUi.RoundResultLabel.Text = "ROUND LOST"
		roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(245, 95, 80)
		local seconds = getCountdownSeconds("RoundResetAt", "NextRoundStartsIn")
		roundUi.RestartHintLabel.Text = "Score " .. youWins .. " / " .. opponentSideWins .. " - Next round in " .. seconds
	else
		roundUi.RoundResultLabel.Text = "ROUND ENDED"
		roundUi.RoundResultLabel.TextColor3 = Color3.fromRGB(245, 255, 250)
		local seconds = getCountdownSeconds("RoundResetAt", "NextRoundStartsIn")
		roundUi.RestartHintLabel.Text = "Score " .. youWins .. " / " .. opponentSideWins .. " - Next round in " .. seconds
	end

	roundUi.RoundResultLabel.Visible = true
	roundUi.RestartHintLabel.Visible = true
	roundUi.RoundStatusPanel.Visible = true
end

local function updateSeriesStatus()
	if not isCombatHudVisible() then
		applyCombatHudVisibility()
		return
	end

	local playerWins = root:GetAttribute("PlayerWins") or 0
	local dummyWins = root:GetAttribute("DummyWins") or 0
	local youWins, opponentWins = getLocalSeriesScore(playerWins, dummyWins)
	local roundNumber = root:GetAttribute("RoundNumber") or 1
	local targetWins = root:GetAttribute("TargetWins") or 3
	local matchEnded = root:GetAttribute("MatchEnded") == true
	local matchResult = root:GetAttribute("MatchResult") or ""
	local localMatchResult = getLocalMatchResult(matchResult)

	roundUi.RoundLabel.Text = "Round: " .. roundNumber
	roundUi.ScoreLabel.Text = "Score: You " .. youWins .. " / Opponent " .. opponentWins
	roundUi.TargetWinsLabel.Text = "First to " .. targetWins

	if matchEnded then
		if localMatchResult == "Win" then
			roundUi.MatchResultLabel.Text = "MATCH WIN"
			roundUi.MatchResultLabel.TextColor3 = Color3.fromRGB(105, 235, 145)
		elseif localMatchResult == "Loss" then
			roundUi.MatchResultLabel.Text = "MATCH LOSE"
			roundUi.MatchResultLabel.TextColor3 = Color3.fromRGB(245, 95, 80)
		else
			roundUi.MatchResultLabel.Text = "MATCH ENDED"
			roundUi.MatchResultLabel.TextColor3 = Color3.fromRGB(245, 255, 250)
		end

		roundUi.MatchResultLabel.Visible = true
	else
		roundUi.MatchResultLabel.Text = ""
		roundUi.MatchResultLabel.Visible = false
	end
end

root:GetAttributeChangedSignal("RoundResult"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("RoundEnded"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("RoundState"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("RoundWinnerTankId"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("RoundLoserTankId"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("RoundResetAt"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("MatchResultAt"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("NextRoundStartsIn"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("ResultStartsIn"):Connect(updateRoundResult)
root:GetAttributeChangedSignal("GameState"):Connect(function()
	refreshTankTargets()
	updateEnemyHealth()
	updateHealth()
	applyCombatHudVisibility()
	updateRoundResult()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("MatchMode"):Connect(function()
	refreshTankTargets()
	updateEnemyHealth()
	updateHealth()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("PlayerWins"):Connect(updateSeriesStatus)
root:GetAttributeChangedSignal("DummyWins"):Connect(updateSeriesStatus)
root:GetAttributeChangedSignal("PlayerSideScore"):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("OpponentSideScore"):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("RoundNumber"):Connect(updateSeriesStatus)
root:GetAttributeChangedSignal("TargetWins"):Connect(updateSeriesStatus)
root:GetAttributeChangedSignal("MatchEnded"):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("MatchResult"):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("MatchWinnerTankId"):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
root:GetAttributeChangedSignal("MatchLoserTankId"):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_REASON_ATTRIBUTE):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_MATCH_ID_ATTRIBUTE):Connect(function()
	updateRoundResult()
	updateSeriesStatus()
end)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(function()
	refreshTankTargets()
	updateEnemyHealth()
	updateHealth()
	applyCombatHudVisibility()
	updateRoundResult()
	updateSeriesStatus()
end)

root.DescendantAdded:Connect(function()
	refreshTankTargets()
	updateEnemyHealth()
	updateHealth()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		lastShotTime = os.clock()
	elseif input.KeyCode == Enum.KeyCode.R
		and localPlayer:GetAttribute("PlayerMode") == "InMatch"
		and root:GetAttribute("RoundEnded") ~= true
		and root:GetAttribute("MatchEnded") ~= true
	then
		resetDummyRequestEvent:FireServer()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	updateReloadStatus()

	elapsedSinceTankRefresh += deltaTime

	if elapsedSinceTankRefresh >= 0.2 then
		elapsedSinceTankRefresh = 0
		refreshTankTargets()
		updateEnemyHealth()
		updateHealth()
		updateRoundResult()
	end
end)

refreshTankTargets()
updateEnemyHealth()
updateHealth()
updateReloadStatus()
updateRoundResult()
updateSeriesStatus()
applyCombatHudVisibility()

print("[WOB] Round status overlay bound to " .. roundUi.Source)
