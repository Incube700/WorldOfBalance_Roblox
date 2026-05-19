local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local ProjectileVisualConfig = require(configs:WaitForChild("ProjectileVisualConfig"))

local root = Workspace:WaitForChild("WOB_Generated")
local localPlayer = Players.LocalPlayer
local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		return nil
	end

	return folder
end

local function waitForRuntimeVfxFolder(timeout)
	local deadline = os.clock() + timeout
	local fallbackLegacyVfxFolder = nil

	while os.clock() < deadline do
		local wobRuntime = Workspace:FindFirstChild("WOB_Runtime")
		local vfxFolder = wobRuntime ~= nil and wobRuntime:FindFirstChild("VFX") or nil

		if vfxFolder ~= nil then
			return vfxFolder
		end

		local legacyRuntime = root:FindFirstChild("Runtime")
		local legacyVfxFolder = legacyRuntime ~= nil and legacyRuntime:FindFirstChild("VFX") or nil

		if legacyVfxFolder ~= nil then
			fallbackLegacyVfxFolder = fallbackLegacyVfxFolder or legacyVfxFolder
		end

		task.wait(0.1)
	end

	return fallbackLegacyVfxFolder
end

local vfxFolder = waitForRuntimeVfxFolder(20)

if vfxFolder == nil then
	warn("[WOB] Impact feedback overlay disabled: VFX folder was not found")
	return
end

local testObjects = root:WaitForChild("TestObjects", 20)
local dummyBody = nil

local function refreshDummyBody()
	if dummyBody ~= nil and dummyBody.Parent ~= nil then
		return dummyBody
	end

	if testObjects == nil then
		return nil
	end

	local dummyTank = testObjects:FindFirstChild("DummyTank")

	if dummyTank == nil then
		return nil
	end

	dummyBody = dummyTank:FindFirstChild("Body")

	return dummyBody
end

local staleLocalVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if staleLocalVisuals ~= nil then
	staleLocalVisuals:Destroy()
end

local wobRuntime = getOrCreateFolder(Workspace, "WOB_Runtime")
local clientRuntime = wobRuntime ~= nil and getOrCreateFolder(wobRuntime, "Client") or nil
local localVisuals = clientRuntime ~= nil and getOrCreateFolder(clientRuntime, "LocalVisuals") or nil

if localVisuals == nil then
	warn("[WOB] Impact feedback overlay disabled: Workspace.WOB_Runtime.Client.LocalVisuals could not be created")
	return
end

local impactFolder = localVisuals:FindFirstChild("ImpactFeedback")

if impactFolder == nil then
	impactFolder = Instance.new("Folder")
	impactFolder.Name = "ImpactFeedback"
	impactFolder.Parent = localVisuals
end

local IMPACT_MARKER_HEIGHT = 0.16
local PULSE_DEDUPE_SECONDS = 0.11
local DUMMY_HIT_RADIUS = 9.5

local recentPulseByCell = {}

local function isImpactVisibleForLocalPlayer()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode == "Lobby"
		or mode == "QueuedForDuel"
		or mode == "InMatch"
		or mode == "InBattleArena"
		or mode == "ArenaRespawning"
	then
		return true
	end

	return mode == nil and root:GetAttribute("GameState") == "Playing"
end

local function getPulseCell(position)
	return math.floor(position.X * 2) .. ":" .. math.floor(position.Z * 2)
end

local function isNearDummy(position)
	local currentDummyBody = refreshDummyBody()

	if currentDummyBody == nil then
		return false
	end

	local flatImpact = Vector3.new(position.X, 0, position.Z)
	local flatDummy = Vector3.new(currentDummyBody.Position.X, 0, currentDummyBody.Position.Z)

	return (flatImpact - flatDummy).Magnitude <= DUMMY_HIT_RADIUS
end

local function getPulseStyle(position)
	if isNearDummy(position) then
		return {
			Lifetime = 0.26,
			OuterStartSize = Vector3.new(2.8, 0.08, 2.8),
			OuterEndSize = Vector3.new(8.4, 0.08, 8.4),
			CoreStartSize = Vector3.new(1.35, 0.1, 1.35),
			CoreEndSize = Vector3.new(3.1, 0.1, 3.1),
			OuterColor = Color3.fromRGB(255, 105, 45),
			CoreColor = Color3.fromRGB(255, 220, 120),
			OuterTransparency = 0.28,
			CoreTransparency = 0.08,
		}
	end

	return {
		Lifetime = 0.18,
		OuterStartSize = Vector3.new(2.1, 0.07, 2.1),
		OuterEndSize = Vector3.new(5.8, 0.07, 5.8),
		CoreStartSize = Vector3.new(0.95, 0.09, 0.95),
		CoreEndSize = Vector3.new(2.15, 0.09, 2.15),
		OuterColor = ProjectileVisualConfig.RicochetSparks.Color,
		CoreColor = Color3.fromRGB(255, 245, 170),
		OuterTransparency = 0.34,
		CoreTransparency = 0.12,
	}
end

local function preparePulsePart(name, position, size, color, transparency, heightOffset)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.CFrame = CFrame.new(position.X, IMPACT_MARKER_HEIGHT + heightOffset, position.Z)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Parent = impactFolder

	return part
end

local function animatePulsePart(part, position, startSize, endSize, startTransparency, lifetime, heightOffset, elapsed)
	local alpha = math.clamp(elapsed / lifetime, 0, 1)
	part.Size = startSize:Lerp(endSize, alpha)
	part.Transparency = startTransparency + alpha * (1 - startTransparency)
	part.CFrame = CFrame.new(position.X, IMPACT_MARKER_HEIGHT + heightOffset, position.Z)
end

local function createPulse(position)
	if not isImpactVisibleForLocalPlayer() then
		impactFolder:ClearAllChildren()
		return
	end

	local now = os.clock()
	local cell = getPulseCell(position)
	local lastPulse = recentPulseByCell[cell]

	if lastPulse ~= nil and now - lastPulse < PULSE_DEDUPE_SECONDS then
		return
	end

	recentPulseByCell[cell] = now
	local style = getPulseStyle(position)

	local outerPulse = preparePulsePart(
		"WOBLocalImpactPulse",
		position,
		style.OuterStartSize,
		style.OuterColor,
		style.OuterTransparency,
		0
	)
	local coreFlash = preparePulsePart(
		"WOBLocalImpactPulseCore",
		position,
		style.CoreStartSize,
		style.CoreColor,
		style.CoreTransparency,
		0.03
	)

	task.spawn(function()
		local elapsed = 0

		while elapsed < style.Lifetime and outerPulse.Parent ~= nil and coreFlash.Parent ~= nil do
			animatePulsePart(
				outerPulse,
				position,
				style.OuterStartSize,
				style.OuterEndSize,
				style.OuterTransparency,
				style.Lifetime,
				0,
				elapsed
			)
			animatePulsePart(
				coreFlash,
				position,
				style.CoreStartSize,
				style.CoreEndSize,
				style.CoreTransparency,
				style.Lifetime,
				0.03,
				elapsed
			)

			elapsed += RunService.RenderStepped:Wait()
		end

		if outerPulse.Parent ~= nil then
			outerPulse:Destroy()
		end

		if coreFlash.Parent ~= nil then
			coreFlash:Destroy()
		end
	end)
end

local function isImpactSpark(instance)
	return instance:IsA("BasePart") and instance.Name == "VFX_Spark"
end

vfxFolder.ChildAdded:Connect(function(child)
	if isImpactVisibleForLocalPlayer() and isImpactSpark(child) then
		createPulse(child.Position)
	end
end)

root:GetAttributeChangedSignal("GameState"):Connect(function()
	if not isImpactVisibleForLocalPlayer() then
		impactFolder:ClearAllChildren()
	end
end)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(function()
	if not isImpactVisibleForLocalPlayer() then
		impactFolder:ClearAllChildren()
	end
end)

print("[WOB] Impact feedback overlay started")
