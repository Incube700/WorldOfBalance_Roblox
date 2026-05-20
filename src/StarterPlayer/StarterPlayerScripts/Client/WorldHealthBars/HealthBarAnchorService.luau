local Workspace = game:GetService("Workspace")

local HealthBarAnchorService = {}
HealthBarAnchorService.__index = HealthBarAnchorService

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

	local hull = findBasePart(model, "Hull")

	if hull ~= nil then
		return hull
	end

	if model.PrimaryPart ~= nil and model.PrimaryPart:IsDescendantOf(model) then
		return model.PrimaryPart
	end

	return nil
end

local function getAnchorPosition(model)
	local bodyPart = getBodyPart(model)

	if bodyPart ~= nil then
		return bodyPart.Position
	end

	local success, cframe = pcall(function()
		return model:GetBoundingBox()
	end)

	if success and typeof(cframe) == "CFrame" then
		return cframe.Position
	end

	return nil
end

function HealthBarAnchorService.new(config)
	return setmetatable({
		Config = config,
		AnchorFolder = nil,
	}, HealthBarAnchorService)
end

function HealthBarAnchorService:Start()
	local config = self.Config
	local legacyAnchorFolder = Workspace:FindFirstChild(config.LEGACY_ANCHOR_FOLDER_NAME)

	if legacyAnchorFolder ~= nil then
		legacyAnchorFolder:Destroy()
	end

	local runtimeRoot = Workspace:FindFirstChild(config.RUNTIME_ROOT_NAME)
		or Workspace:WaitForChild(config.RUNTIME_ROOT_NAME, 10)

	if runtimeRoot == nil then
		runtimeRoot = getOrCreateFolder(Workspace, config.RUNTIME_ROOT_NAME)
	end

	local clientRuntimeFolder = runtimeRoot ~= nil
		and getOrCreateFolder(runtimeRoot, config.CLIENT_RUNTIME_FOLDER_NAME)
		or nil

	if clientRuntimeFolder == nil then
		warn("[WOB] Tank world health bars disabled: Workspace.WOB_Runtime.Client could not be created")
		return false
	end

	local existingAnchorFolder = clientRuntimeFolder:FindFirstChild(config.ANCHOR_FOLDER_NAME)

	if existingAnchorFolder ~= nil then
		existingAnchorFolder:Destroy()
	end

	local anchorFolder = Instance.new("Folder")
	anchorFolder.Name = config.ANCHOR_FOLDER_NAME
	anchorFolder.Parent = clientRuntimeFolder
	self.AnchorFolder = anchorFolder

	return true
end

function HealthBarAnchorService:CreateAnchor(model)
	if self.AnchorFolder == nil then
		return nil
	end

	local anchor = Instance.new("Part")
	anchor.Name = "HealthBarAnchor_" .. model.Name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = self.AnchorFolder

	return anchor
end

function HealthBarAnchorService:UpdateAnchor(model, anchor)
	if anchor == nil then
		return
	end

	local center = getAnchorPosition(model)

	if center == nil then
		return
	end

	anchor.Position = center + self.Config.HEIGHT_OFFSET + self.Config.WORLD_OFFSET
end

function HealthBarAnchorService:CleanupAnchor(anchor)
	if anchor ~= nil then
		anchor:Destroy()
	end
end

return HealthBarAnchorService
