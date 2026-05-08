-- One-time Roblox Studio Command Bar repair for physical tank models.
-- Run outside Play Mode, then File -> Save to File.

local Workspace = game:GetService("Workspace")

local root = Workspace:FindFirstChild("WOB_Generated")

if root == nil then
	error("Workspace/WOB_Generated not found")
end

local testObjects = root:FindFirstChild("TestObjects")

if testObjects == nil then
	testObjects = Instance.new("Folder")
	testObjects.Name = "TestObjects"
	testObjects.Parent = root
end

local PART_SPECS = {
	Body = {
		Size = Vector3.new(8, 3, 11),
		Offset = CFrame.new(0, 2, 0),
		Color = Color3.fromRGB(55, 185, 255),
	},
	Turret = {
		Size = Vector3.new(5.5, 2.2, 5.5),
		Offset = CFrame.new(0, 4.6, 0),
		Color = Color3.fromRGB(80, 220, 160),
	},
	Barrel = {
		Size = Vector3.new(1.2, 1.2, 6),
		Offset = CFrame.new(0, 4.6, -5.8),
		Color = Color3.fromRGB(35, 40, 42),
	},
	ShootPoint = {
		Size = Vector3.new(0.6, 0.6, 0.6),
		Offset = CFrame.new(0, 4.6, -10),
		Color = Color3.fromRGB(255, 230, 80),
	},
}

local HITBOX_SPECS = {
	FrontArmor = {
		Size = Vector3.new(8.7, 5.4, 0.25),
		Offset = CFrame.new(0, 3.4, -5.7),
		Color = Color3.fromRGB(80, 255, 120),
	},
	RearArmor = {
		Size = Vector3.new(8.7, 5.4, 0.25),
		Offset = CFrame.new(0, 3.4, 5.7),
		Color = Color3.fromRGB(255, 90, 90),
	},
	LeftArmor = {
		Size = Vector3.new(0.25, 5.4, 11.7),
		Offset = CFrame.new(-4.2, 3.4, 0),
		Color = Color3.fromRGB(255, 220, 80),
	},
	RightArmor = {
		Size = Vector3.new(0.25, 5.4, 11.7),
		Offset = CFrame.new(4.2, 3.4, 0),
		Color = Color3.fromRGB(255, 220, 80),
	},
}

local TANKS = {
	PlayerTankPrototype = {
		TeamId = "Player",
		ControllerType = "Player",
		IsPlayerTank = true,
		Pivot = CFrame.lookAt(Vector3.new(-42, 0, -42), Vector3.new(42, 0, 42), Vector3.yAxis),
	},
	Player2TankPrototype = {
		TeamId = "Player2",
		ControllerType = "Player",
		IsPlayerTank = true,
		IsActive = false,
		Pivot = CFrame.lookAt(Vector3.new(42, 0, 42), Vector3.new(-42, 0, -42), Vector3.yAxis),
	},
	DummyTank = {
		TeamId = "Dummy",
		ControllerType = "Dummy",
		IsPlayerTank = false,
		IsBot = true,
		Pivot = CFrame.lookAt(Vector3.new(42, 0, 42), Vector3.new(-42, 0, -42), Vector3.yAxis),
		BodyColor = Color3.fromRGB(160, 65, 65),
		TurretColor = Color3.fromRGB(45, 45, 50),
	},
}

local function findBasePart(model, partName)
	local directChild = model:FindFirstChild(partName)

	if directChild ~= nil and directChild:IsA("BasePart") then
		return directChild
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getOrCreateModel(name)
	local model = testObjects:FindFirstChild(name)

	if model ~= nil and not model:IsA("Model") then
		error(model:GetFullName() .. " exists but is " .. model.ClassName .. ", expected Model")
	end

	if model == nil then
		model = Instance.new("Model")
		model.Name = name
		model.Parent = testObjects
	end

	return model
end

local function configurePart(part, spec, pivot, colorOverride)
	part.Size = spec.Size
	part.CFrame = pivot * spec.Offset
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = colorOverride or spec.Color
	part.Transparency = 0
end

local function configureHitbox(part, spec, pivot)
	part.Size = spec.Size
	part.CFrame = pivot * spec.Offset
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = spec.Color
	part.Transparency = 0.45
end

local function ensurePart(model, partName, spec, pivot, colorOverride)
	local part = findBasePart(model, partName)
	local created = false

	if part == nil then
		part = Instance.new("Part")
		part.Name = partName
		part.Parent = model
		created = true
	end

	configurePart(part, spec, pivot, colorOverride)

	if created then
		print("[WOB TANK] Created " .. part:GetFullName())
	end

	return part
end

local function ensureHitboxes(model, pivot)
	local hitboxes = model:FindFirstChild("Hitboxes")

	if hitboxes ~= nil and not hitboxes:IsA("Folder") then
		error(hitboxes:GetFullName() .. " exists but is " .. hitboxes.ClassName .. ", expected Folder")
	end

	if hitboxes == nil then
		hitboxes = Instance.new("Folder")
		hitboxes.Name = "Hitboxes"
		hitboxes.Parent = model
		print("[WOB TANK] Created " .. hitboxes:GetFullName())
	end

	for hitboxName, spec in pairs(HITBOX_SPECS) do
		local hitbox = hitboxes:FindFirstChild(hitboxName)

		if hitbox ~= nil and not hitbox:IsA("BasePart") then
			error(hitbox:GetFullName() .. " exists but is " .. hitbox.ClassName .. ", expected BasePart")
		end

		if hitbox == nil then
			hitbox = Instance.new("Part")
			hitbox.Name = hitboxName
			hitbox.Parent = hitboxes
			print("[WOB TANK] Created " .. hitbox:GetFullName())
		end

		configureHitbox(hitbox, spec, pivot)
	end
end

local function countBaseParts(model)
	local count = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

local function repairTank(tankName, tankConfig)
	local model = getOrCreateModel(tankName)
	local pivot = tankConfig.Pivot
	local body = ensurePart(model, "Body", PART_SPECS.Body, pivot, tankConfig.BodyColor)

	ensurePart(model, "Turret", PART_SPECS.Turret, pivot, tankConfig.TurretColor)
	ensurePart(model, "Barrel", PART_SPECS.Barrel, pivot)
	ensurePart(model, "ShootPoint", PART_SPECS.ShootPoint, pivot)
	ensureHitboxes(model, pivot)

	model.PrimaryPart = body
	model:SetAttribute("TankId", tankName)
	model:SetAttribute("TeamId", tankConfig.TeamId)
	model:SetAttribute("ControllerType", tankConfig.ControllerType)
	model:SetAttribute("IsPlayerTank", tankConfig.IsPlayerTank == true)
	model:SetAttribute("IsBot", tankConfig.IsBot == true)
	model:SetAttribute("IsActive", tankConfig.IsActive ~= false)
	model:SetAttribute("OwnerUserId", nil)
	model:SetAttribute("OwnerName", nil)
	model:SetAttribute("Health", 100)
	model:SetAttribute("MaxHealth", 100)
	model:SetAttribute("IsDead", false)

	print(
		("[WOB TANK] %s ready primaryPart=%s baseParts=%d"):format(
			model:GetFullName(),
			body.Name,
			countBaseParts(model)
		)
	)
end

repairTank("PlayerTankPrototype", TANKS.PlayerTankPrototype)
repairTank("DummyTank", TANKS.DummyTank)
repairTank("Player2TankPrototype", TANKS.Player2TankPrototype)

print("[WOB TANK] Tank model contract ready. File -> Save to File, then test Training and 2-player PvP.")
