local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local ProjectileVisualConfig = require(configs:WaitForChild("ProjectileVisualConfig"))

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local vfxFolder = runtime:WaitForChild("VFX")

local localVisuals = Workspace:FindFirstChild("WOB_LocalVisuals")

if localVisuals == nil then
	localVisuals = Instance.new("Folder")
	localVisuals.Name = "WOB_LocalVisuals"
	localVisuals.Parent = Workspace
end

local impactFolder = localVisuals:FindFirstChild("ImpactFeedback")

if impactFolder == nil then
	impactFolder = Instance.new("Folder")
	impactFolder.Name = "ImpactFeedback"
	impactFolder.Parent = localVisuals
end

local IMPACT_MARKER_LIFETIME = 0.22
local IMPACT_MARKER_START_SIZE = Vector3.new(2.4, 0.08, 2.4)
local IMPACT_MARKER_END_SIZE = Vector3.new(7.2, 0.08, 7.2)
local IMPACT_MARKER_HEIGHT = 0.16
local PULSE_DEDUPE_SECONDS = 0.08

local recentPulseByCell = {}

local function getPulseCell(position)
	return math.floor(position.X * 2) .. ":" .. math.floor(position.Z * 2)
end

local function createPulse(position)
	local now = os.clock()
	local cell = getPulseCell(position)
	local lastPulse = recentPulseByCell[cell]

	if lastPulse ~= nil and now - lastPulse < PULSE_DEDUPE_SECONDS then
		return
	end

	recentPulseByCell[cell] = now

	local pulse = Instance.new("Part")
	pulse.Name = "WOBLocalImpactPulse"
	pulse.Shape = Enum.PartType.Ball
	pulse.Size = IMPACT_MARKER_START_SIZE
	pulse.CFrame = CFrame.new(position.X, IMPACT_MARKER_HEIGHT, position.Z)
	pulse.Anchored = true
	pulse.CanCollide = false
	pulse.CanTouch = false
	pulse.CanQuery = false
	pulse.CastShadow = false
	pulse.Material = Enum.Material.Neon
	pulse.Color = ProjectileVisualConfig.ImpactFlash.Color
	pulse.Transparency = 0.2
	pulse.Parent = impactFolder

	task.spawn(function()
		local elapsed = 0

		while elapsed < IMPACT_MARKER_LIFETIME and pulse.Parent ~= nil do
			local alpha = math.clamp(elapsed / IMPACT_MARKER_LIFETIME, 0, 1)
			pulse.Size = IMPACT_MARKER_START_SIZE:Lerp(IMPACT_MARKER_END_SIZE, alpha)
			pulse.Transparency = 0.2 + alpha * 0.8
			pulse.CFrame = CFrame.new(position.X, IMPACT_MARKER_HEIGHT, position.Z)

			elapsed += RunService.RenderStepped:Wait()
		end

		if pulse.Parent ~= nil then
			pulse:Destroy()
		end
	end)
end

local function isImpactSpark(instance)
	return instance:IsA("BasePart") and instance.Name == "VFX_Spark"
end

vfxFolder.ChildAdded:Connect(function(child)
	if isImpactSpark(child) then
		createPulse(child.Position)
	end
end)

print("[WOB] Impact feedback overlay started")
