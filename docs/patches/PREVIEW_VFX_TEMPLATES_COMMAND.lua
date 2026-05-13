-- Run in Studio Command Bar outside Play Mode.
-- Previews templates from ReplicatedStorage/Shared/Assets/VFX in Workspace/WOB_Generated/VFXPreview.

local PREVIEW_PLAY_SOUNDS = true
local PREVIEW_SPACING = 12
local PREVIEW_CLEAN_OLD = true
local PREVIEW_EMIT_COUNT = 12
local PREVIEW_AUTO_CLEANUP_SECONDS = 0

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB VFX PREVIEW] Run this command outside Play Mode.")
	return
end

local POINT_ORDER = {
	"MuzzleFlashPreview",
	"SmokePreview",
	"ImpactPreview",
	"RicochetPreview",
	"ExplosionPreview",
	"BurningPreview",
}

local TEMPLATE_POINT_OVERRIDES = {
	MuzzleFlashTemplate = "MuzzleFlashPreview",
	MuzzleBlastTemplate = "MuzzleFlashPreview",
	SmokeTemplate = "SmokePreview",
	ImpactFlashTemplate = "ImpactPreview",
	ImpactSparksTemplate = "ImpactPreview",
	RicochetTemplate = "RicochetPreview",
	TankExplosionTemplate = "ExplosionPreview",
	TankBurningTemplate = "BurningPreview",
}

local POINT_COLORS = {
	MuzzleFlashPreview = Color3.fromRGB(255, 198, 74),
	SmokePreview = Color3.fromRGB(110, 118, 120),
	ImpactPreview = Color3.fromRGB(255, 128, 66),
	RicochetPreview = Color3.fromRGB(255, 232, 116),
	ExplosionPreview = Color3.fromRGB(255, 78, 44),
	BurningPreview = Color3.fromRGB(255, 130, 36),
}

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local root = getOrCreateFolder(Workspace, "WOB_Generated")
local previewFolder = root:FindFirstChild("VFXPreview")

if previewFolder ~= nil and PREVIEW_CLEAN_OLD then
	previewFolder:Destroy()
	previewFolder = nil
end

previewFolder = previewFolder or getOrCreateFolder(root, "VFXPreview")

local shared = ReplicatedStorage:FindFirstChild("Shared")
local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil
local vfxFolder = assets ~= nil and assets:FindFirstChild("VFX") or nil

if vfxFolder == nil then
	warn("[WOB VFX PREVIEW] ReplicatedStorage/Shared/Assets/VFX not found.")
	return
end

local function sanitizeInstance(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.CastShadow = false
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function createPreviewPoint(pointName, index)
	local holder = Instance.new("Part")
	holder.Name = pointName
	holder.Size = Vector3.new(1.25, 0.25, 1.25)
	holder.Position = Vector3.new((index - 1) * PREVIEW_SPACING, 2, 0)
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Material = Enum.Material.Neon
	holder.Color = POINT_COLORS[pointName] or Color3.fromRGB(255, 255, 255)
	holder.Parent = previewFolder

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(220, 44)
	label.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	label.AlwaysOnTop = true
	label.Parent = holder

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamSemibold
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.Text = pointName
	text.Parent = label

	return holder
end

local previewPoints = {}

for index, pointName in ipairs(POINT_ORDER) do
	previewPoints[pointName] = createPreviewPoint(pointName, index)
end

local function collectBaseParts(instance)
	local parts = {}

	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function pivotLooseContainer(instance, cframe)
	local parts = collectBaseParts(instance)
	local firstPart = parts[1]

	if firstPart == nil then
		return false
	end

	local delta = cframe * firstPart.CFrame:Inverse()

	for _, part in ipairs(parts) do
		part.CFrame = delta * part.CFrame
	end

	return true
end

local function attachCloneToPoint(template, pointPart)
	local clone = template:Clone()
	clone.Name = template.Name .. "_Preview"
	sanitizeInstance(clone)

	local cframe = pointPart.CFrame * CFrame.new(0, 1.5, 0)

	if clone:IsA("ParticleEmitter") then
		local attachment = Instance.new("Attachment")
		attachment.Name = clone.Name .. "_Attachment"
		attachment.Parent = pointPart
		clone.Parent = attachment
		return attachment
	end

	if clone:IsA("Attachment") then
		clone.Parent = pointPart
		return clone
	end

	if clone:IsA("Sound")
		or clone:IsA("PointLight")
		or clone:IsA("SpotLight")
		or clone:IsA("SurfaceLight")
	then
		clone.Parent = pointPart
		return clone
	end

	clone.Parent = previewFolder

	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	elseif not pivotLooseContainer(clone, cframe) then
		local attachment = Instance.new("Attachment")
		attachment.Name = clone.Name .. "_Attachment"
		attachment.Parent = pointPart
		clone.Parent = attachment
	end

	return clone
end

local function emitParticles(instance)
	local emitters = 0

	if instance:IsA("ParticleEmitter") then
		instance:Emit(PREVIEW_EMIT_COUNT)
		emitters += 1
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")
			descendant:Emit(typeof(emitCount) == "number" and emitCount or PREVIEW_EMIT_COUNT)
			emitters += 1
		end
	end

	return emitters
end

local function playSounds(instance)
	local sounds = 0

	if instance:IsA("Sound") then
		sounds += 1

		if PREVIEW_PLAY_SOUNDS then
			instance:Play()
		end
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Sound") then
			sounds += 1

			if PREVIEW_PLAY_SOUNDS then
				descendant:Play()
			end
		end
	end

	return sounds
end

local function inferPointName(templateName, fallbackIndex)
	local override = TEMPLATE_POINT_OVERRIDES[templateName]

	if override ~= nil then
		return override
	end

	local lowerName = string.lower(templateName)

	if string.find(lowerName, "burn") or string.find(lowerName, "fire") then
		return "BurningPreview"
	elseif string.find(lowerName, "explosion") or string.find(lowerName, "explode") then
		return "ExplosionPreview"
	elseif string.find(lowerName, "ricochet") or string.find(lowerName, "bounce") then
		return "RicochetPreview"
	elseif string.find(lowerName, "impact") or string.find(lowerName, "spark") or string.find(lowerName, "hit") then
		return "ImpactPreview"
	elseif string.find(lowerName, "smoke") then
		return "SmokePreview"
	elseif string.find(lowerName, "muzzle") or string.find(lowerName, "shot") then
		return "MuzzleFlashPreview"
	end

	return POINT_ORDER[((fallbackIndex - 1) % #POINT_ORDER) + 1]
end

local templates = {}

for _, child in ipairs(vfxFolder:GetChildren()) do
	if not child:IsA("ModuleScript") then
		table.insert(templates, child)
	end
end

table.sort(templates, function(left, right)
	return left.Name < right.Name
end)

if #templates == 0 then
	warn("[WOB VFX PREVIEW] No VFX templates found under ReplicatedStorage/Shared/Assets/VFX.")
	return
end

for index, template in ipairs(templates) do
	local pointName = inferPointName(template.Name, index)
	local point = previewPoints[pointName]

	if point ~= nil then
		local clone = attachCloneToPoint(template, point)
		local emitterCount = emitParticles(clone)
		local soundCount = playSounds(clone)

		if PREVIEW_AUTO_CLEANUP_SECONDS > 0 then
			Debris:AddItem(clone, PREVIEW_AUTO_CLEANUP_SECONDS)
		end

		print(
			"[WOB VFX PREVIEW] Previewed "
				.. template.Name
				.. " emitters="
				.. tostring(emitterCount)
				.. " sounds="
				.. tostring(soundCount)
		)
	end
end
