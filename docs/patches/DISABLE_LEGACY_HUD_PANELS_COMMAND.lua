-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Disables legacy combat HUD panels without deleting score/result/menu UI.

local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

if RunService:IsRunning() then
	warn("[WOB HUD DISABLE] Run this command outside Play Mode.")
	return
end

local HUD_GUI_NAME = "HUD"
local HUD_ROOT_NAME = "Root"
local LEGACY_PANEL_NAMES = {
	"EnemyStatusPanel",
	"WeaponStatusPanel",
	"PlayerStatusPanel",
}

local hud = StarterGui:FindFirstChild(HUD_GUI_NAME)

if hud == nil or not hud:IsA("ScreenGui") then
	warn("[WOB HUD DISABLE] StarterGui/HUD was not found or is not a ScreenGui.")
	return
end

local root = hud:FindFirstChild(HUD_ROOT_NAME)

if root == nil or not root:IsA("Frame") then
	warn("[WOB HUD DISABLE] StarterGui/HUD/Root was not found or is not a Frame.")
	return
end

local changedCount = 0

hud.Enabled = false
hud:SetAttribute("WOBDisabledByDefaultOutsideMatch", true)

for _, panelName in ipairs(LEGACY_PANEL_NAMES) do
	local panel = root:FindFirstChild(panelName)

	if panel ~= nil and panel:IsA("GuiObject") then
		panel.Visible = false
		panel:SetAttribute("WOBLegacyPanelDisabled", true)
		changedCount += 1
		print("[WOB HUD DISABLE] disabled " .. panel:GetFullName())
	elseif panel ~= nil then
		warn("[WOB HUD DISABLE] " .. panel:GetFullName() .. " is " .. panel.ClassName .. ", expected GuiObject.")
	else
		warn("[WOB HUD DISABLE] missing StarterGui/HUD/Root/" .. panelName)
	end
end

local matchSeriesPanel = root:FindFirstChild("MatchSeriesPanel")

if matchSeriesPanel ~= nil and matchSeriesPanel:IsA("GuiObject") then
	matchSeriesPanel:SetAttribute("WOBKeptForScore", true)
	print("[WOB HUD DISABLE] kept score panel " .. matchSeriesPanel:GetFullName())
end

local roundStatusPanel = root:FindFirstChild("RoundStatusPanel")

if roundStatusPanel ~= nil and roundStatusPanel:IsA("GuiObject") then
	roundStatusPanel:SetAttribute("WOBKeptForRoundResult", true)
	print("[WOB HUD DISABLE] kept round/result panel " .. roundStatusPanel:GetFullName())
end

print("[WOB HUD DISABLE] complete disabledPanels=" .. tostring(changedCount) .. ". File -> Save to File.")
