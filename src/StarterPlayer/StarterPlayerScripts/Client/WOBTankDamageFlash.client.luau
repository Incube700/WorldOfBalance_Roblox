local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local HudConfig = require(configs:WaitForChild("HudConfig"))

local root = Workspace:WaitForChild("WOB_Generated")
local flashConfig = HudConfig.DamageFlash or {}
local LOCAL_VISUALS_FOLDER_NAME = "WOBLocalDamageFlash"
local DAMAGE_SERIAL_ATTRIBUTE = "LastDamageSerial"

local localVisualsFolder = Workspace:FindFirstChild(LOCAL_VISUALS_FOLDER_NAME)

if localVisualsFolder == nil then
	localVisualsFolder = Instance.new("Folder")
	localVisualsFolder.Name = LOCAL_VISUALS_FOLDER_NAME
	localVisualsFolder.Parent = Workspace
else
	for _, child in ipairs(localVisualsFolder:GetChildren()) do
		child:Destroy()
	end
end

local recordsByModel = {}

local function getFlashConfig()
	return HudConfig.DamageFlash or flashConfig
end

local function getNumberAttribute(instance, attributeName)
	if instance == nil then
		return nil
	end

	local value = instance:GetAttribute(attributeName)

	if typeof(value) == "number" then
		return value
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
	return getNumberAttribute(model, "CurrentHealth") ~= nil
		or getNumberAttribute(model, "HP") ~= nil
		or getNumberAttribute(model, "Health") ~= nil
		or getNumberAttribute(model, "MaxHealth") ~= nil
end

local function shouldWatchModel(model)
	if getFlashConfig().Enabled == false then
		return false
	end

	if not model:IsA("Model") or model.Parent == nil then
		return false
	end

	local isActive = model:GetAttribute("IsActive")

	if isActive == false then
		return false
	end

	return hasParticipantIdentity(model)
		or hasHealthAttributes(model)
		or (isTankName(model.Name) and isActive == true)
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

	if record.Tween ~= nil then
		record.Tween:Cancel()
	end

	if record.Highlight ~= nil then
		record.Highlight:Destroy()
	end

	recordsByModel[model] = nil
end

local function getOrCreateHighlight(model, record)
	if record.Highlight ~= nil and record.Highlight.Parent ~= nil then
		return record.Highlight
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlash_" .. model.Name
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = localVisualsFolder
	record.Highlight = highlight

	return highlight
end

local function playFlash(model, record)
	if not shouldWatchModel(model) then
		cleanupModel(model)
		return
	end

	local config = getFlashConfig()
	local highlight = getOrCreateHighlight(model, record)
	local isLethal = model:GetAttribute("LastDamageWasLethal") == true
	local duration = isLethal and (config.LethalDuration or 0.22) or (config.Duration or 0.14)
	local startTransparency = config.FillTransparencyStart or 0.15
	local endTransparency = config.FillTransparencyEnd or 1
	local fillColor = config.Color or Color3.fromRGB(255, 245, 180)

	if record.Tween ~= nil then
		record.Tween:Cancel()
	end

	highlight.Adornee = model
	highlight.FillColor = fillColor
	highlight.FillTransparency = startTransparency
	highlight.OutlineTransparency = 1
	highlight.Enabled = true

	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = endTransparency }
	)
	record.Tween = tween

	tween.Completed:Connect(function()
		if recordsByModel[model] == record and record.Tween == tween then
			highlight.Enabled = false
			record.Tween = nil
		end
	end)

	tween:Play()
end

local function onDamageSerialChanged(model)
	local record = recordsByModel[model]

	if record == nil then
		return
	end

	local nextSerial = tonumber(model:GetAttribute(DAMAGE_SERIAL_ATTRIBUTE)) or 0
	local previousSerial = record.LastSerial or 0
	record.LastSerial = nextSerial

	if nextSerial > previousSerial and nextSerial > 0 then
		playFlash(model, record)
	end
end

local function ensureRecord(model)
	if recordsByModel[model] ~= nil then
		return
	end

	local record = {
		Connections = {},
		Highlight = nil,
		LastSerial = tonumber(model:GetAttribute(DAMAGE_SERIAL_ATTRIBUTE)) or 0,
		Tween = nil,
	}

	recordsByModel[model] = record

	table.insert(record.Connections, model:GetAttributeChangedSignal(DAMAGE_SERIAL_ATTRIBUTE):Connect(function()
		onDamageSerialChanged(model)
	end))

	table.insert(record.Connections, model:GetAttributeChangedSignal("IsActive"):Connect(function()
		if not shouldWatchModel(model) then
			cleanupModel(model)
		end
	end))

	table.insert(record.Connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cleanupModel(model)
		end
	end))
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
		if shouldWatchModel(model) then
			ensureRecord(model)
		end
	end

	for model in pairs(recordsByModel) do
		if not shouldWatchModel(model) then
			cleanupModel(model)
		end
	end
end

task.spawn(function()
	while localVisualsFolder.Parent ~= nil do
		discoverTankModels()
		task.wait(1)
	end
end)
