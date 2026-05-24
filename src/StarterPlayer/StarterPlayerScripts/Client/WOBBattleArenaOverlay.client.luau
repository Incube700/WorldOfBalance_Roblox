local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local BattleArenaConfig = require(configs:WaitForChild("BattleArenaConfig"))
local BattleArenaLoopConfig = require(configs:WaitForChild("BattleArenaLoopConfig"))
local HudConfig = require(configs:WaitForChild("HudConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))
local hudModules = script.Parent:WaitForChild("Hud")
local HudDeviceUtils = require(hudModules:WaitForChild("HudDeviceUtils"))
local HudVisibilityRules = require(hudModules:WaitForChild("HudVisibilityRules"))
local CompactStatsFormatter = require(hudModules:WaitForChild("CompactStatsFormatter"))
local BattleArenaUpgradeHud = require(hudModules:WaitForChild("BattleArenaUpgradeHud"))
local HudWidgetFactory = require(hudModules:WaitForChild("HudWidgetFactory"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local returnToMenuRequestEvent = remotes:WaitForChild("ReturnToMenuRequestEvent")
local upgradeChoiceEvent = remotes:WaitForChild("UpgradeChoiceEvent")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local root = Workspace:WaitForChild("WOB_Generated")

local GUI_NAME = "WOBBattleArenaOverlay"
local MODE_ARENA_RESPAWNING = "ArenaRespawning"
local PERSISTENT_BOLTS_ATTRIBUTE = "PersistentBolts"
local UNSAVED_BOLTS_ATTRIBUTE = "UnsavedBolts"
local CRYSTALS_ATTRIBUTE = "Crystals"
local PERSISTENT_CRYSTALS_ATTRIBUTE = "PersistentCrystals"
local UNSAVED_CRYSTALS_ATTRIBUTE = "UnsavedCrystals"
local PANEL_Z_INDEX = 10
local ACTION_Z_INDEX = 20
local POPUP_Z_INDEX = 30

local mobileHudConfig = BattleArenaConfig.MobileHud or {}
local mobileHudCompact = mobileHudConfig.Compact ~= false
local mobileUseMenuForReturn = mobileHudConfig.UseMenuForReturn ~= false

local existingGui = playerGui:FindFirstChild(GUI_NAME)

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 82
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- UI primitive construction now lives in Hud/HudWidgetFactory. These thin
-- wrappers keep the overlay's existing call sites and exact visual defaults.
local function addCorner(parent, radius)
	return HudWidgetFactory.addCorner(parent, radius)
end

local function addStroke(parent, color, transparency, thickness)
	return HudWidgetFactory.addStroke(parent, color, transparency, thickness)
end

local function makePanel(name, position, size)
	return HudWidgetFactory.createPanel({
		Name = name,
		Parent = screenGui,
		Position = position,
		Size = size,
		ZIndex = PANEL_Z_INDEX,
	})
end

local function makeLabel(parent, name, position, size, textSize, font)
	return HudWidgetFactory.createLabel({
		Parent = parent,
		Name = name,
		Position = position,
		Size = size,
		TextSize = textSize,
		Font = font or Enum.Font.GothamBold,
		FallbackZIndex = PANEL_Z_INDEX + 1,
	})
end

local function makeBar(parent, name, position, size, fillColor)
	local fill = HudWidgetFactory.createBar({
		Parent = parent,
		Name = name,
		Position = position,
		Size = size,
		FillColor = fillColor,
		FallbackZIndex = PANEL_Z_INDEX + 1,
	})

	return fill
end

local function styleButton(button, text)
	HudWidgetFactory.styleButton(button, text)
end

local healthPanel = makePanel(
	"HealthPanel",
	UDim2.new(0, 18, 0, 18),
	UDim2.new(0, 260, 0, 78)
)

local healthLabel = makeLabel(
	healthPanel,
	"HealthLabel",
	UDim2.new(0, 14, 0, 8),
	UDim2.new(1, -28, 0, 28),
	18,
	Enum.Font.GothamBlack
)

local healthFill = makeBar(
	healthPanel,
	"Health",
	UDim2.new(0, 14, 0, 46),
	UDim2.new(1, -28, 0, 14),
	Color3.fromRGB(80, 220, 135)
)
local healthBack = healthFill.Parent

local scorePanel = makePanel(
	"ScorePanel",
	UDim2.new(1, -272, 0, 18),
	UDim2.new(0, 250, 0, 128)
)

local scoreLabel = makeLabel(
	scorePanel,
	"ScoreLabel",
	UDim2.new(0, 14, 0, 8),
	UDim2.new(1, -28, 0, 28),
	18,
	Enum.Font.GothamBlack
)

local killsDeathsLabel = makeLabel(
	scorePanel,
	"KillsDeathsLabel",
	UDim2.new(0, 14, 0, 36),
	UDim2.new(1, -28, 0, 24),
	16,
	Enum.Font.GothamBold
)

local streakLabel = makeLabel(
	scorePanel,
	"StreakLabel",
	UDim2.new(0, 14, 0, 62),
	UDim2.new(1, -28, 0, 22),
	14,
	Enum.Font.GothamBold
)
streakLabel.TextColor3 = Color3.fromRGB(208, 244, 220)

local upgradesLabel = makeLabel(
	scorePanel,
	"UpgradesLabel",
	UDim2.new(0, 14, 0, 86),
	UDim2.new(1, -28, 0, 34),
	14,
	Enum.Font.GothamMedium
)
upgradesLabel.TextColor3 = Color3.fromRGB(178, 238, 205)

local sessionLabel = makeLabel(
	scorePanel,
	"SessionLabel",
	UDim2.new(0, 14, 0, 120),
	UDim2.new(1, -28, 0, 22),
	13,
	Enum.Font.GothamMedium
)
sessionLabel.TextColor3 = Color3.fromRGB(255, 225, 120)

local actionsRoot = Instance.new("Frame")
actionsRoot.Name = "BattleArenaActionsRoot"
actionsRoot.Position = UDim2.fromScale(0, 0)
actionsRoot.Size = UDim2.fromScale(1, 1)
actionsRoot.BackgroundTransparency = 1
actionsRoot.BorderSizePixel = 0
actionsRoot.Active = false
actionsRoot.ZIndex = ACTION_Z_INDEX
actionsRoot.Parent = screenGui

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToLobbyButton"
returnButton.AnchorPoint = Vector2.new(1, 1)
returnButton.Position = UDim2.new(1, -22, 1, -22)
returnButton.Size = UDim2.fromOffset(154, 42)
returnButton.ZIndex = ACTION_Z_INDEX + 1
returnButton.Parent = actionsRoot
styleButton(returnButton)

local menuButton = Instance.new("TextButton")
menuButton.Name = "BattleArenaMenuButton"
menuButton.AnchorPoint = Vector2.new(0.5, 0)
menuButton.Position = UDim2.new(0.5, 0, 0, 48)
menuButton.Size = UDim2.fromOffset(72, 36)
menuButton.Visible = false
menuButton.ZIndex = ACTION_Z_INDEX + 1
menuButton.Parent = actionsRoot
styleButton(menuButton, "Menu")
menuButton.TextSize = 14

local menuPopupRoot = Instance.new("Frame")
menuPopupRoot.Name = "BattleArenaMenuPopup"
menuPopupRoot.Position = UDim2.fromScale(0, 0)
menuPopupRoot.Size = UDim2.fromScale(1, 1)
menuPopupRoot.BackgroundTransparency = 1
menuPopupRoot.BorderSizePixel = 0
menuPopupRoot.Active = false
menuPopupRoot.Visible = false
menuPopupRoot.ZIndex = POPUP_Z_INDEX
menuPopupRoot.Parent = actionsRoot

local menuDim = Instance.new("Frame")
menuDim.Name = "MenuDim"
menuDim.Position = UDim2.fromScale(0, 0)
menuDim.Size = UDim2.fromScale(1, 1)
menuDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
menuDim.BackgroundTransparency = 0.52
menuDim.BorderSizePixel = 0
menuDim.Active = true
menuDim.ZIndex = POPUP_Z_INDEX
menuDim.Parent = menuPopupRoot

local menuPanel = Instance.new("Frame")
menuPanel.Name = "MenuPanel"
menuPanel.AnchorPoint = Vector2.new(0.5, 0.5)
menuPanel.Position = UDim2.fromScale(0.5, 0.5)
menuPanel.Size = UDim2.fromOffset(260, 172)
menuPanel.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
menuPanel.BackgroundTransparency = 0.05
menuPanel.BorderSizePixel = 0
menuPanel.Active = true
menuPanel.ZIndex = POPUP_Z_INDEX + 1
menuPanel.Parent = menuPopupRoot
addCorner(menuPanel, UDim.new(0, 8))
addStroke(menuPanel, Color3.fromRGB(31, 41, 55), 0.25, 1)

local menuTitleLabel = Instance.new("TextLabel")
menuTitleLabel.Name = "MenuTitleLabel"
menuTitleLabel.Position = UDim2.new(0, 18, 0, 12)
menuTitleLabel.Size = UDim2.new(1, -36, 0, 28)
menuTitleLabel.BackgroundTransparency = 1
menuTitleLabel.BorderSizePixel = 0
menuTitleLabel.Font = Enum.Font.GothamBlack
menuTitleLabel.Text = "Arena Menu"
menuTitleLabel.TextColor3 = Color3.fromRGB(241, 255, 248)
menuTitleLabel.TextSize = 18
menuTitleLabel.TextWrapped = true
menuTitleLabel.ZIndex = POPUP_Z_INDEX + 2
menuTitleLabel.Parent = menuPanel

local resumeButton = Instance.new("TextButton")
resumeButton.Name = "ResumeButton"
resumeButton.Position = UDim2.new(0, 18, 0, 54)
resumeButton.Size = UDim2.new(1, -36, 0, 42)
resumeButton.ZIndex = POPUP_Z_INDEX + 2
resumeButton.Parent = menuPanel
styleButton(resumeButton, "Resume")

local popupReturnButton = Instance.new("TextButton")
popupReturnButton.Name = "PopupReturnToLobbyButton"
popupReturnButton.Position = UDim2.new(0, 18, 0, 108)
popupReturnButton.Size = UDim2.new(1, -36, 0, 42)
popupReturnButton.ZIndex = POPUP_Z_INDEX + 2
popupReturnButton.Parent = menuPanel
styleButton(popupReturnButton)
popupReturnButton.BackgroundColor3 = Color3.fromRGB(166, 74, 64)
popupReturnButton.TextColor3 = Color3.fromRGB(248, 255, 248)

local menuPopupOpen = false
local currentUpgradeOffer = nil

local function setMenuPopupOpen(isOpen)
	menuPopupOpen = isOpen == true
	menuPopupRoot.Active = menuPopupOpen
	menuPopupRoot.Visible = menuPopupOpen
end

local deathPanel = makePanel(
	"DeathPanel",
	UDim2.new(0.5, -150, 0.5, -82),
	UDim2.new(0, 300, 0, 164)
)

local destroyedLabel = makeLabel(
	deathPanel,
	"DestroyedLabel",
	UDim2.new(0, 18, 0, 18),
	UDim2.new(1, -36, 0, 44),
	30,
	Enum.Font.GothamBlack
)
destroyedLabel.Text = "Destroyed"
destroyedLabel.TextXAlignment = Enum.TextXAlignment.Center
destroyedLabel.TextColor3 = Color3.fromRGB(255, 116, 92)

local respawnLabel = makeLabel(
	deathPanel,
	"RespawnLabel",
	UDim2.new(0, 18, 0, 68),
	UDim2.new(1, -36, 0, 30),
	20,
	Enum.Font.GothamBold
)
respawnLabel.TextXAlignment = Enum.TextXAlignment.Center

local deathSummaryLabel = makeLabel(
	deathPanel,
	"DeathSummaryLabel",
	UDim2.new(0, 18, 0, 100),
	UDim2.new(1, -36, 0, 24),
	14,
	Enum.Font.GothamMedium
)
deathSummaryLabel.TextXAlignment = Enum.TextXAlignment.Center
deathSummaryLabel.TextColor3 = Color3.fromRGB(255, 225, 120)

local deathReturnButton = Instance.new("TextButton")
deathReturnButton.Name = "DeathReturnToLobbyButton"
deathReturnButton.Position = UDim2.new(0.18, 0, 1, -52)
deathReturnButton.Size = UDim2.new(0.64, 0, 0, 38)
deathReturnButton.Parent = deathPanel
styleButton(deathReturnButton)

local upgradeHud
upgradeHud = BattleArenaUpgradeHud.new({
	Parent = screenGui,
	ZIndex = POPUP_Z_INDEX,
	OnChoiceSelected = function(upgradeId)
		if currentUpgradeOffer == nil then
			return
		end

		if typeof(upgradeId) ~= "string" or upgradeId == "" then
			return
		end

		upgradeChoiceEvent:FireServer({
			OfferId = currentUpgradeOffer.OfferId,
			UpgradeId = upgradeId,
		})
		currentUpgradeOffer = nil
		upgradeHud:SetOffer(nil)
	end,
})

local function isArenaMode()
	local mode = localPlayer:GetAttribute("PlayerMode")

	return HudVisibilityRules.ShouldShowBattleArenaStats({
		PlayerMode = mode,
	})
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

local function formatSeconds(seconds)
	local safeSeconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(safeSeconds / 60)
	local remainder = safeSeconds % 60

	return string.format("%d:%02d", minutes, remainder)
end

local function getSessionStatusText()
	if BattleArenaLoopConfig.Enabled ~= true then
		return "Fight bots, angle armor, earn Bolts"
	end

	local sessionConfig = BattleArenaLoopConfig.Session or {}

	if sessionConfig.ShowSessionTimer ~= true then
		return "Fight bots, angle armor, earn Bolts"
	end

	local softEndsAt = tonumber(localPlayer:GetAttribute("ArenaSessionSoftEndsAt")) or 0

	if softEndsAt <= 0 then
		return sessionConfig.EndlessMode == false and "Timed arena run" or "Endless arena"
	end

	local remaining = softEndsAt - getServerTimeNow()

	if remaining <= 0 then
		return sessionConfig.EndlessMode == false and "Time up" or "Bonus time"
	end

	return "Timer " .. formatSeconds(remaining) .. "  -  earn Bolts"
end

local function getOwnedTank()
	return TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
end

local function isMobileLayout()
	return HudDeviceUtils.IsMobileLayout()
end

local function shouldHideTopHealthPanel(mobileLayout)
	return not HudVisibilityRules.ShouldShowLegacyHpPanels({
		PlayerMode = localPlayer:GetAttribute("PlayerMode"),
		IsMobile = mobileLayout,
		HudConfig = HudConfig,
	})
end

local function setTextLayout(label, position, size, textSize)
	label.Position = position
	label.Size = size
	label.TextSize = textSize
end

local function setCompactText(label, isCompact)
	label.TextWrapped = not isCompact
	label.TextTruncate = isCompact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
end

-- Presentation layout presets live in HudConfig.Layouts.BattleArena (Phase 2).
-- The overlay only reads these display values and applies them; it does not own
-- any layout constants itself.
local battleArenaLayouts = (HudConfig.Layouts and HudConfig.Layouts.BattleArena) or {}

local function applyPanelLayout(panel, cfg)
	if cfg.AnchorPoint ~= nil then
		panel.AnchorPoint = cfg.AnchorPoint
	end
	if cfg.Position ~= nil then
		panel.Position = cfg.Position
	end
	if cfg.Size ~= nil then
		panel.Size = cfg.Size
	end
	if cfg.BackgroundTransparency ~= nil then
		panel.BackgroundTransparency = cfg.BackgroundTransparency
	end
end

local function applyLabelLayout(label, cfg)
	setTextLayout(label, cfg.Position, cfg.Size, cfg.TextSize)
	if cfg.Compact ~= nil then
		setCompactText(label, cfg.Compact)
	end
	if cfg.Visible ~= nil then
		label.Visible = cfg.Visible
	end
end

local function applyDesktopLayout()
	local layout = battleArenaLayouts.Desktop

	applyPanelLayout(healthPanel, layout.HealthPanel)
	applyLabelLayout(healthLabel, layout.HealthLabel)
	healthBack.Position = layout.HealthBar.Position
	healthBack.Size = layout.HealthBar.Size

	applyPanelLayout(scorePanel, layout.ScorePanel)
	applyLabelLayout(scoreLabel, layout.ScoreLabel)
	applyLabelLayout(killsDeathsLabel, layout.KillsDeathsLabel)
	applyLabelLayout(streakLabel, layout.StreakLabel)
	applyLabelLayout(upgradesLabel, layout.UpgradesLabel)
	applyLabelLayout(sessionLabel, layout.SessionLabel)

	local returnCfg = layout.ReturnButton
	returnButton.AnchorPoint = returnCfg.AnchorPoint
	returnButton.Position = returnCfg.Position
	returnButton.Size = returnCfg.Size
	returnButton.Text = returnCfg.Text
	returnButton.TextSize = returnCfg.TextSize
	returnButton.Visible = returnCfg.Visible
	menuButton.Visible = layout.MenuButtonVisible
	setMenuPopupOpen(false)

	deathPanel.Position = layout.DeathPanel.Position
	deathPanel.Size = layout.DeathPanel.Size
	applyLabelLayout(destroyedLabel, layout.DestroyedLabel)
	applyLabelLayout(respawnLabel, layout.RespawnLabel)
	applyLabelLayout(deathSummaryLabel, layout.DeathSummaryLabel)
	deathReturnButton.Position = layout.DeathReturnButton.Position
	deathReturnButton.Size = layout.DeathReturnButton.Size

	local camera = Workspace.CurrentCamera
	local viewportSize = camera ~= nil and camera.ViewportSize or Vector2.new(1024, 768)
	upgradeHud:SetLayout({
		IsMobile = false,
		ViewportSize = viewportSize,
	})
end

local function applyMobileLayout(viewportSize)
	local m = battleArenaLayouts.Mobile
	local topY = m.TopY
	local sideInset = m.SideInset
	local menuWidth = mobileUseMenuForReturn and m.MenuButtonWidth or 0
	local scoreWidth = math.clamp(
		viewportSize.X - sideInset * 3 - menuWidth,
		m.ScoreWidthCompactMin,
		m.ScoreWidthCompactMax
	)
	local showBolts = scoreWidth >= m.ShowBoltsMinWidth
	local scoreContentWidth = scoreWidth - m.ScoreContentInset
	local scoreColumnWidth = math.floor((scoreContentWidth - m.ScoreColumnGap) * 0.5)

	if not mobileHudCompact then
		scoreWidth = math.clamp(viewportSize.X - sideInset * 2, m.ScoreWidthFullMin, m.ScoreWidthFullMax)
		scoreContentWidth = scoreWidth - m.ScoreContentInset
		scoreColumnWidth = math.floor((scoreContentWidth - m.ScoreColumnGap) * 0.5)
		showBolts = true
	end

	local healthPanelCfg = m.HealthPanel
	healthPanel.AnchorPoint = healthPanelCfg.AnchorPoint
	healthPanel.Position = UDim2.fromOffset(sideInset, healthPanelCfg.OffsetY)
	healthPanel.Size = UDim2.fromOffset(math.min(scoreWidth, healthPanelCfg.MaxWidth), healthPanelCfg.Height)
	healthPanel.BackgroundTransparency = healthPanelCfg.BackgroundTransparency
	setTextLayout(healthLabel, m.HealthLabel.Position, m.HealthLabel.Size, m.HealthLabel.TextSize)
	setCompactText(healthLabel, true)
	healthBack.Position = m.HealthBar.Position
	healthBack.Size = m.HealthBar.Size

	local scorePanelCfg = m.ScorePanel
	scorePanel.AnchorPoint = scorePanelCfg.AnchorPoint
	scorePanel.Position = UDim2.fromOffset(sideInset, topY)
	scorePanel.Size = UDim2.fromOffset(scoreWidth, showBolts and scorePanelCfg.HeightWithBolts or scorePanelCfg.HeightWithoutBolts)
	scorePanel.BackgroundTransparency = scorePanelCfg.BackgroundTransparency
	setTextLayout(
		scoreLabel,
		UDim2.new(0, m.ScoreLabel.OffsetX, 0, m.ScoreLabel.OffsetY),
		UDim2.fromOffset(scoreColumnWidth, m.ScoreLabel.Height),
		m.ScoreLabel.TextSize
	)
	setTextLayout(
		killsDeathsLabel,
		UDim2.new(0, m.KillsDeathsLabel.ColumnGapInset + scoreColumnWidth, 0, m.KillsDeathsLabel.OffsetY),
		UDim2.fromOffset(scoreColumnWidth, m.KillsDeathsLabel.Height),
		m.KillsDeathsLabel.TextSize
	)
	setTextLayout(
		streakLabel,
		UDim2.new(0, m.StreakLabel.OffsetX, 0, m.StreakLabel.OffsetY),
		UDim2.fromOffset(showBolts and scoreColumnWidth or scoreContentWidth, m.StreakLabel.Height),
		m.StreakLabel.TextSize
	)
	setTextLayout(
		upgradesLabel,
		UDim2.new(0, m.UpgradesLabel.ColumnGapInset + scoreColumnWidth, 0, m.UpgradesLabel.OffsetY),
		UDim2.fromOffset(scoreColumnWidth, m.UpgradesLabel.Height),
		m.UpgradesLabel.TextSize
	)
	setCompactText(scoreLabel, true)
	setCompactText(killsDeathsLabel, true)
	setCompactText(streakLabel, true)
	setCompactText(upgradesLabel, true)
	upgradesLabel.Visible = showBolts
	sessionLabel.Visible = false

	returnButton.Visible = not mobileUseMenuForReturn
	menuButton.Visible = mobileUseMenuForReturn
	menuButton.AnchorPoint = m.MenuButton.AnchorPoint
	menuButton.Position = UDim2.new(1, -sideInset, 0, topY)
	menuButton.Size = UDim2.fromOffset(menuWidth, m.MenuButton.Height)
	menuButton.Text = m.MenuButton.Text
	menuButton.TextSize = m.MenuButton.TextSize

	deathPanel.Position = m.DeathPanel.Position
	deathPanel.Size = m.DeathPanel.Size
	setTextLayout(destroyedLabel, m.DestroyedLabel.Position, m.DestroyedLabel.Size, m.DestroyedLabel.TextSize)
	setTextLayout(respawnLabel, m.RespawnLabel.Position, m.RespawnLabel.Size, m.RespawnLabel.TextSize)
	setTextLayout(deathSummaryLabel, m.DeathSummaryLabel.Position, m.DeathSummaryLabel.Size, m.DeathSummaryLabel.TextSize)
	deathReturnButton.Position = m.DeathReturnButton.Position
	deathReturnButton.Size = m.DeathReturnButton.Size

	upgradeHud:SetLayout({
		IsMobile = true,
		ViewportSize = viewportSize,
	})
end

local function updateLayout()
	local camera = Workspace.CurrentCamera
	local viewportSize = camera ~= nil and camera.ViewportSize or Vector2.new(1024, 768)

	if isMobileLayout() then
		applyMobileLayout(viewportSize)
	else
		applyDesktopLayout()
	end
end

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function getFirstNumberAttribute(source, attributeNames)
	if source == nil then
		return nil
	end

	for _, attributeName in ipairs(attributeNames) do
		local value = source:GetAttribute(attributeName)

		if typeof(value) == "number" then
			return value
		end
	end

	return nil
end

local function getOwnedTankHealth(ownedTank)
	local maxHealth = getFirstNumberAttribute(ownedTank, { "MaxHealth" })
		or getFirstNumberAttribute(localPlayer, { "MaxHealth" })
		or 100
	local health = getFirstNumberAttribute(ownedTank, { "CurrentHealth", "Health", "HP" })
		or getFirstNumberAttribute(localPlayer, { "CurrentHealth", "Health", "HP" })
		or maxHealth

	return health, maxHealth
end

local function getUpgradeCount(upgradeIds)
	if typeof(upgradeIds) ~= "string" or upgradeIds == "" then
		return 0
	end

	local count = 0

	for _ in string.gmatch(upgradeIds, "[^,]+") do
		count = count + 1
	end

	return count
end

local function getVisibleBolts()
	local persistentBolts = tonumber(localPlayer:GetAttribute(PERSISTENT_BOLTS_ATTRIBUTE))

	if persistentBolts ~= nil then
		return math.max(0, math.floor(persistentBolts))
	end

	return math.max(0, math.floor(tonumber(localPlayer:GetAttribute(UNSAVED_BOLTS_ATTRIBUTE)) or 0))
end

local function getVisibleCrystals()
	local crystals = tonumber(localPlayer:GetAttribute(CRYSTALS_ATTRIBUTE))

	if crystals ~= nil then
		return math.max(0, math.floor(crystals))
	end

	local persistentCrystals = tonumber(localPlayer:GetAttribute(PERSISTENT_CRYSTALS_ATTRIBUTE))

	if persistentCrystals ~= nil then
		return math.max(0, math.floor(persistentCrystals))
	end

	return math.max(0, math.floor(tonumber(localPlayer:GetAttribute(UNSAVED_CRYSTALS_ATTRIBUTE)) or 0))
end

local function updateHealth(ownedTank, mobileLayout)
	local health, maxHealth = getOwnedTankHealth(ownedTank)
	local normalizedHealth = clamp01(health / math.max(1, maxHealth))
	local separator = mobileLayout and "/" or " / "

	healthLabel.Text = "HP: " .. tostring(math.floor(health)) .. separator .. tostring(math.floor(maxHealth))
	healthFill.Size = UDim2.new(normalizedHealth, 0, 1, 0)

	if normalizedHealth <= 0.3 then
		healthFill.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
	elseif normalizedHealth <= 0.6 then
		healthFill.BackgroundColor3 = Color3.fromRGB(240, 190, 80)
	else
		healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
	end
end

local function updateOverlay()
	local visible = isArenaMode()
	screenGui.Enabled = visible

	if not visible then
		setMenuPopupOpen(false)
		upgradeHud:SetVisible(false)
		upgradeHud:SetOffer(nil)
		return
	end

	local mobileLayout = isMobileLayout()
	updateLayout()
	healthPanel.Visible = not shouldHideTopHealthPanel(mobileLayout)

	local score = localPlayer:GetAttribute("ArenaScore") or 0
	local arenaXP = localPlayer:GetAttribute("ArenaXP") or 0
	local arenaLevel = localPlayer:GetAttribute("ArenaLevel") or 1
	local nextLevelXP = localPlayer:GetAttribute("ArenaNextLevelXP")
	local kills = localPlayer:GetAttribute("ArenaKills") or 0
	local deaths = localPlayer:GetAttribute("ArenaDeaths") or 0
	local streak = localPlayer:GetAttribute("ArenaStreak") or 0
	local upgrades = localPlayer:GetAttribute("ArenaUpgradeIds") or ""
	local ownedTank = getOwnedTank()

	if HudVisibilityRules.ShouldUseCompactMobileStats({ IsMobile = mobileLayout }) then
		local camera = Workspace.CurrentCamera
		local viewportSize = camera ~= nil and camera.ViewportSize or Vector2.new(1024, 768)
		local useShortLabels = viewportSize.X < 390
		local statText = CompactStatsFormatter.FormatArenaStats({
			Score = score,
			XP = arenaXP,
			Level = arenaLevel,
			NextLevelXP = nextLevelXP,
			Kills = kills,
			Deaths = deaths,
			Crystals = getVisibleCrystals(),
			Bolts = getVisibleBolts(),
			UseShortLabels = useShortLabels,
		})

		scoreLabel.Text = statText.Score
		killsDeathsLabel.Text = statText.KillsDeaths
		streakLabel.Text = statText.Crystals
		upgradesLabel.Text = statText.Bolts
	else
		local xpText = nextLevelXP ~= nil and nextLevelXP > 0
			and (tostring(math.floor(arenaXP)) .. " / " .. tostring(math.floor(nextLevelXP)))
			or tostring(math.floor(arenaXP))
		scoreLabel.Text = "Arena: fight bots"
		killsDeathsLabel.Text = "Score: " .. tostring(math.floor(score))
			.. "  K/D: "
			.. tostring(math.floor(kills))
			.. "/"
			.. tostring(math.floor(deaths))
		streakLabel.Text = "Lv "
			.. tostring(math.floor(arenaLevel))
			.. " XP "
			.. xpText
			.. "  Streak "
			.. tostring(math.floor(streak))
		upgradesLabel.Text = "Bolts +" .. tostring(math.floor(localPlayer:GetAttribute("ArenaSessionBolts") or 0))
			.. "  Upg: "
			.. tostring(getUpgradeCount(upgrades))
		sessionLabel.Text = getSessionStatusText()
	end

	updateHealth(ownedTank, mobileLayout)
	upgradeHud:SetVisible(true)
	upgradeHud:SetOffer(currentUpgradeOffer)
	upgradeHud:SetActiveUpgradeIds(upgrades)

	local mode = localPlayer:GetAttribute("PlayerMode")
	local isDead = mode == MODE_ARENA_RESPAWNING
		or (ownedTank ~= nil and ownedTank:GetAttribute("IsDead") == true)
		or localPlayer:GetAttribute("IsDead") == true

	deathPanel.Visible = isDead

	if isDead then
		local respawnAt = localPlayer:GetAttribute("ArenaRespawnAt")
		local seconds = 0

		if typeof(respawnAt) == "number" and respawnAt > 0 then
			seconds = math.max(0, math.ceil(respawnAt - getServerTimeNow()))
		end

		respawnLabel.Text = "Respawn in " .. tostring(seconds) .. "..."
		deathSummaryLabel.Text = tostring(localPlayer:GetAttribute("ArenaLastSummary") or "")
	end
end

local function requestReturnToLobby()
	setMenuPopupOpen(false)
	returnToMenuRequestEvent:FireServer()
end

returnButton.Activated:Connect(requestReturnToLobby)
menuButton.Activated:Connect(function()
	setMenuPopupOpen(true)
end)
resumeButton.Activated:Connect(function()
	setMenuPopupOpen(false)
end)
popupReturnButton.Activated:Connect(requestReturnToLobby)
deathReturnButton.Activated:Connect(requestReturnToLobby)

upgradeChoiceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.OfferId) ~= "string" then
		return
	end

	currentUpgradeOffer = payload
	updateOverlay()
end)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaScore"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaXP"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaLevel"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaNextLevelXP"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaKills"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaDeaths"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaStreak"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaUpgradeIds"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaPendingUpgradeOfferId"):Connect(function()
	if tostring(localPlayer:GetAttribute("ArenaPendingUpgradeOfferId") or "") == "" then
		currentUpgradeOffer = nil
	end

	updateOverlay()
end)
localPlayer:GetAttributeChangedSignal("ArenaSessionSoftEndsAt"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaSessionBolts"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaLastSummary"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaRespawnAt"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("CurrentHealth"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("MaxHealth"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("IsDead"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal(PERSISTENT_BOLTS_ATTRIBUTE):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal(UNSAVED_BOLTS_ATTRIBUTE):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal(CRYSTALS_ATTRIBUTE):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal(PERSISTENT_CRYSTALS_ATTRIBUTE):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal(UNSAVED_CRYSTALS_ATTRIBUTE):Connect(updateOverlay)

local overlayUpdateAccumulator = 0

RunService.RenderStepped:Connect(function(deltaTime)
	overlayUpdateAccumulator += deltaTime

	if overlayUpdateAccumulator < 0.1 then
		return
	end

	overlayUpdateAccumulator = 0
	updateOverlay()
end)
updateOverlay()
