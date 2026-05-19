-- One-time Roblox Studio Command Bar recovery helper.
-- Run outside Play Mode. It finds VFX-like donors/templates in the live DataModel,
-- clones recognized candidates into ReplicatedStorage.Shared.Assets.VFX, sanitizes
-- them, and prints the exact manual Save to File follow-up.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

if RunService:IsRunning() then
	warn("[VFX RECOVERY] Stop Play Mode first.")
	return
end

local COMMAND_NAME = "RECOVER_VFX_TEMPLATES_FROM_SCENE_COMMAND"
local DONOR_FOLDER_NAME = "WOB_EditorOnly_AssetDonors"
local GENERATED_ROOT_NAME = "WOB_Generated"

local TARGET_TEMPLATE_NAMES = {
	"TankExplosionTemplate",
	"TankBurningTemplate",
	"RicochetTemplate",
	"ImpactSparksTemplate",
	"MuzzleEffectTemplate",
	"MuzzleFlashTemplate",
	"MuzzleBlastTemplate",
	"SmokeTemplate",
	"DamageHitTemplate",
	"NoPenTemplate",
	"SelfHitTemplate",
}

local ALIASES_BY_TARGET = {
	TankExplosionTemplate = {
		"TankExplosionTemplate",
		"TankExplosionDonor",
		"TankExplosion",
		"Tank Explosion",
		"Resources explosion",
		"Resources Explosion",
		"Explosion",
	},
	TankBurningTemplate = {
		"TankBurningTemplate",
		"TankBurningDonor",
		"TankBurning",
		"Tank Burning",
		"Fire",
		"Burning",
		"Fire Effect",
	},
	RicochetTemplate = {
		"RicochetTemplate",
		"RicochetDonor",
		"Ricochet",
	},
	ImpactSparksTemplate = {
		"ImpactSparksTemplate",
		"ImpactSparksDonor",
		"ImpactSparks",
		"Impact Sparks",
		"Impact",
		"Sparks",
	},
	MuzzleEffectTemplate = {
		"MuzzleEffectTemplate",
		"MuzzleEffectDonor",
		"MuzzleEffect",
		"Muzzle Effect",
	},
	MuzzleFlashTemplate = {
		"MuzzleFlashTemplate",
		"MuzzleFlashDonor",
		"MuzzleFlash",
		"Muzzle Flash",
	},
	MuzzleBlastTemplate = {
		"MuzzleBlastTemplate",
		"MuzzleBlastDonor",
		"MuzzleBlast",
		"Muzzle Blast",
	},
	SmokeTemplate = {
		"SmokeTemplate",
		"SmokeDonor",
		"Smoke",
	},
	DamageHitTemplate = {
		"DamageHitTemplate",
		"DamageHitDonor",
		"DamageHit",
		"Damage Hit",
	},
	NoPenTemplate = {
		"NoPenTemplate",
		"NoPenDonor",
		"NoPen",
		"No Pen",
	},
	SelfHitTemplate = {
		"SelfHitTemplate",
		"SelfHitDonor",
		"SelfHit",
		"Self Hit",
	},
}

local FUZZY_TARGETS = {
	{ Keyword = "resourcesexplosion", Target = "TankExplosionTemplate" },
	{ Keyword = "tankexplosion", Target = "TankExplosionTemplate" },
	{ Keyword = "explosion", Target = "TankExplosionTemplate" },
	{ Keyword = "tankburning", Target = "TankBurningTemplate" },
	{ Keyword = "fireeffect", Target = "TankBurningTemplate" },
	{ Keyword = "burning", Target = "TankBurningTemplate" },
	{ Keyword = "ricochet", Target = "RicochetTemplate" },
	{ Keyword = "impactsparks", Target = "ImpactSparksTemplate" },
	{ Keyword = "impact", Target = "ImpactSparksTemplate" },
	{ Keyword = "sparks", Target = "ImpactSparksTemplate" },
	{ Keyword = "muzzleeffect", Target = "MuzzleEffectTemplate" },
	{ Keyword = "muzzleflash", Target = "MuzzleFlashTemplate" },
	{ Keyword = "muzzleblast", Target = "MuzzleBlastTemplate" },
	{ Keyword = "smoke", Target = "SmokeTemplate" },
	{ Keyword = "damagehit", Target = "DamageHitTemplate" },
	{ Keyword = "nopen", Target = "NoPenTemplate" },
	{ Keyword = "selfhit", Target = "SelfHitTemplate" },
}

local function normalizeName(name)
	return string.lower((tostring(name):gsub("[%s_%-%./]+", "")))
end

local aliasTargetByNormalizedName = {}

for targetName, aliases in pairs(ALIASES_BY_TARGET) do
	for _, alias in ipairs(aliases) do
		aliasTargetByNormalizedName[normalizeName(alias)] = targetName
	end
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[VFX RECOVERY] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil
		end

		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	print("[VFX RECOVERY] Created " .. instance:GetFullName())
	return instance
end

local function findChildPath(root, pathParts)
	local current = root

	for _, name in ipairs(pathParts) do
		if current == nil then
			return nil
		end

		current = current:FindFirstChild(name)
	end

	return current
end

local function getOrCreateVfxFolder()
	local shared = getOrCreate(ReplicatedStorage, "Folder", "Shared")

	if shared == nil then
		return nil
	end

	local assets = getOrCreate(shared, "Folder", "Assets")

	if assets == nil then
		return nil
	end

	return getOrCreate(assets, "Folder", "VFX")
end

local function getBackupFolder()
	local donors = getOrCreate(Workspace, "Folder", DONOR_FOLDER_NAME)

	if donors == nil then
		return nil
	end

	return getOrCreate(donors, "Folder", "VFX_Backups")
end

local function isScriptInstance(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function isLightInstance(instance)
	return instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
end

local function addUnique(values, value)
	if value == nil or value == "" then
		return
	end

	values[tostring(value)] = true
end

local function sortedKeys(values)
	local keys = {}

	for value in pairs(values) do
		table.insert(keys, value)
	end

	table.sort(keys)
	return keys
end

local function collectInfo(rootInstance)
	local info = {
		ParticleEmitters = 0,
		Sounds = 0,
		Beams = 0,
		Trails = 0,
		Lights = 0,
		BaseParts = 0,
		MeshParts = 0,
		SpecialMeshes = 0,
		Decals = 0,
		Textures = 0,
		Scripts = 0,
		ClickDetectors = 0,
		TextureIds = {},
		SoundIds = {},
		MeshIds = {},
		VfxElementCount = 0,
		Score = 0,
	}

	local function inspect(instance)
		if instance:IsA("ParticleEmitter") then
			info.ParticleEmitters += 1
			info.VfxElementCount += 1
			info.Score += 6
			addUnique(info.TextureIds, instance.Texture)
		elseif instance:IsA("Sound") then
			info.Sounds += 1
			info.VfxElementCount += 1
			info.Score += 5
			addUnique(info.SoundIds, instance.SoundId)
		elseif instance:IsA("Beam") then
			info.Beams += 1
			info.VfxElementCount += 1
			info.Score += 4
			addUnique(info.TextureIds, instance.Texture)
		elseif instance:IsA("Trail") then
			info.Trails += 1
			info.VfxElementCount += 1
			info.Score += 4
			addUnique(info.TextureIds, instance.Texture)
		elseif isLightInstance(instance) then
			info.Lights += 1
			info.VfxElementCount += 1
			info.Score += 3
		elseif instance:IsA("MeshPart") then
			info.MeshParts += 1
			info.BaseParts += 1
			info.VfxElementCount += 1
			info.Score += 2
			addUnique(info.MeshIds, instance.MeshId)
		elseif instance:IsA("BasePart") then
			info.BaseParts += 1
			info.Score += 1
		elseif instance:IsA("SpecialMesh") then
			info.SpecialMeshes += 1
			info.VfxElementCount += 1
			info.Score += 2
			addUnique(info.MeshIds, instance.MeshId)
		elseif instance:IsA("Decal") then
			info.Decals += 1
			info.VfxElementCount += 1
			info.Score += 2
			addUnique(info.TextureIds, instance.Texture)
		elseif instance:IsA("Texture") then
			info.Textures += 1
			info.VfxElementCount += 1
			info.Score += 2
			addUnique(info.TextureIds, instance.Texture)
		elseif isScriptInstance(instance) then
			info.Scripts += 1
		elseif instance:IsA("ClickDetector") then
			info.ClickDetectors += 1
		end
	end

	inspect(rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		inspect(descendant)
	end

	return info
end

local function hasVfxContent(instance)
	return collectInfo(instance).VfxElementCount > 0
end

local function inferTargetName(instance)
	local normalized = normalizeName(instance.Name)
	local exactTarget = aliasTargetByNormalizedName[normalized]

	if exactTarget ~= nil then
		return exactTarget
	end

	for _, rule in ipairs(FUZZY_TARGETS) do
		if string.find(normalized, rule.Keyword, 1, true) ~= nil then
			return rule.Target
		end
	end

	return nil
end

local function formatList(values)
	local keys = sortedKeys(values)

	if #keys == 0 then
		return "-"
	end

	return table.concat(keys, ";")
end

local function formatInfo(info)
	return "ParticleEmitters="
		.. tostring(info.ParticleEmitters)
		.. " Sounds="
		.. tostring(info.Sounds)
		.. " Beams="
		.. tostring(info.Beams)
		.. " Trails="
		.. tostring(info.Trails)
		.. " Lights="
		.. tostring(info.Lights)
		.. " BaseParts="
		.. tostring(info.BaseParts)
		.. " Scripts="
		.. tostring(info.Scripts)
		.. " ClickDetectors="
		.. tostring(info.ClickDetectors)
end

local function printCandidate(candidate)
	print(
		"[VFX RECOVERY] Candidate path="
			.. candidate.Path
			.. " name="
			.. candidate.Instance.Name
			.. " class="
			.. candidate.Instance.ClassName
			.. " target="
			.. tostring(candidate.TargetName or "-")
			.. " "
			.. formatInfo(candidate.Info)
	)
	print("[VFX RECOVERY]   ParticleEmitter.Textures=" .. formatList(candidate.Info.TextureIds))
	print("[VFX RECOVERY]   Sound.SoundIds=" .. formatList(candidate.Info.SoundIds))
	print("[VFX RECOVERY]   MeshIds=" .. formatList(candidate.Info.MeshIds))
end

local function addCandidate(candidates, seen, instance)
	local generatedRoot = Workspace:FindFirstChild(GENERATED_ROOT_NAME)

	if generatedRoot ~= nil and (instance == generatedRoot or instance:IsDescendantOf(generatedRoot)) then
		return
	end

	if instance:IsA("Camera") or instance:IsA("Terrain") then
		return
	end

	if seen[instance] == true then
		return
	end

	local info = collectInfo(instance)

	if info.VfxElementCount <= 0 then
		return
	end

	seen[instance] = true
	table.insert(candidates, {
		Instance = instance,
		Path = instance:GetFullName(),
		TargetName = inferTargetName(instance),
		Info = info,
	})
end

local function collectCandidates(searchRoots)
	local candidates = {}
	local seen = {}

	for _, root in ipairs(searchRoots) do
		if root ~= nil then
			for _, child in ipairs(root:GetChildren()) do
				addCandidate(candidates, seen, child)
			end

			for _, descendant in ipairs(root:GetDescendants()) do
				if inferTargetName(descendant) ~= nil then
					addCandidate(candidates, seen, descendant)
				end
			end
		end
	end

	table.sort(candidates, function(left, right)
		return left.Path < right.Path
	end)

	return candidates
end

local function cloneSource(instance)
	local oldArchivable = instance.Archivable
	instance.Archivable = true

	local success, cloneOrError = pcall(function()
		return instance:Clone()
	end)

	instance.Archivable = oldArchivable

	if not success or cloneOrError == nil then
		return nil, tostring(cloneOrError)
	end

	return cloneOrError, nil
end

local function sanitizeTemplate(rootInstance)
	local removedScripts = 0
	local removedClickDetectors = 0

	local function sanitize(instance)
		if isScriptInstance(instance) then
			removedScripts += 1
			instance:Destroy()
			return
		end

		if instance:IsA("ClickDetector") then
			removedClickDetectors += 1
			instance:Destroy()
			return
		end

		if instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.CastShadow = false
		elseif instance:IsA("ParticleEmitter") then
			instance.Enabled = false
		end
	end

	sanitize(rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		sanitize(descendant)
	end

	return {
		RemovedScripts = removedScripts,
		RemovedClickDetectors = removedClickDetectors,
	}
end

local function uniqueChildName(parent, baseName)
	local name = baseName
	local index = 1

	while parent:FindFirstChild(name) ~= nil do
		index += 1
		name = baseName .. "_" .. tostring(index)
	end

	return name
end

local function moveToBackup(instance, reason)
	local backupFolder = getBackupFolder()

	if backupFolder == nil then
		warn("[VFX RECOVERY] Could not create backup folder for " .. instance:GetFullName())
		return false
	end

	local backupName = uniqueChildName(backupFolder, instance.Name .. "_Backup")
	print("[VFX RECOVERY] Backing up " .. instance:GetFullName() .. " -> " .. backupFolder:GetFullName() .. "/" .. backupName .. " reason=" .. reason)
	instance.Name = backupName
	instance.Parent = backupFolder
	return true
end

local function installCandidate(vfxFolder, targetName, candidate)
	local existing = vfxFolder:FindFirstChild(targetName)
	local existingInfo = existing ~= nil and collectInfo(existing) or nil

	if existing ~= nil and existing == candidate.Instance then
		local sanitized = sanitizeTemplate(existing)
		local finalInfo = collectInfo(existing)
		existing:SetAttribute("WOBVfxTemplate", true)
		existing:SetAttribute("VfxTemplateType", targetName)
		existing:SetAttribute("WOBRecoveredBy", COMMAND_NAME)
		existing:SetAttribute("WOBTextureIds", formatList(finalInfo.TextureIds))
		existing:SetAttribute("WOBSoundIds", formatList(finalInfo.SoundIds))
		existing:SetAttribute("WOBRecoverySourcePath", candidate.Path)
		print("[VFX RECOVERY] Existing installed template sanitized " .. targetName .. " removedScripts=" .. tostring(sanitized.RemovedScripts))
		return "kept-existing"
	end

	if existing ~= nil and existingInfo ~= nil and existingInfo.VfxElementCount > 0 and existingInfo.Score >= candidate.Info.Score then
		print("[VFX RECOVERY] Keeping existing " .. existing:GetFullName() .. " score=" .. tostring(existingInfo.Score) .. " over candidate score=" .. tostring(candidate.Info.Score))
		return "kept-existing"
	end

	if existing ~= nil then
		local reason = existingInfo ~= nil and existingInfo.VfxElementCount <= 0 and "existing-empty" or "candidate-better"
		moveToBackup(existing, reason)
	end

	local clone, cloneError = cloneSource(candidate.Instance)

	if clone == nil then
		warn("[VFX RECOVERY] Could not clone " .. candidate.Path .. ": " .. tostring(cloneError))
		return "clone-failed"
	end

	clone.Name = targetName
	clone.Parent = vfxFolder

	local sanitized = sanitizeTemplate(clone)
	local finalInfo = collectInfo(clone)

	clone:SetAttribute("WOBVfxTemplate", true)
	clone:SetAttribute("VfxTemplateType", targetName)
	clone:SetAttribute("WOBRecoveredBy", COMMAND_NAME)
	clone:SetAttribute("WOBTextureIds", formatList(finalInfo.TextureIds))
	clone:SetAttribute("WOBSoundIds", formatList(finalInfo.SoundIds))
	clone:SetAttribute("WOBRecoverySourcePath", candidate.Path)

	print(
		"[VFX RECOVERY] Installed "
			.. targetName
			.. " from "
			.. candidate.Path
			.. " "
			.. formatInfo(finalInfo)
			.. " RemovedScripts="
			.. tostring(sanitized.RemovedScripts)
			.. " RemovedClickDetectors="
			.. tostring(sanitized.RemovedClickDetectors)
	)

	return "installed"
end

local vfxFolder = getOrCreateVfxFolder()

if vfxFolder == nil then
	return
end

local workspaceDonors = Workspace:FindFirstChild(DONOR_FOLDER_NAME)
local workspaceBackups = workspaceDonors ~= nil and workspaceDonors:FindFirstChild("VFX_Backups") or nil
local workspaceQuarantine = workspaceDonors ~= nil and workspaceDonors:FindFirstChild("VFX_Quarantine") or nil
local workspaceUnclassified = workspaceDonors ~= nil and workspaceDonors:FindFirstChild("VFX_Unclassified") or nil
local serverDonors = ServerStorage:FindFirstChild(DONOR_FOLDER_NAME)

local searchRoots = {
	vfxFolder,
	workspaceDonors,
	workspaceBackups,
	workspaceQuarantine,
	workspaceUnclassified,
	serverDonors,
	Workspace,
	Lighting,
}

local candidates = collectCandidates(searchRoots)
local bestCandidateByTarget = {}

print("[VFX RECOVERY] Candidates: " .. tostring(#candidates))

for _, candidate in ipairs(candidates) do
	printCandidate(candidate)

	if candidate.TargetName ~= nil then
		local currentBest = bestCandidateByTarget[candidate.TargetName]

		if currentBest == nil or candidate.Info.Score > currentBest.Info.Score then
			bestCandidateByTarget[candidate.TargetName] = candidate
		end
	end
end

local installed = {}
local kept = {}
local missing = {}

for _, targetName in ipairs(TARGET_TEMPLATE_NAMES) do
	local candidate = bestCandidateByTarget[targetName]

	if candidate ~= nil then
		local status = installCandidate(vfxFolder, targetName, candidate)

		if status == "installed" then
			table.insert(installed, targetName)
		elseif status == "kept-existing" then
			table.insert(kept, targetName)
		else
			table.insert(missing, targetName)
		end
	elseif vfxFolder:FindFirstChild(targetName) ~= nil and hasVfxContent(vfxFolder:FindFirstChild(targetName)) then
		table.insert(kept, targetName)
	else
		table.insert(missing, targetName)
	end
end

print("[VFX RECOVERY] Installed: " .. (#installed > 0 and table.concat(installed, ", ") or "none"))
print("[VFX RECOVERY] Kept existing: " .. (#kept > 0 and table.concat(kept, ", ") or "none"))
print("[VFX RECOVERY] Missing: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
print("[VFX RECOVERY] Candidates: " .. tostring(#candidates))
print("[VFX RECOVERY] Next step: Right click each installed template -> Save to File... into src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx")
