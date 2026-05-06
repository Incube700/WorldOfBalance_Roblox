local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetDummyRequestEvent = remotes:WaitForChild("ResetDummyRequestEvent")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local dummyTank = testObjects:WaitForChild("DummyTank")

local hud = script.Parent
local mainPanel = hud:WaitForChild("MainPanel")

local dummyHpLabel = mainPanel:WaitForChild("DummyHpLabel")
local dummyHpFill = mainPanel:WaitForChild("DummyHpBack"):WaitForChild("DummyHpFill")

local reloadLabel = mainPanel:WaitForChild("ReloadLabel")
local reloadFill = mainPanel:WaitForChild("ReloadBack"):WaitForChild("ReloadFill")

local feedbackLabel = hud:WaitForChild("FeedbackLabel")

local MAX_DUMMY_HEALTH = 100
local SHOOT_COOLDOWN = 0.45
local FEEDBACK_TIME = 0.8

local previousHealth = dummyTank:GetAttribute("Health") or MAX_DUMMY_HEALTH
local lastShotTime = -100
local feedbackTimer = 0

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function showFeedback(text, color)
	feedbackLabel.Text = text
	feedbackLabel.TextColor3 = color
	feedbackLabel.TextTransparency = 0
	feedbackTimer = FEEDBACK_TIME
end

local function updateDummyHealth()
	local health = dummyTank:GetAttribute("Health") or MAX_DUMMY_HEALTH
	local normalizedHealth = clamp01(health / MAX_DUMMY_HEALTH)

	dummyHpLabel.Text = "Dummy HP: " .. math.floor(health) .. " / " .. MAX_DUMMY_HEALTH
	dummyHpFill.Size = UDim2.new(normalizedHealth, 0, 1, 0)

	if health < previousHealth then
		showFeedback("HIT -" .. math.floor(previousHealth - health), Color3.fromRGB(255, 220, 90))
	end

	if health <= 0 and previousHealth > 0 then
		showFeedback("TARGET DESTROYED", Color3.fromRGB(255, 80, 80))
	end

	if health >= MAX_DUMMY_HEALTH and previousHealth <= 0 then
		showFeedback("TARGET RESET", Color3.fromRGB(120, 255, 150))
	end

	previousHealth = health
end

dummyTank:GetAttributeChangedSignal("Health"):Connect(updateDummyHealth)
updateDummyHealth()

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		lastShotTime = os.clock()
	elseif input.KeyCode == Enum.KeyCode.R then
		resetDummyRequestEvent:FireServer()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local reloadProgress = clamp01((os.clock() - lastShotTime) / SHOOT_COOLDOWN)

	reloadFill.Size = UDim2.new(reloadProgress, 0, 1, 0)

	if reloadProgress >= 1 then
		reloadLabel.Text = "Reload: READY"
	else
		reloadLabel.Text = "Reload: " .. math.floor(reloadProgress * 100) .. "%"
	end

	if feedbackTimer > 0 then
		feedbackTimer -= deltaTime

		if feedbackTimer <= 0 then
			feedbackLabel.TextTransparency = 1
		else
			feedbackLabel.TextTransparency = 1 - clamp01(feedbackTimer / FEEDBACK_TIME)
		end
	end
end)

print("[WOB] HUD controller started")
