-- One-time Roblox Studio Command Bar cleanup for legacy Studio-owned scripts.
-- Run outside Play Mode after Rojo-managed Server/Client scripts are synced.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB LEGACY] Run this command outside Play Mode.")
	return
end

local targets = {
	{ Parent = ServerScriptService:FindFirstChild("Services"), Name = "WOBGameplayServer" },
	{ Parent = ServerScriptService:FindFirstChild("Services"), Name = "WOBDummyRespawnServer" },
	{ Parent = ServerScriptService:FindFirstChild("Services"), Name = "WOBPerformanceServer" },
	{ Parent = ServerScriptService:FindFirstChild("Services"), Name = "WOBProjectileVisualEnhancer" },
	{ Parent = StarterPlayer:FindFirstChild("StarterPlayerScripts"), Name = "WOBClientController" },
	{ Parent = StarterGui:FindFirstChild("HUD"), Name = "WOBHudController" },
}

for _, target in ipairs(targets) do
	local parent = target.Parent
	local instance = parent ~= nil and parent:FindFirstChild(target.Name) or nil

	if instance ~= nil and (instance:IsA("Script") or instance:IsA("LocalScript")) then
		if instance.Enabled ~= false then
			instance.Enabled = false
			print("[WOB LEGACY] Disabled " .. instance:GetFullName())
		else
			print("[WOB LEGACY] Kept disabled " .. instance:GetFullName())
		end
	elseif instance ~= nil then
		print("[WOB LEGACY] Kept " .. instance:GetFullName() .. " (" .. instance.ClassName .. ")")
	elseif parent ~= nil then
		print("[WOB LEGACY] Not found " .. parent:GetFullName() .. "/" .. target.Name)
	else
		print("[WOB LEGACY] Parent missing for " .. target.Name)
	end
end

print("[WOB LEGACY] Legacy script disable pass complete. File -> Save to File.")
