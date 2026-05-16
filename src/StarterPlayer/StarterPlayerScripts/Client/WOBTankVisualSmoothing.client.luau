local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local TankSmoothingConfig = require(configs:WaitForChild("TankSmoothingConfig"))

if TankSmoothingConfig.Enabled ~= true then
	return
end

local root = Workspace:WaitForChild("WOB_Generated", 10)
local testObjects = root ~= nil and root:WaitForChild("TestObjects", 10) or nil

if testObjects == nil then
	warn("[SMOOTHING] Workspace.WOB_Generated.TestObjects not found; tank visual smoothing disabled.")
	return
end

local trackedTanks = {}

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

local function isOwnedByLocalPlayer(model)
	local ownerUserId = model:GetAttribute("OwnerUserId")
	return ownerUserId ~= nil and ownerUserId == localPlayer.UserId
end

local function hasTankContract(model)
	return findBasePart(model, "Body") ~= nil
		and findBasePart(model, "Turret") ~= nil
		and findBasePart(model, "Barrel") ~= nil
		and findBasePart(model, "ShootPoint") ~= nil
		and model:FindFirstChild("Hitboxes", true) ~= nil
end

local function isTankModel(instance)
	if instance == nil or not instance:IsA("Model") then
		return false
	end

	return instance:GetAttribute("TankId") ~= nil
		or instance:GetAttribute("IsPlayerTank") ~= nil
		or instance:GetAttribute("IsBot") ~= nil
		or hasTankContract(instance)
end

local function shouldSmoothTank(model)
	if TankSmoothingConfig.Enabled ~= true or TankSmoothingConfig.SmoothRemoteTanks ~= true then
		return false
	end

	if model.Parent == nil or model:GetAttribute("IsActive") == false then
		return false
	end

	if TankSmoothingConfig.IgnoreDeadTanks == true and model:GetAttribute("IsDead") == true then
		return false
	end

	if isOwnedByLocalPlayer(model) then
		return TankSmoothingConfig.SmoothLocalTank == true
	end

	local controllerType = model:GetAttribute("ControllerType")
	return model:GetAttribute("IsBot") == true
		or controllerType == "Dummy"
		or controllerType == "Bot"
		or model:GetAttribute("OwnerUserId") ~= localPlayer.UserId
end

local function expLerpAlpha(speed, deltaTime)
	return 1 - math.exp(-math.max(0, speed) * math.max(0, deltaTime))
end

local function lerpCFrame(current, target, alpha)
	return current:Lerp(target, math.clamp(alpha, 0, 1))
end

local function collectVisualParts(model)
	local visual = model:FindFirstChild("Visual")
	local parts = {}

	if visual ~= nil then
		for _, descendant in ipairs(visual:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end

		if #parts > 0 then
			return parts
		end
	end

	local fallbackPartNames = { "Body", "Turret", "Barrel", "ShootPoint" }
	local seen = {}

	for _, partName in ipairs(fallbackPartNames) do
		local part = findBasePart(model, partName)

		if part ~= nil and seen[part] ~= true then
			seen[part] = true
			table.insert(parts, part)
		end
	end

	return parts
end

local function getOrCreateTrackedTank(model)
	if not isTankModel(model) then
		return nil
	end

	local tracked = trackedTanks[model]

	if tracked ~= nil then
		return tracked
	end

	tracked = {
		Model = model,
		Parts = collectVisualParts(model),
		DisplayCFrames = {},
		LoggedStart = false,
	}

	trackedTanks[model] = tracked
	return tracked
end

local function getPartSmoothingSpeed(part)
	if part.Name == "Turret" or part.Name == "Barrel" or part.Name == "ShootPoint" then
		return TankSmoothingConfig.TurretRotationLerpSpeed
	end

	return math.max(TankSmoothingConfig.PositionLerpSpeed, TankSmoothingConfig.RotationLerpSpeed)
end

local function updateTrackedTank(tracked, deltaTime)
	local model = tracked.Model

	if model.Parent == nil then
		trackedTanks[model] = nil
		return
	end

	if not shouldSmoothTank(model) then
		table.clear(tracked.DisplayCFrames)
		return
	end

	if #tracked.Parts == 0 then
		tracked.Parts = collectVisualParts(model)
	end

	if TankSmoothingConfig.Debug == true and tracked.LoggedStart ~= true then
		tracked.LoggedStart = true
		print("[SMOOTHING] smoothing tank " .. tostring(model:GetAttribute("TankId") or model.Name))
	end

	for _, part in ipairs(tracked.Parts) do
		if part.Parent ~= nil then
			local targetCFrame = part.CFrame
			local displayCFrame = tracked.DisplayCFrames[part] or targetCFrame
			local distance = (displayCFrame.Position - targetCFrame.Position).Magnitude
			local nextCFrame = targetCFrame

			if distance <= TankSmoothingConfig.MaxSnapDistance then
				nextCFrame = lerpCFrame(displayCFrame, targetCFrame, expLerpAlpha(getPartSmoothingSpeed(part), deltaTime))
			end

			tracked.DisplayCFrames[part] = nextCFrame
			part.CFrame = nextCFrame
		end
	end
end

local function tryTrackFromInstance(instance)
	if instance:IsA("Model") and isTankModel(instance) then
		getOrCreateTrackedTank(instance)
		return
	end

	local current = instance.Parent

	while current ~= nil and current ~= testObjects do
		if current:IsA("Model") and isTankModel(current) then
			getOrCreateTrackedTank(current)
			return
		end

		current = current.Parent
	end
end

for _, descendant in ipairs(testObjects:GetDescendants()) do
	tryTrackFromInstance(descendant)
end

testObjects.DescendantAdded:Connect(tryTrackFromInstance)

RunService.RenderStepped:Connect(function(deltaTime)
	for _, tracked in pairs(trackedTanks) do
		updateTrackedTank(tracked, deltaTime)
	end
end)
