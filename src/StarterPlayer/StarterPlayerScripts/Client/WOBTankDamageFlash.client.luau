local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local HudConfig = require(configs:WaitForChild("HudConfig"))
local PerformanceConfig = require(configs:WaitForChild("PerformanceConfig"))

local flashConfig = HudConfig.DamageFlash or {}
local diagnosticsConfig = PerformanceConfig.Diagnostics or {}

if diagnosticsConfig.DamageFlashEnabled == false then
	return
end

local root = Workspace:WaitForChild("WOB_Generated")
local RUNTIME_ROOT_NAME = "WOB_Runtime"
local CLIENT_RUNTIME_FOLDER_NAME = "Client"
local VISUALS_FOLDER_NAME = "Visuals"
local DAMAGE_FLASH_FOLDER_NAME = "DamageFlash"
local DAMAGE_SERIAL_ATTRIBUTE = "LastDamageSerial"

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

local runtimeRoot = Workspace:FindFirstChild(RUNTIME_ROOT_NAME) or Workspace:WaitForChild(RUNTIME_ROOT_NAME, 10)

if runtimeRoot == nil then
	runtimeRoot = getOrCreateFolder(Workspace, RUNTIME_ROOT_NAME)
end

local clientRuntimeFolder = runtimeRoot ~= nil and getOrCreateFolder(runtimeRoot, CLIENT_RUNTIME_FOLDER_NAME) or nil
local visualsFolder = clientRuntimeFolder ~= nil
	and getOrCreateFolder(clientRuntimeFolder, VISUALS_FOLDER_NAME)
	or nil
local localVisualsFolder = visualsFolder ~= nil
	and getOrCreateFolder(visualsFolder, DAMAGE_FLASH_FOLDER_NAME)
	or nil

local staleRootFolder = Workspace:FindFirstChild("WOBLocalDamageFlash")

if staleRootFolder ~= nil then
	staleRootFolder:Destroy()
end

if localVisualsFolder == nil then
	warn("[HIT FLASH] disabled: Workspace.WOB_Runtime.Client.Visuals.DamageFlash could not be created")
	return
end

for _, child in ipairs(localVisualsFolder:GetChildren()) do
	child:Destroy()
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

local function getDepthMode(config)
	if config.DepthMode == "AlwaysOnTop" then
		return Enum.HighlightDepthMode.AlwaysOnTop
	end

	return Enum.HighlightDepthMode.Occluded
end

local function debugDamageDetected(model, serial)
	local config = getFlashConfig()

	if config.Debug ~= true then
		return
	end

	local amount = tonumber(model:GetAttribute("LastDamageAmount")) or 0
	print(
		("[HIT FLASH] detected model=%s serial=%s amount=%s"):format(
			model:GetFullName(),
			tostring(serial),
			tostring(amount)
		)
	)
end

local function isTankName(name)
	return string.find(name, "Tank") ~= nil
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
	local colorPulseDuration = math.max(0.03, duration * 0.35)
	local fadeDuration = math.max(0.04, duration - colorPulseDuration)
	local startTransparency = config.FillTransparencyStart or 0.15
	local midTransparency = config.FillTransparencyMid or 0.32
	local endTransparency = config.FillTransparencyEnd or 1
	local startColor = config.ColorStart or Color3.fromRGB(255, 255, 245)
	local fillColor = config.Color or Color3.fromRGB(255, 245, 180)

	if record.Tween ~= nil then
		record.Tween:Cancel()
	end

	record.Sequence = (record.Sequence or 0) + 1
	local sequence = record.Sequence

	highlight.Adornee = model
	highlight.DepthMode = getDepthMode(config)
	highlight.FillColor = startColor
	highlight.FillTransparency = startTransparency
	highlight.OutlineTransparency = 1
	highlight.Enabled = true

	local colorTween = TweenService:Create(
		highlight,
		TweenInfo.new(colorPulseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FillColor = fillColor,
			FillTransparency = midTransparency,
		}
	)
	record.Tween = colorTween

	colorTween.Completed:Connect(function()
		if recordsByModel[model] ~= record or record.Sequence ~= sequence then
			return
		end

		local fadeTween = TweenService:Create(
			highlight,
			TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FillTransparency = endTransparency }
		)
		record.Tween = fadeTween

		fadeTween.Completed:Connect(function()
			if recordsByModel[model] == record and record.Sequence == sequence and record.Tween == fadeTween then
				highlight.Enabled = false
				record.Tween = nil
			end
		end)

		fadeTween:Play()
	end)

	task.delay(duration + 0.08, function()
		if recordsByModel[model] == record and record.Sequence == sequence then
			highlight.Enabled = false
		end
	end)

	colorTween:Play()
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
		debugDamageDetected(model, nextSerial)
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
		Sequence = 0,
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

	collectModelsFromRoot(testObjects, models)
	collectModelsFromRoot(battleArena, models)

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

discoverTankModels()

task.spawn(function()
	while localVisualsFolder.Parent ~= nil do
		discoverTankModels()
		local worldHealthBarsConfig = HudConfig.WorldHealthBars or {}
		task.wait(getFlashConfig().DiscoveryInterval or worldHealthBarsConfig.DiscoveryInterval or 1)
	end
end)
