-- One-time Roblox Studio Command Bar cleanup for old HUD objects.
-- Run outside Play Mode after CREATE_MODULAR_HUD_COMMAND.lua. It keeps StarterGui/HUD/Root and modular panels.

local StarterGui = game:GetService("StarterGui")

local EXPECTED_PANELS = {
	EnemyStatusPanel = true,
	WeaponStatusPanel = true,
	PlayerStatusPanel = true,
	RoundStatusPanel = true,
	MatchSeriesPanel = true,
}

local LEGACY_NAMES = {
	MainPanel = true,
	DummyHpLabel = true,
	DummyHpBack = true,
	DummyHpFill = true,
	ReloadLabel = true,
	ReloadBack = true,
	ReloadFill = true,
	PlayerHpLabel = true,
	PlayerHpBack = true,
	PlayerHpFill = true,
	RoundResultLabel = true,
	RestartHintLabel = true,
	SeriesStatusLabel = true,
	MatchResultLabel = true,
	FeedbackLabel = true,
	WOBHudController = true,
	WOBRoundStatusOverlayGui = true,
	WOBRoundStatusEmergencyGui = true,
	WOBSeriesStatusRuntimeGui = true,
}

local hud = StarterGui:FindFirstChild("HUD")

if hud == nil then
	warn("[WOB HUD CLEANUP] StarterGui/HUD not found. Nothing to clean.")
	return
end

if not hud:IsA("ScreenGui") then
	warn("[WOB HUD CLEANUP] StarterGui/HUD is " .. hud.ClassName .. ", expected ScreenGui. Nothing was removed.")
	return
end

local root = hud:FindFirstChild("Root")

if root == nil or not root:IsA("Frame") then
	warn("[WOB HUD CLEANUP] StarterGui/HUD/Root missing. Run docs/patches/CREATE_MODULAR_HUD_COMMAND.lua first. Nothing was removed.")
	return
end

local function isExpectedModularPanel(instance)
	return instance.Parent == root and EXPECTED_PANELS[instance.Name] == true
end

local function isInsideExpectedPanel(instance)
	local current = instance

	while current ~= nil and current ~= hud do
		if isExpectedModularPanel(current) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function shouldRemove(instance)
	if instance == hud or instance == root then
		return false
	end

	if isExpectedModularPanel(instance) or isInsideExpectedPanel(instance) then
		return false
	end

	if LEGACY_NAMES[instance.Name] == true then
		return true
	end

	return false
end

local toRemove = {}

for _, descendant in ipairs(hud:GetDescendants()) do
	if shouldRemove(descendant) then
		table.insert(toRemove, descendant)
	end
end

for _, child in ipairs(hud:GetChildren()) do
	if shouldRemove(child) then
		table.insert(toRemove, child)
	end
end

local removed = {}
local seen = {}

for _, instance in ipairs(toRemove) do
	if instance.Parent ~= nil and seen[instance] ~= true then
		seen[instance] = true
		table.insert(removed, instance:GetFullName())
		instance:Destroy()
	end
end

print("[WOB HUD CLEANUP] Legacy HUD cleanup complete. Removed " .. #removed .. " object(s).")

for _, name in ipairs(removed) do
	print("[WOB HUD CLEANUP] Removed " .. name)
end

print("[WOB HUD CLEANUP] Kept StarterGui/HUD/Root and modular panels. File -> Save to File when the layout looks correct.")
