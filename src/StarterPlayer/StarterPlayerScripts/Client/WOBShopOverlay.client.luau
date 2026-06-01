-- WOBShopOverlay (Shop v1): a simple tank-skin shop. A "SHOP" button in the corner opens a
-- panel listing skins (name, price, color swatch) with Buy / Equip buttons. The server owns
-- all validation; this is display + request only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyEvent = remotes:WaitForChild("ShopBuyEvent")
local equipEvent = remotes:WaitForChild("ShopEquipEvent")
local syncEvent = remotes:WaitForChild("ShopSyncEvent")

local latestData = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WOBShop"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 80
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Open button.
local openBtn = Instance.new("TextButton")
openBtn.Name = "ShopButton"
openBtn.AnchorPoint = Vector2.new(0, 0)
openBtn.Position = UDim2.fromOffset(16, 110)
openBtn.Size = UDim2.fromOffset(96, 36)
openBtn.BackgroundColor3 = Color3.fromRGB(36, 46, 60)
openBtn.Font = Enum.Font.GothamBold
openBtn.Text = "SHOP"
openBtn.TextSize = 16
openBtn.TextColor3 = Color3.fromRGB(245, 248, 255)
openBtn.Parent = screenGui
local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 8)
openCorner.Parent = openBtn

-- Panel (hidden until opened).
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 360)
panel.BackgroundColor3 = Color3.fromRGB(20, 26, 36)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(0.55, 0, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(250, 205, 90)
title.Text = "Tank Shop"
title.Parent = panel

-- Bolts balance (top-right, next to close).
local boltsLabel = Instance.new("TextLabel")
boltsLabel.Name = "BoltsLabel"
boltsLabel.AnchorPoint = Vector2.new(1, 0)
boltsLabel.Position = UDim2.new(1, -46, 0, 12)
boltsLabel.Size = UDim2.fromOffset(150, 24)
boltsLabel.BackgroundTransparency = 1
boltsLabel.Font = Enum.Font.GothamBold
boltsLabel.TextXAlignment = Enum.TextXAlignment.Right
boltsLabel.TextSize = 16
boltsLabel.TextColor3 = Color3.fromRGB(255, 225, 120)
boltsLabel.Text = "0 Bolts"
boltsLabel.Parent = panel

-- Message line (purchase result / errors).
local msgLabel = Instance.new("TextLabel")
msgLabel.Name = "Message"
msgLabel.AnchorPoint = Vector2.new(0.5, 1)
msgLabel.Position = UDim2.new(0.5, 0, 1, -6)
msgLabel.Size = UDim2.new(1, -24, 0, 18)
msgLabel.BackgroundTransparency = 1
msgLabel.Font = Enum.Font.Gotham
msgLabel.TextSize = 14
msgLabel.TextColor3 = Color3.fromRGB(200, 220, 245)
msgLabel.Text = ""
msgLabel.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -10, 0, 10)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 44)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
closeBtn.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 48)
list.Size = UDim2.new(1, -24, 1, -78)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function rowFor(item, equipped, bolts)
	local isEquipped = equipped == item.SkinId
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 52)
	row.BackgroundColor3 = isEquipped and Color3.fromRGB(38, 52, 44) or Color3.fromRGB(30, 38, 50)
	row.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = row

	-- Equipped rows get a soft green border so the current skin is obvious.
	if isEquipped then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(90, 220, 130)
		stroke.Thickness = 2
		stroke.Transparency = 0.25
		stroke.Parent = row
	end

	-- Preview swatch: body color with a turret-color stripe (mini tank preview).
	local swatch = Instance.new("Frame")
	swatch.Position = UDim2.fromOffset(10, 10)
	swatch.Size = UDim2.fromOffset(32, 32)
	swatch.BackgroundColor3 = item.BodyColor or Color3.fromRGB(120, 120, 120)
	swatch.BorderSizePixel = 0
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 6)
	sc.Parent = swatch
	swatch.Parent = row

	local turretDot = Instance.new("Frame")
	turretDot.AnchorPoint = Vector2.new(0.5, 0.5)
	turretDot.Position = UDim2.fromScale(0.5, 0.5)
	turretDot.Size = UDim2.fromOffset(14, 14)
	turretDot.BackgroundColor3 = item.TurretColor or Color3.fromRGB(200, 200, 200)
	turretDot.BorderSizePixel = 0
	local td = Instance.new("UICorner")
	td.CornerRadius = UDim.new(0, 4)
	td.Parent = turretDot
	turretDot.Parent = swatch

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(52, 6)
	name.Size = UDim2.new(1, -180, 0, 22)
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextSize = 16
	name.TextColor3 = Color3.fromRGB(245, 248, 255)
	name.Text = item.DisplayName
	name.Parent = row

	local price = tonumber(item.Price) or 0
	local canAfford = (tonumber(bolts) or 0) >= price

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(52, 28)
	sub.Size = UDim2.new(1, -180, 0, 18)
	sub.Font = Enum.Font.Gotham
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextSize = 13
	if item.Owned then
		sub.Text = isEquipped and "Equipped" or "Owned"
		sub.TextColor3 = Color3.fromRGB(150, 220, 170)
	else
		sub.Text = price .. " Bolts"
		sub.TextColor3 = canAfford and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(220, 120, 120)
	end
	sub.Parent = row

	local action = Instance.new("TextButton")
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -10, 0.5, 0)
	action.Size = UDim2.fromOffset(110, 34)
	action.Font = Enum.Font.GothamBold
	action.TextSize = 15
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = action
	action.Parent = row

	if not item.Owned then
		if canAfford then
			action.Text = "Buy"
			action.BackgroundColor3 = Color3.fromRGB(40, 110, 70)
			action.TextColor3 = Color3.fromRGB(220, 255, 230)
			action.AutoButtonColor = true
			action.MouseButton1Click:Connect(function()
				buyEvent:FireServer(item.SkinId)
			end)
		else
			-- Disabled: can't afford. No click handler, dimmed.
			action.Text = "Need " .. price
			action.BackgroundColor3 = Color3.fromRGB(48, 40, 44)
			action.TextColor3 = Color3.fromRGB(170, 130, 130)
			action.AutoButtonColor = false
		end
	elseif isEquipped then
		action.Text = "Equipped"
		action.BackgroundColor3 = Color3.fromRGB(60, 64, 72)
		action.TextColor3 = Color3.fromRGB(200, 210, 225)
		action.AutoButtonColor = false
	else
		action.Text = "Equip"
		action.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
		action.TextColor3 = Color3.fromRGB(220, 240, 255)
		action.AutoButtonColor = true
		action.MouseButton1Click:Connect(function()
			equipEvent:FireServer(item.SkinId)
		end)
	end

	return row
end

-- Ask the server for a fresh catalog + current balance (empty skinId = sync request).
local function requestSync()
	buyEvent:FireServer("")
end

local function rebuild()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if latestData == nil then
		return
	end
	boltsLabel.Text = (tonumber(latestData.Bolts) or 0) .. " Bolts"
	msgLabel.Text = latestData.Message or ""
	-- Free skins first, then by price.
	table.sort(latestData.Items, function(a, b)
		return (tonumber(a.Price) or 0) < (tonumber(b.Price) or 0)
	end)
	for i, item in ipairs(latestData.Items) do
		local row = rowFor(item, latestData.Equipped, latestData.Bolts)
		row.LayoutOrder = i
		row.Parent = list
	end
end

openBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		requestSync()
		rebuild()
	end
end)
closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

syncEvent.OnClientEvent:Connect(function(data)
	latestData = data
	-- Always refresh balance/message even if closed, and rebuild rows when open.
	boltsLabel.Text = (tonumber(data.Bolts) or 0) .. " Bolts"
	if panel.Visible then
		rebuild()
	end
end)

-- Public hook so a lobby Shop pad can open the shop by firing this BindableEvent.
local openBindable = Instance.new("BindableEvent")
openBindable.Name = "WOBOpenShop"
openBindable.Parent = screenGui
openBindable.Event:Connect(function()
	panel.Visible = true
	requestSync()
	rebuild()
end)

-- ---------------------------------------------------------------------------
-- Drive onto the TankSkinsShowcase stand in the lobby to open the shop, drive away to close.
-- The showcase lives in Workspace.WOB_Generated.Lobby.Showcases.TankSkinsShowcase. We use
-- its DisplayPlatform (or Base) part as the trigger area and check the local tank's distance.
-- ---------------------------------------------------------------------------
local OPEN_RADIUS = 14
local autoOpened = false

local function findShowcaseTrigger()
	local generated = Workspace:FindFirstChild("WOB_Generated")
	local lobby = generated and generated:FindFirstChild("Lobby")
	local showcases = lobby and lobby:FindFirstChild("Showcases")
	local stand = showcases and showcases:FindFirstChild("TankSkinsShowcase")
	if stand == nil then
		return nil
	end
	if stand:IsA("BasePart") then
		return stand
	end
	return stand:FindFirstChild("DisplayPlatform")
		or stand:FindFirstChild("Base")
		or stand:FindFirstChildWhichIsA("BasePart")
end

local function getLocalTankPosition()
	local generated = Workspace:FindFirstChild("WOB_Generated")
	local testObjects = generated and generated:FindFirstChild("TestObjects")
	if testObjects == nil then
		return nil
	end
	for _, model in ipairs(testObjects:GetDescendants()) do
		if model:IsA("Model")
			and model:GetAttribute("IsPlayerTank") == true
			and model:GetAttribute("OwnerUserId") == localPlayer.UserId
		then
			local ok, pivot = pcall(function()
				return model:GetPivot().Position
			end)
			if ok then
				return pivot
			end
		end
	end
	return nil
end

-- The shop is a LOBBY-only feature: hide the SHOP button (and force-close the panel)
-- whenever the player is not in the lobby (in a match / arena / duel / queued).
local function isInLobby()
	local mode = localPlayer:GetAttribute("PlayerMode")
	-- Lobby is the default free-roam state. Anything else (InMatch / InBattleArena /
	-- QueuedForDuel / ArenaRespawning / Result) hides the shop.
	return mode == nil or mode == "Lobby"
end

local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.25 then
		return
	end
	accum = 0

	local inLobby = isInLobby()
	openBtn.Visible = inLobby
	if not inLobby then
		-- Leaving the lobby closes the shop and clears the proximity latch.
		if panel.Visible then
			panel.Visible = false
		end
		autoOpened = false
		return
	end

	local trigger = findShowcaseTrigger()
	local tankPos = getLocalTankPosition()
	if trigger == nil or tankPos == nil then
		return
	end

	local near = (Vector3.new(tankPos.X, 0, tankPos.Z) - Vector3.new(trigger.Position.X, 0, trigger.Position.Z)).Magnitude <= OPEN_RADIUS

	if near and not autoOpened then
		autoOpened = true
		panel.Visible = true
		requestSync()
		rebuild()
	elseif not near and autoOpened then
		autoOpened = false
		panel.Visible = false
	end
end)
