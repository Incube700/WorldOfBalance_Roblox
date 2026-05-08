-- One-time Roblox Studio Command Bar setup for editable Playable Shell main menu.
-- Run outside Play Mode. It creates missing UI objects under StarterGui/WOBPlayableShellGui.

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
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function styleButton(button, text, enabled)
	if not button:IsA("TextButton") then
		return
	end

	button.BackgroundColor3 = enabled and Color3.fromRGB(56, 168, 118) or Color3.fromRGB(48, 55, 58)
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

local gui = getOrCreate(StarterGui, "ScreenGui", GUI_NAME)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local panel = getOrCreate(gui, "Frame", "MainMenuPanel")
panel.Size = UDim2.new(1, 0, 1, 0)
panel.Position = UDim2.new(0, 0, 0, 0)
panel.BackgroundColor3 = Color3.fromRGB(7, 9, 11)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0

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

local buttons = {
	{ Name = "PlayButton", Text = "Play", Enabled = true, Y = 158 },
	{ Name = "TrainingButton", Text = "Training", Enabled = false, Y = 224 },
	{ Name = "StatsButton", Text = "Stats", Enabled = true, Y = 290 },
	{ Name = "SettingsButton", Text = "Settings", Enabled = false, Y = 356 },
}

for _, data in ipairs(buttons) do
	local button = getOrCreate(content, "TextButton", data.Name)
	button.Position = UDim2.new(0.13, 0, 0, data.Y)
	button.Size = UDim2.new(0.74, 0, 0, 50)
	styleButton(button, data.Text, data.Enabled)
end

print("[WOB SHELL] Main menu UI ready at StarterGui/WOBPlayableShellGui/MainMenuPanel.")
