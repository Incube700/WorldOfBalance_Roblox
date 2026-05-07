local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local AimAssistConfig = require(configs:WaitForChild("AimAssistConfig"))

if AimAssistConfig.AimLaserEnabled ~= true then
	return
end

local root = Workspace:WaitForChild("WOB_Generated")
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")
local playerTank = testObjects:WaitForChild("PlayerTankPrototype")
local dummyTank = testObjects:WaitForChild("DummyTank")
local dummyHitboxes = dummyTank:WaitForChild("Hitboxes")
local shootPoint = playerTank:FindFirstChild("ShootPoint")
local barrel = playerTank:FindFirstChild("Barrel")

if shootPoint == nil and barrel == nil then
	warn("[WOB] Aim laser disabled: PlayerTankPrototype ShootPoint/Barrel not found")
	return
end

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

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.IgnoreWater = true

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
end

local function collectLaserMapTargets()
	local targets = {}
	local ricochetWalls = map:FindFirstChild("RicochetWalls")
	local cover = map:FindFirstChild("Cover")

	if ricochetWalls ~= nil then
		table.insert(targets, ricochetWalls)
	end

	if cover ~= nil then
		table.insert(targets, cover)
	end

	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart") and isObstacleName(descendant.Name) then
			table.insert(targets, descendant)
		end
	end

	return targets
end

local laserMapTargets = collectLaserMapTargets()

local function setVisualPhysics(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = AimAssistConfig.AimLaserColor
	part.Parent = laserFolder
end

local laserGlow = Instance.new("Part")
laserGlow.Name = "WOBAimLaserGlow"
setVisualPhysics(laserGlow)
laserGlow.Transparency = math.clamp(AimAssistConfig.AimLaserTransparency + 0.34, 0, 1)

local laserCore = Instance.new("Part")
laserCore.Name = "WOBAimLaserCore"
setVisualPhysics(laserCore)
laserCore.Transparency = AimAssistConfig.AimLaserTransparency

local function getMuzzlePart()
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
	if isVisible then
		laserGlow.Transparency = math.clamp(AimAssistConfig.AimLaserTransparency + 0.34, 0, 1)
		laserCore.Transparency = AimAssistConfig.AimLaserTransparency
	else
		laserGlow.Transparency = 1
		laserCore.Transparency = 1
	end
end

local function getRaycastTargets()
	local targets = table.clone(laserMapTargets)

	table.insert(targets, dummyHitboxes)

	return targets
end

local function updateLaser()
	local muzzlePart = getMuzzlePart()

	if muzzlePart == nil then
		setLaserVisible(false)
		return
	end

	local direction = getFlatDirection(muzzlePart)

	if direction == nil then
		setLaserVisible(false)
		return
	end

	local origin = muzzlePart.Position + Vector3.new(0, AimAssistConfig.AimLaserHeightOffset or 0, 0)
	local rayOrigin = origin + direction * 1.2
	raycastParams.FilterDescendantsInstances = getRaycastTargets()

	local result = Workspace:Raycast(
		rayOrigin,
		direction * AimAssistConfig.AimLaserMaxDistance,
		raycastParams
	)
	local endPosition = rayOrigin + direction * AimAssistConfig.AimLaserMaxDistance

	if result ~= nil then
		endPosition = result.Position
	end

	local length = (endPosition - origin).Magnitude

	if length < 0.5 then
		setLaserVisible(false)
		return
	end

	local midpoint = origin + direction * (length * 0.5)
	local beamCFrame = CFrame.lookAt(midpoint, midpoint + direction, Vector3.yAxis)
	local width = AimAssistConfig.AimLaserWidth

	laserGlow.Size = Vector3.new(width * 2.4, 0.08, length)
	laserGlow.CFrame = beamCFrame

	laserCore.Size = Vector3.new(width, 0.1, length)
	laserCore.CFrame = beamCFrame

	setLaserVisible(true)
end

RunService.RenderStepped:Connect(updateLaser)
updateLaser()

print("[WOB] Aim laser started")
