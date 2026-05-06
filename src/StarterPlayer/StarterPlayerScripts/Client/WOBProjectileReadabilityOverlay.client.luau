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

local function updateGlowCFrame(projectile, glow)
	glow.CFrame = CFrame.new(
		projectile.Position.X,
		projectileVisual.GroundGlowHeightOffset,
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

	local glow = Instance.new("Part")
	glow.Name = "WOBLocalProjectileGroundGlow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = projectileVisual.GroundGlowSize
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanTouch = false
	glow.CanQuery = false
	glow.CastShadow = false
	glow.Material = Enum.Material.Neon
	glow.Color = projectileVisual.GroundGlowColor
	glow.Transparency = projectileVisual.GroundGlowTransparency
	updateGlowCFrame(projectile, glow)
	glow.Parent = glowFolder

	trackedProjectiles[projectile] = glow
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
	for projectile, glow in pairs(trackedProjectiles) do
		if projectile.Parent == nil or glow.Parent == nil then
			if glow.Parent ~= nil then
				glow:Destroy()
			end

			trackedProjectiles[projectile] = nil
		else
			updateGlowCFrame(projectile, glow)
		end
	end
end)

print("[WOB] Projectile readability overlay started")
