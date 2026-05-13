-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It installs a Workspace Toolbox explosion as a reusable VFX template.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB VFX] Run this command outside Play Mode.")
	return
end

local SOURCE_NAMES = {
	"Resources explosion",
	"Resources Explosion",
	"Explosion",
	"TankExplosion",
	"Tank Explosion",
}

local TEMPLATE_NAME = "TankExplosionTemplate"

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB VFX] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil
		end

		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	print("[WOB VFX] Created " .. instance:GetFullName())
	return instance
end

local function findSourceAsset()
	for _, sourceName in ipairs(SOURCE_NAMES) do
		local source = Workspace:FindFirstChild(sourceName)

		if source ~= nil then
			return source
		end
	end

	local donors = Workspace:FindFirstChild("WOB_EditorOnly_AssetDonors")

	if donors ~= nil then
		for _, sourceName in ipairs(SOURCE_NAMES) do
			local source = donors:FindFirstChild(sourceName)

			if source ~= nil then
				return source
			end
		end
	end

	return nil
end

local sourceAsset = findSourceAsset()

if sourceAsset == nil then
	warn("[WOB VFX] Source explosion asset not found in Workspace. Insert Toolbox explosion asset first.")
	return
end

local shared = getOrCreate(ReplicatedStorage, "Folder", "Shared")

if shared == nil then
	return
end

local assets = getOrCreate(shared, "Folder", "Assets")

if assets == nil then
	return
end

local vfxFolder = getOrCreate(assets, "Folder", "VFX")

if vfxFolder == nil then
	return
end

local oldArchivable = sourceAsset.Archivable
sourceAsset.Archivable = true

local success, templateOrError = pcall(function()
	return sourceAsset:Clone()
end)

sourceAsset.Archivable = oldArchivable

if not success or templateOrError == nil then
	warn("[WOB VFX] Could not clone source explosion asset: " .. tostring(templateOrError))
	return
end

local existingTemplate = vfxFolder:FindFirstChild(TEMPLATE_NAME)

if existingTemplate ~= nil then
	existingTemplate:Destroy()
	print("[WOB VFX] Replaced existing " .. TEMPLATE_NAME)
end

local template = templateOrError
template.Name = TEMPLATE_NAME
template.Parent = vfxFolder
template:SetAttribute("WOBVfxTemplate", true)
template:SetAttribute("VfxTemplateType", "TankDeathExplosion")
template:SetAttribute("VfxType", "TankDeathExplosion")

local particleEmitters = 0
local sounds = 0
local baseParts = 0
local scriptsRemoved = 0

local function sanitizeInstance(instance)
	if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
		scriptsRemoved += 1
		instance:Destroy()
		return
	end

	if instance:IsA("BasePart") then
		baseParts += 1
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.CastShadow = false
	elseif instance:IsA("ParticleEmitter") then
		particleEmitters += 1
		instance.Enabled = false
	elseif instance:IsA("Sound") then
		sounds += 1
	end
end

sanitizeInstance(template)

for _, descendant in ipairs(template:GetDescendants()) do
	sanitizeInstance(descendant)
end

print("[WOB VFX] Installed TankExplosionTemplate from " .. sourceAsset:GetFullName())
print("[WOB VFX] ParticleEmitters: " .. tostring(particleEmitters) .. ", Sounds: " .. tostring(sounds) .. ", BaseParts: " .. tostring(baseParts))

if scriptsRemoved > 0 then
	print("[WOB VFX] Removed scripts from template clone: " .. tostring(scriptsRemoved))
end

print("[WOB VFX] Original source asset kept at " .. sourceAsset:GetFullName() .. ". File -> Save to File.")
