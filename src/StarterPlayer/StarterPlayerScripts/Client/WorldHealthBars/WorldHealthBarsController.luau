local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local scriptParent = script.Parent
local Config = require(scriptParent:WaitForChild("WorldHealthBarsConfig"))
local TankModelScanner = require(scriptParent:WaitForChild("TankModelScanner"))
local HealthBarBillboardFactory = require(scriptParent:WaitForChild("HealthBarBillboardFactory"))
local HealthBarAnchorService = require(scriptParent:WaitForChild("HealthBarAnchorService"))
local TankHealthBarRecord = require(scriptParent:WaitForChild("TankHealthBarRecord"))

local WorldHealthBarsController = {}
WorldHealthBarsController.__index = WorldHealthBarsController

function WorldHealthBarsController.new(localPlayer)
	return setmetatable({
		LocalPlayer = localPlayer,
		PlayerGui = localPlayer:WaitForChild("PlayerGui"),
		Generated = Workspace:WaitForChild("WOB_Generated"),
		Config = Config,
		Scanner = TankModelScanner,
		Factory = HealthBarBillboardFactory.new(Config),
		AnchorService = HealthBarAnchorService.new(Config),
		GuiFolder = nil,
		RecordsByModel = {},
		HeartbeatConnection = nil,
	}, WorldHealthBarsController)
end

function WorldHealthBarsController:CreateGuiFolder()
	local existingGui = self.PlayerGui:FindFirstChild(self.Config.GUI_NAME)

	if existingGui ~= nil then
		existingGui:Destroy()
	end

	local guiFolder = Instance.new("Folder")
	guiFolder.Name = self.Config.GUI_NAME
	guiFolder.Parent = self.PlayerGui
	self.GuiFolder = guiFolder
end

function WorldHealthBarsController:CleanupModel(model)
	local record = self.RecordsByModel[model]

	if record == nil then
		return
	end

	record:Destroy()
	self.RecordsByModel[model] = nil
end

function WorldHealthBarsController:EnsureRecord(model)
	local existingRecord = self.RecordsByModel[model]

	if existingRecord ~= nil then
		if not existingRecord:Update() then
			self:CleanupModel(model)
		end

		return
	end

	local record = TankHealthBarRecord.new(model, {
		Config = self.Config,
		Scanner = self.Scanner,
		Factory = self.Factory,
		AnchorService = self.AnchorService,
		LocalPlayer = self.LocalPlayer,
		GuiFolder = self.GuiFolder,
		OnInvalid = function(invalidModel)
			self:CleanupModel(invalidModel)
		end,
	})

	self.RecordsByModel[model] = record
end

function WorldHealthBarsController:Discover()
	for _, model in ipairs(self.Scanner.ScanGenerated(self.Generated, self.Config)) do
		self:EnsureRecord(model)
	end

	local invalidModels = {}

	for model, record in pairs(self.RecordsByModel) do
		if not record:Update() then
			table.insert(invalidModels, model)
		end
	end

	for _, model in ipairs(invalidModels) do
		self:CleanupModel(model)
	end
end

function WorldHealthBarsController:Step(dt)
	local invalidModels = {}

	for model, record in pairs(self.RecordsByModel) do
		if not record:Step(dt) then
			table.insert(invalidModels, model)
		end
	end

	for _, model in ipairs(invalidModels) do
		self:CleanupModel(model)
	end
end

function WorldHealthBarsController:Stop()
	if self.HeartbeatConnection ~= nil then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end

	local models = {}

	for model in pairs(self.RecordsByModel) do
		table.insert(models, model)
	end

	for _, model in ipairs(models) do
		self:CleanupModel(model)
	end
end

function WorldHealthBarsController:Start()
	if self.Config.ENABLED == false then
		return
	end

	self:CreateGuiFolder()

	if not self.AnchorService:Start() then
		return
	end

	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self:Step(dt)
	end)

	while self.GuiFolder.Parent ~= nil do
		self:Discover()
		task.wait(self.Config.DISCOVERY_INTERVAL)
	end

	self:Stop()
end

return WorldHealthBarsController
