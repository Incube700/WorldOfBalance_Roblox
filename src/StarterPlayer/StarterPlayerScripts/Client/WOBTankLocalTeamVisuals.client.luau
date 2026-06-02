local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local utils = shared:WaitForChild("Utils")
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")

local TEAM_HIGHLIGHT_NAME = "WOBTeamReadabilityHighlight"
local FRIENDLY_OUTLINE_COLOR = Color3.fromRGB(85, 215, 255)
local ENEMY_OUTLINE_COLOR = Color3.fromRGB(255, 82, 82)
local DEBUG_VISUALS = false

local loggedOwnedTankId = nil
local elapsedSinceRefresh = 0

local function isVisualTankModel(model)
	if not model:IsA("Model") then
		return false
	end

	return model:GetAttribute("IsPlayerTank") == true
		or model:GetAttribute("TankRole") == "Dummy"
		or model:GetAttribute("IsBot") == true
end

local function isLocalPlayerTank(model)
	if model:GetAttribute("IsPlayerTank") == true
		and model:GetAttribute("OwnerUserId") == localPlayer.UserId
	then
		local tankId = model:GetAttribute("TankId") or model.Name

		if DEBUG_VISUALS and loggedOwnedTankId ~= tankId then
			loggedOwnedTankId = tankId
			print("[PVP] local owned tank found: " .. tostring(tankId))
		end

		return true
	end

	return false
end

local function ensureTeamHighlight(model)
	if not isVisualTankModel(model) then
		return
	end

	local highlight = model:FindFirstChild(TEAM_HIGHLIGHT_NAME)

	if highlight == nil then
		highlight = Instance.new("Highlight")
		highlight.Name = TEAM_HIGHLIGHT_NAME
		highlight.Adornee = model
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = 1
		highlight.Parent = model
	elseif not highlight:IsA("Highlight") then
		return
	end

	local isDead = model:GetAttribute("IsDead") == true
		or model:GetAttribute("IsAlive") == false
	local isActive = model:GetAttribute("IsActive") ~= false

	highlight.Enabled = isActive and not isDead
	highlight.OutlineColor = isLocalPlayerTank(model) and FRIENDLY_OUTLINE_COLOR or ENEMY_OUTLINE_COLOR
	highlight.OutlineTransparency = isLocalPlayerTank(model) and 0.35 or 0.08
	highlight.FillTransparency = 1
end

local function refreshTank(model)
	if not isVisualTankModel(model) then
		return
	end

	-- Do not recolor Body/Turret/Barrel here: tank color is now player cosmetic state
	-- from the shop. This client-only layer keeps team readability separate from skins.
	ensureTeamHighlight(model)
end

local function colorAllTanks()
	local colored = {}

	for _, descendant in ipairs(testObjects:GetDescendants()) do
		if descendant:IsA("Model") then
			local tankModel = TankModelResolver.resolvePhysicalModel(root, descendant) or descendant

			if colored[tankModel] ~= true then
				colored[tankModel] = true
				refreshTank(tankModel)
			end
		end
	end
end

-- PERF: WOB_Generated gets a flood of descendants during combat (every projectile part,
-- attachment, trail, light and VFX particle). Reacting to all of them with a full
-- colorAllTanks() rescan caused per-burst stutter. Only tank Models matter here, so ignore
-- everything else; the 0.25s Heartbeat below is the catch-all safety refresh.
root.DescendantAdded:Connect(function(child)
	if not child:IsA("Model") then
		return
	end

	child:GetAttributeChangedSignal("OwnerUserId"):Connect(colorAllTanks)
	child:GetAttributeChangedSignal("IsActive"):Connect(colorAllTanks)
	child:GetAttributeChangedSignal("IsDead"):Connect(colorAllTanks)
	colorAllTanks()
end)

for _, child in ipairs(testObjects:GetDescendants()) do
	if child:IsA("Model") then
		child:GetAttributeChangedSignal("OwnerUserId"):Connect(colorAllTanks)
		child:GetAttributeChangedSignal("IsActive"):Connect(colorAllTanks)
		child:GetAttributeChangedSignal("IsDead"):Connect(colorAllTanks)
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	elapsedSinceRefresh += deltaTime

	if elapsedSinceRefresh < 0.25 then
		return
	end

	elapsedSinceRefresh = 0
	colorAllTanks()
end)

colorAllTanks()
