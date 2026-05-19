local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local HUD_GUI_NAME = "HUD"
local HUD_ROOT_NAME = "Root"

local function shouldHideHudByDefault()
	return localPlayer:GetAttribute("PlayerMode") ~= "InMatch"
end

local function applyDefaultHudVisibility(hud)
	if hud ~= nil and hud:IsA("ScreenGui") and shouldHideHudByDefault() then
		hud.Enabled = false
	end
end

local function hasValidHud(container)
	local hud = container:FindFirstChild(HUD_GUI_NAME)

	if hud == nil or not hud:IsA("ScreenGui") then
		return false, hud
	end

	local root = hud:FindFirstChild(HUD_ROOT_NAME)

	return root ~= nil and root:IsA("Frame"), hud
end

local function ensureHudInPlayerGui()
	local playerHasHud, playerHud = hasValidHud(playerGui)

	if playerHasHud then
		applyDefaultHudVisibility(playerHud)
		print("[WOB HUD] PlayerGui/HUD already available")
		return
	end

	local starterHasHud, starterHud = hasValidHud(StarterGui)

	if not starterHasHud or starterHud == nil then
		warn("[WOB HUD] StarterGui/HUD template is missing or invalid; run docs/patches/CREATE_MODULAR_HUD_COMMAND.lua outside Play Mode and save the file.")
		return
	end

	local staleHud = playerGui:FindFirstChild(HUD_GUI_NAME)

	if staleHud ~= nil then
		staleHud:Destroy()
	end

	local clonedHud = starterHud:Clone()
	clonedHud.ResetOnSpawn = false
	applyDefaultHudVisibility(clonedHud)
	clonedHud.Parent = playerGui

	print("[WOB HUD] cloned StarterGui/HUD into PlayerGui/HUD")
end

ensureHudInPlayerGui()

task.delay(1, ensureHudInPlayerGui)
