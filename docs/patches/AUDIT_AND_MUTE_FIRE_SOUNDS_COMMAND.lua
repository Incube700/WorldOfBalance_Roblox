-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Audits known sound containers and mutes fire/burning/campfire loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
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

local function lowerText(value)
	return string.lower(tostring(value or ""))
end

local function containsFireKeyword(value)
	local text = lowerText(value)

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

local function formatSound(sound)
	return ("%s SoundId=%s Volume=%s Looped=%s Playing=%s"):format(
		sound:GetFullName(),
		tostring(sound.SoundId),
		tostring(sound.Volume),
		tostring(sound.Looped),
		tostring(sound.Playing)
	)
end

local mutedCount = 0
local removedUnsafeCount = 0
local auditedSoundCount = 0
local mutedSounds = {}

local function shouldMuteSound(sound)
	return containsFireKeyword(sound.Name)
		or containsFireKeyword(sound:GetFullName())
		or containsFireKeyword(sound.SoundId)
end

local function muteSound(sound)
	if mutedSounds[sound] == true then
		return
	end

	mutedSounds[sound] = true
	sound.Volume = 0
	sound.Looped = false

	pcall(function()
		sound:Stop()
	end)

	pcall(function()
		sound.Playing = false
	end)

	mutedCount += 1
	print("[FIRE SOUND CLEAN] muted " .. formatSound(sound))
end

local function auditSounds(root, label)
	if root == nil then
		warn("[FIRE SOUND CLEAN] missing " .. label)
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Sound") then
			auditedSoundCount += 1
			print("[FIRE SOUND CLEAN] sound " .. formatSound(descendant))

			if shouldMuteSound(descendant) then
				muteSound(descendant)
			end
		end
	end
end

local function sanitizeTankBurningTemplate()
	local vfxFolder = getSharedVfxFolder()
	local template = vfxFolder ~= nil and vfxFolder:FindFirstChild("TankBurningTemplate") or nil

	if template == nil then
		warn("[FIRE SOUND CLEAN] ReplicatedStorage.Shared.Assets.VFX.TankBurningTemplate was not found.")
		return
	end

	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("Sound") then
			muteSound(descendant)
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ClickDetector") then
			print("[FIRE SOUND CLEAN] removed unsafe descendant " .. descendant:GetFullName())
			descendant:Destroy()
			removedUnsafeCount += 1
		end
	end

	template:SetAttribute("WOBTemplateSoundsMuted", true)
	template:SetAttribute("WOBMutedSoundCount", mutedCount)
end

local vfxFolder = getSharedVfxFolder()
auditSounds(vfxFolder, "ReplicatedStorage.Shared.Assets.VFX")
auditSounds(Workspace:FindFirstChild("WOB_Generated"), "Workspace.WOB_Generated")
auditSounds(Workspace:FindFirstChild("WOB_Runtime"), "Workspace.WOB_Runtime")
auditSounds(Workspace:FindFirstChild("WOB_EditorOnly_AssetDonors"), "Workspace.WOB_EditorOnly_AssetDonors")
auditSounds(ServerStorage, "ServerStorage")
auditSounds(SoundService, "SoundService")
sanitizeTankBurningTemplate()

print(
	("[FIRE SOUND CLEAN] complete auditedSounds=%d muted=%d unsafeRemoved=%d. File -> Save to File."):format(
		auditedSoundCount,
		mutedCount,
		removedUnsafeCount
	)
)
