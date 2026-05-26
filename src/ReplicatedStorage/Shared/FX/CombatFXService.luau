local CombatFXService = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameplayFXCatalog = require(script.Parent:WaitForChild("GameplayFXCatalog"))

local TEMPORARY_FX_FOLDER_NAME = "WOB_TemporaryFX"

local function isDebugEnabled(options)
	return (options ~= nil and options.Debug == true)
		or (RunService:IsStudio() and GameplayFXCatalog.Debug == true)
end

local function debugLog(options, message)
	if isDebugEnabled(options) then
		print("[GameplayFX] " .. message)
	end
end

local function isLightInstance(instance)
	return instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end

local function isVisualLeaf(instance)
	return instance:IsA("BasePart")
		or instance:IsA("Attachment")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or isLightInstance(instance)
end

local function hasVisualDescendant(instance)
	if isVisualLeaf(instance) then
		return true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if isVisualLeaf(descendant) then
			return true
		end
	end

	return false
end

local function isPlayableTemplate(instance)
	if instance == nil
		or instance:IsA("Script")
		or instance:IsA("LocalScript")
		or instance:IsA("ModuleScript")
		or instance:IsA("Sound")
	then
		return false
	end

	if isVisualLeaf(instance) then
		return true
	end

	if instance:IsA("Model") or instance:IsA("Folder") then
		return hasVisualDescendant(instance)
	end

	return false
end

local function isFolderItselfPlayable(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if isVisualLeaf(child) then
			return true
		end
	end

	return false
end

local function getGameplayFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil, "ReplicatedStorage/Assets is missing"
	end

	local fx = assets:FindFirstChild("FX")
	if fx == nil then
		return nil, "ReplicatedStorage/Assets/FX is missing"
	end

	local gameplay = fx:FindFirstChild("Gameplay")
	if gameplay == nil then
		return nil, "ReplicatedStorage/Assets/FX/Gameplay is missing"
	end

	return gameplay, nil
end

local function getRuntimeFolder()
	local folder = Workspace:FindFirstChild(TEMPORARY_FX_FOLDER_NAME)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = TEMPORARY_FX_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
end

local function getEffectDefinition(effectKey)
	local effects = GameplayFXCatalog.Effects
	return effects ~= nil and effects[effectKey] or nil
end

local function isNonEmptyString(value)
	return typeof(value) == "string" and value ~= ""
end

local function getInstancePath(instance)
	if instance == nil then
		return "<nil>"
	end

	return instance:GetFullName()
end

local function formatVector3(value)
	if typeof(value) ~= "Vector3" then
		return tostring(value)
	end

	return ("(%.2f, %.2f, %.2f)"):format(value.X, value.Y, value.Z)
end

local function getPlayableChildren(categoryFolder)
	local playableChildren = {}

	for _, child in ipairs(categoryFolder:GetChildren()) do
		if isPlayableTemplate(child) then
			table.insert(playableChildren, child)
		end
	end

	table.sort(playableChildren, function(left, right)
		return left.Name < right.Name
	end)

	return playableChildren
end

local function findPlayableChildByName(categoryFolder, childName)
	if not isNonEmptyString(childName) then
		return nil
	end

	local child = categoryFolder:FindFirstChild(childName)

	if isPlayableTemplate(child) then
		return child
	end

	return nil
end

local function getDefaultChildren(playableChildren)
	local defaultChildren = {}

	for _, child in ipairs(playableChildren) do
		if string.find(string.lower(child.Name), "default", 1, true) ~= nil then
			table.insert(defaultChildren, child)
		end
	end

	return defaultChildren
end

local function resolveTemplate(effectKey, options)
	local effectDefinition = getEffectDefinition(effectKey)

	if effectDefinition == nil then
		return nil, nil, "unknown effect key"
	end

	local gameplayFolder, gameplayFolderError = getGameplayFolder()
	if gameplayFolder == nil then
		return nil, effectDefinition, gameplayFolderError
	end

	local categoryFolder = gameplayFolder:FindFirstChild(effectDefinition.FolderName)
	if categoryFolder == nil then
		return nil, effectDefinition, "missing folder " .. effectDefinition.FolderName
	end

	local explicitTemplateName = effectDefinition.TemplateName
	local explicitTemplate = findPlayableChildByName(categoryFolder, explicitTemplateName)

	if explicitTemplate ~= nil then
		return explicitTemplate, effectDefinition, nil, "canonical"
	elseif isNonEmptyString(explicitTemplateName) then
		debugLog(
			options,
			("explicit template %s not found/playable for %s under %s; trying Default/only-child fallback"):format(
				explicitTemplateName,
				tostring(effectKey),
				getInstancePath(categoryFolder)
			)
		)
	end

	local playableChildren = getPlayableChildren(categoryFolder)

	if #playableChildren == 0 then
		if isFolderItselfPlayable(categoryFolder) then
			return categoryFolder, effectDefinition, nil, "canonical"
		end

		return nil, effectDefinition, "no playable template under " .. getInstancePath(categoryFolder)
	end

	local defaultChildren = getDefaultChildren(playableChildren)

	if #defaultChildren == 1 then
		return defaultChildren[1], effectDefinition, nil, "canonical"
	elseif #defaultChildren > 1 then
		debugLog(
			options,
			("skipped %s: multiple Default templates under %s; set TemplateName to choose one"):format(
				tostring(effectKey),
				getInstancePath(categoryFolder)
			)
		)

		return nil, effectDefinition, "ambiguous Default templates without exact TemplateName"
	end

	if #playableChildren == 1 then
		return playableChildren[1], effectDefinition, nil, "canonical"
	end

	debugLog(
		options,
		("skipped %s: multiple playable children under %s and none contains Default"):format(
			tostring(effectKey),
			getInstancePath(categoryFolder)
		)
	)

	return nil, effectDefinition, "ambiguous templates without Default"
end

local function forEachInstance(rootInstance, callback)
	callback(rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		callback(descendant)
	end
end

function CombatFXService.DisableScripts(rootInstance)
	if rootInstance == nil then
		return 0
	end

	local toDestroy = {}

	forEachInstance(rootInstance, function(instance)
		if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
			table.insert(toDestroy, instance)
		end
	end)

	for _, instance in ipairs(toDestroy) do
		if instance.Parent ~= nil then
			instance:Destroy()
		end
	end

	return #toDestroy
end

function CombatFXService.StopAudio(rootInstance)
	if rootInstance == nil then
		return 0
	end

	local stoppedCount = 0

	forEachInstance(rootInstance, function(instance)
		if instance:IsA("Sound") then
			stoppedCount += 1
			instance.Looped = false
			instance.Volume = 0

			pcall(function()
				instance.PlayOnRemove = false
			end)

			pcall(function()
				instance:Stop()
			end)

			pcall(function()
				instance.Playing = false
			end)
		end
	end)

	return stoppedCount
end

local function prepareBasePart(part, anchored)
	part.Anchored = anchored == true
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true

	pcall(function()
		part.CanQuery = false
	end)

	part.CastShadow = false
end

local function prepareBaseParts(rootInstance, anchored)
	if rootInstance:IsA("BasePart") then
		prepareBasePart(rootInstance, anchored)
	end

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			prepareBasePart(descendant, anchored)
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

local function getAxisAlignedBoundsCFrame(rootInstance)
	local parts = collectBaseParts(rootInstance)

	if #parts == 0 then
		return nil
	end

	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5

		for _, xSign in ipairs({ -1, 1 }) do
			for _, ySign in ipairs({ -1, 1 }) do
				for _, zSign in ipairs({ -1, 1 }) do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(
						halfSize.X * xSign,
						halfSize.Y * ySign,
						halfSize.Z * zSign
					))

					minX = math.min(minX, corner.X)
					minY = math.min(minY, corner.Y)
					minZ = math.min(minZ, corner.Z)
					maxX = math.max(maxX, corner.X)
					maxY = math.max(maxY, corner.Y)
					maxZ = math.max(maxZ, corner.Z)
				end
			end
		end
	end

	return CFrame.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
end

local function getVisualBoundsCFrame(rootInstance)
	if rootInstance == nil then
		return nil
	end

	if rootInstance:IsA("Model") then
		local ok, boundsCFrame = pcall(function()
			local cframe = rootInstance:GetBoundingBox()
			return cframe
		end)

		if ok and typeof(boundsCFrame) == "CFrame" then
			return boundsCFrame
		end
	end

	return getAxisAlignedBoundsCFrame(rootInstance)
end

local function createHolder(cframe, name)
	local holder = Instance.new("Part")
	holder.Name = name or "GameplayFXHolder"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = cframe
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false

	pcall(function()
		holder.CanQuery = false
	end)

	holder.CastShadow = false
	holder.Transparency = 1
	holder.Parent = getRuntimeFolder()

	return holder
end

local function pivotBasePartContainer(rootInstance, cframe)
	local parts = collectBaseParts(rootInstance)
	local sourceCFrame = getVisualBoundsCFrame(rootInstance)

	if #parts == 0 or sourceCFrame == nil then
		return false, nil, nil
	end

	local delta = cframe * sourceCFrame:Inverse()

	for _, part in ipairs(parts) do
		part.CFrame = delta * part.CFrame
	end

	return true, sourceCFrame, delta
end

local function pivotCloneToCFrame(rootInstance, cframe)
	local pivoted, sourceCFrame, delta = pivotBasePartContainer(rootInstance, cframe)

	if pivoted then
		return true, sourceCFrame, delta
	end

	if rootInstance:IsA("Model") then
		local sourcePivot = rootInstance:GetPivot()
		rootInstance:PivotTo(cframe)
		return true, sourcePivot, cframe * sourcePivot:Inverse()
	end

	return false, nil, nil
end

local function getEffectCFrame(positionOrCFrame, options, effectDefinition)
	local cframe = nil

	if typeof(positionOrCFrame) == "CFrame" then
		cframe = positionOrCFrame
	elseif typeof(positionOrCFrame) == "Vector3" then
		local direction = options ~= nil and options.Direction or nil

		if typeof(direction) == "Vector3" and direction.Magnitude > 0.001 then
			local flatDirection = Vector3.new(direction.X, 0, direction.Z)

			if flatDirection.Magnitude > 0.001 then
				cframe = CFrame.lookAt(positionOrCFrame, positionOrCFrame + flatDirection.Unit, Vector3.yAxis)
			end
		end

		cframe = cframe or CFrame.new(positionOrCFrame)
	end

	if cframe == nil then
		return nil
	end

	local yOffset = tonumber(options ~= nil and options.YOffset) or tonumber(effectDefinition.YOffset) or 0

	if yOffset ~= 0 then
		cframe *= CFrame.new(0, yOffset, 0)
	end

	return cframe
end

local function scaleNumberSequence(numberSequence, scale)
	local keypoints = {}

	for _, keypoint in ipairs(numberSequence.Keypoints) do
		table.insert(
			keypoints,
			NumberSequenceKeypoint.new(
				keypoint.Time,
				keypoint.Value * scale,
				keypoint.Envelope * scale
			)
		)
	end

	return NumberSequence.new(keypoints)
end

local function applyScaleIfSafe(clone, scaleMultiplier, options)
	local scale = tonumber(scaleMultiplier)

	if scale == nil or scale <= 0 or math.abs(scale - 1) < 0.001 then
		return false
	end

	local scaled = false

	if clone:IsA("Model") then
		local ok = pcall(function()
			clone:ScaleTo((clone:GetScale() or 1) * scale)
		end)

		if ok then
			scaled = true
		end
	elseif clone:IsA("BasePart") then
		clone.Size *= scale
		scaled = true
	end

	if not clone:IsA("Model") then
		for _, part in ipairs(collectBaseParts(clone)) do
			if part ~= clone then
				part.Size *= scale
				scaled = true
			end
		end
	end

	forEachInstance(clone, function(instance)
		if instance:IsA("Attachment") then
			instance.Position *= scale
			scaled = true
		elseif instance:IsA("ParticleEmitter") then
			instance.Size = scaleNumberSequence(instance.Size, scale)
			scaled = true
		elseif instance:IsA("Beam") then
			instance.Width0 *= scale
			instance.Width1 *= scale
			scaled = true
		elseif instance:IsA("Trail") then
			instance.WidthScale = scaleNumberSequence(instance.WidthScale, scale)
			scaled = true
		end
	end)

	if not scaled then
		debugLog(options, ("scale skipped for %s; no safely scalable visual descendants found"):format(clone.ClassName))
	end

	return scaled
end

local function mountCloneAt(clone, cframe, effectKey)
	local holderName = "GameplayFX_" .. tostring(effectKey)

	if clone:IsA("ParticleEmitter") then
		local holder = createHolder(cframe, holderName)
		local attachment = Instance.new("Attachment")
		attachment.Name = "GameplayFXAttachment"
		attachment.Parent = holder
		clone.Parent = attachment
		return holder, nil, holder.CFrame, nil
	end

	if clone:IsA("Beam") or clone:IsA("Trail") then
		local holder = createHolder(cframe, holderName)
		clone.Parent = holder
		return holder, nil, holder.CFrame, nil
	end

	if clone:IsA("Attachment") then
		local holder = createHolder(cframe, holderName)
		clone.Parent = holder
		return holder, nil, holder.CFrame, nil
	end

	if clone:IsA("Sound") or isLightInstance(clone) then
		local holder = createHolder(cframe, holderName)
		clone.Parent = holder
		return holder, nil, holder.CFrame, nil
	end

	clone.Name = holderName
	clone.Parent = getRuntimeFolder()
	prepareBaseParts(clone, true)

	local pivoted, sourceCFrame, delta = pivotCloneToCFrame(clone, cframe)

	if not pivoted then
		local holder = createHolder(cframe, holderName .. "_Anchor")
		clone.Parent = holder
		return holder, nil, holder.CFrame, nil
	end

	return clone, sourceCFrame, getVisualBoundsCFrame(clone), delta
end

local function isAttachmentInsideRoot(rootInstance, attachment)
	return attachment ~= nil
		and (attachment == rootInstance or attachment:IsDescendantOf(rootInstance))
end

local function isExternalAttachmentAllowed(rootInstance, attachment, options)
	return options ~= nil
		and options.AllowExternalAttachments == true
		and attachment ~= nil
		and attachment.Parent ~= nil
		and not attachment:IsDescendantOf(rootInstance)
end

local function bindProjectileAttachments(rootInstance, attachment0, attachment1)
	if attachment0 == nil or attachment1 == nil then
		return 0
	end

	local boundCount = 0

	forEachInstance(rootInstance, function(instance)
		if instance:IsA("Beam") or instance:IsA("Trail") then
			instance.Attachment0 = attachment0
			instance.Attachment1 = attachment1
			boundCount += 1
		end
	end)

	return boundCount
end

local function weldVisualPartsToParent(rootInstance, parentPart)
	if parentPart == nil or not parentPart:IsA("BasePart") then
		return 0
	end

	local weldCount = 0

	for _, part in ipairs(collectBaseParts(rootInstance)) do
		if part ~= parentPart then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "GameplayFXWeld"
			weld.Part0 = parentPart
			weld.Part1 = part
			weld.Parent = part
			weldCount += 1
		end
	end

	return weldCount
end

function CombatFXService.EmitAll(rootInstance, options)
	local stats = {
		ParticleEmitters = 0,
		ParticleBursts = 0,
		BeamsEnabled = 0,
		BeamsSkipped = 0,
		TrailsEnabled = 0,
		TrailsSkipped = 0,
	}

	if rootInstance == nil then
		return stats
	end

	options = options or {}
	local defaultEmitCount = math.max(0, math.floor(tonumber(options.EmitCount) or 1))
	local enableTrails = options.EnableTrails == true
	local enableParticleEmitters = options.EnableParticleEmitters == true
	local allowExternalAttachments = options.AllowExternalAttachments == true

	forEachInstance(rootInstance, function(instance)
		if instance:IsA("ParticleEmitter") then
			stats.ParticleEmitters += 1

			if enableParticleEmitters then
				instance.Enabled = true
			else
				local attributeCount = instance:GetAttribute("EmitCount")
				local emitCount = typeof(attributeCount) == "number" and attributeCount or defaultEmitCount

				if emitCount > 0 then
					instance:Emit(emitCount)
					stats.ParticleBursts += emitCount
				end

				instance.Enabled = false
			end
		elseif instance:IsA("Beam") then
			if isAttachmentInsideRoot(rootInstance, instance.Attachment0)
				and isAttachmentInsideRoot(rootInstance, instance.Attachment1)
				or (
					allowExternalAttachments
					and isExternalAttachmentAllowed(rootInstance, instance.Attachment0, options)
					and isExternalAttachmentAllowed(rootInstance, instance.Attachment1, options)
				)
			then
				instance.Enabled = true
				stats.BeamsEnabled += 1
			else
				instance.Enabled = false
				stats.BeamsSkipped += 1
			end
		elseif instance:IsA("Trail") then
			if enableTrails
				and (
					(
						isAttachmentInsideRoot(rootInstance, instance.Attachment0)
						and isAttachmentInsideRoot(rootInstance, instance.Attachment1)
					)
					or (
						allowExternalAttachments
						and isExternalAttachmentAllowed(rootInstance, instance.Attachment0, options)
						and isExternalAttachmentAllowed(rootInstance, instance.Attachment1, options)
					)
				)
			then
				instance.Enabled = true
				stats.TrailsEnabled += 1
			else
				instance.Enabled = false
				stats.TrailsSkipped += 1
			end
		end
	end)

	return stats
end

function CombatFXService.Cleanup(instance, lifetime)
	if instance == nil then
		return
	end

	Debris:AddItem(instance, math.max(0.1, tonumber(lifetime) or 3))
end

local function playClone(effectKey, template, effectDefinition, cframe, options)
	local clone = template:Clone()
	local removedScripts = CombatFXService.DisableScripts(clone)
	local stoppedSounds = CombatFXService.StopAudio(clone)
	local scaleApplied = applyScaleIfSafe(
		clone,
		options.ScaleMultiplier or effectDefinition.ScaleMultiplier,
		options
	)
	local mounted, sourceCFrame, finalCFrame, delta = mountCloneAt(clone, cframe, effectKey)

	if mounted == nil then
		return nil, removedScripts, stoppedSounds, scaleApplied, nil
	end

	local lifetime = options.Lifetime or effectDefinition.Lifetime or effectDefinition.DefaultLifetime or 3
	local emitCount = options.EmitCount or effectDefinition.EmitCount or effectDefinition.DefaultEmitCount or 1
	local stats = CombatFXService.EmitAll(mounted, {
		EmitCount = emitCount,
		EnableTrails = options.EnableTrails == true,
	})

	if options.SkipCleanup ~= true then
		CombatFXService.Cleanup(mounted, lifetime)
	end

	return mounted, removedScripts, stoppedSounds, scaleApplied, stats, lifetime, sourceCFrame, finalCFrame, delta
end

function CombatFXService.PlayAt(effectKey, positionOrCFrame, options)
	options = options or {}
	debugLog(options, ("request PlayAt key=%s"):format(tostring(effectKey)))

	local template, effectDefinition, missingReason, source = resolveTemplate(effectKey, options)

	if template == nil or effectDefinition == nil then
		debugLog(options, ("missing key=%s reason=%s"):format(tostring(effectKey), tostring(missingReason)))
		return nil
	end

	local cframe = getEffectCFrame(positionOrCFrame, options, effectDefinition)
	if cframe == nil then
		debugLog(options, ("skipped key=%s reason=invalid position/cframe"):format(tostring(effectKey)))
		return nil
	end

	debugLog(
		options,
		("resolved key=%s source=%s template=%s templateType=%s templateName=%s requested=%s lifetime=%s emit=%s yOffset=%s scale=%s"):format(
			tostring(effectKey),
			tostring(source or "canonical"),
			getInstancePath(template),
			template.ClassName,
			tostring(effectDefinition.TemplateName or ""),
			formatVector3(cframe.Position),
			tostring(options.Lifetime or effectDefinition.Lifetime or effectDefinition.DefaultLifetime or 3),
			tostring(options.EmitCount or effectDefinition.EmitCount or effectDefinition.DefaultEmitCount or 1),
			tostring(options.YOffset or effectDefinition.YOffset or 0),
			tostring(options.ScaleMultiplier or effectDefinition.ScaleMultiplier or 1)
		)
	)

	local success, mounted, removedScripts, stoppedSounds, scaleApplied, stats, lifetime, sourceCFrame, finalCFrame, delta = pcall(function()
		return playClone(effectKey, template, effectDefinition, cframe, options)
	end)

	if not success or mounted == nil then
		debugLog(options, ("failed key=%s reason=%s"):format(tostring(effectKey), tostring(mounted)))
		return nil
	end

	local finalOffset = finalCFrame ~= nil and (finalCFrame.Position - cframe.Position) or nil
	local appliedDelta = delta ~= nil and delta.Position or nil

	debugLog(
		options,
		("played key=%s parent=%s requested=%s sourcePivot=%s finalPivot=%s finalOffset=%s appliedDelta=%s lifetime=%.2f particles=%d bursts=%d beams=%d beamSkips=%d trails=%d trailSkips=%d scriptsRemoved=%d soundsStopped=%d scaleApplied=%s"):format(
			tostring(effectKey),
			getInstancePath(mounted.Parent),
			formatVector3(cframe.Position),
			formatVector3(sourceCFrame ~= nil and sourceCFrame.Position or nil),
			formatVector3(finalCFrame ~= nil and finalCFrame.Position or nil),
			formatVector3(finalOffset),
			formatVector3(appliedDelta),
			tonumber(lifetime) or 0,
			stats.ParticleEmitters,
			stats.ParticleBursts,
			stats.BeamsEnabled,
			stats.BeamsSkipped,
			stats.TrailsEnabled,
			stats.TrailsSkipped,
			removedScripts,
			stoppedSounds,
			tostring(scaleApplied)
		)
	)

	return mounted
end

function CombatFXService.AttachTo(effectKey, parentInstance, options)
	options = options or {}
	debugLog(options, ("request AttachTo key=%s"):format(tostring(effectKey)))

	if parentInstance == nil or parentInstance.Parent == nil then
		debugLog(options, ("skipped key=%s reason=missing attach parent"):format(tostring(effectKey)))
		return nil
	end

	local template, effectDefinition, missingReason, source = resolveTemplate(effectKey, options)

	if template == nil or effectDefinition == nil then
		debugLog(options, ("missing key=%s reason=%s"):format(tostring(effectKey), tostring(missingReason)))
		return nil
	end

	debugLog(
		options,
		("resolved key=%s source=%s template=%s templateName=%s attachMode=%s lifetime=%s emit=%s scale=%s"):format(
			tostring(effectKey),
			tostring(source or "canonical"),
			getInstancePath(template),
			tostring(effectDefinition.TemplateName or ""),
			tostring(options.AttachMode or effectDefinition.AttachMode or ""),
			tostring(options.Lifetime or effectDefinition.Lifetime or effectDefinition.DefaultLifetime or 3),
			tostring(options.EmitCount or effectDefinition.EmitCount or effectDefinition.DefaultEmitCount or 1),
			tostring(options.ScaleMultiplier or effectDefinition.ScaleMultiplier or 1)
		)
	)

	local success, cloneOrError, removedScripts, stoppedSounds, scaleApplied = pcall(function()
		local clone = template:Clone()
		local scriptCount = CombatFXService.DisableScripts(clone)
		local soundCount = CombatFXService.StopAudio(clone)
		local wasScaled = applyScaleIfSafe(
			clone,
			options.ScaleMultiplier or effectDefinition.ScaleMultiplier,
			options
		)
		prepareBaseParts(clone, false)
		if parentInstance:IsA("BasePart") then
			pivotCloneToCFrame(clone, parentInstance.CFrame)
		end
		clone.Parent = parentInstance
		if options.Attachment0 ~= nil and options.Attachment1 ~= nil then
			bindProjectileAttachments(clone, options.Attachment0, options.Attachment1)
		end
		if parentInstance:IsA("BasePart") then
			weldVisualPartsToParent(clone, parentInstance)
		end

		return clone, scriptCount, soundCount, wasScaled
	end)

	if not success or cloneOrError == nil then
		debugLog(options, ("failed AttachTo key=%s reason=%s"):format(tostring(effectKey), tostring(cloneOrError)))
		return nil
	end

	local lifetime = options.Lifetime or effectDefinition.Lifetime or effectDefinition.DefaultLifetime or 3
	local emitCount = options.EmitCount or effectDefinition.EmitCount or effectDefinition.DefaultEmitCount or 1
	local stats = CombatFXService.EmitAll(cloneOrError, {
		EmitCount = emitCount,
		EnableTrails = options.EnableTrails == true,
		EnableParticleEmitters = options.EnableParticleEmitters == true,
		AllowExternalAttachments = options.AllowExternalAttachments == true,
	})

	if options.SkipCleanup ~= true then
		CombatFXService.Cleanup(cloneOrError, lifetime)
	end
	debugLog(
		options,
		("attached key=%s parent=%s lifetime=%.2f particles=%d bursts=%d beams=%d beamSkips=%d trails=%d trailSkips=%d scriptsRemoved=%d soundsStopped=%d scaleApplied=%s"):format(
			tostring(effectKey),
			getInstancePath(parentInstance),
			tonumber(lifetime) or 0,
			stats.ParticleEmitters,
			stats.ParticleBursts,
			stats.BeamsEnabled,
			stats.BeamsSkipped,
			stats.TrailsEnabled,
			stats.TrailsSkipped,
			removedScripts,
			stoppedSounds,
			tostring(scaleApplied)
		)
	)

	return cloneOrError
end

return CombatFXService
