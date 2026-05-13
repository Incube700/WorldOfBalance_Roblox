-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It collects known Workspace VFX donors into ReplicatedStorage/Shared/Assets/VFX.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB VFX] Run this command outside Play Mode.")
	return
end

local DONOR_FOLDER_NAME = "WOB_EditorOnly_AssetDonors"

local DONOR_RULES = {
	{ DonorName = "Resources explosion", TemplateName = "TankExplosionTemplate", Type = "TankDeathExplosion", ReplaceExisting = true },
	{ DonorName = "Resources Explosion", TemplateName = "TankExplosionTemplate", Type = "TankDeathExplosion", ReplaceExisting = true },
	{ DonorName = "Explosion", TemplateName = "TankExplosionTemplate", Type = "TankDeathExplosion", ReplaceExisting = true },
	{ DonorName = "TankExplosion", TemplateName = "TankExplosionTemplate", Type = "TankDeathExplosion", ReplaceExisting = true },
	{ DonorName = "Tank Explosion", TemplateName = "TankExplosionTemplate", Type = "TankDeathExplosion", ReplaceExisting = true },
	{ DonorName = "Fire Effect", TemplateName = "TankBurningTemplate", Type = "BurningTank", ReplaceExisting = true },
	{ DonorName = "Burning", TemplateName = "TankBurningTemplate", Type = "BurningTank", ReplaceExisting = true },
	{ DonorName = "TankBurning", TemplateName = "TankBurningTemplate", Type = "BurningTank", ReplaceExisting = true },
	{ DonorName = "Fireball", TemplateName = "MuzzleBlastTemplate", Type = "MuzzleBlast", ReplaceExisting = false },
	{ DonorName = "Smoke", TemplateName = "SmokeTemplate", Type = "Smoke", ReplaceExisting = false },
	{ DonorName = "Sparks", TemplateName = "ImpactSparksTemplate", Type = "Impact", ReplaceExisting = false },
	{ DonorName = "Shrapnels", TemplateName = "ImpactSparksTemplate", Type = "Impact", ReplaceExisting = false },
	{ DonorName = "Ricochet", TemplateName = "RicochetTemplate", Type = "Ricochet", ReplaceExisting = false },
	{ DonorName = "Impact", TemplateName = "ImpactSparksTemplate", Type = "Impact", ReplaceExisting = false },
	{ DonorName = "MuzzleFlash", TemplateName = "MuzzleFlashTemplate", Type = "MuzzleFlash", ReplaceExisting = false },
	{ DonorName = "MuzzleBlast", TemplateName = "MuzzleBlastTemplate", Type = "MuzzleBlast", ReplaceExisting = false },
}

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

local function countAndSanitize(rootInstance)
	local counts = {
		ParticleEmitters = 0,
		Sounds = 0,
		BaseParts = 0,
		ScriptsRemoved = 0,
	}

	local function sanitize(instance)
		if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
			counts.ScriptsRemoved += 1
			instance:Destroy()
			return
		end

		if instance:IsA("BasePart") then
			counts.BaseParts += 1
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.CastShadow = false
		elseif instance:IsA("ParticleEmitter") then
			counts.ParticleEmitters += 1
			instance.Enabled = false
		elseif instance:IsA("Sound") then
			counts.Sounds += 1
		end
	end

	sanitize(rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		sanitize(descendant)
	end

	return counts
end

local function isUsableDonor(instance)
	return instance ~= nil
		and instance.Archivable
		and not instance:IsA("Script")
		and not instance:IsA("LocalScript")
		and not instance:IsA("ModuleScript")
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

local donorFolder = getOrCreate(Workspace, "Folder", DONOR_FOLDER_NAME)

if donorFolder == nil then
	return
end

local searchRoots = { Workspace, donorFolder }
local installedByTemplateName = {}

local function findDonorByName(donorName)
	for _, searchRoot in ipairs(searchRoots) do
		local direct = searchRoot:FindFirstChild(donorName)

		if direct ~= nil and direct ~= donorFolder then
			return direct
		end
	end

	return nil
end

for _, rule in ipairs(DONOR_RULES) do
	local donorName = rule.DonorName
	local donor = findDonorByName(donorName)

	if donor == nil then
		print("[WOB VFX] Skipped " .. donorName .. " -> source not found")
		continue
	end

	if installedByTemplateName[rule.TemplateName] == true then
		print("[WOB VFX] Skipped " .. donor:GetFullName() .. " -> " .. rule.TemplateName .. " already installed this pass")
		continue
	end

	if not isUsableDonor(donor) then
		print("[WOB VFX] Skipped " .. donor:GetFullName() .. " -> source is not archivable or is script-only")
		continue
	end

	local existingTemplate = vfxFolder:FindFirstChild(rule.TemplateName)

	if existingTemplate ~= nil then
		if rule.ReplaceExisting == true then
			existingTemplate:Destroy()
			print("[WOB VFX] Replaced existing " .. rule.TemplateName)
		else
			print("[WOB VFX] Skipped " .. donor:GetFullName() .. " -> " .. rule.TemplateName .. " already exists")
			continue
		end
	end

	local oldArchivable = donor.Archivable
	donor.Archivable = true

	local success, templateOrError = pcall(function()
		return donor:Clone()
	end)

	donor.Archivable = oldArchivable

	if not success or templateOrError == nil then
		warn("[WOB VFX] Skipped " .. donor:GetFullName() .. " -> clone failed: " .. tostring(templateOrError))
		continue
	end

	local template = templateOrError
	template.Name = rule.TemplateName
	template.Parent = vfxFolder
	template:SetAttribute("WOBVfxTemplate", true)
	template:SetAttribute("VfxTemplateType", rule.Type)
	template:SetAttribute("VfxType", rule.Type)

	local counts = countAndSanitize(template)
	installedByTemplateName[rule.TemplateName] = true

	print("[WOB VFX] Installed " .. rule.TemplateName .. " from " .. donor:GetFullName())
	print(
		"[WOB VFX] ParticleEmitters="
			.. tostring(counts.ParticleEmitters)
			.. " Sounds="
			.. tostring(counts.Sounds)
			.. " BaseParts="
			.. tostring(counts.BaseParts)
			.. " ScriptsRemoved="
			.. tostring(counts.ScriptsRemoved)
	)

	if donor.Parent == Workspace then
		donor.Parent = donorFolder
		print("[WOB VFX] Moved original donor to " .. donor:GetFullName())
	else
		print("[WOB VFX] Original donor kept at " .. donor:GetFullName())
	end
end

print("[WOB VFX] VFX collection pass complete. File -> Save to File.")
