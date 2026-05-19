local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local HudConfig = require(configs:WaitForChild("HudConfig"))

local root = Workspace:WaitForChild("WOB_Generated")
local worldHealthConfig = HudConfig.WorldHealthBars or {}
local GUI_FOLDER_NAME = "WOBTankWorldHealthBars"
local TEMPLATE_NAME = "TankHealthBillboard"
local TANK_ATTRIBUTE_NAMES = {
	"CurrentHealth",
	"HP",
	"Health",
	"MaxHealth",
	"IsDead",
	"IsAlive",
	"IsActive",
	"OwnerName",
	"OwnerUserId",
}

local existingFolder = playerGui:FindFirstChild(GUI_FOLDER_NAME)

if existingFolder ~= nil then
	existingFolder:Destroy()
end

local billboardFolder = Instance.new("Folder")
billboardFolder.Name = GUI_FOLDER_NAME
billboardFolder.Parent = playerGui

local recordsByModel = {}
local warnedMissingTemplate = false

local function getWorldHealthConfig()
	return HudConfig.WorldHealthBars or worldHealthConfig
end

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function getNumberAttribute(instance, attributeNames)
	if instance == nil then
		return nil
	end

	for _, attributeName in ipairs(attributeNames) do
		local value = instance:GetAttribute(attributeName)

		if typeof(value) == "number" then
			return value
		end
	end

	return nil
end

local function findNamedBasePart(model, partName)
	local directChild = model:FindFirstChild(partName)

	if directChild ~= nil and directChild:IsA("BasePart") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getAdorneePart(model)
	if model.PrimaryPart ~= nil and model.PrimaryPart:IsDescendantOf(model) then
		return model.PrimaryPart
	end

	local body = findNamedBasePart(model, "Body")

	if body ~= nil then
		return body
	end

	local hull = findNamedBasePart(model, "Hull")

	if hull ~= nil then
		return hull
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function isTankName(name)
	return name == "DummyTank"
		or name == "Player2TankPrototype"
		or name == "PlayerTankPrototype"
		or string.match(name, "^PlayerTank_") ~= nil
		or string.find(name, "Tank") ~= nil
end

local function hasParticipantIdentity(model)
	return model:GetAttribute("TankParticipantId") ~= nil or model:GetAttribute("TankId") ~= nil
end

local function hasHealthAttributes(model)
	return getNumberAttribute(model, { "CurrentHealth", "HP", "Health" }) ~= nil
		or getNumberAttribute(model, { "MaxHealth" }) ~= nil
end

local function isOwnTank(model)
	local ownerUserId = model:GetAttribute("OwnerUserId")

	return typeof(ownerUserId) == "number" and ownerUserId == localPlayer.UserId
end

local function shouldShowModel(model)
	local config = getWorldHealthConfig()

	if config.Enabled == false then
		return false
	end

	if not model:IsA("Model") then
		return false
	end

	if model.Parent == nil then
		return false
	end

	local isActive = model:GetAttribute("IsActive")

	if isActive == false then
		return false
	end

	local hasIdentity = hasParticipantIdentity(model)
	local hasHealth = hasHealthAttributes(model)
	local tankNamed = isTankName(model.Name)

	if not hasIdentity and not hasHealth and not (tankNamed and isActive == true) then
		return false
	end

	if config.ShowOwnTank == false and isOwnTank(model) then
		return false
	end

	return getAdorneePart(model) ~= nil
end

local function findTemplate()
	local assets = shared:FindFirstChild("Assets")
	local ui = assets ~= nil and assets:FindFirstChild("UI") or nil
	local template = ui ~= nil and ui:FindFirstChild(TEMPLATE_NAME) or nil

	if template ~= nil and template:IsA("BillboardGui") then
		return template
	end

	if not warnedMissingTemplate then
		warn("[WOB] TankHealthBillboard template missing; using local fallback. Run docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua.")
		warnedMissingTemplate = true
	end

	return nil
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function createFallbackBillboard()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = TEMPLATE_NAME
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = worldHealthConfig.MaxDistance or 220
	billboard.Size = UDim2.fromOffset(130, 38)
	billboard.StudsOffset = Vector3.new(0, 5, 0)

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.Position = UDim2.fromScale(0.5, 0.5)
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(9, 12, 15)
	background.BackgroundTransparency = 0.18
	background.BorderSizePixel = 0
	background.ZIndex = 1
	background.Parent = billboard
	addCorner(background, UDim.new(0, 6))

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Position = UDim2.new(0, 6, 0, 2)
	nameLabel.Size = UDim2.new(1, -12, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.BorderSizePixel = 0
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "TANK"
	nameLabel.TextColor3 = Color3.fromRGB(245, 255, 250)
	nameLabel.TextScaled = true
	nameLabel.TextStrokeTransparency = 0.45
	nameLabel.ZIndex = 3
	nameLabel.Parent = billboard

	local redBar = Instance.new("Frame")
	redBar.Name = "RedBar"
	redBar.Position = UDim2.new(0, 8, 0, 21)
	redBar.Size = UDim2.new(1, -16, 0, 9)
	redBar.BackgroundColor3 = Color3.fromRGB(165, 45, 45)
	redBar.BorderSizePixel = 0
	redBar.ZIndex = 2
	redBar.Parent = billboard
	addCorner(redBar, UDim.new(0, 4))

	local greenBar = Instance.new("Frame")
	greenBar.Name = "GreenBar"
	greenBar.Size = UDim2.fromScale(1, 1)
	greenBar.BackgroundColor3 = Color3.fromRGB(90, 225, 115)
	greenBar.BorderSizePixel = 0
	greenBar.ZIndex = 3
	greenBar.Parent = redBar
	addCorner(greenBar, UDim.new(0, 4))

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HpText"
	hpText.Position = UDim2.new(0, 8, 0, 27)
	hpText.Size = UDim2.new(1, -16, 0, 10)
	hpText.BackgroundTransparency = 1
	hpText.BorderSizePixel = 0
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = "100/100"
	hpText.TextColor3 = Color3.fromRGB(255, 245, 180)
	hpText.TextScaled = true
	hpText.TextStrokeTransparency = 0.45
	hpText.ZIndex = 4
	hpText.Parent = billboard

	return billboard
end

local function cloneBillboard()
	local template = findTemplate()
	local billboard = template ~= nil and template:Clone() or createFallbackBillboard()
	local config = getWorldHealthConfig()

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = config.MaxDistance or 220
	billboard.Enabled = true

	return billboard
end

local function findDescendant(rootObject, name, className)
	local descendant = rootObject:FindFirstChild(name, true)

	if descendant ~= nil and (className == nil or descendant:IsA(className)) then
		return descendant
	end

	return nil
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

	recordsByModel[model] = nil
end

local function getModelHealth(model)
	local maxHealth = getNumberAttribute(model, { "MaxHealth" }) or 100
	local health = getNumberAttribute(model, { "CurrentHealth", "HP", "Health" }) or maxHealth

	return math.max(0, health), math.max(1, maxHealth)
end

local function updateRecord(model)
	local record = recordsByModel[model]

	if record == nil then
		return
	end

	if not shouldShowModel(model) then
		cleanupModel(model)
		return
	end

	local adornee = getAdorneePart(model)

	if adornee == nil then
		cleanupModel(model)
		return
	end

	local health, maxHealth = getModelHealth(model)
	local ratio = clamp01(health / maxHealth)
	local isDead = model:GetAttribute("IsDead") == true or model:GetAttribute("IsAlive") == false or health <= 0
	local ownerName = model:GetAttribute("OwnerName")
	local displayName = typeof(ownerName) == "string" and ownerName ~= "" and ownerName or model.Name

	record.Billboard.Adornee = adornee
	record.Billboard.Enabled = true

	if record.GreenBar ~= nil then
		record.GreenBar.Size = UDim2.new(ratio, 0, 1, 0)

		if ratio <= 0.3 then
			record.GreenBar.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
		elseif ratio <= 0.6 then
			record.GreenBar.BackgroundColor3 = Color3.fromRGB(240, 190, 80)
		else
			record.GreenBar.BackgroundColor3 = Color3.fromRGB(90, 225, 115)
		end
	end

	if record.HpText ~= nil then
		record.HpText.Text = tostring(math.floor(health)) .. "/" .. tostring(math.floor(maxHealth))
	end

	if record.PlayerName ~= nil then
		record.PlayerName.Text = displayName
	end

	if isDead then
		local hideToken = {}
		record.HideToken = hideToken

		task.delay(getWorldHealthConfig().DeadHideDelay or 1.0, function()
			local latestRecord = recordsByModel[model]

			if latestRecord == record and latestRecord.HideToken == hideToken then
				latestRecord.Billboard.Enabled = false
			end
		end)
	else
		record.HideToken = nil
	end
end

local function ensureRecord(model)
	if recordsByModel[model] ~= nil then
		updateRecord(model)
		return
	end

	local billboard = cloneBillboard()
	billboard.Name = "TankHealthBillboard_" .. model.Name
	billboard.Parent = billboardFolder

	local record = {
		Billboard = billboard,
		GreenBar = findDescendant(billboard, "GreenBar", "Frame"),
		HpText = findDescendant(billboard, "HpText", "TextLabel"),
		PlayerName = findDescendant(billboard, "PlayerName", "TextLabel"),
		Connections = {},
		HideToken = nil,
	}

	recordsByModel[model] = record

	for _, attributeName in ipairs(TANK_ATTRIBUTE_NAMES) do
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

local function collectModelsFromRoot(scanRoot, models)
	if scanRoot == nil or scanRoot.Parent == nil then
		return
	end

	if scanRoot:IsA("Model") then
		models[scanRoot] = true
	end

	for _, descendant in ipairs(scanRoot:GetDescendants()) do
		if descendant:IsA("Model") then
			models[descendant] = true
		end
	end
end

local function discoverTankModels()
	local models = {}
	local testObjects = root:FindFirstChild("TestObjects")
	local battleArena = root:FindFirstChild("BattleArena")
	local battleArenaMap = battleArena ~= nil and battleArena:FindFirstChild("Map") or nil

	collectModelsFromRoot(testObjects, models)
	collectModelsFromRoot(battleArena, models)
	collectModelsFromRoot(battleArenaMap, models)

	for model in pairs(models) do
		if shouldShowModel(model) then
			ensureRecord(model)
		end
	end

	for model in pairs(recordsByModel) do
		updateRecord(model)
	end
end

task.spawn(function()
	while billboardFolder.Parent ~= nil do
		discoverTankModels()
		task.wait(getWorldHealthConfig().DiscoveryInterval or 1.0)
	end
end)
