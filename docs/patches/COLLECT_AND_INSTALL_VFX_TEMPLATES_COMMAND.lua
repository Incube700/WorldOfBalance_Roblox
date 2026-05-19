-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. It collects obvious Workspace VFX donors into
-- ReplicatedStorage/Shared/Assets/VFX as real template instances.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB VFX] Run this command outside Play Mode.")
	return
end

local DONOR_FOLDER_NAME = "WOB_EditorOnly_AssetDonors"
local GENERATED_ROOT_NAME = "WOB_Generated"
local REPLACE_EXISTING_TEMPLATES = true

local DONOR_RULES = {
	{
		TemplateName = "TankExplosionTemplate",
		Type = "TankDeathExplosion",
		DonorNames = { "Resources explosion", "Resources Explosion", "Explosion" },
	},
	{
		TemplateName = "TankBurningTemplate",
		Type = "BurningTank",
		DonorNames = { "Burning", "Fire", "TankBurning", "Tank Burning", "Fire Effect" },
	},
	{
		TemplateName = "RicochetTemplate",
		Type = "Ricochet",
		DonorNames = { "Ricochet" },
	},
	{
		TemplateName = "ImpactSparksTemplate",
		Type = "Impact",
		DonorNames = { "Impact", "Sparks" },
	},
	{
		TemplateName = "MuzzleFlashTemplate",
		Type = "MuzzleFlash",
		DonorNames = { "MuzzleFlash", "Muzzle Flash" },
	},
	{
		TemplateName = "MuzzleBlastTemplate",
		Type = "MuzzleBlast",
		DonorNames = { "MuzzleBlast", "Muzzle Blast" },
	},
	{
		TemplateName = "SmokeTemplate",
		Type = "Smoke",
		DonorNames = { "Smoke" },
	},
}

local function normalizeName(name)
	return string.lower((tostring(name):gsub("[%s_%-%./]+", "")))
end

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

local function isScriptInstance(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function isTemplateInstance(instance)
	return instance:IsA("Folder")
		or instance:IsA("Model")
		or instance:IsA("BasePart")
		or instance:IsA("Attachment")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Sound")
end

local function countAndSanitize(rootInstance)
	local counts = {
		ParticleEmitters = 0,
		Sounds = 0,
		BaseParts = 0,
		ScriptsRemoved = 0,
	}

	local function sanitize(instance)
		if isScriptInstance(instance) then
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
	return instance ~= nil and not isScriptInstance(instance)
end

local function formatCounts(counts)
	return "ParticleEmitters="
		.. tostring(counts.ParticleEmitters)
		.. " Sounds="
		.. tostring(counts.Sounds)
		.. " BaseParts="
		.. tostring(counts.BaseParts)
		.. " ScriptsRemoved="
		.. tostring(counts.ScriptsRemoved)
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

local generatedRoot = Workspace:FindFirstChild(GENERATED_ROOT_NAME)

local function isExcludedWorkspaceInstance(instance)
	if instance == donorFolder or instance:IsDescendantOf(donorFolder) then
		return true
	end

	if generatedRoot ~= nil and (instance == generatedRoot or instance:IsDescendantOf(generatedRoot)) then
		return true
	end

	return false
end

local function collectTemplateNames()
	local names = {}

	for _, child in ipairs(vfxFolder:GetChildren()) do
		if child.Name ~= "VfxTemplateCatalog" and isTemplateInstance(child) then
			table.insert(names, child.Name)
		end
	end

	table.sort(names)
	return names
end

local function printTemplateList(prefix)
	local names = collectTemplateNames()

	if #names == 0 then
		print(prefix .. " none")
	else
		print(prefix .. " " .. table.concat(names, ", "))
	end
end

printTemplateList("[WOB VFX] Existing templates:")

for _, existingTemplate in ipairs(vfxFolder:GetChildren()) do
	if existingTemplate.Name ~= "VfxTemplateCatalog" and isTemplateInstance(existingTemplate) then
		local counts = countAndSanitize(existingTemplate)
		print("[WOB VFX] Sanitized existing " .. existingTemplate.Name .. " " .. formatCounts(counts))
	end
end

local function buildDonorNameLookup(rule)
	local lookup = {}

	for _, donorName in ipairs(rule.DonorNames) do
		lookup[normalizeName(donorName)] = donorName
	end

	return lookup
end

local function findDirectDonor(root, lookup)
	for _, child in ipairs(root:GetChildren()) do
		if isUsableDonor(child) and lookup[normalizeName(child.Name)] ~= nil then
			return child, lookup[normalizeName(child.Name)]
		end
	end

	return nil, nil
end

local function findRecursiveDonor(root, lookup, excludeFunc)
	for _, descendant in ipairs(root:GetDescendants()) do
		if (excludeFunc == nil or excludeFunc(descendant) ~= true)
			and isUsableDonor(descendant)
			and lookup[normalizeName(descendant.Name)] ~= nil
		then
			return descendant, lookup[normalizeName(descendant.Name)]
		end
	end

	return nil, nil
end

local function findDonorForRule(rule)
	local lookup = buildDonorNameLookup(rule)
	local donor, matchedName = findDirectDonor(donorFolder, lookup)

	if donor ~= nil then
		return donor, matchedName
	end

	donor, matchedName = findDirectDonor(Workspace, lookup)

	if donor ~= nil and not isExcludedWorkspaceInstance(donor) then
		return donor, matchedName
	end

	donor, matchedName = findRecursiveDonor(donorFolder, lookup)

	if donor ~= nil then
		return donor, matchedName
	end

	return findRecursiveDonor(Workspace, lookup, isExcludedWorkspaceInstance)
end

local installedCount = 0
local foundCount = 0

for _, rule in ipairs(DONOR_RULES) do
	local donor, matchedName = findDonorForRule(rule)

	if donor == nil then
		print("[WOB VFX] Skipped missing donor for " .. rule.TemplateName .. ": " .. table.concat(rule.DonorNames, ", "))
		continue
	end

	foundCount += 1
	print("[WOB VFX] Found donor " .. donor:GetFullName() .. " matched '" .. tostring(matchedName) .. "' -> " .. rule.TemplateName)

	local existingTemplate = vfxFolder:FindFirstChild(rule.TemplateName)

	if existingTemplate ~= nil then
		if REPLACE_EXISTING_TEMPLATES then
			existingTemplate:Destroy()
			print("[WOB VFX] Replaced existing " .. rule.TemplateName)
		else
			local counts = countAndSanitize(existingTemplate)
			print("[WOB VFX] Kept existing " .. rule.TemplateName .. " " .. formatCounts(counts))
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
	installedCount += 1

	print("[WOB VFX] Installed " .. rule.TemplateName .. " from " .. donor:GetFullName() .. " " .. formatCounts(counts))

	if donor:IsDescendantOf(Workspace) and not donor:IsDescendantOf(donorFolder) then
		donor.Parent = donorFolder
		print("[WOB VFX] Moved original donor to " .. donor:GetFullName())
	else
		print("[WOB VFX] Original donor kept at " .. donor:GetFullName())
	end
end

print("[WOB VFX] Found donors: " .. tostring(foundCount))
print("[WOB VFX] Installed templates: " .. tostring(installedCount))
printTemplateList("[WOB VFX] Final templates:")
print("[WOB VFX] VFX collection pass complete. File -> Save to File if this Studio scene owns the installed assets.")
