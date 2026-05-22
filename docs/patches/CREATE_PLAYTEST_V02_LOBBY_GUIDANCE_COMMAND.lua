-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode after making a scene backup. It adds compact playtest guidance only.

local ENABLE_MUTATION = false
if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] Set ENABLE_MUTATION=true manually after backup to create lobby guidance.")
	return
end

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[PLAYTEST V0.2 GUIDANCE] Run outside Play Mode.")
	return
end

local root = Workspace:FindFirstChild("WOB_Generated")
local lobby = root ~= nil and root:FindFirstChild("Lobby") or nil

if lobby == nil then
	warn("[PLAYTEST V0.2 GUIDANCE] Workspace.WOB_Generated.Lobby was not found.")
	return
end

local function getLobbySurfaceY()
	local configuredY = lobby:GetAttribute("LobbySurfaceY")

	if typeof(configuredY) == "number" then
		return configuredY
	end

	local floor = lobby:FindFirstChild("Floor")

	if floor ~= nil and floor:IsA("BasePart") then
		return floor.Position.Y + floor.Size.Y * 0.5
	end

	return 46
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		warn("[PLAYTEST V0.2 GUIDANCE] " .. folder:GetFullName() .. " is not a Folder.")
		return nil
	end

	return folder
end

local function getOrCreatePart(parent, name)
	local part = parent:FindFirstChild(name)

	if part == nil then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	elseif not part:IsA("BasePart") then
		warn("[PLAYTEST V0.2 GUIDANCE] " .. part:GetFullName() .. " is not a BasePart.")
		return nil
	end

	return part
end

local function ensureLabel(part, title, subtitle, color)
	local billboard = part:FindFirstChild("Label")

	if billboard == nil then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Parent = part
	elseif not billboard:IsA("BillboardGui") then
		warn("[PLAYTEST V0.2 GUIDANCE] " .. billboard:GetFullName() .. " is not a BillboardGui.")
		return
	end

	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.Size = UDim2.fromOffset(280, 92)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	billboard.MaxDistance = 220

	local background = billboard:FindFirstChild("Background") or Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(8, 11, 14)
	background.BackgroundTransparency = 0.16
	background.BorderSizePixel = 0
	background.Parent = billboard

	local corner = background:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = background

	local titleLabel = billboard:FindFirstChild("Title") or Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.new(0.05, 0, 0.06, 0)
	titleLabel.Size = UDim2.new(0.9, 0, 0.4, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.BorderSizePixel = 0
	titleLabel.Font = Enum.Font.BuilderSansBold
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextStrokeTransparency = 0.15
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.ZIndex = 2
	titleLabel.Parent = billboard

	local subtitleLabel = billboard:FindFirstChild("Subtitle") or Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
	subtitleLabel.Size = UDim2.new(0.9, 0, 0.42, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.BorderSizePixel = 0
	subtitleLabel.Font = Enum.Font.BuilderSansMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(248, 255, 250)
	subtitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.TextScaled = true
	subtitleLabel.TextWrapped = true
	subtitleLabel.ZIndex = 2
	subtitleLabel.Parent = billboard
end

local function ensureSign(parent, name, position, title, subtitle, color)
	local part = getOrCreatePart(parent, name)

	if part == nil then
		return
	end

	part.Size = Vector3.new(18, 1, 3)
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.22
	part:SetAttribute("WOBPlaytestV02Guidance", true)
	ensureLabel(part, title, subtitle, color)
end

local guidanceFolder = getOrCreateFolder(lobby, "PlaytestV02Guidance")

if guidanceFolder == nil then
	return
end

local surfaceY = getLobbySurfaceY()

ensureSign(
	guidanceFolder,
	"DuelGuidance",
	Vector3.new(-42, surfaceY + 2.4, 74),
	"DUEL",
	"1v1 Ricochet Duel",
	Color3.fromRGB(135, 225, 255)
)
ensureSign(
	guidanceFolder,
	"ArenaGuidance",
	Vector3.new(42, surfaceY + 2.4, 74),
	"ARENA",
	"Fight bots, earn bolts",
	Color3.fromRGB(255, 220, 90)
)
ensureSign(
	guidanceFolder,
	"ArmorGuidance",
	Vector3.new(0, surfaceY + 2.4, 118),
	"ARMOR",
	"Angle your tank to bounce shots",
	Color3.fromRGB(75, 240, 180)
)
ensureSign(
	guidanceFolder,
	"LobbyGuidance",
	Vector3.new(0, surfaceY + 2.4, 40),
	"LOBBY",
	"Drive into a pad to play",
	Color3.fromRGB(248, 255, 250)
)

print("[PLAYTEST V0.2 GUIDANCE] Guidance signs created/updated. Review positions before saving.")
