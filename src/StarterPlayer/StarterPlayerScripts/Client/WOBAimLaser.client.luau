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
-- Walls don't move, so refresh the (heavy) target-list scan infrequently. Was 0.5s, which
-- walked the whole arena tree twice a second and contributed to client hitching.
local LASER_TARGET_REFRESH_INTERVAL = 3
local playerTank = nil
local loggedOwnedTankId = nil
local smoothedStartPosition = nil
local smoothedEndPosition = nil

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

local staleLocalVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if staleLocalVisuals ~= nil then
	staleLocalVisuals:Destroy()
end

local wobRuntime = Workspace:FindFirstChild("WOB_Runtime") or Workspace:WaitForChild("WOB_Runtime", 10)

if wobRuntime == nil then
	wobRuntime = getOrCreateFolder(Workspace, "WOB_Runtime")
end

local clientRuntime = wobRuntime ~= nil and getOrCreateFolder(wobRuntime, "Client") or nil
local localVisuals = clientRuntime ~= nil and getOrCreateFolder(clientRuntime, "Visuals") or nil

if localVisuals == nil then
	warn("[WOB] Aim laser disabled: Workspace.WOB_Runtime.Client.Visuals could not be created")
	return
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

local cachedLaserTargets = {}
local nextLaserTargetRefreshAt = 0

local function getLaserMapTargets()
	local now = os.clock()

	if now >= nextLaserTargetRefreshAt then
		cachedLaserTargets = collectLaserMapTargets()
		nextLaserTargetRefreshAt = now + LASER_TARGET_REFRESH_INTERVAL
	end

	return cachedLaserTargets
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

-- Ricochet aim preview: the laser is drawn as several beam SEGMENTS that bounce off walls,
-- so the player can see where a bounced shot will go. One segment per bounce + the final
-- one. Segment count = max ricochets + 1 (extra ricochet upgrades just refresh the cap).
local MAX_RICOCHET_SEGMENTS = math.max(1, (tonumber(AimAssistConfig.AimLaserMaxBounces)
	or tonumber(AimAssistConfig.AimLaserBounces)
	or 3) + 1)

local segments = {}

local function createSegment()
	local p0 = createAnchorPart("WOBAimLaserA")
	local p1 = createAnchorPart("WOBAimLaserB")
	local a0 = Instance.new("Attachment")
	a0.Parent = p0
	local a1 = Instance.new("Attachment")
	a1.Parent = p1
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(AimAssistConfig.AimLaserColor)
	beam.Transparency = NumberSequence.new(AimAssistConfig.AimLaserTransparency)
	beam.Width0 = AimAssistConfig.AimLaserWidth
	beam.Width1 = AimAssistConfig.AimLaserWidth
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Enabled = false
	beam.Parent = p0
	return { P0 = p0, P1 = p1, Beam = beam }
end

for _ = 1, MAX_RICOCHET_SEGMENTS do
	table.insert(segments, createSegment())
end

local function hideAllSegments()
	for _, seg in ipairs(segments) do
		seg.Beam.Enabled = false
	end
end

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
		nextLaserTargetRefreshAt = 0

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

local function hideLaser()
	smoothedStartPosition = nil
	smoothedEndPosition = nil
	hideAllSegments()
end

local function getVisualSmoothingAlpha(deltaTime)
	if AimAssistConfig.AimLaserVisualSmoothingEnabled ~= true then
		return 1
	end

	local speed = math.max(0, tonumber(AimAssistConfig.AimLaserVisualSmoothingSpeed) or 30)

	if speed <= 0 then
		return 1
	end

	return 1 - math.exp(-speed * math.max(0, tonumber(deltaTime) or 0))
end

local function smoothLaserPoint(previousPosition, targetPosition, deltaTime)
	if typeof(previousPosition) ~= "Vector3" then
		return targetPosition
	end

	local snapDistance = math.max(0, tonumber(AimAssistConfig.AimLaserVisualSnapDistance) or 120)

	if snapDistance > 0 and (previousPosition - targetPosition).Magnitude > snapDistance then
		return targetPosition
	end

	return previousPosition:Lerp(targetPosition, getVisualSmoothingAlpha(deltaTime))
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

local function updateLaser(deltaTime)
	if not isAimLaserEnabledForLocalPlayer() then
		hideLaser()
		return
	end

	local muzzlePart = getMuzzlePart()

	if muzzlePart == nil then
		hideLaser()
		return
	end

	if not isPlayerTankAbleToAim() then
		hideLaser()
		return
	end

	local direction = getFlatDirection(muzzlePart)

	if direction == nil then
		hideLaser()
		return
	end

	local heightOffset = AimAssistConfig.AimLaserHeightOffset or 0
	local origin = muzzlePart.Position + Vector3.new(0, heightOffset, 0)

	raycastParams.FilterDescendantsInstances = getLaserMapTargets()

	-- Trace the shot, reflecting off walls, drawing one beam segment per leg. Total length
	-- across all legs is capped at AimLaserMaxDistance so a long bounce chain can't run forever.
	local maxTotal = AimAssistConfig.AimLaserMaxDistance
	local remaining = maxTotal
	local segOrigin = origin + direction * 1.2
	local segDir = direction
	local usedSegments = 0
	local drewAnything = false

	for i = 1, MAX_RICOCHET_SEGMENTS do
		if remaining <= 1 then
			break
		end

		local result = Workspace:Raycast(segOrigin, segDir * remaining, raycastParams)
		local segEnd
		local hitWall = false

		if result ~= nil then
			segEnd = result.Position
			-- Reflect only off walls/obstacles, not off tank hitboxes (those end the trace).
			local inst = result.Instance
			local isTank = inst ~= nil and inst:FindFirstAncestor("Hitboxes") ~= nil
			hitWall = not isTank
				and (inst:GetAttribute("WOBMovementObstacle") == true or isObstacleName(inst.Name))
		else
			segEnd = segOrigin + segDir * remaining
		end

		local segVec = segEnd - segOrigin
		if segVec.Magnitude < 0.3 then
			break
		end

		local seg = segments[i]
		-- Smooth each endpoint toward its target for a calmer, less jittery laser.
		local alpha = getVisualSmoothingAlpha(deltaTime)
		seg.P0.Position = smoothLaserPoint(seg.P0.Position, segOrigin, deltaTime) or segOrigin
		seg.P1.Position = smoothLaserPoint(seg.P1.Position, segEnd, deltaTime) or segEnd
		local _ = alpha
		seg.Beam.Enabled = true
		usedSegments = i
		drewAnything = true

		remaining -= segVec.Magnitude

		if not hitWall then
			break -- hit a tank or reached max range: stop here
		end

		-- Reflect the direction off the wall normal and continue from just past the hit.
		local n = result.Normal
		local reflected = segDir - 2 * segDir:Dot(n) * n
		local flat = Vector3.new(reflected.X, 0, reflected.Z)
		if flat.Magnitude < 0.001 then
			break
		end
		segDir = flat.Unit
		segOrigin = segEnd + segDir * 0.2
	end

	-- Hide unused segments from the pool.
	for i = usedSegments + 1, MAX_RICOCHET_SEGMENTS do
		segments[i].Beam.Enabled = false
	end

	if not drewAnything then
		hideLaser()
	end
end

RunService.RenderStepped:Connect(updateLaser)
updateLaser()
