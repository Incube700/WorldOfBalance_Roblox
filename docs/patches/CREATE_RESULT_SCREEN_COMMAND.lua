-- One-time Roblox Studio Command Bar setup for editable Playable Shell result screen.
-- Run outside Play Mode. It creates missing UI objects under StarterGui/WOBPlayableShellGui.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local StarterGui = game:GetService("StarterGui")

local GUI_NAME = "WOBPlayableShellGui"

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB SHELL] %s exists but is %s, expected %s. Leaving it unchanged."):format(
				existing:GetFullName(),
				existing.ClassName,
				className
			))
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent

	return instance, true
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
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function styleButton(button, text)
	if not button:IsA("TextButton") then
		return
	end

	button.BackgroundColor3 = Color3.fromRGB(56, 168, 118)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(248, 255, 248)
	button.TextSize = 20
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Active = true

	pcall(function()
		button.Selectable = true
	end)

	addCorner(button, UDim.new(0, 8))
	addStroke(button, Color3.fromRGB(132, 242, 180), 0.3, 1)
end

local function createStatRow(parent, key, labelText, order)
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
end

local gui = getOrCreate(StarterGui, "ScreenGui", GUI_NAME)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local panel = getOrCreate(gui, "Frame", "ResultScreenPanel")
panel.Size = UDim2.new(1, 0, 1, 0)
panel.Position = UDim2.new(0, 0, 0, 0)
panel.BackgroundColor3 = Color3.fromRGB(7, 9, 11)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false

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
title.TextXAlignment = Enum.TextXAlignment.Center

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
	createStatRow(list, row.Key, row.Label, index)
end

local playAgainButton = getOrCreate(content, "TextButton", "PlayAgainButton")
playAgainButton.Position = UDim2.new(0.1, 0, 1, -128)
playAgainButton.Size = UDim2.new(0.38, 0, 0, 52)
styleButton(playAgainButton, "Play Again")

local menuButton = getOrCreate(content, "TextButton", "BackToMenuButton")
menuButton.Position = UDim2.new(0.52, 0, 1, -128)
menuButton.Size = UDim2.new(0.38, 0, 0, 52)
styleButton(menuButton, "Back to Menu")

print("[WOB SHELL] Result screen UI ready at StarterGui/WOBPlayableShellGui/ResultScreenPanel.")
