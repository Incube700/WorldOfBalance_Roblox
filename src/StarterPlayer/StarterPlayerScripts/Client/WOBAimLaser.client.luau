local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local AimAssistConfig = require(configs:WaitForChild("AimAssistConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))

if AimAssistConfig.AimLaserEnabled ~= true then
	return
end

local root = Workspace:WaitForChild("WOB_Generated")
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")
local localPlayer = Players.LocalPlayer

local DEBUG_AIM_LASER = false
local playerTank = nil
local loggedOwnedTankId = nil

local localVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if localVisuals == nil then
	localVisuals = Instance.new("Folder")
	localVisuals.Name = "WOB_LocalVisuals"
	localVisuals.Parent = Workspace
end

local laserFolder = localVisuals:FindFirstChild("AimLaser")

if laserFolder == nil then
	laserFolder = Instance.new("Folder")
	laserFolder.Name = "AimLaser"
	laserFolder.Parent = localVisuals
else
	laserFolder:ClearAllChildren()
end

local boundaryWallNames = {
	Wall_North = true,
	Wall_South = true,
	Wall_East = true,
	Wall_West = true,
}

local function isObstacleName(name)
	return boundaryWallNames[name] == true
	or string.match(name, "^RicochetWall_") ~= nil
	or string.match(name, "^Cover_Block_") ~= nil
	or string.match(name, "^BoundaryWall_") ~= nil
end

local function collectLaserMapTargets()
	local targets = {}
	local seen = {}

	local function addTarget(instance)
		if instance ~= nil and seen[instance] ~= true then
			seen[instance] = true
			table.insert(targets, instance)
		end
	end

	local function collectObstacleRoot(searchRoot)
		if searchRoot == nil then
			return
		end

		for _, folderName in ipairs({ "RicochetWalls", "Cover", "Boundaries", "BoundaryWalls" }) do
			addTarget(searchRoot:FindFirstChild(folderName))
		end

		for _, descendant in ipairs(searchRoot:GetDescendants()) do
			if descendant:IsA("BasePart")
				and (isObstacleName(descendant.Name) or descendant:GetAttribute("WOBMovementObstacle") == true)
			then
				addTarget(descendant)
			end
		end
	end

	collectObstacleRoot(map)
	collectObstacleRoot(root:FindFirstChild("BattleArena"))

	for _, descendant in ipairs(testObjects:GetDescendants()) do
		if descendant:IsA("Model")
			and descendant:GetAttribute("IsActive") ~= false
		then
			local tankModel = TankModelResolver.resolvePhysicalModel(root, descendant) or descendant

			if tankModel ~= playerTank and seen[tankModel] ~= true then
				local hitboxes = tankModel:FindFirstChild("Hitboxes", true)

				if hitboxes ~= nil then
					addTarget(hitboxes)
				end
			end
		end
	end

	return targets
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.IgnoreWater = true

local function createAnchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.25, 0.25, 0.25)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = laserFolder

	return part
end

local startPart = createAnchorPart("WOBAimLaserStart")
local endPart = createAnchorPart("WOBAimLaserEnd")

local startAttachment = Instance.new("Attachment")
startAttachment.Name = "StartAttachment"
startAttachment.Parent = startPart

local endAttachment = Instance.new("Attachment")
endAttachment.Name = "EndAttachment"
endAttachment.Parent = endPart

local beam = Instance.new("Beam")
beam.Name = "WOBAimLaserBeam"
beam.Attachment0 = startAttachment
beam.Attachment1 = endAttachment
beam.Color = ColorSequence.new(AimAssistConfig.AimLaserColor)
beam.Transparency = NumberSequence.new(AimAssistConfig.AimLaserTransparency)
beam.Width0 = AimAssistConfig.AimLaserWidth
beam.Width1 = AimAssistConfig.AimLaserWidth
beam.FaceCamera = true
beam.LightEmission = 1
beam.LightInfluence = 0
beam.Enabled = false
beam.Parent = startPart

local shootPoint = nil
local barrel = nil

local function getLocalPlayerTank()
	return TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
end

local function refreshMuzzleParts()
	local assignedTank = getLocalPlayerTank()

	if playerTank ~= assignedTank then
		playerTank = assignedTank
		shootPoint = nil
		barrel = nil

		if playerTank ~= nil then
			local tankId = playerTank:GetAttribute("TankId") or playerTank.Name

			if DEBUG_AIM_LASER and loggedOwnedTankId ~= tankId then
				loggedOwnedTankId = tankId
				print("[PVP] local owned tank found: " .. tostring(tankId))
			end
		end
	end

	if playerTank == nil then
		return
	end

	if shootPoint == nil or shootPoint.Parent == nil then
		shootPoint = playerTank:FindFirstChild("ShootPoint", true)
	end

	if barrel == nil or barrel.Parent == nil then
		barrel = playerTank:FindFirstChild("Barrel", true)
	end
end

local function waitForMuzzlePart(timeoutSeconds)
	local startedAt = os.clock()

	while os.clock() - startedAt < timeoutSeconds do
		refreshMuzzleParts()

		if shootPoint ~= nil or barrel ~= nil then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function getMuzzlePart()
	refreshMuzzleParts()

	if shootPoint ~= nil and shootPoint.Parent ~= nil then
		return shootPoint
	end

	if barrel ~= nil and barrel.Parent ~= nil then
		return barrel
	end

	return nil
end

local function getFlatDirection(muzzlePart)
	local look = muzzlePart.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)

	if flatLook.Magnitude < 0.001 then
		return nil
	end

	return flatLook.Unit
end

local function setLaserVisible(isVisible)
	beam.Enabled = isVisible
end

local function isAimLaserEnabledForLocalPlayer()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode == "Lobby" or mode == "QueuedForDuel" or mode == "InMatch" or mode == "InBattleArena" then
		return true
	end

	return mode == nil and root:GetAttribute("GameState") == "Playing"
end

local function isPlayerTankAbleToAim()
	return playerTank ~= nil
		and playerTank.Parent ~= nil
		and playerTank:GetAttribute("IsDead") ~= true
		and playerTank:GetAttribute("IsControllable") ~= false
		and playerTank:GetAttribute("CanShoot") ~= false
end

local function updateLaser()
	if not isAimLaserEnabledForLocalPlayer() then
		setLaserVisible(false)
		return
	end

	local muzzlePart = getMuzzlePart()

	if muzzlePart == nil then
		setLaserVisible(false)
		return
	end

	if not isPlayerTankAbleToAim() then
		setLaserVisible(false)
		return
	end

	local direction = getFlatDirection(muzzlePart)

	if direction == nil then
		setLaserVisible(false)
		return
	end

	local heightOffset = AimAssistConfig.AimLaserHeightOffset or 0
	local origin = muzzlePart.Position + Vector3.new(0, heightOffset, 0)
	local rayOrigin = origin + direction * 1.2

	raycastParams.FilterDescendantsInstances = collectLaserMapTargets()

	local result = Workspace:Raycast(
		rayOrigin,
		direction * AimAssistConfig.AimLaserMaxDistance,
		raycastParams
	)

	local endPosition = rayOrigin + direction * AimAssistConfig.AimLaserMaxDistance

	if result ~= nil then
		endPosition = result.Position
	end

	if (endPosition - origin).Magnitude < 0.5 then
		setLaserVisible(false)
		return
	end

	startPart.Position = origin
	endPart.Position = endPosition

	setLaserVisible(true)
end

RunService.RenderStepped:Connect(updateLaser)
updateLaser()

print("[WOB] Aim laser started")
