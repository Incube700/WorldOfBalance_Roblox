-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Prints lobby pad root/trigger/visual/label diagnostics.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[PAD AUDIT] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local LOBBY_NAME = "Lobby"
local FAR_DISTANCE = 4

local KNOWN_PAD_NAMES = {
	ArenaPad = true,
	DuelPad = true,
	TrainingPad = true,
	StartPad = true,
}

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
	if root ~= nil and root.Parent ~= nil then
		pads[root] = true
	end
end

local function collectPadRoots(lobby)
	local pads = {}

	for padName, _ in pairs(KNOWN_PAD_NAMES) do
		addPadRoot(pads, lobby:FindFirstChild(padName))
	end

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:GetAttribute("WOBPadType") ~= nil then
			addPadRoot(pads, getTopLobbyChild(lobby, descendant))
		end
	end

	return pads
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

	if padRoot:IsA("BasePart") then
		return padRoot
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

local function getLegacyVisual(padRoot)
	local lobby = padRoot.Parent

	if lobby == nil then
		return nil, nil
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

			local cframe = getPartsBounds(parts)

			if cframe ~= nil then
				return container, cframe.Position
			end
		end
	end

	return nil, nil
end

local function getLabelText(padRoot)
	local texts = {}

	for _, descendant in ipairs(padRoot:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Text ~= "" then
			table.insert(texts, descendant.Text)
		end
	end

	if #texts == 0 then
		return ""
	end

	return table.concat(texts, " / ")
end

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "nil"
	end

	return ("(%.1f, %.1f, %.1f)"):format(vector.X, vector.Y, vector.Z)
end

local function auditPad(padRoot)
	local trigger = findTrigger(padRoot)
	local visual = findVisualPart(padRoot)
	local legacyVisual, legacyVisualPosition = getLegacyVisual(padRoot)
	local padType = padRoot:GetAttribute("WOBPadType")
	local requiredPlayers = padRoot:GetAttribute("RequiredPlayers")
	local enabled = padRoot:GetAttribute("WOBPadEnabled")
	local labelText = getLabelText(padRoot)
	local warnings = {}

	if typeof(padType) ~= "string" or padType == "" then
		table.insert(warnings, "missing WOBPadType")
	end

	if typeof(requiredPlayers) ~= "number" then
		table.insert(warnings, "missing RequiredPlayers")
	end

	if enabled ~= true then
		table.insert(warnings, "WOBPadEnabled not true")
	end

	if trigger == nil then
		table.insert(warnings, "missing trigger")
	elseif trigger:GetAttribute("WOBPadTrigger") ~= true then
		table.insert(warnings, "trigger missing WOBPadTrigger")
	end

	if trigger ~= nil and trigger.CanTouch ~= true then
		table.insert(warnings, "trigger CanTouch false")
	end

	if trigger ~= nil and trigger.CanQuery ~= true then
		table.insert(warnings, "trigger CanQuery false")
	end

	if labelText == "" then
		table.insert(warnings, "missing label text")
	end

	local distance = nil
	local visualPath = visual ~= nil and visual:GetFullName() or "nil"
	local visualPosition = visual ~= nil and visual.Position or nil
	local legacyDistance = nil

	if legacyVisual ~= nil and trigger ~= nil then
		legacyDistance = (trigger.Position - legacyVisualPosition).Magnitude

		if legacyDistance <= FAR_DISTANCE then
			visualPath = legacyVisual:GetFullName()
			visualPosition = legacyVisualPosition
			distance = legacyDistance
		end
	end

	if distance == nil and trigger ~= nil and visual ~= nil then
		distance = (trigger.Position - visual.Position).Magnitude

		if distance > FAR_DISTANCE then
			table.insert(warnings, ("trigger %.1f studs from visual"):format(distance))
		end
	end

	local status = #warnings == 0 and "OK" or ("WARN " .. table.concat(warnings, "; "))

	print(
		("[PAD AUDIT] %s type=%s required=%s trigger=%s triggerPos=%s size=%s visual=%s visualPos=%s distance=%s CanTouch=%s CanQuery=%s label=\"%s\" %s"):format(
			padRoot.Name,
			tostring(padType),
			tostring(requiredPlayers),
			trigger ~= nil and trigger:GetFullName() or "nil",
			trigger ~= nil and formatVector3(trigger.Position) or "nil",
			trigger ~= nil and formatVector3(trigger.Size) or "nil",
			visualPath,
			formatVector3(visualPosition),
			distance ~= nil and string.format("%.1f", distance) or "nil",
			trigger ~= nil and tostring(trigger.CanTouch) or "nil",
			trigger ~= nil and tostring(trigger.CanQuery) or "nil",
			labelText,
			status
		)
	)
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[PAD AUDIT] Workspace/" .. ROOT_NAME .. " was not found.")
	return
end

local lobby = root:FindFirstChild(LOBBY_NAME)

if lobby == nil then
	warn("[PAD AUDIT] Workspace/" .. ROOT_NAME .. "/" .. LOBBY_NAME .. " was not found.")
	return
end

local pads = collectPadRoots(lobby)
local count = 0

for padRoot, _ in pairs(pads) do
	if padRoot ~= nil and padRoot.Parent ~= nil then
		count += 1
		auditPad(padRoot)
	end
end

print("[PAD AUDIT] Complete. Pads found: " .. tostring(count) .. ".")
