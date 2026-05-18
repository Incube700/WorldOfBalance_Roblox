local CombatVfxService = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")

local vfxFolder = nil
local warnedKeys = {}

local function warnOnce(key, message)
	if warnedKeys[key] == true then
		return
	end

	warnedKeys[key] = true
	warn(message)
end

local function isNonEmptyString(value)
	return typeof(value) == "string" and value ~= ""
end

local function appendTemplateName(names, seen, templateName)
	if not isNonEmptyString(templateName) or seen[templateName] == true then
		return
	end

	seen[templateName] = true
	table.insert(names, templateName)
end

local function getConfiguredTemplateNames(config)
	local names = {}
	local seen = {}

	if config == nil then
		return names
	end

	appendTemplateName(names, seen, config.TemplateName)
	appendTemplateName(names, seen, config.TemplateFallbackName)

	local fallbackNames = config.TemplateFallbackNames
	if typeof(fallbackNames) == "table" then
		for _, templateName in ipairs(fallbackNames) do
			appendTemplateName(names, seen, templateName)
		end
	end

	return names
end

local function getFlatDirection(direction)
	if typeof(direction) ~= "Vector3" then
		return Vector3.new(0, 0, -1)
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flatDirection.Unit
end

local function getEffectCFrame(position, direction)
	local flatDirection = getFlatDirection(direction)
	return CFrame.lookAt(position, position + flatDirection, Vector3.yAxis)
end

local function getTemplateLifetime(config)
	if config == nil then
		return 0.8
	end

	return math.max(
		tonumber(config.TemplateLifetime) or 0,
		tonumber(config.ParticleLifetimeMax) or 0,
		tonumber(config.Lifetime) or 0,
		0.25
	)
end

local function createTemplateHolder(cframe, name)
	local holder = Instance.new("Part")
	holder.Name = name or "VFX_TemplateHolder"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = cframe
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Parent = vfxFolder

	return holder
end

local function prepareBasePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function isLightInstance(instance)
	return instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end

local function prepareBaseParts(rootInstance)
	if rootInstance:IsA("BasePart") then
		prepareBasePart(rootInstance)
	end

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			prepareBasePart(descendant)
		end
	end
end

local function collectBaseParts(rootInstance)
	local parts = {}

	if rootInstance:IsA("BasePart") then
		table.insert(parts, rootInstance)
	end

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function pivotBasePartContainer(rootInstance, cframe)
	local parts = collectBaseParts(rootInstance)
	local firstPart = parts[1]

	if firstPart == nil then
		return false
	end

	local delta = cframe * firstPart.CFrame:Inverse()

	for _, part in ipairs(parts) do
		part.CFrame = delta * part.CFrame
	end

	return true
end

function CombatVfxService.init(effectsFolder)
	vfxFolder = effectsFolder
end

function CombatVfxService.getVfxTemplatesFolder()
	local assets = shared:FindFirstChild("Assets")

	if assets == nil then
		warnOnce("missingAssetsFolder", "[VFX] ReplicatedStorage/Shared/Assets not found; template VFX disabled.")
		return nil
	end

	local templatesFolder = assets:FindFirstChild("VFX")

	if templatesFolder == nil then
		warnOnce("missingVfxFolder", "[VFX] ReplicatedStorage/Shared/Assets/VFX not found; template VFX disabled.")
		return nil
	end

	return templatesFolder
end

function CombatVfxService.findVfxTemplate(templateName, effectName, warnIfMissing)
	if not isNonEmptyString(templateName) then
		return nil
	end

	local templatesFolder = CombatVfxService.getVfxTemplatesFolder()

	if templatesFolder == nil then
		return nil
	end

	local template = templatesFolder:FindFirstChild(templateName)

	if template == nil and warnIfMissing ~= false then
		warnOnce(
			"missingTemplate:" .. templateName,
			"[VFX] Template '" .. templateName .. "' for " .. tostring(effectName or "effect") .. " was not found under ReplicatedStorage/Shared/Assets/VFX; using fallback."
		)
	end

	return template
end

function CombatVfxService.pivotVfxClone(clone, cframe, effectName)
	if vfxFolder == nil then
		warnOnce("missingRuntimeVfxFolder", "[VFX] Runtime VFX folder is missing; template VFX disabled.")
		return nil
	end

	local holderName = "VFX_Template_" .. tostring(effectName or clone.Name)

	if clone:IsA("ParticleEmitter") then
		local holder = createTemplateHolder(cframe, holderName)
		local attachment = Instance.new("Attachment")
		attachment.Name = "VFXTemplateAttachment"
		attachment.Parent = holder
		clone.Parent = attachment
		return holder
	end

	if clone:IsA("Attachment") then
		local holder = createTemplateHolder(cframe, holderName)
		clone.Parent = holder
		return holder
	end

	if clone:IsA("Sound") or isLightInstance(clone) then
		local holder = createTemplateHolder(cframe, holderName)
		clone.Parent = holder
		return holder
	end

	clone.Name = holderName
	clone.Parent = vfxFolder
	prepareBaseParts(clone)

	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	elseif not pivotBasePartContainer(clone, cframe) then
		local holder = createTemplateHolder(cframe, holderName .. "_Anchor")
		clone.Parent = holder
		return holder
	end

	return clone
end

local function forEachInstance(rootInstance, callback)
	callback(rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		callback(descendant)
	end
end

function CombatVfxService.emitAllParticles(rootInstance, emitCount)
	if rootInstance == nil then
		return
	end

	local defaultEmitCount = math.max(0, math.floor(tonumber(emitCount) or 1))

	forEachInstance(rootInstance, function(instance)
		if instance:IsA("ParticleEmitter") then
			local emitterEmitCount = instance:GetAttribute("EmitCount")
			local count = typeof(emitterEmitCount) == "number" and emitterEmitCount or defaultEmitCount

			if count > 0 then
				instance:Emit(count)
			end
		end
	end)
end

function CombatVfxService.playAllSounds(rootInstance, soundVolumeOverride)
	-- Legacy helper. Do not use for new combat audio; AudioCatalog/WOBAudioController owns sound playback.
	if rootInstance == nil then
		return
	end

	forEachInstance(rootInstance, function(instance)
		if instance:IsA("Sound") then
			if typeof(soundVolumeOverride) == "number" then
				instance.Volume = soundVolumeOverride
			end

			local soundKey = isNonEmptyString(instance.SoundId) and instance.SoundId or instance:GetFullName()
			local success, errorMessage = pcall(function()
				instance:Play()
			end)

			if not success then
				warnOnce(
					"templateSoundPlayFailed:" .. soundKey,
					"[VFX] Template sound for " .. soundKey .. " could not be played: " .. tostring(errorMessage)
				)
			end
		end
	end)
end

function CombatVfxService.playConfiguredSound(position, config, effectName)
	-- Legacy helper. Do not use for new combat audio; AudioCatalog/WOBAudioController owns sound playback.
	if config == nil or not isNonEmptyString(config.SoundId) then
		return false
	end

	if vfxFolder == nil then
		warnOnce("missingRuntimeVfxFolderForSound", "[VFX] Runtime VFX folder is missing; configured sound VFX disabled.")
		return false
	end

	local holder = createTemplateHolder(CFrame.new(position), "SFX_" .. tostring(effectName or "ConfiguredVfx"))
	local sound = Instance.new("Sound")
	sound.Name = "Sound"
	sound.SoundId = config.SoundId
	sound.Volume = config.SoundVolume or 0.7
	local playbackSpeed = config.SoundPlaybackSpeed or 1
	local playbackSpeedJitter = math.max(0, tonumber(config.SoundPlaybackSpeedJitter) or 0)

	if playbackSpeedJitter > 0 then
		playbackSpeed += (math.random() * 2 - 1) * playbackSpeedJitter
	end

	sound.PlaybackSpeed = math.max(0.05, playbackSpeed)
	sound.RollOffMaxDistance = config.SoundRollOffMaxDistance or 180
	sound.RollOffMinDistance = config.SoundRollOffMinDistance or 8
	sound.Parent = holder
	local success, errorMessage = pcall(function()
		sound:Play()
	end)
	Debris:AddItem(holder, config.SoundLifetime or 3)

	if not success then
		warnOnce(
			"configuredSoundPlayFailed:" .. config.SoundId,
			"[VFX] Configured sound for " .. tostring(effectName or "effect") .. " could not be played: "
				.. tostring(errorMessage)
		)
		return false
	end

	return true
end

function CombatVfxService.playVfxTemplate(position, direction, config, effectName)
	if config == nil or config.Enabled ~= true then
		return false
	end

	local templateNames = getConfiguredTemplateNames(config)
	if #templateNames == 0 then
		return false
	end

	local template = nil
	local templateName = nil

	for index, candidateTemplateName in ipairs(templateNames) do
		local warnIfMissing = index == 1 and config.WarnIfMissingTemplate ~= false
		template = CombatVfxService.findVfxTemplate(candidateTemplateName, effectName, warnIfMissing)

		if template ~= nil then
			templateName = candidateTemplateName
			break
		end
	end

	if template == nil then
		return false
	end

	local effectCFrame = getEffectCFrame(position, direction)
	local success, cloneOrError = pcall(function()
		local clone = template:Clone()
		return CombatVfxService.pivotVfxClone(clone, effectCFrame, effectName)
	end)

	if not success or cloneOrError == nil then
		warnOnce(
			"templateFailed:" .. templateName,
			"[VFX] Template '" .. templateName .. "' for " .. tostring(effectName or "effect") .. " could not be played; using fallback."
		)
		return false
	end

	CombatVfxService.emitAllParticles(cloneOrError, config.TemplateEmitCount or config.EmitCount or 1)
	Debris:AddItem(cloneOrError, getTemplateLifetime(config))

	return true
end

return CombatVfxService
