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
		PlayerNameLabel = context.Factory:FindDescendant(billboard, "PlayerName", "TextLabel"),
		RedBar = context.Factory:FindDescendant(billboard, "RedBar", "Frame"),
		GreenBar = context.Factory:FindDescendant(billboard, "GreenBar", "Frame"),
		ReloadBack = context.Factory:FindDescendant(billboard, "ReloadBack", "Frame"),
		ReloadBar = context.Factory:FindDescendant(billboard, "ReloadBar", "Frame"),
		Connections = {},
		-- Smoothed world position for the anchor Part (nil until first Step).
		-- Only used when Config.SMOOTHING_ENABLED is true.
		SmoothedPosition = nil,
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
	-- camera. Remap it to StudsOffset.Y (camera-space up) so the bar is pushed
	-- toward the top of the screen regardless of world orientation.
	-- StudsOffsetWorldSpace stays zero — no rotation artifacts.
	--
	-- Three anchor cases:
	--   Attachment inside Body  → camera-space StudsOffset (automatic world tracking)
	--   Smoothed floating Part  → camera-space StudsOffset (code lerps world position)
	--   Legacy non-smoothed Part → zero StudsOffset (WORLD_OFFSET baked into Part.Position)
	self.Billboard.StudsOffsetWorldSpace = Vector3.zero
	local useCameraSpaceOffset = (self.AnchorPart ~= nil and self.AnchorPart:IsA("Attachment"))
		or self.Config.SMOOTHING_ENABLED
	if useCameraSpaceOffset then
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
	self:UpdatePlayerName()

	return true
end

-- Shows the tank owner's name (or "BOT") above the bar. Reads OwnerDisplayName written by
-- TankFactory; hides the label if empty. Visual only.
function TankHealthBarRecord:UpdatePlayerName()
	local label = self.PlayerNameLabel
	if label == nil then
		return
	end

	local name = self.Model:GetAttribute("OwnerDisplayName")
	if typeof(name) == "string" and name ~= "" then
		if label.Text ~= name then
			label.Text = name
		end
		label.Visible = true
	else
		label.Visible = false
	end
end

function TankHealthBarRecord:Step(dt)
	if self.Model.Parent == nil or self.AnchorPart == nil then
		return false
	end

	if self.Billboard.Enabled == false then
		return true
	end

	if self.Config.SMOOTHING_ENABLED and self.AnchorPart:IsA("BasePart") then
		-- Lerp the floating anchor Part toward the raw body center each frame.
		-- This decouples the bar's visual position from the server replication tick
		-- so it glides smoothly even when the body teleports at ~20 fps.
		local rawCenter = self.AnchorService:GetRawCenter(self.Model)
		if rawCenter ~= nil then
			local target = rawCenter + self.Config.HEIGHT_OFFSET
			local safeDt = typeof(dt) == "number" and math.max(0, dt) or (1 / 60)
			if self.SmoothedPosition == nil then
				-- First frame: snap to avoid sliding in from origin.
				self.SmoothedPosition = target
			else
				local alpha = math.min(1, self.Config.POSITION_SMOOTHING_SPEED * safeDt)
				self.SmoothedPosition = self.SmoothedPosition:Lerp(target, alpha)
			end
			self.AnchorPart.Position = self.SmoothedPosition
		end
	else
		-- Non-smoothed path: Attachment follows body automatically; Part gets
		-- its world position updated via UpdateAnchor (legacy behaviour).
		self:UpdateAnchor()
	end

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
