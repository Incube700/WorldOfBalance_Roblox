local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local ProjectileVisualConfig = require(configs:WaitForChild("ProjectileVisualConfig"))
local projectileVisual = ProjectileVisualConfig.ProjectileTypeVisuals.PrototypeRicochetShell

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local projectileFolder = runtime:WaitForChild("Projectiles")

local localVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if localVisuals == nil then
	localVisuals = Instance.new("Folder")
	localVisuals.Name = "WOB_LocalVisuals"
	localVisuals.Parent = Workspace
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
	coreGlow.Color = Color3.fromRGB(255, 240, 160)
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

print("[WOB] Projectile readability overlay started")
