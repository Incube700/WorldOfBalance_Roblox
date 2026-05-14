local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local utils = shared:WaitForChild("Utils")
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local returnToMenuRequestEvent = remotes:WaitForChild("ReturnToMenuRequestEvent")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local root = Workspace:WaitForChild("WOB_Generated")

local GUI_NAME = "WOBBattleArenaOverlay"
local MODE_IN_BATTLE_ARENA = "InBattleArena"
local MODE_ARENA_RESPAWNING = "ArenaRespawning"

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
	panel.BackgroundColor3 = Color3.fromRGB(10, 13, 16)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	addCorner(panel, UDim.new(0, 8))
	addStroke(panel, Color3.fromRGB(90, 165, 140), 0.35, 1)

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
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
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
	back.Parent = parent
	addCorner(back, UDim.new(0, 4))

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	addCorner(fill, UDim.new(0, 4))

	return fill
end

local function styleButton(button)
	button.BackgroundColor3 = Color3.fromRGB(54, 148, 114)
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "Return to Lobby"
	button.TextColor3 = Color3.fromRGB(248, 255, 248)
	button.TextSize = 16
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Active = true
	addCorner(button, UDim.new(0, 8))
	addStroke(button, Color3.fromRGB(138, 236, 185), 0.25, 1)
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

local actionsRoot = Instance.new("Frame")
actionsRoot.Name = "BattleArenaActionsRoot"
actionsRoot.Position = UDim2.fromScale(0, 0)
actionsRoot.Size = UDim2.fromScale(1, 1)
actionsRoot.BackgroundTransparency = 1
actionsRoot.BorderSizePixel = 0
actionsRoot.Active = false
actionsRoot.ZIndex = 20
actionsRoot.Parent = screenGui

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToLobbyButton"
returnButton.AnchorPoint = Vector2.new(0.5, 0)
returnButton.Position = UDim2.new(0.5, 0, 0, 10)
returnButton.Size = UDim2.fromOffset(168, 36)
returnButton.ZIndex = 21
returnButton.Parent = actionsRoot
styleButton(returnButton)
returnButton.TextSize = 14

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

local deathReturnButton = Instance.new("TextButton")
deathReturnButton.Name = "DeathReturnToLobbyButton"
deathReturnButton.Position = UDim2.new(0.18, 0, 1, -52)
deathReturnButton.Size = UDim2.new(0.64, 0, 0, 38)
deathReturnButton.Parent = deathPanel
styleButton(deathReturnButton)

local function isArenaMode()
	local mode = localPlayer:GetAttribute("PlayerMode")

	return mode == MODE_IN_BATTLE_ARENA or mode == MODE_ARENA_RESPAWNING
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

local function getOwnedTank()
	return TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
end

local function updateLayout()
	local camera = Workspace.CurrentCamera
	local viewportSize = camera ~= nil and camera.ViewportSize or Vector2.new(1024, 768)
	local compact = viewportSize.X < 620
	local narrowTopHud = viewportSize.X < 720

	if compact then
		healthPanel.Position = UDim2.new(0, 12, 0, 56)
		healthPanel.Size = UDim2.new(0, 220, 0, 78)
		scorePanel.Position = UDim2.new(0, 12, 0, 142)
		scorePanel.Size = UDim2.new(0, 220, 0, 128)
	elseif narrowTopHud then
		healthPanel.Position = UDim2.new(0, 18, 0, 58)
		healthPanel.Size = UDim2.new(0, 260, 0, 78)
		scorePanel.Position = UDim2.new(1, -272, 0, 58)
		scorePanel.Size = UDim2.new(0, 250, 0, 128)
	else
		healthPanel.Position = UDim2.new(0, 18, 0, 18)
		healthPanel.Size = UDim2.new(0, 260, 0, 78)
		scorePanel.Position = UDim2.new(1, -272, 0, 18)
		scorePanel.Size = UDim2.new(0, 250, 0, 128)
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

local function formatUpgrades(upgradeIds)
	if typeof(upgradeIds) ~= "string" or upgradeIds == "" then
		return "Upgrades: -"
	end

	return "Upgrades: " .. string.gsub(upgradeIds, ",", ", ")
end

local function updateHealth(ownedTank)
	local health, maxHealth = getOwnedTankHealth(ownedTank)
	local normalizedHealth = clamp01(health / math.max(1, maxHealth))

	healthLabel.Text = "HP: " .. tostring(math.floor(health)) .. " / " .. tostring(math.floor(maxHealth))
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
		return
	end

	updateLayout()

	local score = localPlayer:GetAttribute("ArenaScore") or 0
	local kills = localPlayer:GetAttribute("ArenaKills") or 0
	local deaths = localPlayer:GetAttribute("ArenaDeaths") or 0
	local streak = localPlayer:GetAttribute("ArenaStreak") or 0
	local upgrades = localPlayer:GetAttribute("ArenaUpgradeIds") or ""
	local ownedTank = getOwnedTank()

	scoreLabel.Text = "Arena Score: " .. tostring(math.floor(score))
	killsDeathsLabel.Text = "Kills: " .. tostring(math.floor(kills)) .. " Deaths: " .. tostring(math.floor(deaths))
	streakLabel.Text = "Streak: " .. tostring(math.floor(streak))
	upgradesLabel.Text = formatUpgrades(upgrades)
	updateHealth(ownedTank)

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
	end
end

local function requestReturnToLobby()
	returnToMenuRequestEvent:FireServer()
end

returnButton.Activated:Connect(requestReturnToLobby)
deathReturnButton.Activated:Connect(requestReturnToLobby)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaScore"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaKills"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaDeaths"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaStreak"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaUpgradeIds"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("ArenaRespawnAt"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("CurrentHealth"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("MaxHealth"):Connect(updateOverlay)
localPlayer:GetAttributeChangedSignal("IsDead"):Connect(updateOverlay)

RunService.RenderStepped:Connect(updateOverlay)
updateOverlay()
