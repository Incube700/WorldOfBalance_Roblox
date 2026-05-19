-- Roblox Studio Command Bar helper.
-- Audits StarterGui HUD objects that look like legacy Player HP / Enemy HP / Reload panels.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local KEYWORDS = {
	"player hp",
	"you hp",
	"enemy hp",
	"opponent hp",
	"reload",
	"ready",
}

local PANEL_NAMES = {
	EnemyStatusPanel = true,
	WeaponStatusPanel = true,
	PlayerStatusPanel = true,
}

local function lowerText(value)
	return string.lower(tostring(value or ""))
end

local function containsKeyword(text)
	local lower = lowerText(text)

	for _, keyword in ipairs(KEYWORDS) do
		if string.find(lower, keyword, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function describeGuiObject(object)
	local visible = object:IsA("GuiObject") and tostring(object.Visible) or "-"
	local enabled = object:IsA("ScreenGui") and tostring(object.Enabled) or "-"
	local text = ""

	if object:IsA("TextLabel") or object:IsA("TextButton") then
		text = object.Text
	end

	print(
		("[WOB HUD AUDIT] candidate path=%s class=%s visible=%s enabled=%s text=%s"):format(
			object:GetFullName(),
			object.ClassName,
			visible,
			enabled,
			tostring(text)
		)
	)
end

local function inspectRoot(root, label)
	if root == nil then
		warn("[WOB HUD AUDIT] missing " .. label)
		return 0
	end

	local count = 0

	for _, descendant in ipairs(root:GetDescendants()) do
		local matchesName = PANEL_NAMES[descendant.Name] == true or containsKeyword(descendant.Name)
		local matchesText = false

		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			matchesText = containsKeyword(descendant.Text)
		end

		if matchesName or matchesText then
			describeGuiObject(descendant)
			count += 1
		end
	end

	print("[WOB HUD AUDIT] " .. label .. " candidates=" .. tostring(count))
	return count
end

local total = inspectRoot(StarterGui, "StarterGui")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer ~= nil and localPlayer:FindFirstChild("PlayerGui") or nil

if playerGui ~= nil then
	total += inspectRoot(playerGui, "PlayerGui")
end

print("[WOB HUD AUDIT] complete candidates=" .. tostring(total) .. ". No objects were changed.")
