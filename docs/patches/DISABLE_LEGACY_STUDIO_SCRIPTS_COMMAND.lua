-- One-time Roblox Studio Command Bar cleanup for legacy Studio-owned scripts.
-- Run outside Play Mode after Rojo-managed Server/Client scripts are synced.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

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
		instance.Enabled = false
		print("[WOB LEGACY] Disabled " .. instance:GetFullName())
	end
end

print("[WOB LEGACY] Legacy script disable pass complete. File -> Save to File.")
