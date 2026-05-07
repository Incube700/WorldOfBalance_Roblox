local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local playerTank = testObjects:WaitForChild("PlayerTankPrototype")

local existingGui = playerGui:FindFirstChild("WOBRoundStatusOverlayGui")

if existingGui ~= nil then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WOBRoundStatusOverlayGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -18, 0, 18)
panel.Size = UDim2.new(0, 230, 0, 92)
panel.BackgroundColor3 = Color3.fromRGB(12, 14, 16)
panel.BackgroundTransparency = 0.22
panel.BorderSizePixel = 0
panel.Parent = screenGui

local playerHpLabel = Instance.new("TextLabel")
playerHpLabel.Name = "PlayerHpLabel"
playerHpLabel.Position = UDim2.new(0, 12, 0, 10)
playerHpLabel.Size = UDim2.new(1, -24, 0, 24)
playerHpLabel.BackgroundTransparency = 1
playerHpLabel.Font = Enum.Font.GothamBold
playerHpLabel.TextColor3 = Color3.fromRGB(235, 245, 240)
playerHpLabel.TextSize = 18
playerHpLabel.TextXAlignment = Enum.TextXAlignment.Left
playerHpLabel.Parent = panel

local healthBack = Instance.new("Frame")
healthBack.Name = "PlayerHpBack"
healthBack.Position = UDim2.new(0, 12, 0, 40)
healthBack.Size = UDim2.new(1, -24, 0, 8)
healthBack.BackgroundColor3 = Color3.fromRGB(42, 48, 52)
healthBack.BorderSizePixel = 0
healthBack.Parent = panel

local healthFill = Instance.new("Frame")
healthFill.Name = "PlayerHpFill"
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBack

local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "ResultLabel"
resultLabel.Position = UDim2.new(0, 12, 0, 54)
resultLabel.Size = UDim2.new(1, -24, 0, 32)
resultLabel.BackgroundTransparency = 1
resultLabel.Font = Enum.Font.GothamBlack
resultLabel.TextColor3 = Color3.fromRGB(235, 245, 240)
resultLabel.TextSize = 16
resultLabel.TextWrapped = true
resultLabel.TextXAlignment = Enum.TextXAlignment.Left
resultLabel.Visible = false
resultLabel.Parent = panel

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function updateHealth()
	local maxHealth = playerTank:GetAttribute("MaxHealth") or 100
	local health = playerTank:GetAttribute("Health") or maxHealth
	local normalizedHealth = clamp01(health / maxHealth)

	playerHpLabel.Text = "Player HP: " .. math.floor(health) .. " / " .. math.floor(maxHealth)
	healthFill.Size = UDim2.new(normalizedHealth, 0, 1, 0)

	if normalizedHealth <= 0.3 then
		healthFill.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
	elseif normalizedHealth <= 0.6 then
		healthFill.BackgroundColor3 = Color3.fromRGB(240, 190, 80)
	else
		healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 135)
	end
end

local function updateRoundResult()
	local result = root:GetAttribute("RoundResult") or "Playing"

	if result == "Win" then
		resultLabel.Text = "WIN\nPress R to restart"
		resultLabel.TextColor3 = Color3.fromRGB(105, 235, 145)
		resultLabel.Visible = true
	elseif result == "Lose" then
		resultLabel.Text = "LOSE\nPress R to restart"
		resultLabel.TextColor3 = Color3.fromRGB(245, 95, 80)
		resultLabel.Visible = true
	else
		resultLabel.Visible = false
	end
end

playerTank:GetAttributeChangedSignal("Health"):Connect(updateHealth)
playerTank:GetAttributeChangedSignal("MaxHealth"):Connect(updateHealth)
root:GetAttributeChangedSignal("RoundResult"):Connect(updateRoundResult)

updateHealth()
updateRoundResult()

print("[WOB] Round status overlay started")
