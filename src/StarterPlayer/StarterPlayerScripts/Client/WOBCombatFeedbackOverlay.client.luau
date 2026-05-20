local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatFeedbackEvent = remotes:WaitForChild("CombatFeedbackEvent")

local root = Workspace:WaitForChild("WOB_Generated")
local localPlayer = Players.LocalPlayer
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
	warn("[WOB] Combat feedback overlay disabled: Workspace.WOB_Runtime.Client.Visuals could not be created")
	return
end

local feedbackFolder = localVisuals:FindFirstChild("CombatFeedback")

if feedbackFolder == nil then
	feedbackFolder = Instance.new("Folder")
	feedbackFolder.Name = "CombatFeedback"
	feedbackFolder.Parent = localVisuals
else
	feedbackFolder:ClearAllChildren()
end

local DEFAULT_LIFETIME = 0.65
local DEFAULT_RISE_DISTANCE = 2.4
local FEEDBACK_BILLBOARD_SIZE = UDim2.fromOffset(160, 44)
local MAX_ACTIVE_FEEDBACK = 8

local activeFeedback = {}

local function createAnchor(position)
	local part = Instance.new("Part")
	part.Name = "WOBCombatFeedbackAnchor"
	part.Size = Vector3.new(0.25, 0.25, 0.25)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = feedbackFolder

	return part
end

local function createBillboard(anchor, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WOBCombatFeedbackBillboard"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.Size = FEEDBACK_BILLBOARD_SIZE
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.15
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Active = false
	label.Selectable = false
	label.Parent = billboard

	return label
end

local function normalizePayload(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	if typeof(payload.Position) ~= "Vector3" then
		return nil
	end

	local text = tostring(payload.Text or payload.Type or "HIT")
	local color = payload.Color

	if typeof(color) ~= "Color3" then
		color = Color3.fromRGB(255, 255, 255)
	end

	return {
		Position = payload.Position,
		Text = text,
		Color = color,
		Lifetime = tonumber(payload.Lifetime) or DEFAULT_LIFETIME,
		RiseDistance = tonumber(payload.RiseDistance) or DEFAULT_RISE_DISTANCE,
		CreatedAt = os.clock(),
	}
end

local function removeFeedbackAt(index)
	local feedback = activeFeedback[index]

	if feedback ~= nil and feedback.Anchor.Parent ~= nil then
		feedback.Anchor:Destroy()
	end

	table.remove(activeFeedback, index)
end

local function clearFeedback()
	for i = #activeFeedback, 1, -1 do
		removeFeedbackAt(i)
	end

	feedbackFolder:ClearAllChildren()
end

local function trimOldFeedback()
	while #activeFeedback > MAX_ACTIVE_FEEDBACK do
		removeFeedbackAt(1)
	end
end

local function showFeedback(payload)
	if typeof(payload) == "table" and payload.AudioOnly == true then
		return
	end

	local mode = localPlayer:GetAttribute("PlayerMode")
	local isGameplayVisible = mode == "Lobby"
		or mode == "QueuedForDuel"
		or mode == "InMatch"
		or mode == "InBattleArena"
		or mode == "ArenaRespawning"
		or (mode == nil and root:GetAttribute("GameState") == "Playing")

	if not isGameplayVisible then
		clearFeedback()
		return
	end

	local data = normalizePayload(payload)

	if data == nil then
		return
	end

	local anchor = createAnchor(data.Position + Vector3.new(0, 3.5, 0))
	local label = createBillboard(anchor, data.Text, data.Color)

	table.insert(activeFeedback, {
		Anchor = anchor,
		Label = label,
		StartPosition = anchor.Position,
		CreatedAt = data.CreatedAt,
		Lifetime = data.Lifetime,
		RiseDistance = data.RiseDistance,
	})

	trimOldFeedback()
end

combatFeedbackEvent.OnClientEvent:Connect(showFeedback)

root:GetAttributeChangedSignal("GameState"):Connect(function()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode ~= "Lobby"
		and mode ~= "QueuedForDuel"
		and mode ~= "InMatch"
		and mode ~= "InBattleArena"
		and mode ~= "ArenaRespawning"
		and root:GetAttribute("GameState") ~= "Playing"
	then
		clearFeedback()
	end
end)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(function()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode ~= "Lobby"
		and mode ~= "QueuedForDuel"
		and mode ~= "InMatch"
		and mode ~= "InBattleArena"
		and mode ~= "ArenaRespawning"
	then
		clearFeedback()
	end
end)

RunService.RenderStepped:Connect(function()
	if #activeFeedback == 0 then
		return
	end

	local currentTime = os.clock()

	for i = #activeFeedback, 1, -1 do
		local feedback = activeFeedback[i]
		local elapsed = currentTime - feedback.CreatedAt
		local progress = math.clamp(elapsed / feedback.Lifetime, 0, 1)

		if feedback.Anchor.Parent == nil then
			table.remove(activeFeedback, i)
			continue
		end

		feedback.Anchor.Position = feedback.StartPosition + Vector3.new(0, progress * feedback.RiseDistance, 0)

		if feedback.Label.Parent ~= nil then
			feedback.Label.TextTransparency = progress
			feedback.Label.TextStrokeTransparency = 0.15 + progress * 0.85
		end

		if progress >= 1 then
			removeFeedbackAt(i)
		end
	end
end)
