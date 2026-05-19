-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It creates a visual DuelPad frame and status BillboardGui.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB DUELPAD] Run this command outside Play Mode.")
	return
end

local FRAME_THICKNESS = 2.2
local FRAME_HEIGHT = 0.45
local FRAME_Y_OFFSET = 0.35
local CORNER_SIZE = Vector3.new(3.4, 0.7, 3.4)

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB DUELPAD] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	print("[WOB DUELPAD] Created " .. instance:GetFullName())
	return instance, true
end

local function configureVisualPart(part, size, cframe, color)
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.08
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local root = Workspace:FindFirstChild("WOB_Generated")

if root == nil then
	warn("[WOB DUELPAD] Workspace/WOB_Generated was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local lobby = root:FindFirstChild("Lobby")

if lobby == nil then
	warn("[WOB DUELPAD] Workspace/WOB_Generated/Lobby was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local duelPad = lobby:FindFirstChild("DuelPad")

if duelPad == nil or not duelPad:IsA("BasePart") then
	warn("[WOB DUELPAD] Lobby/DuelPad was not found or is not a BasePart.")
	return
end

duelPad.Anchored = true
duelPad.CanCollide = false
duelPad.CanTouch = true
duelPad.CanQuery = false
duelPad.CastShadow = false
duelPad.Transparency = math.max(duelPad.Transparency, 0.82)
duelPad:SetAttribute("DuelQueueCount", duelPad:GetAttribute("DuelQueueCount") or 0)
duelPad:SetAttribute("DuelQueueRequired", duelPad:GetAttribute("DuelQueueRequired") or 2)
duelPad:SetAttribute("DuelCountdown", duelPad:GetAttribute("DuelCountdown") or 0)
duelPad:SetAttribute("DuelState", duelPad:GetAttribute("DuelState") or "Idle")
duelPad:SetAttribute("WOBPadType", "Duel")
duelPad:SetAttribute("RequiredPlayers", 2)
duelPad:SetAttribute("WOBPadEnabled", true)

local visuals = getOrCreate(lobby, "Folder", "DuelPadVisuals")

if visuals == nil then
	return
end

local size = duelPad.Size
local halfX = size.X * 0.5
local halfZ = size.Z * 0.5
local yOffset = size.Y * 0.5 + FRAME_Y_OFFSET
local frameColor = Color3.fromRGB(90, 230, 255)
local cornerColor = Color3.fromRGB(255, 225, 95)

local frameSpecs = {
	{
		Name = "Frame_North",
		Size = Vector3.new(size.X + FRAME_THICKNESS * 2, FRAME_HEIGHT, FRAME_THICKNESS),
		CFrame = duelPad.CFrame * CFrame.new(0, yOffset, -halfZ - FRAME_THICKNESS * 0.5),
	},
	{
		Name = "Frame_South",
		Size = Vector3.new(size.X + FRAME_THICKNESS * 2, FRAME_HEIGHT, FRAME_THICKNESS),
		CFrame = duelPad.CFrame * CFrame.new(0, yOffset, halfZ + FRAME_THICKNESS * 0.5),
	},
	{
		Name = "Frame_East",
		Size = Vector3.new(FRAME_THICKNESS, FRAME_HEIGHT, size.Z + FRAME_THICKNESS * 2),
		CFrame = duelPad.CFrame * CFrame.new(halfX + FRAME_THICKNESS * 0.5, yOffset, 0),
	},
	{
		Name = "Frame_West",
		Size = Vector3.new(FRAME_THICKNESS, FRAME_HEIGHT, size.Z + FRAME_THICKNESS * 2),
		CFrame = duelPad.CFrame * CFrame.new(-halfX - FRAME_THICKNESS * 0.5, yOffset, 0),
	},
}

for _, spec in ipairs(frameSpecs) do
	local part = getOrCreate(visuals, "Part", spec.Name)

	if part ~= nil then
		configureVisualPart(part, spec.Size, spec.CFrame, frameColor)
		print("[WOB DUELPAD] Repaired " .. part:GetFullName())
	end
end

local cornerOffsets = {
	{ Name = "Corner_NW", Offset = Vector3.new(-halfX - FRAME_THICKNESS * 0.5, yOffset + 0.08, -halfZ - FRAME_THICKNESS * 0.5) },
	{ Name = "Corner_NE", Offset = Vector3.new(halfX + FRAME_THICKNESS * 0.5, yOffset + 0.08, -halfZ - FRAME_THICKNESS * 0.5) },
	{ Name = "Corner_SW", Offset = Vector3.new(-halfX - FRAME_THICKNESS * 0.5, yOffset + 0.08, halfZ + FRAME_THICKNESS * 0.5) },
	{ Name = "Corner_SE", Offset = Vector3.new(halfX + FRAME_THICKNESS * 0.5, yOffset + 0.08, halfZ + FRAME_THICKNESS * 0.5) },
}

for _, spec in ipairs(cornerOffsets) do
	local corner = getOrCreate(visuals, "Part", spec.Name)

	if corner ~= nil then
		configureVisualPart(corner, CORNER_SIZE, duelPad.CFrame * CFrame.new(spec.Offset), cornerColor)
		corner.Transparency = 0
	end
end

local billboard = duelPad:FindFirstChild("DuelPadStatusBillboard")

if billboard == nil then
	billboard = Instance.new("BillboardGui")
	billboard.Name = "DuelPadStatusBillboard"
	billboard.Parent = duelPad
	print("[WOB DUELPAD] Created " .. billboard:GetFullName())
elseif not billboard:IsA("BillboardGui") then
	warn("[WOB DUELPAD] DuelPadStatusBillboard exists but is " .. billboard.ClassName .. ", expected BillboardGui.")
	return
end

billboard.Adornee = duelPad
billboard.AlwaysOnTop = true
billboard.Size = UDim2.fromOffset(240, 84)
billboard.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
billboard.MaxDistance = 260
billboard.Enabled = true

local label = billboard:FindFirstChild("StatusText")

if label == nil then
	label = Instance.new("TextLabel")
	label.Name = "StatusText"
	label.Parent = billboard
	print("[WOB DUELPAD] Created " .. label:GetFullName())
elseif not label:IsA("TextLabel") then
	warn("[WOB DUELPAD] StatusText exists but is " .. label.ClassName .. ", expected TextLabel.")
	return
end

label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Font = Enum.Font.BuilderSansBold
label.Text = "0/2"
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(245, 255, 255)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.18
label.TextWrapped = true

print("[WOB DUELPAD] DuelPad visual frame and status BillboardGui ready. File -> Save to File.")
