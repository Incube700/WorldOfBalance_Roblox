-- Diagnostic Roblox Studio Command Bar helper for HUD visibility.
-- Run during Play Mode if a duplicate panel is visible. It prints PlayerGui/HUD frames and label text.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local function collectTextLabels(frame)
	local labels = {}

	for _, descendant in ipairs(frame:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			table.insert(labels, descendant.Name .. "=" .. string.format("%q", descendant.Text))
		end
	end

	return table.concat(labels, ", ")
end

local function printHudFrames(hud, label)
	if hud == nil then
		warn("[WOB HUD DIAG] " .. label .. "/HUD not found")
		return
	end

	print("[WOB HUD DIAG] " .. label .. " " .. hud:GetFullName())

	for _, descendant in ipairs(hud:GetDescendants()) do
		if descendant:IsA("Frame") then
			print(("[WOB HUD DIAG] %s Visible=%s Position=%s Size=%s BackgroundTransparency=%s TextLabels={%s}"):format(
				descendant:GetFullName(),
				tostring(descendant.Visible),
				tostring(descendant.Position),
				tostring(descendant.Size),
				tostring(descendant.BackgroundTransparency),
				collectTextLabels(descendant)
			))
		end
	end
end

local localPlayer = Players.LocalPlayer

if localPlayer ~= nil then
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local playerHud = playerGui and playerGui:FindFirstChild("HUD")
	printHudFrames(playerHud, "PlayerGui")
else
	warn("[WOB HUD DIAG] Players.LocalPlayer is nil. Run during Play Mode from the client context to inspect PlayerGui/HUD.")
end

printHudFrames(StarterGui:FindFirstChild("HUD"), "StarterGui")
