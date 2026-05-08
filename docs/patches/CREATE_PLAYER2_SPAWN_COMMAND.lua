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
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn("[WOB SPAWN] Map not found in Workspace")
		return
	end

	local spawnPoints = getOrCreate(map, "Folder", "SpawnPoints")
	local p1Spawn = spawnPoints:FindFirstChild("PlayerSpawn")
	local dummySpawn = spawnPoints:FindFirstChild("DummySpawn")

	local p2Spawn, created = getOrCreate(spawnPoints, "Part", "Player2Spawn")
	
	p2Spawn.Size = Vector3.new(12, 1, 12)
	p2Spawn.Anchored = true
	p2Spawn.CanCollide = false
	p2Spawn.Transparency = 0.5
	p2Spawn.Color = Color3.fromRGB(255, 100, 100) -- Reddish for P2
	p2Spawn.Material = Enum.Material.Neon
	
	if created then
		-- Position it where DummySpawn is (or was)
		if dummySpawn and dummySpawn:IsA("BasePart") then
			p2Spawn.CFrame = dummySpawn.CFrame
		elseif p1Spawn and p1Spawn:IsA("BasePart") then
			p2Spawn.CFrame = p1Spawn.CFrame * CFrame.new(20, 0, 0)
		else
			p2Spawn.Position = Vector3.new(0, 0.5, 50)
		end
		print("[WOB SPAWN] Created Player2Spawn at " .. tostring(p2Spawn.Position))
	else
		print("[WOB SPAWN] Updated Player2Spawn")
	end
end

setupPlayer2Spawn()
