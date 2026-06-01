-- WOBAchievementToast (Etap 4): shows an "Achievement unlocked" card when the server fires
-- AchievementToastEvent. Display only -- no remotes fired back, no gameplay effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toastEvent = remotes:WaitForChild("AchievementToastEvent")

local HOLD_TIME = 3.5
local SLIDE_TIME = 0.4

local screenGui = playerGui:FindFirstChild("WOBAchievementToast")
if screenGui == nil then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WOBAchievementToast"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 70
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

local queue = {}
local showing = false

local function buildCard(data)
	local icon = typeof(data) == "table" and tostring(data.Icon or "★") or "★"
	local title = typeof(data) == "table" and tostring(data.Title or "Achievement") or "Achievement"
	local desc = typeof(data) == "table" and tostring(data.Description or "") or ""
	local reward = typeof(data) == "table" and tonumber(data.RewardBolts) or 0

	local card = Instance.new("Frame")
	card.Name = "AchievementCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(360, 64)
	card.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(250, 205, 90)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = card

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.Position = UDim2.new(0, 12, 0.5, 0)
	iconLabel.Size = UDim2.fromOffset(40, 40)
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextScaled = true
	iconLabel.Text = icon
	iconLabel.TextColor3 = Color3.fromRGB(250, 205, 90)
	iconLabel.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.AnchorPoint = Vector2.new(0, 0)
	titleLabel.Position = UDim2.new(0, 60, 0, 10)
	titleLabel.Size = UDim2.new(1, -72, 0, 22)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
	local rewardSuffix = reward > 0 and ("  +%d Bolts"):format(reward) or ""
	titleLabel.Text = "Achievement: " .. title .. rewardSuffix
	titleLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.BackgroundTransparency = 1
	descLabel.AnchorPoint = Vector2.new(0, 0)
	descLabel.Position = UDim2.new(0, 60, 0, 34)
	descLabel.Size = UDim2.new(1, -72, 0, 18)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextSize = 13
	descLabel.TextColor3 = Color3.fromRGB(190, 205, 225)
	descLabel.Text = desc
	descLabel.Parent = card

	return card
end

local function showNext()
	if showing then
		return
	end
	local data = table.remove(queue, 1)
	if data == nil then
		return
	end

	showing = true
	local card = buildCard(data)
	card.Position = UDim2.new(0.5, 0, 0, -80)

	local slideIn = TweenService:Create(card, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18),
	})
	slideIn:Play()

	task.delay(HOLD_TIME, function()
		local slideOut = TweenService:Create(card, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -80),
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			if card.Parent ~= nil then
				card:Destroy()
			end
			showing = false
			showNext()
		end)
	end)
end

toastEvent.OnClientEvent:Connect(function(data)
	table.insert(queue, data)
	showNext()
end)
