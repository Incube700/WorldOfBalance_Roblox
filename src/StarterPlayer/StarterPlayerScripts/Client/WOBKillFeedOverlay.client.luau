-- WOBKillFeedOverlay (Etap 2): a small top-center kill feed. Listens to the server
-- KillFeedEvent and shows "Killer  ⚔[weapon]  Victim" entries that fade out after a few
-- seconds. Display only -- no gameplay, no remotes fired back, no server state touched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local killFeedEvent = remotes:WaitForChild("KillFeedEvent")

local MAX_ENTRIES = 5
local ENTRY_LIFETIME = 4.5
local FADE_TIME = 0.5

-- Short weapon glyphs for the kill feed. Unknown weapons fall back to a generic shot.
local WEAPON_GLYPH = {
	DefaultCannon = "•",
	Rocket = "✸",
	MachineGun = "⁙",
	RailGun = "➤",
	PhaseShot = "◈",
}

local screenGui = playerGui:FindFirstChild("WOBKillFeed")
if screenGui == nil then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WOBKillFeed"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 60
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

local container = screenGui:FindFirstChild("Container")
if container == nil then
	container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.fromScale(0.5, 0.06)
	container.Size = UDim2.fromOffset(420, 160)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = container
end

local nextOrder = 0

local function trimOldEntries()
	local entries = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(entries, child)
		end
	end
	-- Oldest = lowest LayoutOrder.
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #entries > MAX_ENTRIES do
		local oldest = table.remove(entries, 1)
		oldest:Destroy()
	end
end

local function addEntry(data)
	local killer = typeof(data) == "table" and tostring(data.Killer or "?") or "?"
	local victim = typeof(data) == "table" and tostring(data.Victim or "?") or "?"
	local weapon = typeof(data) == "table" and data.Weapon or nil
	local glyph = (weapon ~= nil and WEAPON_GLYPH[weapon]) or "•"

	nextOrder += 1

	local entry = Instance.new("Frame")
	entry.Name = "KillEntry"
	entry.LayoutOrder = nextOrder
	entry.Size = UDim2.fromOffset(400, 26)
	entry.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
	entry.BackgroundTransparency = 0.35
	entry.BorderSizePixel = 0
	entry.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = entry

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(240, 246, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.RichText = true
	label.Text = ("<font color='#9fe0ff'>%s</font>  %s  <font color='#ff9a9a'>%s</font>"):format(killer, glyph, victim)
	label.Parent = entry

	trimOldEntries()

	-- Fade + remove after lifetime.
	task.delay(ENTRY_LIFETIME, function()
		if entry.Parent == nil then
			return
		end
		TweenService:Create(entry, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(FADE_TIME), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(FADE_TIME, function()
			if entry.Parent ~= nil then
				entry:Destroy()
			end
		end)
	end)
end

killFeedEvent.OnClientEvent:Connect(addEntry)
