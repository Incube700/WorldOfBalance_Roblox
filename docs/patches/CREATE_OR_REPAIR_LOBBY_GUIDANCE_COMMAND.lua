-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Adds lobby wayfinding signs, arrows, and floating tips.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB GUIDANCE] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local LOBBY_NAME = "Lobby"

local changedCount = 0

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB GUIDANCE] %s is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil, false
		end

		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	changedCount += 1
	print("[WOB GUIDANCE] Created " .. instance:GetFullName())

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

local function findPadRoot(lobby, padType, names)
	for _, name in ipairs(names) do
		local named = lobby:FindFirstChild(name)

		if named ~= nil then
			return named
		end
	end

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:GetAttribute("WOBPadType") == padType then
			local current = descendant
			local top = descendant

			while current ~= nil and current ~= lobby do
				top = current
				current = current.Parent
			end

			if current == lobby then
				return top
			end
		end
	end

	return nil
end

local function findAdorneePart(rootInstance)
	if rootInstance == nil then
		return nil
	end

	if rootInstance:IsA("BasePart") then
		return rootInstance
	end

	local trigger = rootInstance:FindFirstChild("Trigger")

	if trigger ~= nil and trigger:IsA("BasePart") then
		return trigger
	end

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("WOBPadTrigger") == true then
			return descendant
		end
	end

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function ensureTextLabel(parent, name, position, size, text, textSize, color)
	local label = parent:FindFirstChild(name)

	if label == nil then
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
		changedCount += 1
	elseif not label:IsA("TextLabel") then
		warn("[WOB GUIDANCE] " .. label:GetFullName() .. " is " .. label.ClassName .. ", expected TextLabel.")
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
	label.TextStrokeTransparency = 0.12
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2

	return label
end

local function ensureBillboardBackground(billboard)
	local background = billboard:FindFirstChild("Background")

	if background == nil then
		background = Instance.new("Frame")
		background.Name = "Background"
		background.Parent = billboard
		changedCount += 1
	end

	if not background:IsA("Frame") then
		return
	end

	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(8, 11, 14)
	background.BackgroundTransparency = 0.18
	background.BorderSizePixel = 0
	background.ZIndex = 1

	local corner = background:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = background
end

local function ensurePadLabel(padRoot, title, subtitle, modeText)
	local adornee = findAdorneePart(padRoot)

	if padRoot == nil or adornee == nil then
		return
	end

	local label = padRoot:FindFirstChild("Label")

	if label == nil then
		label = Instance.new("BillboardGui")
		label.Name = "Label"
		label.Parent = padRoot
		changedCount += 1
	elseif not label:IsA("BillboardGui") then
		warn("[WOB GUIDANCE] " .. label:GetFullName() .. " is " .. label.ClassName .. ", expected BillboardGui.")
		return
	end

	label.Adornee = adornee
	label.AlwaysOnTop = true
	label.Enabled = true
	label.Size = UDim2.fromOffset(260, modeText ~= nil and 118 or 96)
	label.StudsOffsetWorldSpace = Vector3.new(0, 7.2, 0)
	label.MaxDistance = 250
	ensureBillboardBackground(label)

	ensureTextLabel(label, "TitleText", UDim2.new(0.04, 0, 0.04, 0), UDim2.new(0.92, 0, 0.4, 0), title, 26, Color3.fromRGB(248, 255, 250))

	if modeText ~= nil then
		ensureTextLabel(label, "ModeText", UDim2.new(0.04, 0, 0.43, 0), UDim2.new(0.92, 0, 0.25, 0), modeText, 18, Color3.fromRGB(135, 225, 255))
		ensureTextLabel(label, "StatusText", UDim2.new(0.04, 0, 0.68, 0), UDim2.new(0.92, 0, 0.26, 0), subtitle, 18, Color3.fromRGB(255, 225, 120))
	else
		ensureTextLabel(label, "SubtitleText", UDim2.new(0.04, 0, 0.5, 0), UDim2.new(0.92, 0, 0.38, 0), subtitle, 18, Color3.fromRGB(135, 225, 255))
	end

	print("[WOB GUIDANCE] Repaired label " .. label:GetFullName())
end

local function configureFlatPart(part, size, cframe, color, transparency)
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("WOBMovementObstacle", nil)
	part:SetAttribute("WOBGuidance", true)
	changedCount += 1
end

local function ensureArrow(guidanceFolder, name, cframe, color)
	local model = getOrCreate(guidanceFolder, "Model", name)

	if model == nil then
		return
	end

	model:SetAttribute("WOBGuidance", true)

	local stem = getOrCreate(model, "Part", "Stem")
	local headLeft = getOrCreate(model, "Part", "HeadLeft")
	local headRight = getOrCreate(model, "Part", "HeadRight")

	if stem ~= nil then
		configureFlatPart(stem, Vector3.new(4, 0.25, 24), cframe * CFrame.new(0, 0, 6), color, 0.2)
	end

	if headLeft ~= nil then
		configureFlatPart(headLeft, Vector3.new(3.5, 0.25, 13), cframe * CFrame.new(-3.4, 0, -7.6) * CFrame.Angles(0, math.rad(-35), 0), color, 0.12)
	end

	if headRight ~= nil then
		configureFlatPart(headRight, Vector3.new(3.5, 0.25, 13), cframe * CFrame.new(3.4, 0, -7.6) * CFrame.Angles(0, math.rad(35), 0), color, 0.12)
	end

	print("[WOB GUIDANCE] Repaired arrow " .. model:GetFullName())
end

local function ensureTip(guidanceFolder, name, position, text, color)
	local anchor = getOrCreate(guidanceFolder, "Part", name .. "Anchor")

	if anchor == nil then
		return
	end

	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor:SetAttribute("WOBGuidance", true)

	local billboard = anchor:FindFirstChild("Tip")

	if billboard == nil then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "Tip"
		billboard.Parent = anchor
		changedCount += 1
	elseif not billboard:IsA("BillboardGui") then
		warn("[WOB GUIDANCE] " .. billboard:GetFullName() .. " is " .. billboard.ClassName .. ", expected BillboardGui.")
		return
	end

	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.Size = UDim2.fromOffset(300, 74)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.MaxDistance = 190
	ensureBillboardBackground(billboard)
	ensureTextLabel(billboard, "Text", UDim2.new(0.05, 0, 0.08, 0), UDim2.new(0.9, 0, 0.82, 0), text, 18, color)

	print("[WOB GUIDANCE] Repaired tip " .. anchor:GetFullName())
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[WOB GUIDANCE] Workspace/" .. ROOT_NAME .. " was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local lobby = root:FindFirstChild(LOBBY_NAME)

if lobby == nil then
	warn("[WOB GUIDANCE] Workspace/" .. ROOT_NAME .. "/" .. LOBBY_NAME .. " was not found. Run CREATE_LOBBY_COMMAND.lua first.")
	return
end

local surfaceY = getLobbySurfaceY(lobby)
local guidanceFolder = getOrCreate(lobby, "Folder", "Guidance")

if guidanceFolder == nil then
	return
end

local arenaPad = findPadRoot(lobby, "BattleArena", { "ArenaPad" })
local duelPad = findPadRoot(lobby, "Duel", { "DuelPad" })
local trainingPad = findPadRoot(lobby, "Training", { "TrainingPad", "StartPad" })

ensurePadLabel(arenaPad, "BATTLE ARENA", "Drive here", nil)
ensurePadLabel(duelPad, "DUEL", "0/2", "1v1")
ensurePadLabel(trainingPad, "TRAINING", "Practice here", nil)

ensureArrow(guidanceFolder, "ArrowToTraining", CFrame.new(-64, surfaceY + 0.28, 142), Color3.fromRGB(105, 180, 255))
ensureArrow(guidanceFolder, "ArrowToDuel", CFrame.new(0, surfaceY + 0.28, 142), Color3.fromRGB(255, 220, 90))
ensureArrow(guidanceFolder, "ArrowToBattleArena", CFrame.new(64, surfaceY + 0.28, 142), Color3.fromRGB(96, 235, 165))

ensureTip(guidanceFolder, "TipCrystals", Vector3.new(0, surfaceY + 16, 182), "Earn Crystals by winning Duels", Color3.fromRGB(135, 225, 255))
ensureTip(guidanceFolder, "TipBattleArena", Vector3.new(70, surfaceY + 15, 112), "Battle Arena: fight, respawn, upgrade", Color3.fromRGB(140, 255, 190))
ensureTip(guidanceFolder, "TipRicochet", Vector3.new(-70, surfaceY + 15, 112), "Use ricochets to hit enemies", Color3.fromRGB(255, 230, 120))

print("[WOB GUIDANCE] Complete. Changed/checked properties: " .. tostring(changedCount) .. ". File -> Save to File.")
