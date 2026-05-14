-- Full VFX organization pass for Stable Fun Duel v0.1.
-- Run this in Roblox Studio Command Bar outside Play Mode.

local RunService = game:GetService("RunService")
if RunService:IsRunning() then
	warn("[WOB VFX ORGANIZER] Stop Play Mode first.")
	return
end

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")

local COMMAND_NAME = "ORGANIZE_ALL_VFX_ASSETS_COMMAND"
local REPORT_PATH = "docs/VFX_ORGANIZER_REPORT.md"
local DONOR_FOLDER_NAME = "WOB_EditorOnly_AssetDonors"
local BACKUPS_FOLDER_NAME = "VFX_Backups"
local QUARANTINE_FOLDER_NAME = "VFX_Quarantine"
local UNCLASSIFIED_FOLDER_NAME = "VFX_Unclassified"
local GENERATED_ROOT_NAME = "WOB_Generated"

local TIMESTAMP = os.date("!%Y%m%dT%H%M%SZ")
local REPORT_VALUE_CHUNK_SIZE = 180000

local TARGET_ORDER = {
	"MuzzleEffectTemplate",
	"MuzzleFlashTemplate",
	"MuzzleBlastTemplate",
	"SmokeTemplate",
	"ImpactSparksTemplate",
	"RicochetTemplate",
	"DamageHitTemplate",
	"NoPenTemplate",
	"SelfHitTemplate",
	"TankExplosionTemplate",
	"TankBurningTemplate",
}

local TARGET_SET = {}
for _, templateName in ipairs(TARGET_ORDER) do
	TARGET_SET[templateName] = true
end

local foundCandidateLines = {}
local classifiedLines = {}
local installedLines = {}
local quarantinedLines = {}
local suspiciousLines = {}
local materialVariantLines = {}
local aggregateTextureIds = {}
local aggregateTextureSet = {}
local aggregateSoundIds = {}
local aggregateSoundSet = {}
local aggregateDecalTextureIds = {}
local aggregateDecalTextureSet = {}
local aggregateMeshIds = {}
local aggregateMeshSet = {}

local function logInfo(message)
	local line = "[WOB VFX ORGANIZER] " .. message
	print(line)
	return line
end

local function logWarn(message)
	local line = "[WOB VFX ORGANIZER] " .. message
	warn(line)
	return line
end

local function safeFullName(instance)
	if instance == nil then
		return "<nil>"
	end

	local ok, fullName = pcall(function()
		return instance:GetFullName()
	end)

	if ok then
		return fullName
	end

	return instance.Name
end

local function addUnique(list, set, value)
	if typeof(value) ~= "string" or value == "" then
		return
	end

	if set[value] == true then
		return
	end

	set[value] = true
	table.insert(list, value)
end

local function joinList(list)
	if #list == 0 then
		return ""
	end

	return table.concat(list, ";")
end

local function listForOutput(list)
	if #list == 0 then
		return "(none)"
	end

	return table.concat(list, ", ")
end

local function getAllTextureIds(summary)
	local textureIds = {}
	local textureSet = {}

	for _, textureId in ipairs(summary.TextureIds) do
		addUnique(textureIds, textureSet, textureId)
	end

	for _, textureId in ipairs(summary.DecalTextureIds) do
		addUnique(textureIds, textureSet, textureId)
	end

	return textureIds
end

local function normalizeName(name)
	return string.lower((tostring(name):gsub("[%s_%-%./]+", "")))
end

local function lowerText(value)
	return string.lower(tostring(value or ""))
end

local function containsAny(text, needles)
	for _, needle in ipairs(needles) do
		if string.find(text, needle, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function getOrCreateFolder(parent, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA("Folder") then
			logWarn(existing:GetFullName() .. " exists but is " .. existing.ClassName .. ", expected Folder.")
			return nil
		end

		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	logInfo("Created " .. folder:GetFullName())
	return folder
end

local shared = getOrCreateFolder(ReplicatedStorage, "Shared")
if shared == nil then
	return
end

local assets = getOrCreateFolder(shared, "Assets")
if assets == nil then
	return
end

local vfxFolder = getOrCreateFolder(assets, "VFX")
if vfxFolder == nil then
	return
end

local workspaceDonors = getOrCreateFolder(Workspace, DONOR_FOLDER_NAME)
if workspaceDonors == nil then
	return
end

local backupsFolder = getOrCreateFolder(workspaceDonors, BACKUPS_FOLDER_NAME)
local quarantineFolder = getOrCreateFolder(workspaceDonors, QUARANTINE_FOLDER_NAME)
local unclassifiedFolder = getOrCreateFolder(workspaceDonors, UNCLASSIFIED_FOLDER_NAME)

if backupsFolder == nil or quarantineFolder == nil or unclassifiedFolder == nil then
	return
end

local serverStorageDonors = ServerStorage:FindFirstChild(DONOR_FOLDER_NAME)
local generatedRoot = Workspace:FindFirstChild(GENERATED_ROOT_NAME)

local function isScriptInstance(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function isLightInstance(instance)
	return instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end

local function isTemplateContainer(instance)
	return instance:IsA("Model")
		or instance:IsA("Folder")
		or instance:IsA("BasePart")
		or instance:IsA("Attachment")
end

local function isTemplateInstance(instance)
	return instance:IsA("Folder")
		or instance:IsA("Model")
		or instance:IsA("BasePart")
		or instance:IsA("Attachment")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Sound")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or isLightInstance(instance)
end

local function hasVfxKeyword(name)
	local text = lowerText(name)

	return containsAny(text, {
		"vfx",
		"donor",
		"effect",
		"muzzle",
		"smoke",
		"spark",
		"impact",
		"ricochet",
		"explosion",
		"fire",
		"burn",
		"ember",
		"debris",
		"shrapnel",
		"blast",
		"flash",
		"cannon",
		"hit",
		"armor",
		"no pen",
	})
end

local function isProtectedInfrastructure(instance)
	if instance == nil then
		return false
	end

	return instance == vfxFolder
		or instance == assets
		or instance == shared
		or instance == workspaceDonors
		or instance == backupsFolder
		or instance == quarantineFolder
		or instance == unclassifiedFolder
		or instance == generatedRoot
end

local function isInFolder(instance, folder)
	return folder ~= nil and (instance == folder or instance:IsDescendantOf(folder))
end

local function getRootParentLabel(instance)
	if instance == nil then
		return "<nil>"
	end

	for _, rootInfo in ipairs({
		{ Root = workspaceDonors, Label = "Workspace.WOB_EditorOnly_AssetDonors" },
		{ Root = vfxFolder, Label = "ReplicatedStorage.Shared.Assets.VFX" },
		{ Root = serverStorageDonors, Label = "ServerStorage.WOB_EditorOnly_AssetDonors" },
		{ Root = Workspace, Label = "Workspace" },
		{ Root = ReplicatedStorage, Label = "ReplicatedStorage" },
		{ Root = ServerStorage, Label = "ServerStorage" },
		{ Root = Lighting, Label = "Lighting" },
	}) do
		if rootInfo.Root ~= nil and (instance == rootInfo.Root or instance:IsDescendantOf(rootInfo.Root)) then
			return rootInfo.Label
		end
	end

	return safeFullName(instance.Parent)
end

local function inspectColorSequence(colorSequence, summary)
	local keypoints = colorSequence.Keypoints

	for _, keypoint in ipairs(keypoints) do
		local color = keypoint.Value
		local maxChannel = math.max(color.R, color.G, color.B)
		local minChannel = math.min(color.R, color.G, color.B)
		local brightness = (color.R + color.G + color.B) / 3

		if maxChannel - minChannel < 0.12 and brightness > 0.18 and brightness < 0.82 then
			summary.Signals.GrayParticles = true
		end

		if brightness > 0.68 then
			summary.Signals.BrightParticles = true
		end

		if color.R > 0.65 and color.G > 0.22 and color.B < 0.4 then
			summary.Signals.WarmParticles = true
		end

		if color.R > 0.65 and color.G < 0.28 and color.B < 0.28 then
			summary.Signals.RedParticles = true
		end
	end
end

local function inspectNumberSequence(numberSequence, summary)
	local maxValue = 0

	for _, keypoint in ipairs(numberSequence.Keypoints) do
		if keypoint.Value > maxValue then
			maxValue = keypoint.Value
		end
	end

	if maxValue <= 0.65 then
		summary.Signals.SmallParticles = true
	elseif maxValue >= 2.0 then
		summary.Signals.LargeParticles = true
	end
end

local function readScriptSource(scriptInstance)
	local ok, source = pcall(function()
		return scriptInstance.Source
	end)

	if ok and typeof(source) == "string" then
		return source
	end

	return ""
end

local function collectSuspiciousKeywords(scriptInstance)
	local source = readScriptSource(scriptInstance)
	local lowerSource = string.lower(source)
	local matches = {}

	if string.find(lowerSource, "kick", 1, true) ~= nil then
		table.insert(matches, "Kick")
	end

	if string.find(lowerSource, "httpservice", 1, true) ~= nil then
		table.insert(matches, "HttpService")
	end

	if string.find(lowerSource, "require%s*%(%s*%d+") ~= nil then
		table.insert(matches, "require(number)")
	end

	if string.find(lowerSource, "loadstring", 1, true) ~= nil then
		table.insert(matches, "loadstring")
	end

	if string.find(lowerSource, "getfenv", 1, true) ~= nil then
		table.insert(matches, "getfenv")
	end

	if string.find(lowerSource, "setfenv", 1, true) ~= nil then
		table.insert(matches, "setfenv")
	end

	return matches
end

local function createEmptySummary(root)
	return {
		Root = root,
		ParticleEmitters = 0,
		Sounds = 0,
		Beams = 0,
		Trails = 0,
		Lights = 0,
		BaseParts = 0,
		Scripts = 0,
		Decals = 0,
		Textures = 0,
		MeshParts = 0,
		SpecialMeshes = 0,
		VisualMarkers = 0,
		HasThumbnailCamera = false,
		TextureIds = {},
		TextureIdSet = {},
		SoundIds = {},
		SoundIdSet = {},
		DecalTextureIds = {},
		DecalTextureSet = {},
		MeshIds = {},
		MeshIdSet = {},
		SuspiciousScripts = {},
		AllScriptPaths = {},
		NameText = lowerText(root.Name),
		Signals = {
			GrayParticles = false,
			BrightParticles = false,
			WarmParticles = false,
			RedParticles = false,
			FastParticles = false,
			SmallParticles = false,
			LargeParticles = false,
			LongLivedParticles = false,
			ShortLivedParticles = false,
			HighEmissionParticles = false,
		},
	}
end

local function analyzeInstance(root)
	local summary = createEmptySummary(root)
	local instances = { root }

	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(instances, descendant)
	end

	for _, instance in ipairs(instances) do
		summary.NameText = summary.NameText .. " " .. lowerText(instance.Name)

		if instance:IsA("ParticleEmitter") then
			summary.ParticleEmitters += 1
			summary.VisualMarkers += 1
			addUnique(summary.TextureIds, summary.TextureIdSet, instance.Texture)
			addUnique(aggregateTextureIds, aggregateTextureSet, instance.Texture)
			inspectColorSequence(instance.Color, summary)
			inspectNumberSequence(instance.Size, summary)

			if instance.Speed.Max >= 14 then
				summary.Signals.FastParticles = true
			end

			if instance.Lifetime.Max >= 0.75 then
				summary.Signals.LongLivedParticles = true
			end

			if instance.Lifetime.Max <= 0.2 then
				summary.Signals.ShortLivedParticles = true
			end

			if instance.LightEmission >= 0.35 then
				summary.Signals.HighEmissionParticles = true
				summary.Signals.BrightParticles = true
			end
		elseif instance:IsA("Sound") then
			summary.Sounds += 1
			summary.VisualMarkers += 1
			addUnique(summary.SoundIds, summary.SoundIdSet, instance.SoundId)
			addUnique(aggregateSoundIds, aggregateSoundSet, instance.SoundId)
		elseif instance:IsA("Beam") then
			summary.Beams += 1
			summary.VisualMarkers += 1
			addUnique(summary.TextureIds, summary.TextureIdSet, instance.Texture)
			addUnique(aggregateTextureIds, aggregateTextureSet, instance.Texture)
		elseif instance:IsA("Trail") then
			summary.Trails += 1
			summary.VisualMarkers += 1
			addUnique(summary.TextureIds, summary.TextureIdSet, instance.Texture)
			addUnique(aggregateTextureIds, aggregateTextureSet, instance.Texture)
		elseif isLightInstance(instance) then
			summary.Lights += 1
			summary.VisualMarkers += 1
		elseif instance:IsA("Decal") then
			summary.Decals += 1
			summary.VisualMarkers += 1
			addUnique(summary.DecalTextureIds, summary.DecalTextureSet, instance.Texture)
			addUnique(aggregateDecalTextureIds, aggregateDecalTextureSet, instance.Texture)
		elseif instance:IsA("Texture") then
			summary.Textures += 1
			summary.VisualMarkers += 1
			addUnique(summary.TextureIds, summary.TextureIdSet, instance.Texture)
			addUnique(aggregateTextureIds, aggregateTextureSet, instance.Texture)
		elseif instance:IsA("MeshPart") then
			summary.MeshParts += 1
			summary.VisualMarkers += 1
			addUnique(summary.MeshIds, summary.MeshIdSet, instance.MeshId)
			addUnique(aggregateMeshIds, aggregateMeshSet, instance.MeshId)
		elseif instance:IsA("SpecialMesh") then
			summary.SpecialMeshes += 1
			summary.VisualMarkers += 1
			addUnique(summary.MeshIds, summary.MeshIdSet, instance.MeshId)
			addUnique(aggregateMeshIds, aggregateMeshSet, instance.MeshId)
		end

		if instance:IsA("BasePart") then
			summary.BaseParts += 1
		end

		if instance.Name == "ThumbnailCamera" or instance:IsA("Camera") then
			summary.HasThumbnailCamera = true
		end

		if isScriptInstance(instance) then
			summary.Scripts += 1
			table.insert(summary.AllScriptPaths, safeFullName(instance))

			local keywords = collectSuspiciousKeywords(instance)
			if #keywords > 0 then
				table.insert(summary.SuspiciousScripts, {
					Path = safeFullName(instance),
					Keywords = keywords,
				})
			end
		end
	end

	return summary
end

local function hasGoodVfxContent(summary)
	return summary.VisualMarkers > 0
		and (
			summary.ParticleEmitters > 0
			or summary.Sounds > 0
			or summary.Beams > 0
			or summary.Trails > 0
			or summary.Lights > 0
			or summary.Decals > 0
			or summary.Textures > 0
			or summary.MeshParts > 0
			or summary.SpecialMeshes > 0
		)
end

local function addScore(scores, reasons, target, amount, reason)
	scores[target] = (scores[target] or 0) + amount
	table.insert(reasons, target .. "+" .. tostring(amount) .. " " .. reason)
end

local function isSparkLike(summary)
	local text = summary.NameText

	if containsAny(text, { "spark", "sparks", "ricochet", "metal", "impact", "shrapnel", "debris" }) then
		return true
	end

	return summary.Signals.FastParticles
		and (summary.Signals.BrightParticles or summary.Signals.HighEmissionParticles)
		and summary.Signals.SmallParticles
end

local function isClearMuzzleLike(summary)
	local text = summary.NameText

	if containsAny(text, { "muzzle effect", "muzzleeffect", "muzzle", "gun flash", "cannon" }) then
		return true
	end

	return summary.Signals.ShortLivedParticles
		and (summary.Signals.BrightParticles or summary.Lights > 0)
		and not summary.Signals.LongLivedParticles
end

local function classifySummary(summary, instance)
	local text = summary.NameText
	local normalized = normalizeName(text)
	local scores = {}
	local reasons = {}

	if TARGET_SET[instance.Name] == true then
		addScore(scores, reasons, instance.Name, 85, "exact template name")
	end

	if containsAny(text, { "muzzle effect", "muzzle", "gun flash" }) or string.find(normalized, "muzzleeffect", 1, true) ~= nil then
		addScore(scores, reasons, "MuzzleEffectTemplate", 58, "muzzle name")
		addScore(scores, reasons, "MuzzleFlashTemplate", 34, "muzzle can flash")
		addScore(scores, reasons, "MuzzleBlastTemplate", 24, "muzzle can blast")
	end

	if containsAny(text, { "flash", "gun flash" }) then
		addScore(scores, reasons, "MuzzleFlashTemplate", 52, "flash name")
		addScore(scores, reasons, "MuzzleEffectTemplate", 28, "flash can drive shot muzzle")
	end

	if containsAny(text, { "cannon", "muzzle blast", "blast" }) then
		addScore(scores, reasons, "MuzzleBlastTemplate", 45, "blast/cannon name")
		addScore(scores, reasons, "MuzzleEffectTemplate", 20, "blast can drive shot muzzle")
	end

	if containsAny(text, { "smoke" }) then
		addScore(scores, reasons, "SmokeTemplate", 70, "smoke name")
	end

	if containsAny(text, { "spark", "sparks", "impact", "shrapnel", "debris" }) then
		addScore(scores, reasons, "ImpactSparksTemplate", 58, "impact/sparks name")
		addScore(scores, reasons, "DamageHitTemplate", 26, "impact can damage hit")
		addScore(scores, reasons, "RicochetTemplate", 22, "sparks can ricochet")
	end

	if containsAny(text, { "ricochet", "metal spark", "metal sparks" }) then
		addScore(scores, reasons, "RicochetTemplate", 78, "ricochet/metal spark name")
	end

	if containsAny(text, { "explosion", "fireball", "resources explosion" }) then
		addScore(scores, reasons, "TankExplosionTemplate", 82, "explosion name")
	end

	if containsAny(text, { "fire", "burning", "burn", "embers", "ember", "campfire" }) then
		addScore(scores, reasons, "TankBurningTemplate", 64, "fire/burning name")
	end

	if containsAny(text, { "no pen", "nopen", "no penetration", "armor", "armour", "dull" }) then
		addScore(scores, reasons, "NoPenTemplate", 72, "no-pen/armor name")
	end

	if containsAny(text, { "self", "critical" }) then
		addScore(scores, reasons, "SelfHitTemplate", 70, "self/critical name")
	end

	if summary.Signals.GrayParticles and summary.Signals.LongLivedParticles then
		addScore(scores, reasons, "SmokeTemplate", 28, "gray long-lived particles")
	end

	if summary.TextureIdSet["rbxassetid://771221224"] == true or summary.TextureIdSet["771221224"] == true then
		addScore(scores, reasons, "SmokeTemplate", 36, "known smoke texture")
	end

	if summary.TextureIdSet["rbxassetid://243660364"] == true or summary.TextureIdSet["243660364"] == true then
		addScore(scores, reasons, "MuzzleEffectTemplate", 30, "known muzzle flash texture")
		addScore(scores, reasons, "MuzzleFlashTemplate", 30, "known muzzle flash texture")
	end

	if summary.TextureIdSet["rbxassetid://1038411245"] == true or summary.TextureIdSet["1038411245"] == true then
		addScore(scores, reasons, "ImpactSparksTemplate", 32, "known spark texture")
		addScore(scores, reasons, "RicochetTemplate", 24, "known spark texture")
	end

	if summary.Signals.FastParticles and (summary.Signals.BrightParticles or summary.Signals.HighEmissionParticles) then
		addScore(scores, reasons, "ImpactSparksTemplate", 26, "fast bright particles")
		addScore(scores, reasons, "RicochetTemplate", 24, "fast bright particles")
		addScore(scores, reasons, "DamageHitTemplate", 14, "fast bright particles")
	end

	if summary.Signals.FastParticles and summary.Signals.SmallParticles then
		addScore(scores, reasons, "RicochetTemplate", 16, "sharp small fast particles")
	end

	if summary.Signals.GrayParticles and summary.Signals.SmallParticles then
		addScore(scores, reasons, "NoPenTemplate", 18, "dull gray small particles")
	end

	if summary.Signals.WarmParticles and summary.Signals.FastParticles then
		addScore(scores, reasons, "DamageHitTemplate", 20, "warm fast impact particles")
	end

	if summary.Signals.RedParticles and summary.Signals.FastParticles then
		addScore(scores, reasons, "SelfHitTemplate", 18, "red/orange strong impact")
	end

	if summary.ParticleEmitters >= 4 and summary.Sounds > 0 and summary.Lights > 0 then
		addScore(scores, reasons, "TankExplosionTemplate", 18, "multi-emitter sound light effect")
	end

	if summary.Signals.WarmParticles and summary.Signals.LongLivedParticles then
		addScore(scores, reasons, "TankBurningTemplate", 24, "warm long-lived particles")
	end

	if isClearMuzzleLike(summary) then
		addScore(scores, reasons, "MuzzleEffectTemplate", 16, "clear short muzzle-like content")
	end

	local bestTarget = nil
	local bestScore = 0

	for _, target in ipairs(TARGET_ORDER) do
		local score = scores[target] or 0
		if score > bestScore then
			bestScore = score
			bestTarget = target
		end
	end

	local confidence = "none"
	if bestScore >= 70 then
		confidence = "high"
	elseif bestScore >= 42 then
		confidence = "medium"
	elseif bestScore >= 28 then
		confidence = "low"
	end

	return {
		Target = bestTarget,
		Score = bestScore,
		Confidence = confidence,
		Scores = scores,
		Reasons = reasons,
		IsSparkLike = isSparkLike(summary),
		IsClearMuzzleLike = isClearMuzzleLike(summary),
	}
end

local function formatSummaryCounts(summary)
	return "particles="
		.. tostring(summary.ParticleEmitters)
		.. " sounds="
		.. tostring(summary.Sounds)
		.. " beams="
		.. tostring(summary.Beams)
		.. " trails="
		.. tostring(summary.Trails)
		.. " lights="
		.. tostring(summary.Lights)
		.. " baseParts="
		.. tostring(summary.BaseParts)
		.. " scripts="
		.. tostring(summary.Scripts)
end

local function collectCandidates()
	local roots = {
		{ Root = workspaceDonors, Label = "Workspace.WOB_EditorOnly_AssetDonors" },
		{ Root = vfxFolder, Label = "ReplicatedStorage.Shared.Assets.VFX" },
		{ Root = serverStorageDonors, Label = "ServerStorage.WOB_EditorOnly_AssetDonors" },
		{ Root = Workspace, Label = "Workspace" },
		{ Root = ReplicatedStorage, Label = "ReplicatedStorage" },
		{ Root = ServerStorage, Label = "ServerStorage" },
		{ Root = Lighting, Label = "Lighting" },
	}

	local seen = {}
	local candidates = {}

	for _, rootInfo in ipairs(roots) do
		local root = rootInfo.Root
		if root ~= nil then
			local instances = { root }
			for _, descendant in ipairs(root:GetDescendants()) do
				table.insert(instances, descendant)
			end

			for _, instance in ipairs(instances) do
				if seen[instance] ~= true and isTemplateContainer(instance) and not isProtectedInfrastructure(instance) then
					seen[instance] = true

					if not isInFolder(instance, quarantineFolder) and not isInFolder(instance, backupsFolder) then
						local summary = analyzeInstance(instance)
						if hasGoodVfxContent(summary) then
							local classification = classifySummary(summary, instance)
							table.insert(candidates, {
								Instance = instance,
								Name = instance.Name,
								ClassName = instance.ClassName,
								FullName = safeFullName(instance),
								RootLabel = getRootParentLabel(instance),
								SearchRootLabel = rootInfo.Label,
								Summary = summary,
								Classification = classification,
								SelectedTargets = {},
								InstalledTargets = {},
							})
						end
					end
				end
			end
		end
	end

	return candidates
end

local function getCandidateRank(candidate, target)
	local summary = candidate.Summary
	local classification = candidate.Classification
	local score = classification.Scores[target] or 0

	if candidate.ForcedRanks ~= nil and candidate.ForcedRanks[target] ~= nil then
		score = score + candidate.ForcedRanks[target]
	end

	score += math.min(summary.VisualMarkers * 2, 24)
	score += math.min(summary.ParticleEmitters * 4, 28)
	score += math.min(summary.Sounds * 2, 8)

	if isInFolder(candidate.Instance, workspaceDonors) or isInFolder(candidate.Instance, serverStorageDonors) then
		score += 8
	end

	if candidate.Instance.Parent == vfxFolder and candidate.Instance.Name == target then
		score += 28
	end

	if candidate.Instance.Parent == Workspace and hasVfxKeyword(candidate.Instance.Name) then
		score += 6
	end

	if summary.Scripts > 0 then
		score -= 8
	end

	if #summary.SuspiciousScripts > 0 then
		score -= 20
	end

	if summary.BaseParts > 150 and not hasVfxKeyword(candidate.Instance.Name) then
		score -= 35
	end

	return score
end

local function isCandidateEligibleForTarget(candidate, target)
	local score = candidate.Classification.Scores[target] or 0

	if candidate.ForcedTargets ~= nil and candidate.ForcedTargets[target] == true then
		return true
	end

	if target == "MuzzleEffectTemplate" and score >= 34 and candidate.Classification.IsClearMuzzleLike then
		return true
	end

	if candidate.Instance.Parent == vfxFolder and candidate.Instance.Name == target then
		return true
	end

	return score >= 42
end

local function selectBestCandidates(candidates)
	local selectedByTarget = {}

	for _, candidate in ipairs(candidates) do
		if not isInFolder(candidate.Instance, unclassifiedFolder) and not isInFolder(candidate.Instance, quarantineFolder) then
			for _, target in ipairs(TARGET_ORDER) do
				if isCandidateEligibleForTarget(candidate, target) then
					local current = selectedByTarget[target]
					local candidateRank = getCandidateRank(candidate, target)
					if current == nil or candidateRank > getCandidateRank(current, target) then
						selectedByTarget[target] = candidate
					end
				end
			end
		end
	end

	local existingMuzzle = vfxFolder:FindFirstChild("MuzzleEffectTemplate")
	if existingMuzzle ~= nil then
		local existingSummary = analyzeInstance(existingMuzzle)
		local existingClass = classifySummary(existingSummary, existingMuzzle)

		if existingClass.IsSparkLike then
			local bestNewMuzzle = nil
			local bestNewRank = 0

			for _, candidate in ipairs(candidates) do
				local instance = candidate.Instance
				local isSameExisting = instance == existingMuzzle or instance:IsDescendantOf(existingMuzzle)

				if not isSameExisting
					and candidate.Classification.IsClearMuzzleLike
					and not candidate.Classification.IsSparkLike
				then
					local rank = getCandidateRank(candidate, "MuzzleEffectTemplate")
					if rank > bestNewRank then
						bestNewRank = rank
						bestNewMuzzle = candidate
					end
				end
			end

			if bestNewMuzzle ~= nil then
				local oldMuzzleCandidate = {
					Instance = existingMuzzle,
					Name = existingMuzzle.Name,
					ClassName = existingMuzzle.ClassName,
					FullName = safeFullName(existingMuzzle),
					RootLabel = "ReplicatedStorage.Shared.Assets.VFX",
					SearchRootLabel = "ReplicatedStorage.Shared.Assets.VFX",
					Summary = existingSummary,
					Classification = existingClass,
					SelectedTargets = {},
					InstalledTargets = {},
					ForcedTargets = {
						RicochetTemplate = true,
					},
					ForcedRanks = {
						RicochetTemplate = 130,
					},
					SpecialReason = "old spark-like MuzzleEffectTemplate repurposed as RicochetTemplate",
				}

				selectedByTarget.RicochetTemplate = oldMuzzleCandidate
				selectedByTarget.MuzzleEffectTemplate = bestNewMuzzle
				bestNewMuzzle.ForcedTargets = bestNewMuzzle.ForcedTargets or {}
				bestNewMuzzle.ForcedTargets.MuzzleEffectTemplate = true
				bestNewMuzzle.ForcedRanks = bestNewMuzzle.ForcedRanks or {}
				bestNewMuzzle.ForcedRanks.MuzzleEffectTemplate = 90
				logInfo(
					"Special rule: existing MuzzleEffectTemplate looks spark-like; "
						.. "selected "
						.. bestNewMuzzle.FullName
						.. " for MuzzleEffectTemplate and old shot effect for RicochetTemplate."
				)
			end
		end
	end

	return selectedByTarget
end

local function setDisabledIfPossible(scriptInstance)
	if scriptInstance:IsA("Script") or scriptInstance:IsA("LocalScript") then
		pcall(function()
			scriptInstance.Disabled = true
		end)
	end
end

local function uniqueChildName(parent, baseName)
	local cleanName = tostring(baseName):gsub("[^%w_%-]", "_")
	if cleanName == "" then
		cleanName = "Object"
	end

	local name = cleanName
	local index = 2

	while parent:FindFirstChild(name) ~= nil do
		name = cleanName .. "_" .. tostring(index)
		index += 1
	end

	return name
end

local function moveToFolder(instance, folder, baseName, reason)
	if instance == nil or folder == nil then
		return nil
	end

	local oldPath = safeFullName(instance)
	local newName = uniqueChildName(folder, baseName)
	instance.Name = newName
	instance.Parent = folder
	pcall(function()
		instance:SetAttribute("WOBMovedBy", COMMAND_NAME)
		instance:SetAttribute("WOBMoveReason", reason or "")
		instance:SetAttribute("WOBSourcePath", oldPath)
	end)

	local line = oldPath .. " -> " .. safeFullName(instance) .. " (" .. tostring(reason or "moved") .. ")"
	table.insert(quarantinedLines, line)
	logInfo("Moved " .. line)
	return instance
end

local function sanitizeClone(root, sourcePath, scriptsRemovedLines)
	local instances = { root }
	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(instances, descendant)
	end

	for _, instance in ipairs(instances) do
		if isScriptInstance(instance) then
			table.insert(scriptsRemovedLines, sourcePath .. " cloned script removed: " .. safeFullName(instance))
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.CastShadow = false
		elseif instance:IsA("ParticleEmitter") then
			instance.Enabled = false
		end
	end
end

local function sanitizeTemplateInPlace(root, reason)
	local movedScripts = {}
	local instances = { root }
	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(instances, descendant)
	end

	for _, instance in ipairs(instances) do
		if isScriptInstance(instance) then
			setDisabledIfPossible(instance)
			table.insert(movedScripts, safeFullName(instance))
		elseif instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.CastShadow = false
		elseif instance:IsA("ParticleEmitter") then
			instance.Enabled = false
		end
	end

	for _, scriptPath in ipairs(movedScripts) do
		local scriptInstance = nil
		for _, descendant in ipairs(root:GetDescendants()) do
			if safeFullName(descendant) == scriptPath then
				scriptInstance = descendant
				break
			end
		end

		if scriptInstance ~= nil then
			moveToFolder(scriptInstance, quarantineFolder, "Script_From_" .. root.Name .. "_" .. TIMESTAMP, reason)
			table.insert(suspiciousLines, scriptPath .. " removed from template/quarantined (" .. tostring(reason) .. ")")
		end
	end
end

local isSafeToMoveSource = nil

local function installTemplate(candidate, target, forceReplace)
	local source = candidate.Instance
	local sourcePath = candidate.FullName or safeFullName(source)

	if source == nil or source.Parent == nil then
		table.insert(installedLines, target .. ": skipped because source no longer exists (" .. tostring(sourcePath) .. ")")
		return false
	end

	local existing = vfxFolder:FindFirstChild(target)
	local candidateRank = getCandidateRank(candidate, target)

	if existing ~= nil then
		if existing == source and existing.Parent == vfxFolder and existing.Name == target then
			sanitizeTemplateInPlace(existing, "sanitize existing selected template")
			local existingSummary = analyzeInstance(existing)
			pcall(function()
				existing:SetAttribute("WOBVfxTemplate", true)
				existing:SetAttribute("VfxTemplateType", target)
				existing:SetAttribute("WOBInstalledBy", COMMAND_NAME)
				existing:SetAttribute("WOBTextureIds", joinList(getAllTextureIds(existingSummary)))
				existing:SetAttribute("WOBSoundIds", joinList(existingSummary.SoundIds))
				existing:SetAttribute("WOBSourcePath", sourcePath)
			end)
			table.insert(installedLines, target .. ": kept existing " .. safeFullName(existing))
			logInfo("Kept existing template " .. safeFullName(existing))
			return true
		end

		local existingSummary = analyzeInstance(existing)
		local existingCandidate = {
			Instance = existing,
			Summary = existingSummary,
			Classification = classifySummary(existingSummary, existing),
			FullName = safeFullName(existing),
		}
		local existingRank = getCandidateRank(existingCandidate, target)

		if not forceReplace and existingRank >= candidateRank then
			sanitizeTemplateInPlace(existing, "sanitize existing better template")
			table.insert(
				installedLines,
				target
					.. ": kept existing "
					.. safeFullName(existing)
					.. " rank="
					.. tostring(existingRank)
					.. " over "
					.. sourcePath
					.. " rank="
					.. tostring(candidateRank)
			)
			logInfo("Kept existing " .. target .. " over candidate " .. sourcePath)

			if isSafeToMoveSource ~= nil and isSafeToMoveSource(candidate) then
				moveToFolder(
					candidate.Instance,
					backupsFolder,
					candidate.Instance.Name .. "_NotInstalled_" .. TIMESTAMP,
					"existing " .. target .. " ranked better"
				)
			else
				logInfo("Candidate kept in place because it may be part of gameplay scene: " .. sourcePath)
			end

			return false
		end

		moveToFolder(existing, backupsFolder, target .. "_Backup_" .. TIMESTAMP, "replaced by " .. sourcePath)
	end

	local clone = source:Clone()
	clone.Name = target
	local scriptsRemovedLines = {}
	sanitizeClone(clone, sourcePath, scriptsRemovedLines)

	for _, line in ipairs(scriptsRemovedLines) do
		table.insert(suspiciousLines, line)
	end

	pcall(function()
		clone:SetAttribute("WOBVfxTemplate", true)
		clone:SetAttribute("VfxTemplateType", target)
		clone:SetAttribute("WOBInstalledBy", COMMAND_NAME)
		clone:SetAttribute("WOBTextureIds", joinList(getAllTextureIds(candidate.Summary)))
		clone:SetAttribute("WOBSoundIds", joinList(candidate.Summary.SoundIds))
		clone:SetAttribute("WOBSourcePath", sourcePath)
	end)

	clone.Parent = vfxFolder
	table.insert(
		installedLines,
		target
			.. ": installed from "
			.. sourcePath
			.. " rank="
			.. tostring(candidateRank)
			.. " textures="
			.. listForOutput(getAllTextureIds(candidate.Summary))
			.. " sounds="
			.. listForOutput(candidate.Summary.SoundIds)
	)
	logInfo("Installed " .. target .. " from " .. sourcePath)

	return true
end

isSafeToMoveSource = function(candidate)
	local source = candidate.Instance

	if source == nil or source.Parent == nil then
		return false
	end

	if source == vfxFolder or source == workspaceDonors or source == backupsFolder or source == quarantineFolder then
		return false
	end

	if isInFolder(source, backupsFolder) or isInFolder(source, quarantineFolder) or isInFolder(source, unclassifiedFolder) then
		return false
	end

	if isInFolder(source, workspaceDonors) or isInFolder(source, serverStorageDonors) then
		return true
	end

	if source.Parent == vfxFolder and source.Name ~= "VfxTemplateCatalog" and TARGET_SET[source.Name] ~= true then
		return true
	end

	if source.Parent == Workspace and generatedRoot ~= source and hasVfxKeyword(source.Name) then
		return true
	end

	if (source.Parent == ServerStorage or source.Parent == ReplicatedStorage or source.Parent == Lighting) and hasVfxKeyword(source.Name) then
		return true
	end

	return false
end

local function moveInstalledSourceIfNeeded(candidate)
	local source = candidate.Instance

	if source == nil or source.Parent == nil then
		return
	end

	if source.Parent == Workspace and hasVfxKeyword(source.Name) then
		moveToFolder(source, workspaceDonors, source.Name .. "_Donor_" .. TIMESTAMP, "recognized VFX donor moved out of Workspace after install")
	else
		logInfo("Source kept in place: " .. safeFullName(source))
	end
end

local function quarantineSuspiciousScriptsForSafeSource(candidate)
	if #candidate.Summary.SuspiciousScripts == 0 or not isSafeToMoveSource(candidate) then
		return
	end

	local scriptsToMove = {}
	local root = candidate.Instance

	for _, descendant in ipairs(root:GetDescendants()) do
		if isScriptInstance(descendant) and #collectSuspiciousKeywords(descendant) > 0 then
			table.insert(scriptsToMove, descendant)
		end
	end

	for _, scriptInstance in ipairs(scriptsToMove) do
		setDisabledIfPossible(scriptInstance)
		local oldPath = safeFullName(scriptInstance)
		moveToFolder(scriptInstance, quarantineFolder, "SuspiciousScript_" .. TIMESTAMP, "suspicious script inside VFX source")
		table.insert(suspiciousLines, oldPath .. " disabled/quarantined from source")
	end
end

local function handleUnselectedCandidates(candidates, selectedByTarget)
	local selectedInstances = {}

	for _, candidate in pairs(selectedByTarget) do
		selectedInstances[candidate.Instance] = true
	end

	for _, candidate in ipairs(candidates) do
		local source = candidate.Instance
		local classification = candidate.Classification

		if source ~= nil and source.Parent ~= nil and selectedInstances[source] ~= true then
			if #candidate.Summary.SuspiciousScripts > 0 then
				quarantineSuspiciousScriptsForSafeSource(candidate)
			end

			if classification.Confidence == "none" or classification.Confidence == "low" then
				local line = "Unclassified VFX kept: " .. candidate.FullName
				table.insert(classifiedLines, line)
				logInfo(line)

				if isSafeToMoveSource(candidate) then
					moveToFolder(source, unclassifiedFolder, source.Name .. "_Unclassified_" .. TIMESTAMP, "ambiguous VFX candidate")
				end
			elseif source.Parent == vfxFolder and TARGET_SET[source.Name] ~= true and source.Name ~= "VfxTemplateCatalog" then
				moveToFolder(source, unclassifiedFolder, source.Name .. "_Unclassified_" .. TIMESTAMP, "classified but not connected target template")
			end
		end
	end
end

local function quarantineEmptyTemplates()
	for _, child in ipairs(vfxFolder:GetChildren()) do
		if child.Name ~= "VfxTemplateCatalog" and isTemplateInstance(child) then
			local summary = analyzeInstance(child)
			if not hasGoodVfxContent(summary) then
				moveToFolder(child, quarantineFolder, child.Name .. "_EmptyTemplate_" .. TIMESTAMP, "empty/old VFX template without visual content")
			end
		end
	end
end

local function auditCandidates(candidates)
	table.sort(candidates, function(left, right)
		return left.FullName < right.FullName
	end)

	for _, candidate in ipairs(candidates) do
		local summary = candidate.Summary
		local classification = candidate.Classification
		local candidateLine = "Candidate "
			.. candidate.FullName
			.. " class="
			.. candidate.ClassName
			.. " root="
			.. candidate.RootLabel
			.. " "
			.. formatSummaryCounts(summary)
			.. " thumbnailCamera="
			.. tostring(summary.HasThumbnailCamera)

		logInfo(candidateLine)
		table.insert(foundCandidateLines, candidateLine)

		local textureLine = "Texture IDs: " .. listForOutput(getAllTextureIds(summary))
		local soundLine = "Sound IDs: " .. listForOutput(summary.SoundIds)
		local decalLine = "Decal Texture IDs: " .. listForOutput(summary.DecalTextureIds)
		local meshLine = "Mesh IDs: " .. listForOutput(summary.MeshIds)
		logInfo(textureLine)
		logInfo(soundLine)
		logInfo(decalLine)
		logInfo(meshLine)

		if #summary.SuspiciousScripts == 0 then
			logInfo("Suspicious scripts: (none)")
		else
			for _, scriptInfo in ipairs(summary.SuspiciousScripts) do
				local suspiciousLine = scriptInfo.Path .. " keywords=" .. table.concat(scriptInfo.Keywords, ", ")
				logWarn("Suspicious scripts: " .. suspiciousLine)
				table.insert(suspiciousLines, suspiciousLine)
			end
		end

		local classLine = candidate.FullName
			.. " -> "
			.. tostring(classification.Target or "Unclassified")
			.. " confidence="
			.. classification.Confidence
			.. " score="
			.. tostring(classification.Score)
			.. " reasons="
			.. listForOutput(classification.Reasons)
		table.insert(classifiedLines, classLine)
		logInfo("Classified " .. classLine)
	end
end

local function reportMaterialVariants()
	local variants = {}

	for _, descendant in ipairs(MaterialService:GetDescendants()) do
		if descendant:IsA("MaterialVariant") then
			table.insert(variants, safeFullName(descendant))
		end
	end

	table.sort(variants)

	if #variants == 0 then
		table.insert(materialVariantLines, "No MaterialVariant objects found under MaterialService.")
	else
		for _, variantPath in ipairs(variants) do
			table.insert(materialVariantLines, variantPath)
			logInfo("MaterialVariant report-only: " .. variantPath)
		end
	end
end

local function buildMarkdownReport()
	local lines = {
		"# VFX Organizer Report",
		"",
		"Generated by `" .. COMMAND_NAME .. "` at `" .. TIMESTAMP .. "`.",
		"",
		"Studio may not expose filesystem writes to Command Bar scripts. If this file was not overwritten automatically, copy the `VFX_ORGANIZER_REPORT_MD_*` StringValue from `Workspace.WOB_EditorOnly_AssetDonors.VFX_Backups` into this file after running the command.",
		"",
		"## Found candidates",
	}

	if #foundCandidateLines == 0 then
		table.insert(lines, "- None.")
	else
		for _, line in ipairs(foundCandidateLines) do
			table.insert(lines, "- " .. line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Classified templates")
	if #classifiedLines == 0 then
		table.insert(lines, "- None.")
	else
		for _, line in ipairs(classifiedLines) do
			table.insert(lines, "- " .. line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Installed templates")
	if #installedLines == 0 then
		table.insert(lines, "- None.")
	else
		for _, line in ipairs(installedLines) do
			table.insert(lines, "- " .. line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Quarantined objects")
	if #quarantinedLines == 0 then
		table.insert(lines, "- None.")
	else
		for _, line in ipairs(quarantinedLines) do
			table.insert(lines, "- " .. line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Asset IDs found")
	table.insert(lines, "- ParticleEmitter/Beam/Trail/Texture IDs: " .. listForOutput(aggregateTextureIds))
	table.insert(lines, "- Sound IDs: " .. listForOutput(aggregateSoundIds))
	table.insert(lines, "- Decal Texture IDs: " .. listForOutput(aggregateDecalTextureIds))
	table.insert(lines, "- Mesh IDs: " .. listForOutput(aggregateMeshIds))

	table.insert(lines, "")
	table.insert(lines, "## Suspicious scripts removed/disabled")
	if #suspiciousLines == 0 then
		table.insert(lines, "- None.")
	else
		for _, line in ipairs(suspiciousLines) do
			table.insert(lines, "- " .. line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## MaterialVariant report")
	for _, line in ipairs(materialVariantLines) do
		table.insert(lines, "- " .. line)
	end

	table.insert(lines, "")
	table.insert(lines, "## Manual save-to-file steps")
	table.insert(lines, "1. In Studio, open `ReplicatedStorage.Shared.Assets.VFX`.")
	table.insert(lines, "2. Right click each installed template and choose `Save to File...`.")
	table.insert(lines, "3. Save each file into `/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox/src/ReplicatedStorage/Shared/Assets/VFX/TemplateName.rbxmx`.")
	table.insert(lines, "4. Save at least these objects when present: `MuzzleEffectTemplate`, `MuzzleFlashTemplate`, `MuzzleBlastTemplate`, `SmokeTemplate`, `ImpactSparksTemplate`, `RicochetTemplate`, `DamageHitTemplate`, `NoPenTemplate`, `SelfHitTemplate`, `TankExplosionTemplate`, `TankBurningTemplate`.")
	table.insert(lines, "5. Run `rojo build default.project.json --output /private/tmp/wob-vfx-organizer-check.rbxm` after saving `.rbxmx` files.")
	table.insert(lines, "6. `TemplateName` is the object name. `TextureId` and `SoundId` are asset ids inside emitters/sounds. One template may contain many texture IDs.")

	return table.concat(lines, "\n")
end

local function persistReport(markdown)
	local saved = false

	if type(writefile) == "function" then
		local ok, errorMessage = pcall(function()
			writefile(REPORT_PATH, markdown)
		end)

		if ok then
			saved = true
			logInfo("Report written to " .. REPORT_PATH)
		else
			logWarn("Could not write " .. REPORT_PATH .. ": " .. tostring(errorMessage))
		end
	end

	local chunkIndex = 1
	local offset = 1

	while offset <= #markdown do
		local reportValue = Instance.new("StringValue")
		local suffix = #markdown > REPORT_VALUE_CHUNK_SIZE and "_Part" .. tostring(chunkIndex) or ""
		reportValue.Name = uniqueChildName(backupsFolder, "VFX_ORGANIZER_REPORT_MD_" .. TIMESTAMP .. suffix)
		reportValue.Value = string.sub(markdown, offset, offset + REPORT_VALUE_CHUNK_SIZE - 1)
		reportValue.Parent = backupsFolder
		offset += REPORT_VALUE_CHUNK_SIZE
		chunkIndex += 1
	end

	if not saved then
		logWarn(
			"Studio Command Bar usually cannot write repo files. Report stored at "
				.. backupsFolder:GetFullName()
				.. "; copy it to "
				.. REPORT_PATH
				.. " if needed."
		)
	end
end

logInfo("Starting full VFX organization pass.")

reportMaterialVariants()
quarantineEmptyTemplates()

local candidates = collectCandidates()
auditCandidates(candidates)

local selectedByTarget = selectBestCandidates(candidates)

for _, target in ipairs(TARGET_ORDER) do
	local candidate = selectedByTarget[target]
	if candidate ~= nil then
		local forceReplace = candidate.ForcedTargets ~= nil and candidate.ForcedTargets[target] == true
		local installed = installTemplate(candidate, target, forceReplace)

		if installed then
			candidate.InstalledTargets[target] = true
			moveInstalledSourceIfNeeded(candidate)
		end
	else
		table.insert(installedLines, target .. ": no confident candidate; procedural/runtime fallback remains.")
		logInfo(target .. ": no confident candidate; fallback remains.")
	end
end

handleUnselectedCandidates(candidates, selectedByTarget)

local finalTemplateNames = {}
for _, child in ipairs(vfxFolder:GetChildren()) do
	if child.Name ~= "VfxTemplateCatalog" and isTemplateInstance(child) then
		table.insert(finalTemplateNames, child.Name)
	end
end

table.sort(finalTemplateNames)
logInfo("Final VFX templates: " .. listForOutput(finalTemplateNames))
logInfo("Projectile size/trail and Shot.SoundId are controlled by VfxConfig; this command does not modify them.")

local markdownReport = buildMarkdownReport()
persistReport(markdownReport)

logInfo("Finished full VFX organization pass.")
