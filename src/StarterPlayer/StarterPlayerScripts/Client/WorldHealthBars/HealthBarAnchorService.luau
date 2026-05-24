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

	-- When smoothing is disabled, prefer an Attachment inside the Body part.
	-- The billboard adorns the Attachment, which follows the Body automatically —
	-- no per-frame position writes needed.
	if not self.Config.SMOOTHING_ENABLED then
		local bodyPart = getBodyPart(model)

		if bodyPart ~= nil then
			local existing = bodyPart:FindFirstChild("HealthBarAnchor")
			if existing ~= nil then
				existing:Destroy()
			end

			local attachment = Instance.new("Attachment")
			attachment.Name = "HealthBarAnchor"
			-- Use only HEIGHT_OFFSET in local body space. WORLD_OFFSET was a world-space
			-- hack for the old floating Part anchor and rotates with the tank when applied
			-- to an Attachment, causing the bar to appear to the side instead of above.
			attachment.Position = self.Config.HEIGHT_OFFSET
			attachment.Parent = bodyPart

			return attachment
		end
	end

	-- Smoothing enabled (or no Body found): use a floating Part in the anchor folder.
	-- TankHealthBarRecord:Step(dt) lerps this Part's world Position each Heartbeat so
	-- the billboard glides rather than jumping with the server replication tick.
	local anchor = Instance.new("Part")
	anchor.Name = "HealthBarAnchor_" .. model.Name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = self.AnchorFolder

	-- Snap to initial world position so the billboard appears at a sensible
	-- location immediately, before the first smoothed Step runs.
	local initialCenter = getAnchorPosition(model)
	if initialCenter ~= nil then
		anchor.Position = initialCenter + self.Config.HEIGHT_OFFSET
	end

	return anchor
end

function HealthBarAnchorService:UpdateAnchor(model, anchor)
	if anchor == nil then
		return
	end

	if anchor:IsA("Attachment") then
		-- The Attachment follows its parent Body part automatically in world space.
		-- Only HEIGHT_OFFSET is applied here; WORLD_OFFSET is omitted because it
		-- would rotate with the body and shift the bar sideways as the tank turns.
		anchor.Position = self.Config.HEIGHT_OFFSET
		return
	end

	if self.Config.SMOOTHING_ENABLED then
		-- Smoothed floating Part: position is managed by TankHealthBarRecord:Step(dt).
		-- Do not overwrite it here or the lerp gets snapped on every attribute change.
		return
	end

	-- Non-smoothed Part fallback: reposition in world space.
	local center = getAnchorPosition(model)

	if center == nil then
		return
	end

	anchor.Position = center + self.Config.HEIGHT_OFFSET + self.Config.WORLD_OFFSET
end

-- Returns the raw world-space center of the model's body/hull/PrimaryPart.
-- Used by TankHealthBarRecord:Step(dt) as the smoothing target.
function HealthBarAnchorService:GetRawCenter(model)
	return getAnchorPosition(model)
end

function HealthBarAnchorService:CleanupAnchor(anchor)
	if anchor ~= nil then
		anchor:Destroy()
	end
end

return HealthBarAnchorService
