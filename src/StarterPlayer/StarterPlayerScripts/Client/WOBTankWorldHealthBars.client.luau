local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local assets = shared:WaitForChild("Assets")
local uiAssets = assets:FindFirstChild("UI")
local HudConfig = require(configs:WaitForChild("HudConfig"))

local generated = Workspace:WaitForChild("WOB_Generated")

local GUI_NAME = "WOBTankWorldHealthBars"
local RUNTIME_ROOT_NAME = "WOB_Runtime"
local CLIENT_RUNTIME_FOLDER_NAME = "Client"
local ANCHOR_FOLDER_NAME = "HealthBarAnchors"
local LEGACY_ANCHOR_FOLDER_NAME = "WOB_ClientHealthBarAnchors"
local TEMPLATE_NAME = "TankHealthBillboard"

local worldHealthBarsConfig = HudConfig.WorldHealthBars or {}
local SHOW_RELOAD_BAR = worldHealthBarsConfig.Enabled ~= false and worldHealthBarsConfig.ShowReloadBar ~= false
local BILLBOARD_SIZE = SHOW_RELOAD_BAR and UDim2.fromOffset(68, 14) or UDim2.fromOffset(64, 8)
local HEIGHT_OFFSET = Vector3.new(0, 2.2, 0)

-- Top-down offset по плоскости карты.
-- Если бар с неправильной стороны — меняй -5 на 5.
local WORLD_OFFSET = Vector3.new(0, 0, -7)

local MAX_DISTANCE = 180
local DISCOVERY_INTERVAL = 1

local HEALTH_ATTRIBUTES = { "CurrentHealth", "HP", "Health" }

local TRACKED_ATTRIBUTES = {
	"CurrentHealth",
	"HP",
	"Health",
	"MaxHealth",
	"IsDead",
	"IsAlive",
	"IsActive",
	"TankParticipantId",
	"LastShotAtServerTime",
	"ReloadDuration",
	"ReloadProgress",
	"ReloadReady",
}

local existingGui = playerGui:FindFirstChild(GUI_NAME)

if existingGui ~= nil then
	existingGui:Destroy()
end

local guiFolder = Instance.new("Folder")
guiFolder.Name = GUI_NAME
guiFolder.Parent = playerGui

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		return nil
	end

	return folder
end

local legacyAnchorFolder = Workspace:FindFirstChild(LEGACY_ANCHOR_FOLDER_NAME)

if legacyAnchorFolder ~= nil then
	legacyAnchorFolder:Destroy()
end

local runtimeRoot = Workspace:FindFirstChild(RUNTIME_ROOT_NAME) or Workspace:WaitForChild(RUNTIME_ROOT_NAME, 10)

if runtimeRoot == nil then
	runtimeRoot = getOrCreateFolder(Workspace, RUNTIME_ROOT_NAME)
end

local clientRuntimeFolder = runtimeRoot ~= nil and getOrCreateFolder(runtimeRoot, CLIENT_RUNTIME_FOLDER_NAME) or nil
local existingAnchorFolder = clientRuntimeFolder ~= nil and clientRuntimeFolder:FindFirstChild(ANCHOR_FOLDER_NAME) or nil

if existingAnchorFolder ~= nil then
	existingAnchorFolder:Destroy()
end

if clientRuntimeFolder == nil then
	warn("[WOB] Tank world health bars disabled: Workspace.WOB_Runtime.Client could not be created")
	return
end

local anchorFolder = Instance.new("Folder")
anchorFolder.Name = ANCHOR_FOLDER_NAME
anchorFolder.Parent = clientRuntimeFolder

local recordsByModel = {}
local warnedMissingTemplate = false

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

local function getHealth(model)
	local maxHealth = getNumberAttribute(model, { "MaxHealth" }) or 100
	local currentHealth = getNumberAttribute(model, HEALTH_ATTRIBUTES) or maxHealth

	return math.max(0, currentHealth), math.max(1, maxHealth)
end

local function getReloadRatio(model)
	if not SHOW_RELOAD_BAR then
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

local function findBasePart(model, name)
	local child = model:FindFirstChild(name)

	if child ~= nil and child:IsA("BasePart") then
		return child
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == name and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getBodyPart(model)
	local body = findBasePart(model, "Body")

	if body ~= nil then
		return body
	end

	if model.PrimaryPart ~= nil and model.PrimaryPart:IsDescendantOf(model) then
		return model.PrimaryPart
	end

	return findBasePart(model, "Hull")
end

local function isTankModel(model)
	if not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("IsActive") == false then
		return false
	end

	local hasHealth = getNumberAttribute(model, HEALTH_ATTRIBUTES) ~= nil
	local hasMaxHealth = getNumberAttribute(model, { "MaxHealth" }) ~= nil
	local hasParticipant = model:GetAttribute("TankParticipantId") ~= nil
	local hasBody = getBodyPart(model) ~= nil

	return hasBody and (hasHealth or hasMaxHealth or hasParticipant)
end

local function findTemplate()
	if uiAssets == nil then
		return nil
	end

	local template = uiAssets:FindFirstChild(TEMPLATE_NAME)

	if template ~= nil and template:IsA("BillboardGui") then
		return template
	end

	if not warnedMissingTemplate then
		warn("[WOB] TankHealthBillboard template missing. Using local fallback.")
		warnedMissingTemplate = true
	end

	return nil
end

local function createFallbackBillboard()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = TEMPLATE_NAME
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = MAX_DISTANCE
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = Vector3.zero

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = billboard

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
	barBack.Size = SHOW_RELOAD_BAR and UDim2.new(1, 0, 0, 8) or UDim2.fromScale(1, 1)
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

	if SHOW_RELOAD_BAR then
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

local function findDescendant(root, name, className)
	local object = root:FindFirstChild(name, true)

	if object ~= nil and (className == nil or object:IsA(className)) then
		return object
	end

	return nil
end

local function getOrCreateFrame(parent, name)
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

local function configureBillboard(billboard)
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = Vector3.zero
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = MAX_DISTANCE
	billboard.Enabled = true
end

local function configureBillboardLayout(billboard)
	local root = findDescendant(billboard, "Root", "Frame")

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

	local barBack = findDescendant(billboard, "BarBack", "Frame") or getOrCreateFrame(barsRoot, "BarBack")

	if barBack ~= nil then
		barBack.Parent = barsRoot
		barBack.AnchorPoint = Vector2.new(0, 0)
		barBack.Position = UDim2.fromOffset(0, 0)
		barBack.Size = SHOW_RELOAD_BAR and UDim2.new(1, 0, 0, 8) or UDim2.fromScale(1, 1)
		barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		barBack.BackgroundTransparency = 0.15
		barBack.BorderSizePixel = 0
		barBack.ClipsDescendants = true

		local redBar = findDescendant(barBack, "RedBar", "Frame") or getOrCreateFrame(barBack, "RedBar")
		local greenBar = findDescendant(barBack, "GreenBar", "Frame") or getOrCreateFrame(barBack, "GreenBar")

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

	local reloadBack = findDescendant(billboard, "ReloadBack", "Frame")

	if SHOW_RELOAD_BAR then
		reloadBack = reloadBack or getOrCreateFrame(barsRoot, "ReloadBack")

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

			local reloadBar = findDescendant(reloadBack, "ReloadBar", "Frame") or getOrCreateFrame(reloadBack, "ReloadBar")

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

local function createBillboard()
	local template = findTemplate()
	local billboard = template ~= nil and template:Clone() or createFallbackBillboard()

	configureBillboard(billboard)
	configureBillboardLayout(billboard)

	local playerName = findDescendant(billboard, "PlayerName", "TextLabel")
	local hpText = findDescendant(billboard, "HpText", "TextLabel")

	if playerName ~= nil then
		playerName.Visible = false
	end

	if hpText ~= nil then
		hpText.Visible = false
	end

	return billboard
end

local function createAnchorPart(model)
	local anchor = Instance.new("Part")
	anchor.Name = "HealthBarAnchor_" .. model.Name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = anchorFolder

	return anchor
end

local function getModelCenter(model)
	local success, cframe = pcall(function()
		return model:GetBoundingBox()
	end)

	if success and typeof(cframe) == "CFrame" then
		return cframe.Position
	end

	local bodyPart = getBodyPart(model)

	if bodyPart ~= nil then
		return bodyPart.Position
	end

	return nil
end

local function updateAnchor(model, record)
	if record.AnchorPart == nil then
		return
	end

	local center = getModelCenter(model)

	if center == nil then
		return
	end

	record.AnchorPart.Position = center + HEIGHT_OFFSET + WORLD_OFFSET
end

local function disconnectRecord(record)
	for _, connection in ipairs(record.Connections) do
		connection:Disconnect()
	end

	record.Connections = {}
end

local function cleanupModel(model)
	local record = recordsByModel[model]

	if record == nil then
		return
	end

	disconnectRecord(record)

	if record.Billboard ~= nil then
		record.Billboard:Destroy()
	end

	if record.AnchorPart ~= nil then
		record.AnchorPart:Destroy()
	end

	recordsByModel[model] = nil
end

local function updateReloadBar(model, record)
	if not SHOW_RELOAD_BAR then
		if record.ReloadBack ~= nil then
			record.ReloadBack.Visible = false
		end

		return
	end

	if record.ReloadBack ~= nil then
		record.ReloadBack.Visible = true
	end

	if record.ReloadBar == nil then
		return
	end

	local reloadRatio = getReloadRatio(model)
	record.ReloadBar.AnchorPoint = Vector2.new(0, 0.5)
	record.ReloadBar.Position = UDim2.fromScale(0, 0.5)
	record.ReloadBar.Size = UDim2.new(reloadRatio, 0, 1, 0)
	record.ReloadBar.Visible = true
end

local function updateRecord(model)
	local record = recordsByModel[model]

	if record == nil then
		return
	end

	if not isTankModel(model) then
		cleanupModel(model)
		return
	end

	local currentHealth, maxHealth = getHealth(model)
	local ratio = math.clamp(currentHealth / maxHealth, 0, 1)
	local isDead = model:GetAttribute("IsDead") == true
	or model:GetAttribute("IsAlive") == false
	or currentHealth <= 0

	updateAnchor(model, record)

	record.Billboard.Adornee = record.AnchorPart
	record.Billboard.Enabled = not isDead
	configureBillboard(record.Billboard)

	if record.RedBar ~= nil then
		record.RedBar.AnchorPoint = Vector2.new(0, 0.5)
		record.RedBar.Position = UDim2.fromScale(0, 0.5)
		record.RedBar.Size = UDim2.fromScale(1, 1)
		record.RedBar.Visible = true
	end

	if record.GreenBar ~= nil then
		record.GreenBar.AnchorPoint = Vector2.new(0, 0.5)
		record.GreenBar.Position = UDim2.fromScale(0, 0.5)
		record.GreenBar.Size = UDim2.new(ratio, 0, 1, 0)
		record.GreenBar.Visible = ratio > 0
	end

	updateReloadBar(model, record)
end

local function ensureRecord(model)
	if recordsByModel[model] ~= nil then
		updateRecord(model)
		return
	end

	local billboard = createBillboard()
	billboard.Name = "TankHealthBillboard_" .. model.Name
	billboard.Parent = guiFolder

	local record = {
		Billboard = billboard,
		AnchorPart = createAnchorPart(model),
		RedBar = findDescendant(billboard, "RedBar", "Frame"),
		GreenBar = findDescendant(billboard, "GreenBar", "Frame"),
		ReloadBack = findDescendant(billboard, "ReloadBack", "Frame"),
		ReloadBar = findDescendant(billboard, "ReloadBar", "Frame"),
		Connections = {},
	}

	recordsByModel[model] = record

	for _, attributeName in ipairs(TRACKED_ATTRIBUTES) do
		table.insert(record.Connections, model:GetAttributeChangedSignal(attributeName):Connect(function()
			updateRecord(model)
		end))
	end

	table.insert(record.Connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cleanupModel(model)
		end
	end))

	updateRecord(model)
end

local function scanRoot(scanRoot)
	if scanRoot == nil then
		return
	end

	for _, descendant in ipairs(scanRoot:GetDescendants()) do
		if descendant:IsA("Model") and isTankModel(descendant) then
			ensureRecord(descendant)
		end
	end
end

local function discover()
	scanRoot(generated:FindFirstChild("TestObjects"))
	scanRoot(generated:FindFirstChild("BattleArena"))

	for model in pairs(recordsByModel) do
		updateRecord(model)
	end
end

RunService.Heartbeat:Connect(function()
	for model, record in pairs(recordsByModel) do
		if model.Parent ~= nil and record.AnchorPart ~= nil then
			updateAnchor(model, record)
			updateReloadBar(model, record)
		end
	end
end)

while guiFolder.Parent ~= nil do
	discover()
	task.wait(DISCOVERY_INTERVAL)
end
