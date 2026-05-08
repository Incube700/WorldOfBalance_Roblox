-- Editor-only Roblox Studio Command Bar helper.
-- Hides Playable Shell panels in StarterGui so they do not cover the 3D editor.
-- Run outside Play Mode. Does not change WOBPlayableShellGui.Enabled.

local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

if RunService:IsRunning() then
	warn("[WOB SHELL] Run this command outside Play Mode.")
	return
end

local gui = StarterGui:FindFirstChild("WOBPlayableShellGui")

if gui == nil then
	warn("[WOB SHELL] StarterGui/WOBPlayableShellGui was not found.")
	return
end

local function setPanelVisible(name, isVisible)
	local panel = gui:FindFirstChild(name)

	if panel == nil then
		warn("[WOB SHELL] Missing " .. name .. " under StarterGui/WOBPlayableShellGui.")
		return
	end

	if panel:IsA("GuiObject") then
		panel.Visible = isVisible
	end
end

setPanelVisible("MainMenuPanel", false)
setPanelVisible("ResultScreenPanel", false)
setPanelVisible("StatsPanel", false)

print("[WOB SHELL] Editor shell panels hidden. WOBPlayableShellGui.Enabled was not changed.")
