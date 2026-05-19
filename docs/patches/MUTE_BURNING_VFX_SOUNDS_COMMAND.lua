-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Mutes unsafe burning template sounds without deleting the VFX template.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB VFX MUTE] Run this command outside Play Mode.")
	return
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil
local vfxFolder = assets ~= nil and assets:FindFirstChild("VFX") or nil
local template = vfxFolder ~= nil and vfxFolder:FindFirstChild("TankBurningTemplate") or nil

if template == nil then
	warn("[WOB VFX MUTE] ReplicatedStorage.Shared.Assets.VFX.TankBurningTemplate was not found.")
	return
end

local soundCount = 0
local removedRuntimeScriptCount = 0

for _, descendant in ipairs(template:GetDescendants()) do
	if descendant:IsA("Sound") then
		soundCount += 1
		descendant.Volume = 0
		descendant.Looped = false

		pcall(function()
			descendant:Stop()
		end)

		pcall(function()
			descendant.Playing = false
		end)

		print(
			("[WOB VFX MUTE] Muted sound %s soundId=%s"):format(
				descendant:GetFullName(),
				tostring(descendant.SoundId)
			)
		)
	elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ClickDetector") then
		removedRuntimeScriptCount += 1
		print("[WOB VFX MUTE] Removed unsafe descendant " .. descendant:GetFullName())
		descendant:Destroy()
	end
end

template:SetAttribute("WOBTemplateSoundsMuted", true)
template:SetAttribute("WOBMutedSoundCount", soundCount)

print(
	("[WOB VFX MUTE] Complete for %s. Sounds muted=%d unsafe descendants removed=%d. File -> Save to File."):format(
		template:GetFullName(),
		soundCount,
		removedRuntimeScriptCount
	)
)
