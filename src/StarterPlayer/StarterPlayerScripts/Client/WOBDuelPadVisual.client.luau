local Workspace = game:GetService("Workspace")

local root = Workspace:WaitForChild("WOB_Generated")
local lobby = root:WaitForChild("Lobby", 20)

if lobby == nil then
	warn("[DUELPAD] Lobby not found; DuelPad visual updater disabled.")
	return
end

local duelPad = lobby:WaitForChild("DuelPad", 20)

if duelPad == nil then
	warn("[DUELPAD] Lobby/DuelPad not found; DuelPad visual updater disabled.")
	return
end

local statusLabels = {}

local function getDuelPadTrigger()
	local directTrigger = duelPad:FindFirstChild("Trigger")

	if directTrigger ~= nil and directTrigger:IsA("BasePart") then
		return directTrigger
	end

	for _, descendant in ipairs(duelPad:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("WOBPadTrigger") == true then
			return descendant
		end
	end

	return nil
end

local function addStatusLabel(instance)
	if instance:IsA("TextLabel")
		and (instance.Name == "StatusText" or instance.Name == "DuelPadStatusText")
	then
		statusLabels[instance] = true
	end
end

local function refreshStatusLabels()
	table.clear(statusLabels)

	for _, descendant in ipairs(lobby:GetDescendants()) do
		addStatusLabel(descendant)
	end

	for _, descendant in ipairs(duelPad:GetDescendants()) do
		addStatusLabel(descendant)
	end
end

local function getReplicatedDuelAttribute(attributeName)
	for _, source in ipairs({ duelPad, getDuelPadTrigger(), lobby, root }) do
		local value = source ~= nil and source:GetAttribute(attributeName) or nil

		if value ~= nil then
			return value
		end
	end

	return nil
end

local function getDuelPadText()
	local queueCount = tonumber(getReplicatedDuelAttribute("DuelQueueCount")) or 0
	local required = tonumber(getReplicatedDuelAttribute("DuelQueueRequired")) or 2
	local countdown = tonumber(getReplicatedDuelAttribute("DuelCountdown")) or 0
	local state = tostring(getReplicatedDuelAttribute("DuelState") or "Idle")
	local counterText = tostring(math.clamp(queueCount, 0, required)) .. "/" .. tostring(required)

	if state == "Countdown" and countdown > 0 then
		return counterText .. "\nDUEL STARTING IN " .. tostring(math.ceil(countdown))
	end

	if queueCount == 1 then
		return counterText .. "\nWAITING FOR OPPONENT"
	end

	if queueCount >= required then
		return counterText .. "\nDUEL STARTING"
	end

	return counterText
end

local function updateStatusText()
	refreshStatusLabels()

	local text = getDuelPadText()

	for label, _ in pairs(statusLabels) do
		if label.Parent ~= nil then
			label.Text = text
		else
			statusLabels[label] = nil
		end
	end
end

for _, attributeName in ipairs({
	"DuelQueueCount",
	"DuelQueueRequired",
	"DuelCountdown",
	"DuelState",
}) do
	root:GetAttributeChangedSignal(attributeName):Connect(updateStatusText)
	lobby:GetAttributeChangedSignal(attributeName):Connect(updateStatusText)
	duelPad:GetAttributeChangedSignal(attributeName):Connect(updateStatusText)

	local trigger = getDuelPadTrigger()

	if trigger ~= nil then
		trigger:GetAttributeChangedSignal(attributeName):Connect(updateStatusText)
	end
end

lobby.DescendantAdded:Connect(function(descendant)
	addStatusLabel(descendant)
	updateStatusText()
end)

duelPad.DescendantAdded:Connect(function(descendant)
	addStatusLabel(descendant)
	updateStatusText()
end)

updateStatusText()
