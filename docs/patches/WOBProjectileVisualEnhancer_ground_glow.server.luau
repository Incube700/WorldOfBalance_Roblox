local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local ProjectileVisualConfig = require(configs:WaitForChild("ProjectileVisualConfig"))
local projectileVisual = ProjectileVisualConfig.ProjectileTypeVisuals.PrototypeRicochetShell
local trailConfig = projectileVisual.Trail

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local projectileFolder = runtime:WaitForChild("Projectiles")

local groundGlows = {}

local function updateGroundGlowCFrame(projectile, glow)
	glow.CFrame = CFrame.new(
		projectile.Position.X,
		projectileVisual.GroundGlowHeightOffset,
		projectile.Position.Z
	)
end

local function addGroundGlow(projectile)
	if projectileVisual.GroundGlowEnabled ~= true then
		return
	end

	if projectile:FindFirstChild("WOBGroundGlow") ~= nil then
		return
	end

	local glow = Instance.new("Part")
	glow.Name = "WOBGroundGlow"
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
	updateGroundGlowCFrame(projectile, glow)
	glow.Parent = projectile

	groundGlows[projectile] = glow
end

local function addTrail(projectile)
	if not projectile:IsA("BasePart") then
		return
	end

	if projectile:FindFirstChild(trailConfig.Name) ~= nil then
		addGroundGlow(projectile)
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = trailConfig.Attachment0Name
	attachment0.Position = trailConfig.Attachment0Position
	attachment0.Parent = projectile

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = trailConfig.Attachment1Name
	attachment1.Position = trailConfig.Attachment1Position
	attachment1.Parent = projectile

	local trail = Instance.new("Trail")
	trail.Name = trailConfig.Name
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = trailConfig.Lifetime
	trail.MinLength = trailConfig.MinLength
	trail.LightEmission = trailConfig.LightEmission
	trail.FaceCamera = trailConfig.FaceCamera
	trail.Color = ColorSequence.new(trailConfig.ColorStart, trailConfig.ColorEnd)
	trail.Transparency = NumberSequence.new(trailConfig.TransparencyStart, trailConfig.TransparencyEnd)
	trail.Parent = projectile

	addGroundGlow(projectile)
end

for _, child in ipairs(projectileFolder:GetChildren()) do
	addTrail(child)
end

projectileFolder.ChildAdded:Connect(addTrail)

RunService.Heartbeat:Connect(function()
	for projectile, glow in pairs(groundGlows) do
		if projectile.Parent == nil or glow.Parent == nil then
			groundGlows[projectile] = nil
		else
			updateGroundGlowCFrame(projectile, glow)
		end
	end
end)

print("[WOB] Projectile visual enhancer started")
