-- Roblox Studio Command Bar helper.
-- Mutates only reviewed fire/burning/campfire sounds, and is disabled by default.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script mutates VFX sounds. Set ENABLE_MUTATION=true manually after audit.")
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

if RunService:IsRunning() then
	warn("[FIRE SOUND CLEAN] Run this command outside Play Mode.")
	return
end

local FIRE_KEYWORDS = {
	"fire",
	"burning",
	"campfire",
	"tankburningtemplate",
}

local function containsKeyword(value)
	local text = string.lower(tostring(value or ""))

	for _, keyword in ipairs(FIRE_KEYWORDS) do
		if string.find(text, keyword, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function getSharedVfxFolder()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil
	return assets ~= nil and assets:FindFirstChild("VFX") or nil
end

local function shouldMuteSound(sound)
	return containsKeyword(sound.Name)
		or containsKeyword(sound:GetFullName())
		or containsKeyword(sound.SoundId)
end

local function muteSound(sound, totals)
	sound.Volume = 0
	sound.Looped = false

	pcall(function()
		sound:Stop()
	end)

	pcall(function()
		sound.Playing = false
	end)

	totals.Muted += 1
	print(
		("[FIRE SOUND CLEAN] muted %s SoundId=%s"):format(
			sound:GetFullName(),
			tostring(sound.SoundId)
		)
	)
end

local function sanitizeUnsafeTemplateDescendants(root, totals)
	if root == nil then
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ClickDetector") then
			totals.RemovedUnsafe += 1
			print("[FIRE SOUND CLEAN] removed unsafe descendant " .. descendant:GetFullName())
			descendant:Destroy()
		end
	end
end

local function scanSounds(root, label, totals)
	if root == nil then
		warn("[FIRE SOUND CLEAN] missing " .. label)
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Sound") and shouldMuteSound(descendant) then
			muteSound(descendant, totals)
		end
	end
end

local totals = {
	Muted = 0,
	RemovedUnsafe = 0,
}

local vfxFolder = getSharedVfxFolder()
local tankBurningTemplate = vfxFolder ~= nil and vfxFolder:FindFirstChild("TankBurningTemplate") or nil

scanSounds(vfxFolder, "ReplicatedStorage.Shared.Assets.VFX", totals)
scanSounds(SoundService, "SoundService", totals)
scanSounds(Workspace:FindFirstChild("WOB_Generated"), "Workspace.WOB_Generated", totals)
scanSounds(Workspace:FindFirstChild("WOB_Runtime"), "Workspace.WOB_Runtime", totals)
sanitizeUnsafeTemplateDescendants(tankBurningTemplate, totals)

if tankBurningTemplate ~= nil then
	tankBurningTemplate:SetAttribute("WOBTemplateSoundsMuted", true)
	tankBurningTemplate:SetAttribute("WOBMutedSoundCount", totals.Muted)
end

print(
	("[FIRE SOUND CLEAN] complete muted=%d unsafeRemoved=%d. File -> Save to File after review."):format(
		totals.Muted,
		totals.RemovedUnsafe
	)
)
