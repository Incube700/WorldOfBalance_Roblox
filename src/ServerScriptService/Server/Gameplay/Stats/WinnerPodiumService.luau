-- WinnerPodiumService (Etap 5): two global "champion" podiums in the lobby.
--   * Arena Champion  -> highest arena level ever reached (record).
--   * Duel King       -> most duel kills ever (record).
--
-- Global records use OrderedDataStore (works on the PUBLISHED place). On server start it
-- reads the current #1 for each board and shows their name on the matching podium. When a
-- player beats a record this session, it writes the new value and refreshes the podium.
--
-- Studio authoring: place two parts/attachments in the lobby named (or tagged) so this
-- service can find them. It looks for, under Workspace.WOB_Generated.Lobby:
--     ArenaChampionPodium  (BasePart) -- where the arena champion nameplate sits
--     DuelKingPodium       (BasePart) -- where the duel king nameplate sits
-- If a podium part is missing it is skipped with a warning (no crash, no guessing).

local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local WinnerPodiumService = {}

local ARENA_STORE = "WOBArenaChampionV1"
local DUEL_STORE = "WOBDuelKingV1"
local TOP_KEY = "Global" -- single global bucket per board

local PODIUMS = {
	Arena = { PartName = "ArenaChampionPodium", Title = "ARENA CHAMPION", Store = ARENA_STORE },
	Duel = { PartName = "DuelKingPodium", Title = "DUEL KING", Store = DUEL_STORE },
}

local storesByBoard = {}
local recordByBoard = { Arena = { Name = "—", Value = 0 }, Duel = { Name = "—", Value = 0 } }
local warnedNoStore = false
local deps = {}

local function getStore(board)
	if storesByBoard[board] ~= nil then
		return storesByBoard[board]
	end
	local def = PODIUMS[board]
	if def == nil then
		return nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(def.Store)
	end)
	if ok then
		storesByBoard[board] = result
		return result
	end
	if not warnedNoStore then
		warnedNoStore = true
		warn("[PODIUM] OrderedDataStore unavailable (publish the place): " .. tostring(result))
	end
	return nil
end

local function getLobby()
	local generated = Workspace:FindFirstChild("WOB_Generated")
	return generated ~= nil and generated:FindFirstChild("Lobby") or nil
end

local function findPodiumPart(partName)
	local lobby = getLobby()
	if lobby == nil then
		return nil
	end
	local direct = lobby:FindFirstChild(partName)
	if direct ~= nil and direct:IsA("BasePart") then
		return direct
	end
	for _, d in ipairs(lobby:GetDescendants()) do
		if d.Name == partName and d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

-- Finds the model that owns/contains the podium part (so we can place the display tank
-- on its TankAnchor and store the display tank inside it).
local function findPodiumModel(partName)
	local part = findPodiumPart(partName)
	if part == nil then
		return nil
	end
	return part:FindFirstAncestorWhichIsA("Model") or part.Parent
end

-- Places a non-interactive display tank on the podium showing the winner's tank + skin.
-- Rebuilds only when the displayed winner changed, so it doesn't churn every frame.
local function refreshPodiumTank(board)
	if deps.getTankTemplate == nil then
		return -- display tank disabled (no template provider wired)
	end

	local container = findPodiumModel(PODIUMS[board].PartName)
	if container == nil then
		return
	end

	local anchor = container:FindFirstChild("TankAnchor", true)
	if anchor == nil or not anchor:IsA("BasePart") then
		return
	end

	local record = recordByBoard[board]
	local key = (record.Name or "—") .. "|" .. tostring(record.SkinId or "")

	-- Skip if the same winner/skin is already shown.
	local existing = container:FindFirstChild("WinnerDisplayTank")
	if existing ~= nil and existing:GetAttribute("DisplayKey") == key then
		return
	end
	if existing ~= nil then
		existing:Destroy()
	end

	-- No real winner yet: leave the podium empty.
	if record.Name == nil or record.Name == "—" then
		return
	end

	local template = deps.getTankTemplate()
	if template == nil then
		return
	end

	local clone = template:Clone()
	clone.Name = "WinnerDisplayTank"
	clone:SetAttribute("DisplayKey", key)

	-- Strip anything that could make it act like a live tank (scripts, hitbox queries).
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end

	-- Apply the winner's skin if we can.
	if deps.applySkin ~= nil and record.SkinId ~= nil then
		pcall(function()
			deps.applySkin(clone, record.SkinId)
		end)
	end

	clone.Parent = container
	-- Sit it on the anchor, slightly raised, facing outward.
	local ok = pcall(function()
		clone:PivotTo(anchor.CFrame * CFrame.new(0, 2.5, 0))
	end)
	if not ok then
		clone:Destroy()
	end
end

-- Builds / refreshes the floating nameplate above a podium part. Display only.
local function refreshPodiumPlate(board)
	local def = PODIUMS[board]
	local part = findPodiumPart(def.PartName)
	if part == nil then
		warn(("[PODIUM] %s part 'Workspace.WOB_Generated.Lobby.%s' not found; podium skipped."):format(board, def.PartName))
		return
	end

	local record = recordByBoard[board]

	local gui = part:FindFirstChild("WinnerPodiumPlate")
	if gui == nil then
		gui = Instance.new("BillboardGui")
		gui.Name = "WinnerPodiumPlate"
		gui.Size = UDim2.fromOffset(220, 60)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Parent = part

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 22)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(250, 205, 90)
		title.TextStrokeTransparency = 0.4
		title.Parent = gui

		local name = Instance.new("TextLabel")
		name.Name = "WinnerName"
		name.BackgroundTransparency = 1
		name.Position = UDim2.new(0, 0, 0, 24)
		name.Size = UDim2.new(1, 0, 0, 22)
		name.Font = Enum.Font.GothamBlack
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(240, 246, 255)
		name.TextStrokeTransparency = 0.4
		name.Parent = gui

		local value = Instance.new("TextLabel")
		value.Name = "WinnerValue"
		value.BackgroundTransparency = 1
		value.Position = UDim2.new(0, 0, 0, 44)
		value.Size = UDim2.new(1, 0, 0, 14)
		value.Font = Enum.Font.Gotham
		value.TextScaled = true
		value.TextColor3 = Color3.fromRGB(180, 205, 235)
		value.Parent = gui
	end

	gui.Title.Text = def.Title
	gui.WinnerName.Text = record.Name or "—"
	gui.WinnerValue.Text = board == "Arena"
		and ("Level " .. tostring(record.Value or 0))
		or (tostring(record.Value or 0) .. " duels")

	refreshPodiumTank(board)
end

local function loadRecord(board)
	local store = getStore(board)
	if store == nil then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 1) -- descending, top 1
	end)
	if not ok then
		warn(("[PODIUM] %s record read failed: %s"):format(board, tostring(pages)))
		return
	end
	local top = pages:GetCurrentPage()[1]
	if top ~= nil then
		-- Key is the player name, value is the record number.
		recordByBoard[board] = { Name = tostring(top.key), Value = tonumber(top.value) or 0 }
	end
	refreshPodiumPlate(board)
end

-- Duel King counts COMPLETED DUELS (not kills). We keep the running total per player in the
-- same OrderedDataStore (keyed by name): each completed duel does +1 via UpdateAsync, then we
-- refresh the podium if it beats the shown record. Returns the new total (or nil on failure).
function WinnerPodiumService.submitDuelCompletion(playerName, skinId)
	if typeof(playerName) ~= "string" or playerName == "" then
		return nil
	end
	-- Local running tally so the podium works even without DataStore (Studio / unpublished).
	local localTotal = (recordByBoard.Duel.Name == playerName and (recordByBoard.Duel.Value or 0) or 0) + 1

	local store = getStore("Duel")
	local newTotal = localTotal
	if store ~= nil then
		local ok, stored = pcall(function()
			return store:UpdateAsync(playerName, function(old)
				return (tonumber(old) or 0) + 1
			end)
		end)
		if ok and tonumber(stored) ~= nil then
			newTotal = tonumber(stored)
		end
	end

	-- Update the podium even if DataStore is down (in-memory record).
	if newTotal > (recordByBoard.Duel.Value or 0) then
		recordByBoard.Duel = { Name = playerName, Value = newTotal, SkinId = skinId }
		refreshPodiumPlate("Duel")
	end
	return newTotal
end

-- Submits a candidate record for a player. board = "Arena" | "Duel".
-- skinId (optional) is shown on the podium's display tank.
function WinnerPodiumService.submit(board, playerName, value, skinId)
	if PODIUMS[board] == nil or typeof(playerName) ~= "string" or playerName == "" then
		return
	end
	value = math.max(0, math.floor(tonumber(value) or 0))
	if value <= 0 then
		return
	end

	-- Persist the MAX to OrderedDataStore when available (published place). When DataStore is
	-- down (Studio/unpublished) we still update the local podium so it works in-session.
	local store = getStore(board)
	if store ~= nil then
		pcall(function()
			store:UpdateAsync(playerName, function(old)
				old = tonumber(old) or 0
				return math.max(old, value)
			end)
		end)
	end

	-- Update the local podium if this beats the shown record.
	if value > (recordByBoard[board].Value or 0) then
		recordByBoard[board] = { Name = playerName, Value = value, SkinId = skinId }
		refreshPodiumPlate(board)
	end
end

-- options.getTankTemplate() -> a Model to clone for the display tank (e.g. BaseTankTemplate)
-- options.applySkin(model, skinId) -> applies a skin to the cloned display tank
function WinnerPodiumService.init(options)
	deps = options or {}
	-- Initial read for both boards (deferred so the lobby has loaded).
	task.spawn(function()
		for board in pairs(PODIUMS) do
			loadRecord(board)
		end
	end)
end

return WinnerPodiumService
