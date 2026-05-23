local Workspace = game:GetService("Workspace")

local TankHealthBarRecord = {}
TankHealthBarRecord.__index = TankHealthBarRecord

local function getNumberAttribute(instance, names)
	for _, name in ipairs(names) do
		local value = instance:GetAttribute(name)

		if typeof(value) == "number" then
			return value
		end
	end

	return nil
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

local function getHealth(model, config)
	local maxHealth = getNumberAttribute(model, { "MaxHealth" }) or 100
	local currentHealth = getNumberAttribute(model, config.HEALTH_ATTRIBUTES) or maxHealth

	return math.max(0, currentHealth), math.max(1, maxHealth)
end

local function getReloadRatio(model, config)
	if not config.SHOW_RELOAD_BAR then
		return 1
	end

	if model:GetAttribute("ReloadReady") == true then
		return 1
	end

	local lastShotAtServerTime = model:GetAttribute("LastShotAtServerTime")
	local reloadDuration = model:GetAttribute("ReloadDuration")

	if typeof(lastShotAtServerTime) == "number" and typeof(reloadDuration) == "number" and reloadDuration > 0 then
		return math.clamp((getServerTimeNow() - lastShotAtServerTime) / reloadDuration, 0, 1)
	end

	local reloadProgress = model:GetAttribute("ReloadProgress")

	if typeof(reloadProgress) == "number" then
		return math.clamp(reloadProgress, 0, 1)
	end

	return 1
end

function TankHealthBarRecord.new(model, context)
	local billboard = context.Factory:CreateBillboard()
	billboard.Name = "TankHealthBillboard_" .. model.Name
	billboard.Parent = context.GuiFolder

	local record = setmetatable({
		Model = model,
		Config = context.Config,
		Scanner = context.Scanner,
		Factory = context.Factory,
		AnchorService = context.AnchorService,
		OnInvalid = context.OnInvalid,
		Billboard = billboard,
		AnchorPart = context.AnchorService:CreateAnchor(model),
		RedBar = context.Factory:FindDescendant(billboard, "RedBar", "Frame"),
		GreenBar = context.Factory:FindDescendant(billboard, "GreenBar", "Frame"),
		ReloadBack = context.Factory:FindDescendant(billboard, "ReloadBack", "Frame"),
		ReloadBar = context.Factory:FindDescendant(billboard, "ReloadBar", "Frame"),
		Connections = {},
	}, TankHealthBarRecord)

	record:Connect()
	record:Update()

	return record
end

function TankHealthBarRecord:Connect()
	for _, attributeName in ipairs(self.Config.TRACKED_ATTRIBUTES) do
		table.insert(self.Connections, self.Model:GetAttributeChangedSignal(attributeName):Connect(function()
			if not self:Update() and self.OnInvalid ~= nil then
				self.OnInvalid(self.Model)
			end
		end))
	end

	table.insert(self.Connections, self.Model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and self.OnInvalid ~= nil then
			self.OnInvalid(self.Model)
		end
	end))
end

function TankHealthBarRecord:UpdateAnchor()
	self.AnchorService:UpdateAnchor(self.Model, self.AnchorPart)
end

function TankHealthBarRecord:UpdateReloadBar()
	if not self.Config.SHOW_RELOAD_BAR then
		if self.ReloadBack ~= nil then
			self.ReloadBack.Visible = false
		end

		return
	end

	if self.ReloadBack ~= nil then
		self.ReloadBack.Visible = true
	end

	if self.ReloadBar == nil then
		return
	end

	local reloadRatio = getReloadRatio(self.Model, self.Config)
	self.ReloadBar.AnchorPoint = Vector2.new(0, 0.5)
	self.ReloadBar.Position = UDim2.fromScale(0, 0.5)
	self.ReloadBar.Size = UDim2.new(reloadRatio, 0, 1, 0)
	self.ReloadBar.Visible = true
end

function TankHealthBarRecord:Update()
	if not self.Scanner.IsTankModel(self.Model, self.Config) then
		return false
	end

	local currentHealth, maxHealth = getHealth(self.Model, self.Config)
	local ratio = math.clamp(currentHealth / maxHealth, 0, 1)
	local isDead = self.Model:GetAttribute("IsDead") == true
		or self.Model:GetAttribute("IsAlive") == false
		or currentHealth <= 0

	self:UpdateAnchor()

	self.Billboard.Adornee = self.AnchorPart
	self.Billboard.Enabled = not isDead
	self.Factory:ConfigureBillboard(self.Billboard)

	-- WORLD_OFFSET.Z is a world-space Z shift that appears sideways in a top-down
	-- camera. For Attachment anchors we remap it to StudsOffset.Y (camera-space up),
	-- so the bar is pushed toward the top of the screen regardless of world orientation.
	-- StudsOffsetWorldSpace stays zero — no rotation artifacts.
	-- The fallback Part anchor bakes WORLD_OFFSET into its world position already,
	-- so its billboard uses zero here to avoid doubling the offset.
	self.Billboard.StudsOffsetWorldSpace = Vector3.zero
	if self.AnchorPart ~= nil and self.AnchorPart:IsA("Attachment") then
		self.Billboard.StudsOffset = Vector3.new(0, math.abs(self.Config.WORLD_OFFSET.Z), 0)
	else
		self.Billboard.StudsOffset = Vector3.zero
	end

	if self.RedBar ~= nil then
		self.RedBar.AnchorPoint = Vector2.new(0, 0.5)
		self.RedBar.Position = UDim2.fromScale(0, 0.5)
		self.RedBar.Size = UDim2.fromScale(1, 1)
		self.RedBar.Visible = true
	end

	if self.GreenBar ~= nil then
		self.GreenBar.AnchorPoint = Vector2.new(0, 0.5)
		self.GreenBar.Position = UDim2.fromScale(0, 0.5)
		self.GreenBar.Size = UDim2.new(ratio, 0, 1, 0)
		self.GreenBar.Visible = ratio > 0
	end

	self:UpdateReloadBar()

	return true
end

function TankHealthBarRecord:Step()
	if self.Model.Parent == nil or self.AnchorPart == nil then
		return false
	end

	if self.Billboard.Enabled == false then
		return true
	end

	self:UpdateAnchor()
	self:UpdateReloadBar()

	return true
end

function TankHealthBarRecord:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end

	self.Connections = {}

	if self.Billboard ~= nil then
		self.Billboard:Destroy()
	end

	self.AnchorService:CleanupAnchor(self.AnchorPart)
	self.AnchorPart = nil
end

return TankHealthBarRecord
