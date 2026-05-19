local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local PERSISTENT_BOLTS_ATTRIBUTE = "PersistentBolts"
local UNSAVED_BOLTS_ATTRIBUTE = "UnsavedBolts"
local LAST_REWARD_AMOUNT_ATTRIBUTE = "LastBoltsRewardAmount"
local LAST_REWARD_REASON_ATTRIBUTE = "LastBoltsRewardReason"
local LAST_REWARD_SEQUENCE_ATTRIBUTE = "LastBoltsRewardSequence"
local CRYSTALS_ATTRIBUTE = "Crystals"
local PERSISTENT_CRYSTALS_ATTRIBUTE = "PersistentCrystals"
local UNSAVED_CRYSTALS_ATTRIBUTE = "UnsavedCrystals"
local LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE = "LastCrystalsRewardAmount"
local LAST_CRYSTALS_REWARD_REASON_ATTRIBUTE = "LastCrystalsRewardReason"
local LAST_CRYSTALS_REWARD_SEQUENCE_ATTRIBUTE = "LastCrystalsRewardSequence"

local gui = Instance.new("ScreenGui")
gui.Name = "WOBWalletOverlay"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 45
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "WalletFrame"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -18, 0, 18)
frame.Size = UDim2.fromOffset(174, 70)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 26)
frame.BackgroundTransparency = 0.12
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 90)
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = frame

local totalLabel = Instance.new("TextLabel")
totalLabel.Name = "Total"
totalLabel.BackgroundTransparency = 1
totalLabel.Position = UDim2.fromOffset(12, 7)
totalLabel.Size = UDim2.new(1, -24, 0, 22)
totalLabel.Font = Enum.Font.BuilderSansBold
totalLabel.Text = "Bolts: 0"
totalLabel.TextColor3 = Color3.fromRGB(255, 238, 175)
totalLabel.TextScaled = true
totalLabel.TextXAlignment = Enum.TextXAlignment.Left
totalLabel.Parent = frame

local crystalsLabel = Instance.new("TextLabel")
crystalsLabel.Name = "Crystals"
crystalsLabel.BackgroundTransparency = 1
crystalsLabel.Position = UDim2.fromOffset(12, 27)
crystalsLabel.Size = UDim2.new(1, -24, 0, 20)
crystalsLabel.Font = Enum.Font.BuilderSansBold
crystalsLabel.Text = "Crystals: 0"
crystalsLabel.TextColor3 = Color3.fromRGB(175, 230, 255)
crystalsLabel.TextScaled = true
crystalsLabel.TextXAlignment = Enum.TextXAlignment.Left
crystalsLabel.Parent = frame

local rewardLabel = Instance.new("TextLabel")
rewardLabel.Name = "Reward"
rewardLabel.BackgroundTransparency = 1
rewardLabel.Position = UDim2.fromOffset(12, 48)
rewardLabel.Size = UDim2.new(1, -24, 0, 16)
rewardLabel.Font = Enum.Font.BuilderSansBold
rewardLabel.Text = ""
rewardLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
rewardLabel.TextScaled = true
rewardLabel.TextTransparency = 1
rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
rewardLabel.Parent = frame

local rewardToken = 0
local lastRewardSequence = tonumber(localPlayer:GetAttribute(LAST_REWARD_SEQUENCE_ATTRIBUTE)) or 0
local lastCrystalsRewardSequence = tonumber(localPlayer:GetAttribute(LAST_CRYSTALS_REWARD_SEQUENCE_ATTRIBUTE)) or 0

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

local function updateTotal()
	totalLabel.Text = "Bolts: " .. tostring(getVisibleBolts())
	crystalsLabel.Text = "Crystals: " .. tostring(getVisibleCrystals())
end

local function showReward(text, color)
	if text == "" then
		return
	end

	rewardToken += 1
	local token = rewardToken

	rewardLabel.Text = text
	rewardLabel.TextColor3 = color
	rewardLabel.TextTransparency = 0

	TweenService:Create(rewardLabel, TweenInfo.new(0.18), {
		TextTransparency = 0,
	}):Play()

	task.delay(1.35, function()
		if token ~= rewardToken then
			return
		end

		TweenService:Create(rewardLabel, TweenInfo.new(0.35), {
			TextTransparency = 1,
		}):Play()
	end)
end

local function showBoltsReward()
	local rewardAmount = math.max(0, math.floor(tonumber(localPlayer:GetAttribute(LAST_REWARD_AMOUNT_ATTRIBUTE)) or 0))

	if rewardAmount <= 0 then
		return
	end

	local reason = tostring(localPlayer:GetAttribute(LAST_REWARD_REASON_ATTRIBUTE) or "")
	local suffix = ""

	if reason == "TrainingKill" or reason == "PvPKill" then
		suffix = " kill"
	end

	showReward(
		"+" .. tostring(rewardAmount) .. " Bolt" .. (rewardAmount == 1 and "" or "s") .. suffix,
		Color3.fromRGB(120, 255, 160)
	)
end

local function showCrystalsReward()
	local rewardAmount = math.max(0, math.floor(tonumber(localPlayer:GetAttribute(LAST_CRYSTALS_REWARD_AMOUNT_ATTRIBUTE)) or 0))

	if rewardAmount <= 0 then
		return
	end

	showReward(
		"+" .. tostring(rewardAmount) .. " Crystal" .. (rewardAmount == 1 and "" or "s"),
		Color3.fromRGB(135, 225, 255)
	)
end

local function updateRewardFromSequence()
	local nextSequence = tonumber(localPlayer:GetAttribute(LAST_REWARD_SEQUENCE_ATTRIBUTE)) or 0

	if nextSequence == lastRewardSequence then
		return
	end

	lastRewardSequence = nextSequence
	showBoltsReward()
end

local function updateCrystalsRewardFromSequence()
	local nextSequence = tonumber(localPlayer:GetAttribute(LAST_CRYSTALS_REWARD_SEQUENCE_ATTRIBUTE)) or 0

	if nextSequence == lastCrystalsRewardSequence then
		return
	end

	lastCrystalsRewardSequence = nextSequence
	showCrystalsReward()
end

local function updateVisibility()
	local mode = localPlayer:GetAttribute("PlayerMode")
	local visible = mode == nil
		or mode == "Lobby"
		or mode == "QueuedForDuel"
		or mode == "Result"

	gui.Enabled = visible
end

localPlayer:GetAttributeChangedSignal(PERSISTENT_BOLTS_ATTRIBUTE):Connect(updateTotal)
localPlayer:GetAttributeChangedSignal(UNSAVED_BOLTS_ATTRIBUTE):Connect(updateTotal)
localPlayer:GetAttributeChangedSignal(CRYSTALS_ATTRIBUTE):Connect(updateTotal)
localPlayer:GetAttributeChangedSignal(PERSISTENT_CRYSTALS_ATTRIBUTE):Connect(updateTotal)
localPlayer:GetAttributeChangedSignal(UNSAVED_CRYSTALS_ATTRIBUTE):Connect(updateTotal)
localPlayer:GetAttributeChangedSignal(LAST_REWARD_SEQUENCE_ATTRIBUTE):Connect(updateRewardFromSequence)
localPlayer:GetAttributeChangedSignal(LAST_CRYSTALS_REWARD_SEQUENCE_ATTRIBUTE):Connect(updateCrystalsRewardFromSequence)
localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(updateVisibility)

updateTotal()
updateVisibility()
