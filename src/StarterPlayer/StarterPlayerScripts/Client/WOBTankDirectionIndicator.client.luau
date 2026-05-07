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
else
	indicatorFolder:ClearAllChildren()
end

local GROUND_Y = 0.14
local TOP_Y = 0.22
local SHAFT_SIZE = Vector3.new(0.9, 0.08, 3.7)
local HEAD_SIZE = Vector3.new(0.9, 0.08, 2.9)
local OUTLINE_GROW = Vector3.new(0.42, 0.02, 0.42)
local GREEN = Color3.fromRGB(80, 255, 105)
local GREEN_CORE = Color3.fromRGB(180, 255, 175)
local OUTLINE_GREEN = Color3.fromRGB(12, 80, 34)
local HEAD_ANGLE = math.rad(36)

local arrowPieces = {}

local function prepareVisualPart(part, color, transparency, material)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Parent = indicatorFolder
end

local function createPiece(name, size, color, transparency, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	prepareVisualPart(part, color, transparency, material)

	return part
end

local function addArrowStroke(name, size, localOffset, yawOffset, color)
	local outline = createPiece(
		name .. "Outline",
		size + OUTLINE_GROW,
		OUTLINE_GREEN,
		0.28,
		Enum.Material.SmoothPlastic
	)
	local top = createPiece(name, size, color, 0.02, Enum.Material.Neon)

	table.insert(arrowPieces, {
		Outline = outline,
		Top = top,
		LocalOffset = localOffset,
		YawOffset = yawOffset,
	})
end

addArrowStroke("DirectionShaft", SHAFT_SIZE, Vector3.new(0, 0, -8.2), 0, GREEN)
addArrowStroke("DirectionHeadLeft", HEAD_SIZE, Vector3.new(-1.05, 0, -10.4), -HEAD_ANGLE, GREEN)
addArrowStroke("DirectionHeadRight", HEAD_SIZE, Vector3.new(1.05, 0, -10.4), HEAD_ANGLE, GREEN)
addArrowStroke("DirectionTipCore", Vector3.new(0.7, 0.09, 1.35), Vector3.new(0, 0, -11.45), 0, GREEN_CORE)

local function getFlatBodyCFrame(height)
	local position = tankBody.Position
	local flatPosition = Vector3.new(position.X, height, position.Z)
	local forward = Vector3.new(tankBody.CFrame.LookVector.X, 0, tankBody.CFrame.LookVector.Z)

	if forward.Magnitude < 0.001 then
		forward = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(flatPosition, flatPosition + forward.Unit, Vector3.yAxis)
end

local function updateIndicator()
	local outlineFrame = getFlatBodyCFrame(GROUND_Y)
	local topFrame = getFlatBodyCFrame(TOP_Y)

	for _, piece in ipairs(arrowPieces) do
		local rotation = CFrame.Angles(0, piece.YawOffset, 0)
		piece.Outline.CFrame = outlineFrame * CFrame.new(piece.LocalOffset) * rotation
		piece.Top.CFrame = topFrame * CFrame.new(piece.LocalOffset) * rotation
	end
end

RunService.RenderStepped:Connect(updateIndicator)
updateIndicator()

print("[WOB] Tank direction indicator started")
