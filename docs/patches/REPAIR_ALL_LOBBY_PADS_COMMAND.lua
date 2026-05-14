-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Repairs lobby pad roots, triggers, visuals, and labels.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[PAD REPAIR] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local LOBBY_NAME = "Lobby"
local DEBUG_TRIGGER_TRANSPARENCY = 1
local TRIGGER_HEIGHT = 6
local DEFAULT_PAD_Y_OFFSET = 3
local FAR_DISTANCE = 4

local PAD_SPECS = {
	ArenaPad = {
		PadType = "BattleArena",
		RequiredPlayers = 1,
		Title = "BATTLE ARENA",
		Subtitle = "Drive here",
		MinSize = Vector3.new(48, TRIGGER_HEIGHT, 34),
		DefaultCFrame = CFrame.new(64, 46.14, 92),
		Color = Color3.fromRGB(96, 235, 165),
	},
	DuelPad = {
		PadType = "Duel",
		RequiredPlayers = 2,
		Title = "DUEL",
		Subtitle = "0/2",
		MinSize = Vector3.new(48, TRIGGER_HEIGHT, 34),
		DefaultCFrame = CFrame.new(0, 46.14, 92),
		Color = Color3.fromRGB(255, 210, 70),
	},
	TrainingPad = {
		PadType = "Training",
		RequiredPlayers = 1,
		Title = "TRAINING",
		Subtitle = "Drive here",
		MinSize = Vector3.new(40, TRIGGER_HEIGHT, 30),
		DefaultCFrame = CFrame.new(-64, 46.14, 92),
		Color = Color3.fromRGB(105, 180, 255),
	},
	StartPad = {
		PadType = "Training",
		RequiredPlayers = 1,
		Title = "TRAINING",
		Subtitle = "Drive here",
		MinSize = Vector3.new(40, TRIGGER_HEIGHT, 30),
		DefaultCFrame = CFrame.new(-64, 46.14, 92),
		Color = Color3.fromRGB(105, 180, 255),
	},
}

local PAD_TYPE_DEFAULTS = {
	BattleArena = PAD_SPECS.ArenaPad,
	Duel = PAD_SPECS.DuelPad,
	Training = PAD_SPECS.TrainingPad,
}

local changedCount = 0

local function configureVisualPart(part, color)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = math.clamp(part.Transparency, 0.08, 0.38)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	changedCount += 1
end

local function isPadTrigger(instance)
	return instance:IsA("BasePart")
		and (instance.Name == "Trigger" or instance:GetAttribute("WOBPadTrigger") == true)
end

local function getTopLobbyChild(lobby, instance)
	local current = instance
	local last = instance

	while current ~= nil and current ~= lobby do
		last = current
		current = current.Parent
	end

	if current == lobby then
		return last
	end

	return nil
end

local function addPadRoot(pads, root)
	if root == nil or root.Parent == nil then
		return
	end

	pads[root] = true
end

local function collectPadRoots(lobby)
	local pads = {}

	for padName, _ in pairs(PAD_SPECS) do
		addPadRoot(pads, lobby:FindFirstChild(padName))
	end

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:GetAttribute("WOBPadType") ~= nil then
			addPadRoot(pads, getTopLobbyChild(lobby, descendant))
		end
	end

	return pads
end

local function getPadSpec(padRoot)
	local namedSpec = PAD_SPECS[padRoot.Name]

	if namedSpec ~= nil then
		return namedSpec
	end

	local padType = padRoot:GetAttribute("WOBPadType")

	if typeof(padType) == "string" and PAD_TYPE_DEFAULTS[padType] ~= nil then
		return PAD_TYPE_DEFAULTS[padType]
	end

	return {
		PadType = tostring(padType or "Training"),
		RequiredPlayers = tonumber(padRoot:GetAttribute("RequiredPlayers")) or 1,
		Title = string.upper(padRoot.Name),
		Subtitle = "Drive here",
		MinSize = Vector3.new(36, TRIGGER_HEIGHT, 28),
		DefaultCFrame = CFrame.new(0, 46.14, 92),
		Color = Color3.fromRGB(120, 220, 200),
	}
end

local function findTrigger(padRoot)
	local direct = padRoot:FindFirstChild("Trigger")

	if direct ~= nil and direct:IsA("BasePart") then
		return direct
	end

	for _, descendant in ipairs(padRoot:GetDescendants()) do
		if isPadTrigger(descendant) then
			return descendant
		end
	end

	return nil
end

local function findVisualPart(padRoot)
	if padRoot:IsA("BasePart") then
		return padRoot
	end

	local bestPart = nil
	local bestVolume = -1

	for _, descendant in ipairs(padRoot:GetDescendants()) do
		if descendant:IsA("BasePart") and not isPadTrigger(descendant) then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z

			if volume > bestVolume then
				bestVolume = volume
				bestPart = descendant
			end
		end
	end

	return bestPart
end

local function getPartsBounds(parts)
	if #parts == 0 then
		return nil, nil
	end

	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5
		minX = math.min(minX, part.Position.X - halfSize.X)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)
	end

	local minVector = Vector3.new(minX, minY, minZ)
	local maxVector = Vector3.new(maxX, maxY, maxZ)
	local center = (minVector + maxVector) * 0.5
	local size = maxVector - minVector

	return CFrame.new(center), size
end

local function getLegacyVisualBounds(padRoot)
	local lobby = padRoot.Parent

	if lobby == nil then
		return nil, nil, nil
	end

	local candidateNames = {
		padRoot.Name .. "Visual",
		padRoot.Name .. "Visuals",
		padRoot.Name .. "Frame",
	}

	if padRoot.Name == "DuelPad" then
		table.insert(candidateNames, "DuelPadVisuals")
	elseif padRoot.Name == "ArenaPad" then
		table.insert(candidateNames, "ArenaPadFrame")
	end

	for _, candidateName in ipairs(candidateNames) do
		local container = lobby:FindFirstChild(candidateName)

		if container ~= nil then
			local parts = {}

			for _, descendant in ipairs(container:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end

			local cframe, size = getPartsBounds(parts)

			if cframe ~= nil then
				return cframe, size, container
			end
		end
	end

	return nil, nil, nil
end

local function getReferenceCFrameAndSize(padRoot, spec)
	local legacyCFrame, legacySize, legacyContainer = getLegacyVisualBounds(padRoot)

	if legacyCFrame ~= nil and padRoot:IsA("BasePart") then
		local distance = (legacyCFrame.Position - padRoot.Position).Magnitude

		if padRoot.Transparency > 0.7 and distance > FAR_DISTANCE then
			return legacyCFrame, legacySize, legacyContainer, "legacyVisual"
		end
	end

	local visualPart = findVisualPart(padRoot)

	if visualPart ~= nil then
		return visualPart.CFrame, visualPart.Size, visualPart, "visual"
	end

	if padRoot:IsA("Model") then
		local cframe, size = padRoot:GetBoundingBox()

		if size.Magnitude > 0.001 then
			return cframe, size, nil, "model"
		end
	end

	return spec.DefaultCFrame, spec.MinSize, nil, "default"
end

local function getTriggerSize(referenceSize, spec)
	return Vector3.new(
		math.max(referenceSize.X, spec.MinSize.X),
		math.max(TRIGGER_HEIGHT, spec.MinSize.Y),
		math.max(referenceSize.Z, spec.MinSize.Z)
	)
end

local function getTriggerCFrame(referenceCFrame, referenceSize, triggerSize)
	local topOffset = referenceSize.Y * 0.5 + triggerSize.Y * 0.5

	if referenceSize.Y <= 0.01 then
		topOffset = DEFAULT_PAD_Y_OFFSET
	end

	return referenceCFrame * CFrame.new(0, topOffset, 0)
end

local function configureTrigger(trigger, padRoot, spec, referenceCFrame, referenceSize)
	local triggerSize = getTriggerSize(referenceSize, spec)
	local triggerCFrame = getTriggerCFrame(referenceCFrame, referenceSize, triggerSize)
	local previousPosition = trigger.Position
	local distance = (previousPosition - triggerCFrame.Position).Magnitude

	if distance > FAR_DISTANCE then
		warn(
			("[PAD REPAIR] %s trigger was %.1f studs from visual/root; moving trigger to preserved pad position."):format(
				padRoot:GetFullName(),
				distance
			)
		)
	end

	trigger.Size = triggerSize
	trigger.CFrame = triggerCFrame
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger.CanQuery = true
	trigger.CastShadow = false
	trigger.Transparency = DEBUG_TRIGGER_TRANSPARENCY
	trigger.Material = Enum.Material.ForceField
	trigger.Color = Color3.fromRGB(110, 255, 180)
	trigger.TopSurface = Enum.SurfaceType.Smooth
	trigger.BottomSurface = Enum.SurfaceType.Smooth
	trigger:SetAttribute("WOBPadType", spec.PadType)
	trigger:SetAttribute("RequiredPlayers", spec.RequiredPlayers)
	trigger:SetAttribute("WOBPadEnabled", true)
	trigger:SetAttribute("WOBPadTrigger", true)
	changedCount += 1
	print("[PAD REPAIR] Fixed trigger " .. trigger:GetFullName())
end

local function setPadAttributes(padRoot, spec)
	padRoot:SetAttribute("WOBPadType", spec.PadType)
	padRoot:SetAttribute("RequiredPlayers", spec.RequiredPlayers)
	padRoot:SetAttribute("WOBPadEnabled", true)

	if spec.PadType == "Duel" then
		padRoot:SetAttribute("DuelQueueCount", padRoot:GetAttribute("DuelQueueCount") or 0)
		padRoot:SetAttribute("DuelQueueRequired", padRoot:GetAttribute("DuelQueueRequired") or spec.RequiredPlayers)
		padRoot:SetAttribute("DuelCountdown", padRoot:GetAttribute("DuelCountdown") or 0)
		padRoot:SetAttribute("DuelState", padRoot:GetAttribute("DuelState") or "Idle")
	end

	changedCount += 1
end

local function hideLegacyRootPart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part:SetAttribute("WOBPadTrigger", nil)
	changedCount += 1
end

local function ensureVisualContainer(padRoot, spec, referenceCFrame, referenceSize, source)
	local visual = padRoot:FindFirstChild("Visual")

	if visual == nil then
		visual = Instance.new("Folder")
		visual.Name = "Visual"
		visual.Parent = padRoot
		changedCount += 1
		print("[PAD REPAIR] Created " .. visual:GetFullName())
	end

	if padRoot:IsA("BasePart") then
		if source == "legacyVisual" then
			hideLegacyRootPart(padRoot)
			print("[PAD REPAIR] Kept legacy root hidden " .. padRoot:GetFullName())
			return visual
		end

		configureVisualPart(padRoot, spec.Color)
		return visual
	end

	local visualPart = findVisualPart(padRoot)

	if visualPart == nil then
		visualPart = Instance.new("Part")
		visualPart.Name = "PadPlate"
		visualPart.Parent = visual
		visualPart.Size = Vector3.new(
			math.max(referenceSize.X, spec.MinSize.X),
			0.45,
			math.max(referenceSize.Z, spec.MinSize.Z)
		)
		visualPart.CFrame = referenceCFrame
		changedCount += 1
		print("[PAD REPAIR] Created visual " .. visualPart:GetFullName())
	end

	configureVisualPart(visualPart, spec.Color)

	return visual
end

local function ensureTextLabel(parent, name, position, size, text, textSize)
	local label = parent:FindFirstChild(name)

	if label == nil then
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
		changedCount += 1
	elseif not label:IsA("TextLabel") then
		warn("[PAD REPAIR] " .. label:GetFullName() .. " is " .. label.ClassName .. ", expected TextLabel.")
		return nil
	end

	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.BuilderSansBold
	label.Text = text
	label.TextScaled = false
	label.TextSize = textSize
	label.TextColor3 = Color3.fromRGB(246, 255, 250)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.12
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	return label
end

local function ensureLabel(padRoot, trigger, spec)
	local label = padRoot:FindFirstChild("Label")

	if label == nil then
		label = Instance.new("BillboardGui")
		label.Name = "Label"
		label.Parent = padRoot
		changedCount += 1
	elseif not label:IsA("BillboardGui") then
		warn("[PAD REPAIR] " .. label:GetFullName() .. " is " .. label.ClassName .. ", expected BillboardGui.")
		return
	end

	label.Adornee = trigger
	label.AlwaysOnTop = true
	label.Enabled = true
	label.Size = UDim2.fromOffset(250, 92)
	label.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	label.MaxDistance = 260

	ensureTextLabel(label, "TitleText", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.55, 0), spec.Title, 26)

	local subtitleName = spec.PadType == "Duel" and "StatusText" or "SubtitleText"
	ensureTextLabel(label, subtitleName, UDim2.new(0, 0, 0.52, 0), UDim2.new(1, 0, 0.42, 0), spec.Subtitle, 18)

	print("[PAD REPAIR] Fixed label " .. label:GetFullName())
end

local function repairPad(padRoot)
	local spec = getPadSpec(padRoot)
	local referenceCFrame, referenceSize, _, source = getReferenceCFrameAndSize(padRoot, spec)

	print("[PAD REPAIR] Found pad " .. padRoot:GetFullName() .. " type=" .. spec.PadType)
	print("[PAD REPAIR] Preserved position " .. tostring(referenceCFrame.Position) .. " source=" .. source)

	setPadAttributes(padRoot, spec)
	ensureVisualContainer(padRoot, spec, referenceCFrame, referenceSize, source)

	local trigger = findTrigger(padRoot)

	if trigger == nil then
		trigger = Instance.new("Part")
		trigger.Name = "Trigger"
		trigger.Parent = padRoot
		changedCount += 1
		print("[PAD REPAIR] Created " .. trigger:GetFullName())
	end

	configureTrigger(trigger, padRoot, spec, referenceCFrame, referenceSize)
	ensureLabel(padRoot, trigger, spec)
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[PAD REPAIR] Workspace/" .. ROOT_NAME .. " was not found.")
	return
end

local lobby = root:FindFirstChild(LOBBY_NAME)

if lobby == nil then
	warn("[PAD REPAIR] Workspace/" .. ROOT_NAME .. "/" .. LOBBY_NAME .. " was not found.")
	return
end

local pads = collectPadRoots(lobby)

if lobby:FindFirstChild("ArenaPad") == nil then
	local arenaPad = Instance.new("Part")
	arenaPad.Name = "ArenaPad"
	arenaPad.Size = Vector3.new(48, 0.45, 34)
	arenaPad.CFrame = PAD_SPECS.ArenaPad.DefaultCFrame
	arenaPad.Parent = lobby
	addPadRoot(pads, arenaPad)
	changedCount += 1
	print("[PAD REPAIR] Created missing ArenaPad at default position.")
end

for padRoot, _ in pairs(pads) do
	if padRoot ~= nil and padRoot.Parent ~= nil then
		repairPad(padRoot)
	end
end

print("[PAD REPAIR] Complete. Changed/checked properties: " .. tostring(changedCount) .. ". File -> Save to File.")
