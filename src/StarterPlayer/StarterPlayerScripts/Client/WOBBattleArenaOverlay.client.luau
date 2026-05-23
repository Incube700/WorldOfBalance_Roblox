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

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function makePanel(name, position, size)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.ZIndex = PANEL_Z_INDEX
	panel.Parent = screenGui
	addCorner(panel, UDim.new(0, 8))
	addStroke(panel, Color3.fromRGB(31, 41, 55), 0.25, 1)

	return panel
end

local function makeLabel(parent, name, position, size, textSize, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or Enum.Font.GothamBold
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(241, 255, 248)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or PANEL_Z_INDEX + 1
	label.Parent = parent

	return label
end

local function makeBar(parent, name, position, size, fillColor)
	local back = Instance.new("Frame")
	back.Name = name .. "Back"
	back.Position = position
	back.Size = size
	back.BackgroundColor3 = Color3.fromRGB(35, 42, 45)
	back.BorderSizePixel = 0
	back.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or PANEL_Z_INDEX + 1
	back.Parent = parent
	addCorner(back, UDim.new(0, 4))

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ZIndex = back.ZIndex + 1
	fill.Parent = back
	addCorner(fill, UDim.new(0, 4))

	return fill
end

local function styleButton(button, text)
	button.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text or "Return to Lobby"
	button.TextColor3 = Color3.fromRGB(13, 17, 23)
	button.TextSize = 16
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Active = true
	addCorner(button, UDim.new(0, 8))
	addStroke(button, Color3.fromRGB(249, 115, 22), 0.3, 1)
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

-- Upgrade offer panel ----------------------------------------------------------
local upgradeOfferPanel = makePanel(
	"UpgradeOfferPanel",
	UDim2.new(0.5, -190, 0, 106),
	UDim2.fromOffset(380, 260)
)
upgradeOfferPanel.AnchorPoint = Vector2.new(0.5, 0)
upgradeOfferPanel.Visible = false
upgradeOfferPanel.Active = false
upgradeOfferPanel.ZIndex = POPUP_Z_INDEX

local upgradeOfferTitle = makeLabel(
	upgradeOfferPanel,
	"UpgradeOfferTitle",
	UDim2.new(0, 14, 0, 10),
	UDim2.new(1, -28, 0, 26),
	16,
	Enum.Font.GothamBlack
)
upgradeOfferTitle.Text = "Choose Upgrade"
upgradeOfferTitle.TextColor3 = Color3.fromRGB(250, 204, 21)
upgradeOfferTitle.TextXAlignment = Enum.TextXAlignment.Center

local upgradeOfferSubtitle = makeLabel(
	upgradeOfferPanel,
	"UpgradeOfferSubtitle",
	UDim2.new(0, 14, 0, 36),
	UDim2.new(1, -28, 0, 20),
	12,
	Enum.Font.GothamMedium
)
upgradeOfferSubtitle.Text = "Run upgrade"
upgradeOfferSubtitle.TextColor3 = Color3.fromRGB(178, 238, 205)
upgradeOfferSubtitle.TextXAlignment = Enum.TextXAlignment.Center

-- Part 1: Card-based upgrade choices.
-- Each entry: { Card=Frame, Icon=TextLabel, Title=TextLabel, Effect=TextLabel, Button=TextButton }
local upgradeCards = {}

for index = 1, 3 do
	local card = Instance.new("Frame")
	card.Name = "UpgradeCard" .. tostring(index)
	card.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ZIndex = POPUP_Z_INDEX + 1
	card.Parent = upgradeOfferPanel
	addCorner(card, UDim.new(0, 6))
	addStroke(card, Color3.fromRGB(250, 204, 21), 0.55, 1)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.BackgroundTransparency = 1
	iconLabel.BorderSizePixel = 0
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Text = "★"
	iconLabel.TextColor3 = Color3.fromRGB(241, 255, 248)
	iconLabel.TextSize = 22
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.TextYAlignment = Enum.TextYAlignment.Center
	iconLabel.ZIndex = POPUP_Z_INDEX + 2
	iconLabel.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.BorderSizePixel = 0
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = ""
	titleLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	titleLabel.TextSize = 14
	titleLabel.TextWrapped = false
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.ZIndex = POPUP_Z_INDEX + 2
	titleLabel.Parent = card

	local effectLabel = Instance.new("TextLabel")
	effectLabel.Name = "Effect"
	effectLabel.BackgroundTransparency = 1
	effectLabel.BorderSizePixel = 0
	effectLabel.Font = Enum.Font.GothamMedium
	effectLabel.Text = ""
	effectLabel.TextColor3 = Color3.fromRGB(178, 238, 205)
	effectLabel.TextSize = 11
	effectLabel.TextWrapped = false
	effectLabel.TextTruncate = Enum.TextTruncate.AtEnd
	effectLabel.TextXAlignment = Enum.TextXAlignment.Left
	effectLabel.TextYAlignment = Enum.TextYAlignment.Center
	effectLabel.ZIndex = POPUP_Z_INDEX + 2
	effectLabel.Parent = card

	-- Transparent full-card button for tap/click detection
	local clickButton = Instance.new("TextButton")
	clickButton.Name = "ClickButton"
	clickButton.Position = UDim2.fromScale(0, 0)
	clickButton.Size = UDim2.fromScale(1, 1)
	clickButton.BackgroundTransparency = 1
	clickButton.BorderSizePixel = 0
	clickButton.Text = ""
	clickButton.AutoButtonColor = false
	clickButton.Active = true
	clickButton.ZIndex = POPUP_Z_INDEX + 3
	clickButton.Parent = card

	table.insert(upgradeCards, {
		Card = card,
		Icon = iconLabel,
		Title = titleLabel,
		Effect = effectLabel,
		Button = clickButton,
	})
end

-- Part 2: Active upgrade icon strip.
-- Shows up to 5 emoji icons from ArenaUpgradeIds, +N for overflow.
local UPGRADE_ICON_SLOT_COUNT = 5

local upgradeIconStrip = Instance.new("Frame")
upgradeIconStrip.Name = "UpgradeIconStrip"
upgradeIconStrip.BackgroundTransparency = 1
upgradeIconStrip.BorderSizePixel = 0
upgradeIconStrip.ZIndex = PANEL_Z_INDEX + 1
upgradeIconStrip.Visible = false
upgradeIconStrip.Parent = screenGui

local upgradeIconSlots = {}

for i = 1, UPGRADE_ICON_SLOT_COUNT do
	local slot = Instance.new("TextLabel")
	slot.Name = "Slot" .. tostring(i)
	slot.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
	slot.BackgroundTransparency = 0.22
	slot.BorderSizePixel = 0
	slot.Font = Enum.Font.GothamBold
	slot.Text = "★"
	slot.TextColor3 = Color3.fromRGB(241, 255, 248)
	slot.TextSize = 16
	slot.TextXAlignment = Enum.TextXAlignment.Center
	slot.TextYAlignment = Enum.TextYAlignment.Center
	slot.Visible = false
	slot.ZIndex = PANEL_Z_INDEX + 2
	slot.Parent = upgradeIconStrip
	addCorner(slot, UDim.new(0, 5))
	addStroke(slot, Color3.fromRGB(250, 204, 21), 0.55, 1)
	table.insert(upgradeIconSlots, slot)
end

local upgradeIconOverflow = Instance.new("TextLabel")
upgradeIconOverflow.Name = "Overflow"
upgradeIconOverflow.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
upgradeIconOverflow.BackgroundTransparency = 0.22
upgradeIconOverflow.BorderSizePixel = 0
upgradeIconOverflow.Font = Enum.Font.GothamBold
upgradeIconOverflow.Text = "+0"
upgradeIconOverflow.TextColor3 = Color3.fromRGB(178, 238, 205)
upgradeIconOverflow.TextSize = 12
upgradeIconOverflow.TextXAlignment = Enum.TextXAlignment.Center
upgradeIconOverflow.TextYAlignment = Enum.TextYAlignment.Center
upgradeIconOverflow.Visible = false
upgradeIconOverflow.ZIndex = PANEL_Z_INDEX + 2
upgradeIconOverflow.Parent = upgradeIconStrip
addCorner(upgradeIconOverflow, UDim.new(0, 5))

-- Helper: map upgrade id → emoji icon
local function getUpgradeIcon(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return "★"
	end

	local lower = string.lower(upgradeId)

	if string.find(lower, "firerate") or string.find(lower, "fire_rate") or string.find(lower, "reload") then
		return "⚡"
	elseif string.find(lower, "damage") then
		return "💥"
	elseif string.find(lower, "ricochet") or string.find(lower, "bounce") then
		return "🔁"
	elseif string.find(lower, "repair") or string.find(lower, "armor") or string.find(lower, "hp") then
		return "🛡"
	elseif string.find(lower, "speed") or string.find(lower, "turbo") or string.find(lower, "move") then
		return "🏎"
	elseif string.find(lower, "shield") then
		return "🔵"
	elseif string.find(lower, "triple") or string.find(lower, "double") or string.find(lower, "explosion") or string.find(lower, "bigboom") then
		return "🔥"
	elseif string.find(lower, "bolt") or string.find(lower, "reward") or string.find(lower, "magnet") then
		return "🧲"
	else
		return "★"
	end
end

-- Helper: set icon strip slot sizes/positions after strip anchor/position is set
local function layoutIconStrip(slotSize, gap)
	for i, slot in ipairs(upgradeIconSlots) do
		slot.Position = UDim2.fromOffset((i - 1) * (slotSize + gap), 0)
		slot.Size = UDim2.fromOffset(slotSize, slotSize)
		slot.TextSize = math.max(12, math.floor(slotSize * 0.52))
	end

	local overflowX = UPGRADE_ICON_SLOT_COUNT * (slotSize + gap)
	upgradeIconOverflow.Position = UDim2.fromOffset(overflowX, 0)
	upgradeIconOverflow.Size = UDim2.fromOffset(math.floor(slotSize * 1.25), slotSize)
	upgradeIconOverflow.TextSize = math.max(10, math.floor(slotSize * 0.38))
end

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

local function applyDesktopLayout()
	healthPanel.AnchorPoint = Vector2.new(0, 0)
	healthPanel.Position = UDim2.new(0, 18, 0, 18)
	healthPanel.Size = UDim2.new(0, 260, 0, 78)
	healthPanel.BackgroundTransparency = 0.1
	setTextLayout(healthLabel, UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 28), 18)
	setCompactText(healthLabel, false)
	healthBack.Position = UDim2.new(0, 14, 0, 46)
	healthBack.Size = UDim2.new(1, -28, 0, 14)

	scorePanel.AnchorPoint = Vector2.new(0, 0)
	scorePanel.Position = UDim2.new(1, -272, 0, 18)
	scorePanel.Size = UDim2.new(0, 250, 0, 154)
	scorePanel.BackgroundTransparency = 0.1
	setTextLayout(scoreLabel, UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 28), 18)
	setTextLayout(killsDeathsLabel, UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 24), 16)
	setTextLayout(streakLabel, UDim2.new(0, 14, 0, 62), UDim2.new(1, -28, 0, 22), 14)
	setTextLayout(upgradesLabel, UDim2.new(0, 14, 0, 86), UDim2.new(1, -28, 0, 34), 14)
	setTextLayout(sessionLabel, UDim2.new(0, 14, 0, 120), UDim2.new(1, -28, 0, 22), 13)
	setCompactText(scoreLabel, false)
	setCompactText(killsDeathsLabel, false)
	setCompactText(streakLabel, false)
	setCompactText(upgradesLabel, false)
	setCompactText(sessionLabel, true)
	upgradesLabel.Visible = true
	sessionLabel.Visible = true

	returnButton.AnchorPoint = Vector2.new(1, 1)
	returnButton.Position = UDim2.new(1, -22, 1, -22)
	returnButton.Size = UDim2.fromOffset(154, 42)
	returnButton.Text = "Return to Lobby"
	returnButton.TextSize = 16
	returnButton.Visible = true
	menuButton.Visible = false
	setMenuPopupOpen(false)

	deathPanel.Position = UDim2.new(0.5, -150, 0.5, -92)
	deathPanel.Size = UDim2.new(0, 300, 0, 184)
	setTextLayout(destroyedLabel, UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 44), 30)
	setTextLayout(respawnLabel, UDim2.new(0, 18, 0, 68), UDim2.new(1, -36, 0, 30), 20)
	setTextLayout(deathSummaryLabel, UDim2.new(0, 18, 0, 100), UDim2.new(1, -36, 0, 24), 14)
	deathReturnButton.Position = UDim2.new(0.18, 0, 1, -52)
	deathReturnButton.Size = UDim2.new(0.64, 0, 0, 38)

	-- Upgrade panel: 3 cards × 58 px + spacing, total 260 px
	upgradeOfferPanel.Position = UDim2.new(0.5, 0, 0, 106)
	upgradeOfferPanel.Size = UDim2.fromOffset(380, 260)
	setTextLayout(upgradeOfferTitle, UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 26), 16)
	setTextLayout(upgradeOfferSubtitle, UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 20), 12)

	local cardH, cardGap, cardStart = 58, 6, 62
	for index, entry in ipairs(upgradeCards) do
		entry.Card.Position = UDim2.new(0, 14, 0, cardStart + (index - 1) * (cardH + cardGap))
		entry.Card.Size = UDim2.fromOffset(380 - 28, cardH)
		entry.Icon.Position = UDim2.fromOffset(0, 0)
		entry.Icon.Size = UDim2.fromOffset(50, cardH)
		entry.Icon.TextSize = 22
		entry.Title.Position = UDim2.new(0, 54, 0, 4)
		entry.Title.Size = UDim2.new(1, -58, 0, 26)
		entry.Title.TextSize = 14
		entry.Effect.Position = UDim2.new(0, 54, 0, 30)
		entry.Effect.Size = UDim2.new(1, -58, 0, 22)
		entry.Effect.TextSize = 11
	end

	-- Icon strip: right-aligned below score panel (scorePanel top=18, height=154 → bottom at 172)
	upgradeIconStrip.AnchorPoint = Vector2.new(1, 0)
	upgradeIconStrip.Position = UDim2.new(1, -22, 0, 182)
	upgradeIconStrip.Size = UDim2.fromOffset(250, 34)
	layoutIconStrip(30, 4)
end

local function applyMobileLayout(viewportSize)
	local topY = 18
	local sideInset = 12
	local menuWidth = mobileUseMenuForReturn and 68 or 0
	local scoreWidth = math.clamp(viewportSize.X - sideInset * 3 - menuWidth, 188, 270)
	local showBolts = scoreWidth >= 224
	local scoreContentWidth = scoreWidth - 20
	local scoreColumnWidth = math.floor((scoreContentWidth - 6) * 0.5)

	if not mobileHudCompact then
		scoreWidth = math.clamp(viewportSize.X - sideInset * 2, 220, 300)
		scoreContentWidth = scoreWidth - 20
		scoreColumnWidth = math.floor((scoreContentWidth - 6) * 0.5)
		showBolts = true
	end

	healthPanel.AnchorPoint = Vector2.new(0, 0)
	healthPanel.Position = UDim2.fromOffset(sideInset, 78)
	healthPanel.Size = UDim2.fromOffset(math.min(scoreWidth, 180), 54)
	healthPanel.BackgroundTransparency = 0.32
	setTextLayout(healthLabel, UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 24), 14)
	setCompactText(healthLabel, true)
	healthBack.Position = UDim2.new(0, 10, 0, 36)
	healthBack.Size = UDim2.new(1, -20, 0, 6)

	scorePanel.AnchorPoint = Vector2.new(0, 0)
	scorePanel.Position = UDim2.fromOffset(sideInset, topY)
	scorePanel.Size = UDim2.fromOffset(scoreWidth, showBolts and 48 or 44)
	scorePanel.BackgroundTransparency = 0.32
	setTextLayout(scoreLabel, UDim2.new(0, 10, 0, 3), UDim2.fromOffset(scoreColumnWidth, 18), 12)
	setTextLayout(
		killsDeathsLabel,
		UDim2.new(0, 16 + scoreColumnWidth, 0, 3),
		UDim2.fromOffset(scoreColumnWidth, 18),
		12
	)
	setTextLayout(
		streakLabel,
		UDim2.new(0, 10, 0, 23),
		UDim2.fromOffset(showBolts and scoreColumnWidth or scoreContentWidth, 18),
		12
	)
	setTextLayout(
		upgradesLabel,
		UDim2.new(0, 16 + scoreColumnWidth, 0, 23),
		UDim2.fromOffset(scoreColumnWidth, 18),
		12
	)
	setCompactText(scoreLabel, true)
	setCompactText(killsDeathsLabel, true)
	setCompactText(streakLabel, true)
	setCompactText(upgradesLabel, true)
	upgradesLabel.Visible = showBolts
	sessionLabel.Visible = false

	returnButton.Visible = not mobileUseMenuForReturn
	menuButton.Visible = mobileUseMenuForReturn
	menuButton.AnchorPoint = Vector2.new(1, 0)
	menuButton.Position = UDim2.new(1, -sideInset, 0, topY)
	menuButton.Size = UDim2.fromOffset(menuWidth, 34)
	menuButton.Text = "Menu"
	menuButton.TextSize = 13

	deathPanel.Position = UDim2.new(0.5, -130, 0.5, -78)
	deathPanel.Size = UDim2.new(0, 260, 0, 156)
	setTextLayout(destroyedLabel, UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 38), 24)
	setTextLayout(respawnLabel, UDim2.new(0, 16, 0, 58), UDim2.new(1, -32, 0, 28), 17)
	setTextLayout(deathSummaryLabel, UDim2.new(0, 16, 0, 86), UDim2.new(1, -32, 0, 22), 12)
	deathReturnButton.Position = UDim2.new(0.15, 0, 1, -42)
	deathReturnButton.Size = UDim2.new(0.7, 0, 0, 32)

	-- Upgrade panel: top-center (y=138), 3 cards × 64 px + spacing, total 270 px.
	-- Bottom of panel ≈ y=408, well above bottom-left (Move/REV) and bottom-right (Aim/Fire) controls.
	local panelW = math.min(320, viewportSize.X - 24)
	upgradeOfferPanel.Position = UDim2.new(0.5, 0, 0, 138)
	upgradeOfferPanel.Size = UDim2.fromOffset(panelW, 270)
	setTextLayout(upgradeOfferTitle, UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 24), 14)
	setTextLayout(upgradeOfferSubtitle, UDim2.new(0, 12, 0, 32), UDim2.new(1, -24, 0, 18), 11)

	local mCardH, mCardGap, mCardStart = 64, 6, 56
	for index, entry in ipairs(upgradeCards) do
		entry.Card.Position = UDim2.new(0, 12, 0, mCardStart + (index - 1) * (mCardH + mCardGap))
		entry.Card.Size = UDim2.fromOffset(panelW - 24, mCardH)
		entry.Icon.Position = UDim2.fromOffset(0, 0)
		entry.Icon.Size = UDim2.fromOffset(52, mCardH)
		entry.Icon.TextSize = 24
		entry.Title.Position = UDim2.new(0, 56, 0, 6)
		entry.Title.Size = UDim2.new(1, -60, 0, 28)
		entry.Title.TextSize = 15
		entry.Effect.Position = UDim2.new(0, 56, 0, 34)
		entry.Effect.Size = UDim2.new(1, -60, 0, 24)
		entry.Effect.TextSize = 12
	end

	-- Icon strip: bottom-center, 90 px from bottom.
	-- Centered in the safe zone between left and right control clusters.
	upgradeIconStrip.AnchorPoint = Vector2.new(0.5, 1)
	upgradeIconStrip.Position = UDim2.new(0.5, 0, 1, -90)
	upgradeIconStrip.Size = UDim2.fromOffset(244, 40)
	layoutIconStrip(36, 4)
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

local function updateUpgradeOfferPanel()
	local offer = currentUpgradeOffer
	local choices = offer ~= nil and offer.Choices or {}

	upgradeOfferPanel.Visible = isArenaMode() and offer ~= nil and #choices > 0

	if not upgradeOfferPanel.Visible then
		return
	end

	local source = tostring(offer.Source or "LevelUp")
	local arenaLevel = tonumber(offer.ArenaLevel) or tonumber(localPlayer:GetAttribute("ArenaLevel")) or 1
	upgradeOfferTitle.Text = source == "SupplyCrate" and "Supply Crate" or "Level Up"
	upgradeOfferSubtitle.Text = "Arena Level " .. tostring(math.floor(arenaLevel)) .. " upgrade"

	for index, entry in ipairs(upgradeCards) do
		local choice = choices[index]

		if choice ~= nil then
			local choiceId = tostring(choice.Id or "")
			local choiceTitle = tostring(choice.Title or choice.Id or "Upgrade")
			local choiceEffect = tostring(choice.Description or "")
			entry.Card.Visible = true
			entry.Icon.Text = getUpgradeIcon(choiceId)
			entry.Title.Text = choiceTitle
			entry.Effect.Text = choiceEffect
			entry.Button:SetAttribute("UpgradeId", choiceId)
		else
			entry.Card.Visible = false
			entry.Title.Text = ""
			entry.Effect.Text = ""
			entry.Button:SetAttribute("UpgradeId", nil)
		end
	end
end

local function updateUpgradeIconStrip()
	local upgradeIds = tostring(localPlayer:GetAttribute("ArenaUpgradeIds") or "")
	local ids = {}

	if upgradeIds ~= "" then
		for id in string.gmatch(upgradeIds, "[^,]+") do
			table.insert(ids, id)
		end
	end

	local visible = isArenaMode() and #ids > 0
	upgradeIconStrip.Visible = visible

	if not visible then
		return
	end

	local displayCount = math.min(#ids, UPGRADE_ICON_SLOT_COUNT)
	local overflow = #ids - displayCount

	for i, slot in ipairs(upgradeIconSlots) do
		if i <= displayCount then
			slot.Text = getUpgradeIcon(ids[i])
			slot.Visible = true
		else
			slot.Visible = false
		end
	end

	if overflow > 0 then
		upgradeIconOverflow.Text = "+" .. tostring(overflow)
		upgradeIconOverflow.Visible = true
	else
		upgradeIconOverflow.Visible = false
	end
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
		upgradeOfferPanel.Visible = false
		upgradeIconStrip.Visible = false
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
	updateUpgradeOfferPanel()
	updateUpgradeIconStrip()

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

for _, entry in ipairs(upgradeCards) do
	local clickButton = entry.Button
	clickButton.Activated:Connect(function()
		if currentUpgradeOffer == nil then
			return
		end

		local upgradeId = clickButton:GetAttribute("UpgradeId")

		if typeof(upgradeId) ~= "string" or upgradeId == "" then
			return
		end

		upgradeChoiceEvent:FireServer({
			OfferId = currentUpgradeOffer.OfferId,
			UpgradeId = upgradeId,
		})
		currentUpgradeOffer = nil
		updateUpgradeOfferPanel()
	end)
end

upgradeChoiceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.OfferId) ~= "string" then
		return
	end

	currentUpgradeOffer = payload
	updateLayout()
	updateUpgradeOfferPanel()
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
