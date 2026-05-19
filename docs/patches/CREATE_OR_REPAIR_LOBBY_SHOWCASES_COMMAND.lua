-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Creates/repairs future lobby showcases without enabling purchases.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB SHOWCASES] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local LOBBY_NAME = "Lobby"

local changedCount = 0

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB SHOWCASES] %s is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	changedCount += 1
	print("[WOB SHOWCASES] Created " .. instance:GetFullName())

	return instance, true
end

local function getLobbySurfaceY(lobby)
	local surfaceY = lobby:GetAttribute("LobbySurfaceY")

	if typeof(surfaceY) == "number" then
		return surfaceY
	end

	local floor = lobby:FindFirstChild("Floor")

	if floor ~= nil and floor:IsA("BasePart") then
		return floor.Position.Y + floor.Size.Y * 0.5
	end

	return 46
end

local function configurePart(part, size, cframe, color, transparency, material, canCollide)
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("WOBMovementObstacle", nil)
	part:SetAttribute("WOBRicochetSurface", nil)
	changedCount += 1
end

local function ensureTextLabel(parent, name, position, size, text, textSize, color)
	local label = parent:FindFirstChild(name)

	if label == nil then
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
		changedCount += 1
	elseif not label:IsA("TextLabel") then
		warn("[WOB SHOWCASES] " .. label:GetFullName() .. " is " .. label.ClassName .. ", expected TextLabel.")
		return nil
	end

	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.BuilderSansBold
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.15
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2

	return label
end

local function ensureShowcaseLabel(model, adornee, title, subtitle)
	local billboard = model:FindFirstChild("Label")

	if billboard == nil then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Parent = model
		changedCount += 1
	elseif not billboard:IsA("BillboardGui") then
		warn("[WOB SHOWCASES] " .. billboard:GetFullName() .. " is " .. billboard.ClassName .. ", expected BillboardGui.")
		return
	end

	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.Size = UDim2.fromOffset(240, 96)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
	billboard.MaxDistance = 210

	local background = billboard:FindFirstChild("Background")

	if background == nil then
		background = Instance.new("Frame")
		background.Name = "Background"
		background.Parent = billboard
		changedCount += 1
	end

	if background:IsA("Frame") then
		background.Size = UDim2.fromScale(1, 1)
		background.BackgroundColor3 = Color3.fromRGB(8, 12, 16)
		background.BackgroundTransparency = 0.18
		background.BorderSizePixel = 0
		background.ZIndex = 1

		local corner = background:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = background
	end

	ensureTextLabel(billboard, "TitleText", UDim2.new(0.04, 0, 0.06, 0), UDim2.new(0.92, 0, 0.48, 0), title, 24, Color3.fromRGB(245, 255, 250))
	ensureTextLabel(billboard, "SubtitleText", UDim2.new(0.04, 0, 0.54, 0), UDim2.new(0.92, 0, 0.36, 0), subtitle, 18, Color3.fromRGB(135, 225, 255))
end

local function getModelPivotOrDefault(model, defaultCFrame, wasCreated)
	if wasCreated then
		return defaultCFrame
	end

	local hasBasePart = false

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			hasBasePart = true
			break
		end
	end

	if not hasBasePart then
		return defaultCFrame
	end

	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)

	if ok and typeof(pivot) == "CFrame" then
		return pivot
	end

	return defaultCFrame
end

local function repairShowcase(showcasesFolder, spec, surfaceY)
	local model, wasCreated = getOrCreate(showcasesFolder, "Model", spec.Name)

	if model == nil then
		return
	end

	local pivot = getModelPivotOrDefault(model, CFrame.new(spec.Position.X, surfaceY, spec.Position.Z), wasCreated)

	model:SetAttribute("WOBShowcase", true)
	model:SetAttribute("ShowcaseType", spec.ShowcaseType)
	model:SetAttribute("Locked", true)
	model:SetAttribute("ComingSoon", true)

	local base = getOrCreate(model, "Part", "Base")
	local platform = getOrCreate(model, "Part", "DisplayPlatform")
	local preview = getOrCreate(model, "Part", "PlaceholderPreview")

	if base ~= nil then
		configurePart(
			base,
			Vector3.new(22, 2, 16),
			pivot * CFrame.new(0, 1.0, 0),
			spec.BaseColor,
			0.08,
			Enum.Material.Metal,
			true
		)
	end

	if platform ~= nil then
		configurePart(
			platform,
			Vector3.new(15, 0.55, 10),
			pivot * CFrame.new(0, 2.45, 0),
			spec.PlatformColor,
			0.12,
			Enum.Material.Neon,
			false
		)
	end

	if preview ~= nil then
		configurePart(
			preview,
			spec.PreviewSize,
			pivot * CFrame.new(0, 4.2, 0),
			spec.PreviewColor,
			0.18,
			Enum.Material.SmoothPlastic,
			false
		)
	end

	ensureShowcaseLabel(model, platform or base, spec.Title, spec.Subtitle)

	print("[WOB SHOWCASES] Repaired " .. model:GetFullName() .. " at " .. tostring(pivot.Position))
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[WOB SHOWCASES] Workspace/" .. ROOT_NAME .. " was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local lobby = root:FindFirstChild(LOBBY_NAME)

if lobby == nil then
	warn("[WOB SHOWCASES] Workspace/" .. ROOT_NAME .. "/" .. LOBBY_NAME .. " was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local surfaceY = getLobbySurfaceY(lobby)
local showcasesFolder = getOrCreate(lobby, "Folder", "Showcases")

if showcasesFolder == nil then
	return
end

local specs = {
	{
		Name = "TankSkinsShowcase",
		ShowcaseType = "TankSkins",
		Title = "TANK SKINS",
		Subtitle = "COMING SOON",
		Position = Vector3.new(-92, surfaceY, 132),
		BaseColor = Color3.fromRGB(42, 76, 86),
		PlatformColor = Color3.fromRGB(110, 235, 185),
		PreviewColor = Color3.fromRGB(76, 154, 180),
		PreviewSize = Vector3.new(9, 3, 6),
	},
	{
		Name = "WeaponSkinsShowcase",
		ShowcaseType = "WeaponSkins",
		Title = "WEAPON SKINS",
		Subtitle = "COMING SOON",
		Position = Vector3.new(-92, surfaceY, 176),
		BaseColor = Color3.fromRGB(64, 58, 78),
		PlatformColor = Color3.fromRGB(255, 210, 90),
		PreviewColor = Color3.fromRGB(210, 170, 75),
		PreviewSize = Vector3.new(3, 3, 12),
	},
	{
		Name = "PremiumSkinsShowcase",
		ShowcaseType = "PremiumSkins",
		Title = "COMING SOON SKINS",
		Subtitle = "PREVIEW ONLY",
		Position = Vector3.new(92, surfaceY, 132),
		BaseColor = Color3.fromRGB(76, 52, 82),
		PlatformColor = Color3.fromRGB(190, 130, 255),
		PreviewColor = Color3.fromRGB(178, 118, 240),
		PreviewSize = Vector3.new(8, 4, 8),
	},
	{
		Name = "CrystalsInfoStand",
		ShowcaseType = "Crystals",
		Title = "CRYSTAL SHOP",
		Subtitle = "WIN DUELS TO EARN",
		Position = Vector3.new(92, surfaceY, 176),
		BaseColor = Color3.fromRGB(35, 72, 88),
		PlatformColor = Color3.fromRGB(90, 225, 255),
		PreviewColor = Color3.fromRGB(115, 225, 255),
		PreviewSize = Vector3.new(6, 6, 6),
	},
}

for _, spec in ipairs(specs) do
	repairShowcase(showcasesFolder, spec, surfaceY)
end

print("[WOB SHOWCASES] Complete. Changed/checked properties: " .. tostring(changedCount) .. ". No Robux/IAP/shop purchases were added. File -> Save to File.")
