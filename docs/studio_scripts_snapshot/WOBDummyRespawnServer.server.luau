local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetDummyRequestEvent = remotes:WaitForChild("ResetDummyRequestEvent")

local root = Workspace:WaitForChild("WOB_Generated")
local testObjects = root:WaitForChild("TestObjects")
local dummyTank = testObjects:WaitForChild("DummyTank")

local MAX_HEALTH = 100
local RESPAWN_DELAY = 2.25

local isRespawning = false

local function setPartColor(part)
	if part.Name == "Body" then
		part.Color = Color3.fromRGB(160, 65, 65)
	elseif part.Name == "Turret" then
		part.Color = Color3.fromRGB(45, 45, 50)
	elseif part.Name == "Barrel" then
		part.Color = Color3.fromRGB(30, 30, 35)
	elseif part.Name == "ShootPoint" then
		part.Color = Color3.fromRGB(255, 230, 80)
	elseif part.Name == "FrontArmor" then
		part.Color = Color3.fromRGB(80, 180, 255)
	elseif part.Name == "RearArmor" then
		part.Color = Color3.fromRGB(255, 150, 80)
	elseif part.Name == "LeftArmor" or part.Name == "RightArmor" then
		part.Color = Color3.fromRGB(180, 255, 120)
	end
end

local function resetDummy()
	dummyTank:SetAttribute("Health", MAX_HEALTH)

	for _, descendant in ipairs(dummyTank:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setPartColor(descendant)
		end
	end

	print("[RESET] DummyTank health restored")
end

local function scheduleRespawn()
	if isRespawning then
		return
	end

	isRespawning = true

	task.delay(RESPAWN_DELAY, function()
		resetDummy()
		isRespawning = false
	end)
end

dummyTank:GetAttributeChangedSignal("Health"):Connect(function()
	local health = dummyTank:GetAttribute("Health") or MAX_HEALTH

	if health <= 0 then
		scheduleRespawn()
	end
end)

resetDummyRequestEvent.OnServerEvent:Connect(function()
	resetDummy()
end)

print("[WOB] Dummy respawn server started")
