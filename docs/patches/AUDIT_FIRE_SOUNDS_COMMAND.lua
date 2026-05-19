-- Roblox Studio Command Bar helper.
-- Audit-only: prints fire/burning/campfire-related sounds without mutating anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

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

local function formatSound(sound)
	return ("%s SoundId=%s Volume=%s Looped=%s Playing=%s"):format(
		sound:GetFullName(),
		tostring(sound.SoundId),
		tostring(sound.Volume),
		tostring(sound.Looped),
		tostring(sound.Playing)
	)
end

local function auditSounds(root, label, totals)
	if root == nil then
		warn("[FIRE SOUND AUDIT] missing " .. label)
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Sound") then
			totals.Sounds += 1
			local suspicious = containsKeyword(descendant.Name)
				or containsKeyword(descendant:GetFullName())
				or containsKeyword(descendant.SoundId)

			if suspicious then
				totals.Suspicious += 1
				warn("[FIRE SOUND AUDIT] suspicious " .. formatSound(descendant))
			else
				print("[FIRE SOUND AUDIT] sound " .. formatSound(descendant))
			end
		end
	end
end

local totals = {
	Sounds = 0,
	Suspicious = 0,
}

auditSounds(getSharedVfxFolder(), "ReplicatedStorage.Shared.Assets.VFX", totals)
auditSounds(SoundService, "SoundService", totals)
auditSounds(Workspace:FindFirstChild("WOB_Generated"), "Workspace.WOB_Generated", totals)
auditSounds(Workspace:FindFirstChild("WOB_Runtime"), "Workspace.WOB_Runtime", totals)

print(
	("[FIRE SOUND AUDIT] complete sounds=%d suspicious=%d. No objects were changed."):format(
		totals.Sounds,
		totals.Suspicious
	)
)
