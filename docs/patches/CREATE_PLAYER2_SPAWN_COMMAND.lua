-- One-time Roblox Studio Command Bar setup for Player2Spawn.
-- Run outside Play Mode.

local Workspace = game:GetService("Workspace")

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			warn(("[WOB SPAWN] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
		end
		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance, true
end

local function setupPlayer2Spawn()
	local root = Workspace:FindFirstChild("WOB_Generated")

	if root == nil then
		warn("[WOB SPAWN] Workspace/WOB_Generated not found")
		return
	end

	local map = root:FindFirstChild("Map")

	if not map then
		warn("[WOB SPAWN] Workspace/WOB_Generated/Map not found")
		return
	end

	local spawnPoints = getOrCreate(map, "Folder", "SpawnPoints")
	local p1Spawn = spawnPoints:FindFirstChild("PlayerSpawn")
	local dummySpawn = spawnPoints:FindFirstChild("DummySpawn")
	local legacySpawns = map:FindFirstChild("Spawns")
	local legacyEnemySpawn = legacySpawns ~= nil and legacySpawns:FindFirstChild("EnemySpawnPoint") or nil

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
		if dummySpawn and dummySpawn:IsA("BasePart") then
			p2Spawn.CFrame = dummySpawn.CFrame
		elseif legacyEnemySpawn and legacyEnemySpawn:IsA("BasePart") then
			p2Spawn.CFrame = legacyEnemySpawn.CFrame
		elseif p1Spawn and p1Spawn:IsA("BasePart") then
			p2Spawn.CFrame = p1Spawn.CFrame * CFrame.new(42, 0, 42)
		else
			p2Spawn.CFrame = CFrame.lookAt(Vector3.new(42, 0.3, 42), Vector3.new(-42, 0.3, -42), Vector3.yAxis)
		end
		print("[WOB SPAWN] Created Player2Spawn at " .. tostring(p2Spawn.Position))
	else
		print("[WOB SPAWN] Updated Player2Spawn at " .. p2Spawn:GetFullName())
	end
end

setupPlayer2Spawn()
