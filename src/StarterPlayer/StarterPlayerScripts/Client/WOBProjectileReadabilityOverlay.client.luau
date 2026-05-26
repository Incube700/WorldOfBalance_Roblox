local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local PerformanceConfig = require(configs:WaitForChild("PerformanceConfig"))
local ProjectileVisualConfig = require(configs:WaitForChild("ProjectileVisualConfig"))
local projectileVisual = ProjectileVisualConfig.ProjectileTypeVisuals.PrototypeRicochetShell

local diagnosticsConfig = PerformanceConfig.Diagnostics or {}

if diagnosticsConfig.ProjectileVfxEnabled == false then
	return
end

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime", 20)

if runtime == nil then
	warn("[WOB] Projectile readability overlay disabled: Runtime folder was not found")
	return
end

local projectileFolder = runtime:WaitForChild("Projectiles", 20)

if projectileFolder == nil then
	warn("[WOB] Projectile readability overlay disabled: Projectiles folder was not found")
	return
end

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

local staleLocalVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if staleLocalVisuals ~= nil then
	staleLocalVisuals:Destroy()
end

local wobRuntime = Workspace:FindFirstChild("WOB_Runtime") or Workspace:WaitForChild("WOB_Runtime", 10)

if wobRuntime == nil then
	wobRuntime = getOrCreateFolder(Workspace, "WOB_Runtime")
end

local clientRuntime = wobRuntime ~= nil and getOrCreateFolder(wobRuntime, "Client") or nil
local localVisuals = clientRuntime ~= nil and getOrCreateFolder(clientRuntime, "Visuals") or nil

if localVisuals == nil then
	warn("[WOB] Projectile readability overlay disabled: Workspace.WOB_Runtime.Client.Visuals could not be created")
	return
end

local glowFolder = localVisuals:FindFirstChild("ProjectileReadabilityGlows")

if glowFolder == nil then
	glowFolder = Instance.new("Folder")
	glowFolder.Name = "ProjectileReadabilityGlows"
	glowFolder.Parent = localVisuals
end

local trackedProjectiles = {}

local CORE_SCALE = 0.42
local CORE_HEIGHT_OFFSET = 0.025
local CORE_TRANSPARENCY_OFFSET = -0.18

local function setVisualPhysics(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
end

local function updateGlowCFrame(projectile, glowParts)
	glowParts.Outer.CFrame = CFrame.new(
		projectile.Position.X,
		projectileVisual.GroundGlowHeightOffset,
		projectile.Position.Z
	)
	glowParts.Core.CFrame = CFrame.new(
		projectile.Position.X,
		projectileVisual.GroundGlowHeightOffset + CORE_HEIGHT_OFFSET,
		projectile.Position.Z
	)
end

local function isSmallRuntimePart(part)
	local size = part.Size
	return math.max(size.X, size.Y, size.Z) <= 4
end

local function isProjectileCandidate(instance)
	if not instance:IsA("BasePart") then
		return false
	end

	local lowerName = string.lower(instance.Name)

	if string.find(lowerName, "glow") ~= nil or string.find(lowerName, "spark") ~= nil or string.find(lowerName, "flash") ~= nil then
		return false
	end

	if string.find(lowerName, "projectile") ~= nil or string.find(lowerName, "bullet") ~= nil or string.find(lowerName, "shell") ~= nil then
		return true
	end

	return instance:IsDescendantOf(projectileFolder) and isSmallRuntimePart(instance)
end

local function attachGlow(projectile)
	if projectileVisual.GroundGlowEnabled ~= true then
		return
	end

	if trackedProjectiles[projectile] ~= nil or not isProjectileCandidate(projectile) then
		return
	end

	local outerGlow = Instance.new("Part")
	outerGlow.Name = "WOBLocalProjectileGroundGlow"
	outerGlow.Shape = Enum.PartType.Ball
	outerGlow.Size = projectileVisual.GroundGlowSize
	setVisualPhysics(outerGlow)
	outerGlow.Color = projectileVisual.GroundGlowColor
	outerGlow.Transparency = projectileVisual.GroundGlowTransparency
	outerGlow.Parent = glowFolder

	local coreGlow = Instance.new("Part")
	coreGlow.Name = "WOBLocalProjectileGroundGlowCore"
	coreGlow.Shape = Enum.PartType.Ball
	coreGlow.Size = Vector3.new(
		projectileVisual.GroundGlowSize.X * CORE_SCALE,
		projectileVisual.GroundGlowSize.Y,
		projectileVisual.GroundGlowSize.Z * CORE_SCALE
	)
	setVisualPhysics(coreGlow)
	coreGlow.Color = projectileVisual.GroundGlowCoreColor or Color3.fromRGB(110, 170, 220)
	coreGlow.Transparency = math.clamp(projectileVisual.GroundGlowTransparency + CORE_TRANSPARENCY_OFFSET, 0, 1)
	coreGlow.Parent = glowFolder

	local glowParts = {
		Outer = outerGlow,
		Core = coreGlow,
	}

	updateGlowCFrame(projectile, glowParts)
	trackedProjectiles[projectile] = glowParts
end

for _, descendant in ipairs(projectileFolder:GetDescendants()) do
	attachGlow(descendant)
end

projectileFolder.DescendantAdded:Connect(attachGlow)

runtime.DescendantAdded:Connect(function(descendant)
	if isProjectileCandidate(descendant) then
		attachGlow(descendant)
	end
end)

RunService.RenderStepped:Connect(function()
	for projectile, glowParts in pairs(trackedProjectiles) do
		if projectile.Parent == nil or glowParts.Outer.Parent == nil or glowParts.Core.Parent == nil then
			if glowParts.Outer.Parent ~= nil then
				glowParts.Outer:Destroy()
			end

			if glowParts.Core.Parent ~= nil then
				glowParts.Core:Destroy()
			end

			trackedProjectiles[projectile] = nil
		else
			updateGlowCFrame(projectile, glowParts)
		end
	end
end)
