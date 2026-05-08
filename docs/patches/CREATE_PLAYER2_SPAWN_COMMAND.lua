-- One-time Roblox Studio Command Bar setup for Player2Spawn.
-- Run outside Play Mode.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB SPAWN] Run this command outside Play Mode.")
	return
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			warn(("[WOB SPAWN] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
		end
		print("[WOB SPAWN] Kept existing " .. existing:GetFullName())
		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	print("[WOB SPAWN] Created " .. instance:GetFullName())
	return instance, true
end

local function setupPlayer2Spawn()
	local root = Workspace:FindFirstChild("WOB_Generated")

	if root == nil then
		root = Instance.new("Folder")
		root.Name = "WOB_Generated"
		root.Parent = Workspace
		print("[WOB SPAWN] Created " .. root:GetFullName())
	else
		print("[WOB SPAWN] Kept existing " .. root:GetFullName())
	end

	local map = root:FindFirstChild("Map")
	local legacySpawnPoints = map ~= nil and map:FindFirstChild("SpawnPoints") or nil
	local spawnPoints = getOrCreate(root, "Folder", "SpawnPoints")
	local p1Spawn = spawnPoints:FindFirstChild("PlayerSpawn")
	local dummySpawn = spawnPoints:FindFirstChild("DummySpawn")

	if p1Spawn == nil and legacySpawnPoints ~= nil then
		p1Spawn = legacySpawnPoints:FindFirstChild("PlayerSpawn")
	end

	if dummySpawn == nil and legacySpawnPoints ~= nil then
		dummySpawn = legacySpawnPoints:FindFirstChild("DummySpawn")
	end
	local defaultPosition = Vector3.new(42, 0.3, -42)
	local defaultLookAt = Vector3.new(-42, 0.3, 42)
	local defaultCFrame = CFrame.lookAt(defaultPosition, defaultLookAt, Vector3.yAxis)

	local p2Spawn, created = getOrCreate(spawnPoints, "Part", "Player2Spawn")
	
	p2Spawn.Size = Vector3.new(5, 0.35, 5)
	p2Spawn.Anchored = true
	p2Spawn.CanCollide = false
	p2Spawn.CanTouch = false
	p2Spawn.CanQuery = false
	p2Spawn.Transparency = 0.45
	p2Spawn.Color = Color3.fromRGB(255, 100, 100)
	p2Spawn.Material = Enum.Material.Neon
	p2Spawn.TopSurface = Enum.SurfaceType.Smooth
	p2Spawn.BottomSurface = Enum.SurfaceType.Smooth

	if created then
		if p1Spawn and p1Spawn:IsA("BasePart") then
			p2Spawn.CFrame = CFrame.lookAt(defaultPosition, p1Spawn.Position, Vector3.yAxis)
		else
			p2Spawn.CFrame = defaultCFrame
		end
		print("[WOB SPAWN] Created Player2Spawn at " .. tostring(p2Spawn.Position))
	else
		print("[WOB SPAWN] Updated Player2Spawn at " .. p2Spawn:GetFullName())
	end

	if dummySpawn and dummySpawn:IsA("BasePart") then
		local flatDelta = Vector3.new(
			p2Spawn.Position.X - dummySpawn.Position.X,
			0,
			p2Spawn.Position.Z - dummySpawn.Position.Z
		)

		if flatDelta.Magnitude < 8 then
			local separatedCFrame = defaultCFrame

			if p1Spawn and p1Spawn:IsA("BasePart") then
				separatedCFrame = CFrame.lookAt(defaultPosition, p1Spawn.Position, Vector3.yAxis)
			end

			p2Spawn.CFrame = separatedCFrame
			print("[WOB SPAWN] Moved Player2Spawn away from DummySpawn to " .. tostring(p2Spawn.Position))
		end
	end

	print("[WOB SPAWN] Player2Spawn ready at Workspace/WOB_Generated/SpawnPoints. File -> Save to File.")
end

setupPlayer2Spawn()
