local Workspace = game:GetService("Workspace")

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local projectileFolder = runtime:WaitForChild("Projectiles")

local function addTrail(projectile)
	if not projectile:IsA("BasePart") then
		return
	end

	if projectile:FindFirstChild("WOBTrail") ~= nil then
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TrailAttachment0"
	attachment0.Position = Vector3.new(0, 0, -0.45)
	attachment0.Parent = projectile

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "TrailAttachment1"
	attachment1.Position = Vector3.new(0, 0, 0.45)
	attachment1.Parent = projectile

	local trail = Instance.new("Trail")
	trail.Name = "WOBTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 0.18
	trail.MinLength = 0.1
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 120, 40))
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.Parent = projectile
end

for _, child in ipairs(projectileFolder:GetChildren()) do
	addTrail(child)
end

projectileFolder.ChildAdded:Connect(addTrail)

print("[WOB] Projectile visual enhancer started")
