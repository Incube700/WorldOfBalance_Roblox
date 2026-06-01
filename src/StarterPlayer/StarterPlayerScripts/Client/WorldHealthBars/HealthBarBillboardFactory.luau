local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealthBarBillboardFactory = {}
HealthBarBillboardFactory.__index = HealthBarBillboardFactory

local function resolveUiAssets()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local assets = shared:WaitForChild("Assets")
	return assets:FindFirstChild("UI")
end

function HealthBarBillboardFactory.new(config)
	return setmetatable({
		Config = config,
		UiAssets = resolveUiAssets(),
		WarnedMissingTemplate = false,
	}, HealthBarBillboardFactory)
end

function HealthBarBillboardFactory:FindDescendant(root, name, className)
	local object = root:FindFirstChild(name, true)

	if object ~= nil and (className == nil or object:IsA(className)) then
		return object
	end

	return nil
end

function HealthBarBillboardFactory:GetOrCreateFrame(parent, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if existing:IsA("Frame") then
			return existing
		end

		warn(("[WOB] %s.%s is %s, expected Frame. World health bar layout may be incomplete."):format(
			parent:GetFullName(),
			name,
			existing.ClassName
		))
		return nil
	end

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.Parent = parent

	return frame
end

function HealthBarBillboardFactory:FindTemplate()
	if self.UiAssets == nil then
		return nil
	end

	local template = self.UiAssets:FindFirstChild(self.Config.TEMPLATE_NAME)

	if template ~= nil and template:IsA("BillboardGui") then
		return template
	end

	if not self.WarnedMissingTemplate then
		warn("[WOB] TankHealthBillboard template missing. Using local fallback.")
		self.WarnedMissingTemplate = true
	end

	return nil
end

function HealthBarBillboardFactory:CreateFallbackBillboard()
	local config = self.Config
	local billboard = Instance.new("BillboardGui")
	billboard.Name = config.TEMPLATE_NAME
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = config.MAX_DISTANCE
	billboard.Size = config.BILLBOARD_SIZE
	billboard.StudsOffset = Vector3.zero

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = billboard

	-- Player name label, sits just above the bars.
	local playerName = Instance.new("TextLabel")
	playerName.Name = "PlayerName"
	playerName.BackgroundTransparency = 1
	playerName.BorderSizePixel = 0
	playerName.AnchorPoint = Vector2.new(0.5, 1)
	playerName.Position = UDim2.new(0.5, 0, 0, -2)
	playerName.Size = UDim2.new(1, 20, 0, 12)
	playerName.Font = Enum.Font.GothamBold
	playerName.TextScaled = true
	playerName.TextColor3 = Color3.fromRGB(240, 246, 255)
	playerName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	playerName.TextStrokeTransparency = 0.4
	playerName.Text = ""
	playerName.Visible = false
	playerName.Parent = root

	local barsRoot = Instance.new("Frame")
	barsRoot.Name = "BarsRoot"
	barsRoot.BackgroundTransparency = 1
	barsRoot.BorderSizePixel = 0
	barsRoot.Size = UDim2.fromScale(1, 1)
	barsRoot.Parent = root

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barBack.BackgroundTransparency = 0.15
	barBack.BorderSizePixel = 0
	barBack.ClipsDescendants = true
	barBack.Size = config.SHOW_RELOAD_BAR and UDim2.new(1, 0, 0, 8) or UDim2.fromScale(1, 1)
	barBack.Parent = barsRoot

	local redBar = Instance.new("Frame")
	redBar.Name = "RedBar"
	redBar.AnchorPoint = Vector2.new(0, 0.5)
	redBar.Position = UDim2.fromScale(0, 0.5)
	redBar.Size = UDim2.fromScale(1, 1)
	redBar.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
	redBar.BorderSizePixel = 0
	redBar.ZIndex = 1
	redBar.Parent = barBack

	local greenBar = Instance.new("Frame")
	greenBar.Name = "GreenBar"
	greenBar.AnchorPoint = Vector2.new(0, 0.5)
	greenBar.Position = UDim2.fromScale(0, 0.5)
	greenBar.Size = UDim2.fromScale(1, 1)
	greenBar.BackgroundColor3 = Color3.fromRGB(90, 225, 115)
	greenBar.BorderSizePixel = 0
	greenBar.ZIndex = 2
	greenBar.Parent = barBack

	if config.SHOW_RELOAD_BAR then
		local reloadBack = Instance.new("Frame")
		reloadBack.Name = "ReloadBack"
		reloadBack.BackgroundColor3 = Color3.fromRGB(8, 16, 28)
		reloadBack.BackgroundTransparency = 0.12
		reloadBack.BorderSizePixel = 0
		reloadBack.ClipsDescendants = true
		reloadBack.Position = UDim2.new(0, 0, 0, 10)
		reloadBack.Size = UDim2.new(1, 0, 0, 4)
		reloadBack.Parent = barsRoot

		local reloadBar = Instance.new("Frame")
		reloadBar.Name = "ReloadBar"
		reloadBar.AnchorPoint = Vector2.new(0, 0.5)
		reloadBar.Position = UDim2.fromScale(0, 0.5)
		reloadBar.Size = UDim2.fromScale(1, 1)
		reloadBar.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
		reloadBar.BorderSizePixel = 0
		reloadBar.ZIndex = 2
		reloadBar.Parent = reloadBack
	end

	return billboard
end

function HealthBarBillboardFactory:ConfigureBillboard(billboard)
	billboard.Size = self.Config.BILLBOARD_SIZE
	billboard.StudsOffset = Vector3.zero
	-- Reset world-space offset to zero so callers can override it safely.
	-- TankHealthBarRecord sets StudsOffsetWorldSpace per anchor type after this call.
	billboard.StudsOffsetWorldSpace = Vector3.zero
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = self.Config.MAX_DISTANCE
	billboard.Enabled = true
end

function HealthBarBillboardFactory:ConfigureBillboardLayout(billboard)
	local config = self.Config
	local root = self:FindDescendant(billboard, "Root", "Frame")

	if root == nil then
		root = Instance.new("Frame")
		root.Name = "Root"
		root.Parent = billboard
	end

	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)

	local barsRoot = root:FindFirstChild("BarsRoot")

	if barsRoot == nil then
		barsRoot = Instance.new("Frame")
		barsRoot.Name = "BarsRoot"
		barsRoot.Parent = root
	elseif not barsRoot:IsA("Frame") then
		warn("[WOB] TankHealthBillboard BarsRoot is " .. barsRoot.ClassName .. ", expected Frame.")
		return
	end

	barsRoot.BackgroundTransparency = 1
	barsRoot.BorderSizePixel = 0
	barsRoot.Size = UDim2.fromScale(1, 1)

	local barBack = self:FindDescendant(billboard, "BarBack", "Frame") or self:GetOrCreateFrame(barsRoot, "BarBack")

	if barBack ~= nil then
		barBack.Parent = barsRoot
		barBack.AnchorPoint = Vector2.new(0, 0)
		barBack.Position = UDim2.fromOffset(0, 0)
		barBack.Size = config.SHOW_RELOAD_BAR and UDim2.new(1, 0, 0, 8) or UDim2.fromScale(1, 1)
		barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		barBack.BackgroundTransparency = 0.15
		barBack.BorderSizePixel = 0
		barBack.ClipsDescendants = true

		local redBar = self:FindDescendant(barBack, "RedBar", "Frame") or self:GetOrCreateFrame(barBack, "RedBar")
		local greenBar = self:FindDescendant(barBack, "GreenBar", "Frame") or self:GetOrCreateFrame(barBack, "GreenBar")

		if redBar ~= nil then
			redBar.AnchorPoint = Vector2.new(0, 0.5)
			redBar.Position = UDim2.fromScale(0, 0.5)
			redBar.Size = UDim2.fromScale(1, 1)
			redBar.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
			redBar.BorderSizePixel = 0
			redBar.ZIndex = 1
		end

		if greenBar ~= nil then
			greenBar.AnchorPoint = Vector2.new(0, 0.5)
			greenBar.Position = UDim2.fromScale(0, 0.5)
			greenBar.BackgroundColor3 = Color3.fromRGB(90, 225, 115)
			greenBar.BorderSizePixel = 0
			greenBar.ZIndex = 2
		end
	end

	local reloadBack = self:FindDescendant(billboard, "ReloadBack", "Frame")

	if config.SHOW_RELOAD_BAR then
		reloadBack = reloadBack or self:GetOrCreateFrame(barsRoot, "ReloadBack")

		if reloadBack ~= nil then
			reloadBack.Parent = barsRoot
			reloadBack.AnchorPoint = Vector2.new(0, 0)
			reloadBack.Position = UDim2.new(0, 0, 0, 10)
			reloadBack.Size = UDim2.new(1, 0, 0, 4)
			reloadBack.BackgroundColor3 = Color3.fromRGB(8, 16, 28)
			reloadBack.BackgroundTransparency = 0.30
			reloadBack.BorderSizePixel = 0
			reloadBack.ClipsDescendants = true
			reloadBack.Visible = true

			local reloadBar = self:FindDescendant(reloadBack, "ReloadBar", "Frame")
				or self:GetOrCreateFrame(reloadBack, "ReloadBar")

			if reloadBar ~= nil then
				reloadBar.AnchorPoint = Vector2.new(0, 0.5)
				reloadBar.Position = UDim2.fromScale(0, 0.5)
				reloadBar.Size = UDim2.fromScale(1, 1)
				reloadBar.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
				reloadBar.BorderSizePixel = 0
				reloadBar.ZIndex = 2
				reloadBar.Visible = true
			end
		end
	elseif reloadBack ~= nil then
		reloadBack.Visible = false
	end
end

function HealthBarBillboardFactory:CreateBillboard()
	local template = self:FindTemplate()
	local billboard = template ~= nil and template:Clone() or self:CreateFallbackBillboard()

	self:ConfigureBillboard(billboard)
	self:ConfigureBillboardLayout(billboard)

	local hpText = self:FindDescendant(billboard, "HpText", "TextLabel")

	-- PlayerName label is kept and filled by TankHealthBarRecord (shows owner / "BOT").
	if hpText ~= nil then
		hpText.Visible = false
	end

	return billboard
end

return HealthBarBillboardFactory
