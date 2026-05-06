local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local playerTank = testObjects:WaitForChild("PlayerTankPrototype")
local tankBody = playerTank:WaitForChild("Body")

local localVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if localVisuals == nil then
	localVisuals = Instance.new("Folder")
	localVisuals.Name = "WOB_LocalVisuals"
	localVisuals.Parent = Workspace
end

local indicatorFolder = localVisuals:FindFirstChild("TankDirectionIndicator")

if indicatorFolder == nil then
	indicatorFolder = Instance.new("Folder")
	indicatorFolder.Name = "TankDirectionIndicator"
	indicatorFolder.Parent = localVisuals
end

local INDICATOR_HEIGHT_ABOVE_BODY = 3.35
local SHAFT_SIZE = Vector3.new(1.2, 0.22, 5.8)
local TIP_SIZE = Vector3.new(4.3, 0.24, 1.8)
local SHAFT_COLOR = Color3.fromRGB(80, 235, 255)
local TIP_COLOR = Color3.fromRGB(255, 245, 120)

local function prepareVisualPart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.04
	part.Parent = indicatorFolder
end

local shaft = Instance.new("Part")
shaft.Name = "WOBTankDirectionShaft"
shaft.Size = SHAFT_SIZE
shaft.Color = SHAFT_COLOR
prepareVisualPart(shaft)

local tip = Instance.new("Part")
tip.Name = "WOBTankDirectionTip"
tip.Size = TIP_SIZE
tip.Color = TIP_COLOR
prepareVisualPart(tip)

local function updateIndicator()
	local bodySize = tankBody.Size
	local shaftOffset = -(bodySize.Z * 0.5 + SHAFT_SIZE.Z * 0.5 + 0.15)
	local tipOffset = -(bodySize.Z * 0.5 + SHAFT_SIZE.Z + TIP_SIZE.Z * 0.5 + 0.35)
	local heightOffset = Vector3.new(0, INDICATOR_HEIGHT_ABOVE_BODY, 0)

	shaft.CFrame = tankBody.CFrame * CFrame.new(heightOffset + Vector3.new(0, 0, shaftOffset))
	tip.CFrame = tankBody.CFrame * CFrame.new(heightOffset + Vector3.new(0, 0, tipOffset))
end

RunService.RenderStepped:Connect(updateIndicator)
updateIndicator()

print("[WOB] Tank direction indicator started")
