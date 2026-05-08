-- One-time Roblox Studio Command Bar repair for saved physical tank models.
-- Run outside Play Mode, then File -> Save to File.

local Workspace = game:GetService("Workspace")

local GENERATED_ROOT_NAME = "WOB_Generated"
local TEST_OBJECTS_NAME = "TestObjects"

local PART_SPECS = {
	Body = {
		Size = Vector3.new(8, 3, 11),
		Offset = CFrame.new(0, 2, 0),
		Color = Color3.fromRGB(55, 185, 255),
		Transparency = 0,
		CanQuery = false,
	},
	Turret = {
		Size = Vector3.new(5.5, 2.2, 5.5),
		Offset = CFrame.new(0, 4.6, 0),
		Color = Color3.fromRGB(80, 220, 160),
		Transparency = 0,
		CanQuery = false,
	},
	Barrel = {
		Size = Vector3.new(1.2, 1.2, 6),
		Offset = CFrame.new(0, 4.6, -5.8),
		Color = Color3.fromRGB(35, 40, 42),
		Transparency = 0,
		CanQuery = false,
	},
	ShootPoint = {
		Size = Vector3.new(0.6, 0.6, 0.6),
		Offset = CFrame.new(0, 4.6, -10),
		Color = Color3.fromRGB(255, 230, 80),
		Transparency = 0.35,
		CanQuery = false,
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
		IsBot = false,
		IsActive = true,
		Pivot = CFrame.lookAt(Vector3.new(-42, 0, -42), Vector3.new(42, 0, 42), Vector3.yAxis),
	},
	Player2TankPrototype = {
		TeamId = "Player2",
		ControllerType = "Player",
		IsPlayerTank = true,
		IsBot = false,
		IsActive = false,
		Pivot = CFrame.lookAt(Vector3.new(42, 0, -42), Vector3.new(-42, 0, 42), Vector3.yAxis),
		BodyColor = Color3.fromRGB(230, 65, 70),
		TurretColor = Color3.fromRGB(255, 105, 80),
	},
	DummyTank = {
		TeamId = "Dummy",
		ControllerType = "Dummy",
		IsPlayerTank = false,
		IsBot = true,
		IsActive = true,
		Pivot = CFrame.lookAt(Vector3.new(42, 0, 42), Vector3.new(-42, 0, -42), Vector3.yAxis),
		BodyColor = Color3.fromRGB(160, 65, 65),
		TurretColor = Color3.fromRGB(45, 45, 50),
	},
}

local function getOrCreateFolder(parent, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA("Folder") then
			error(existing:GetFullName() .. " exists but is " .. existing.ClassName .. ", expected Folder")
		end

		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	print("[TANK CONTRACT] created " .. folder:GetFullName())

	return folder
end

local root = getOrCreateFolder(Workspace, GENERATED_ROOT_NAME)
local testObjects = getOrCreateFolder(root, TEST_OBJECTS_NAME)

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

local function findFirstBasePart(model)
	local body = findBasePart(model, "Body")

	if body ~= nil then
		return body
	end

	local hull = findBasePart(model, "Hull")

	if hull ~= nil then
		return hull
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
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

local function getModelPivotOrDefault(model, defaultPivot)
	if countBaseParts(model) == 0 then
		return defaultPivot
	end

	local success, pivot = pcall(function()
		return model:GetPivot()
	end)

	if success and typeof(pivot) == "CFrame" then
		return pivot
	end

	return defaultPivot
end

local function getOrCreateTankModel(name)
	local existing = testObjects:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA("Model") then
			error(existing:GetFullName() .. " exists but is " .. existing.ClassName .. ", expected Model")
		end

		return existing
	end

	local model = Instance.new("Model")
	model.Name = name
	model.Parent = testObjects
	print("[TANK CONTRACT] created " .. model:GetFullName())

	return model
end

local function configureNewPart(part, spec, pivot, colorOverride)
	part.Size = spec.Size
	part.CFrame = pivot * spec.Offset
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = spec.CanQuery == true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = colorOverride or spec.Color
	part.Transparency = spec.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function preserveExistingVisualPart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function ensurePart(model, partName, pivot, colorOverride)
	local part = findBasePart(model, partName)

	if part ~= nil then
		preserveExistingVisualPart(part)
		return part, false
	end

	part = Instance.new("Part")
	part.Name = partName
	part.Parent = model
	configureNewPart(part, PART_SPECS[partName], pivot, colorOverride)
	print("[TANK CONTRACT] created " .. part:GetFullName())

	return part, true
end

local function configureNewHitbox(part, spec, pivot)
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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function preserveExistingHitbox(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
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
		print("[TANK CONTRACT] created " .. hitboxes:GetFullName())
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
			configureNewHitbox(hitbox, spec, pivot)
			print("[TANK CONTRACT] created " .. hitbox:GetFullName())
		else
			preserveExistingHitbox(hitbox)
		end
	end

	return hitboxes
end

local function assignPrimaryPart(model)
	local primaryPart = findBasePart(model, "Body") or findBasePart(model, "Hull") or findFirstBasePart(model)

	if primaryPart ~= nil then
		model.PrimaryPart = primaryPart
	end

	return primaryPart
end

local function setTankAttributes(model, tankName, tankConfig)
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
end

local function repairTank(tankName, tankConfig)
	local model = getOrCreateTankModel(tankName)
	local pivot = getModelPivotOrDefault(model, tankConfig.Pivot)

	ensurePart(model, "Body", pivot, tankConfig.BodyColor)
	ensurePart(model, "Turret", pivot, tankConfig.TurretColor)
	ensurePart(model, "Barrel", pivot)
	ensurePart(model, "ShootPoint", pivot)
	ensureHitboxes(model, pivot)
	setTankAttributes(model, tankName, tankConfig)

	local primaryPart = assignPrimaryPart(model)
	local primaryPartName = primaryPart ~= nil and primaryPart.Name or "nil"
	local basePartCount = countBaseParts(model)

	print(
		("[TANK CONTRACT] %s primaryPart=%s baseParts=%d"):format(
			tankName,
			primaryPartName,
			basePartCount
		)
	)
end

repairTank("PlayerTankPrototype", TANKS.PlayerTankPrototype)
repairTank("Player2TankPrototype", TANKS.Player2TankPrototype)
repairTank("DummyTank", TANKS.DummyTank)

print("[TANK CONTRACT] complete. File -> Save to File, then test Training and 2-player PvP.")
