local PlayerTankSpawner = {}

local REQUIRED_PART_NAMES = {
	"Body",
	"Turret",
	"Barrel",
	"ShootPoint",
}

local ARMOR_HITBOX_NAMES = {
	"FrontArmor",
	"RearArmor",
	"LeftArmor",
	"RightArmor",
}

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

local function getModelPivot(model)
	local success, pivot = pcall(function()
		return model:GetPivot()
	end)

	if success and typeof(pivot) == "CFrame" then
		return pivot
	end

	return CFrame.new()
end

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

	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
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

local function configureVisualPart(part, spec, pivot)
	part.Size = spec.Size
	part.CFrame = pivot * spec.Offset
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = spec.Color
	part.Transparency = 0
end

local function configureHitboxPart(part, spec, pivot)
	part.Size = spec.Size
	part.CFrame = pivot * spec.Offset
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = spec.Color
	part.Transparency = 1
end

local function ensurePart(model, partName)
	local existing = findBasePart(model, partName)

	if existing ~= nil then
		return existing, false
	end

	local part = Instance.new("Part")
	part.Name = partName
	part.Parent = model

	configureVisualPart(part, PART_SPECS[partName], getModelPivot(model))

	warn("[TANK] created missing " .. model:GetFullName() .. "." .. partName)

	return part, true
end

local function ensureHitboxes(model)
	local hitboxes = model:FindFirstChild("Hitboxes")

	if hitboxes ~= nil and not hitboxes:IsA("Folder") then
		warn("[TANK] " .. hitboxes:GetFullName() .. " is " .. hitboxes.ClassName .. ", expected Folder")
		hitboxes = nil
	end

	if hitboxes == nil then
		hitboxes = Instance.new("Folder")
		hitboxes.Name = "Hitboxes"
		hitboxes.Parent = model
		warn("[TANK] created missing " .. model:GetFullName() .. ".Hitboxes")
	end

	local pivot = getModelPivot(model)

	for _, hitboxName in ipairs(ARMOR_HITBOX_NAMES) do
		local hitbox = hitboxes:FindFirstChild(hitboxName)

		if hitbox ~= nil and not hitbox:IsA("BasePart") then
			warn("[TANK] " .. hitbox:GetFullName() .. " is " .. hitbox.ClassName .. ", expected BasePart")
			hitbox = nil
		end

		if hitbox == nil then
			hitbox = Instance.new("Part")
			hitbox.Name = hitboxName
			hitbox.Parent = hitboxes
			configureHitboxPart(hitbox, HITBOX_SPECS[hitboxName], pivot)
			warn("[TANK] created missing " .. model:GetFullName() .. ".Hitboxes." .. hitboxName)
		end
	end

	return hitboxes
end

function PlayerTankSpawner.ensurePrimaryPart(model)
	local primaryPart = findFirstBasePart(model)

	if primaryPart ~= nil then
		model.PrimaryPart = primaryPart
	end

	return primaryPart
end

function PlayerTankSpawner.getTankParts(model)
	local parts = {
		Model = model,
		Body = findBasePart(model, "Body"),
		Hull = findBasePart(model, "Hull"),
		Turret = findBasePart(model, "Turret"),
		Barrel = findBasePart(model, "Barrel"),
		ShootPoint = findBasePart(model, "ShootPoint"),
		Hitboxes = model:FindFirstChild("Hitboxes"),
		BasePartCount = countBaseParts(model),
		PrimaryPart = PlayerTankSpawner.ensurePrimaryPart(model),
	}

	if parts.Hitboxes ~= nil and not parts.Hitboxes:IsA("Folder") then
		parts.Hitboxes = nil
	end

	return parts
end

function PlayerTankSpawner.ensurePhysicalTankModel(model)
	if model == nil or not model:IsA("Model") then
		return model
	end

	for _, partName in ipairs(REQUIRED_PART_NAMES) do
		ensurePart(model, partName)
	end

	ensureHitboxes(model)
	PlayerTankSpawner.ensurePrimaryPart(model)

	return model
end

local function waitForTankParts(model)
	PlayerTankSpawner.ensurePhysicalTankModel(model)

	return PlayerTankSpawner.getTankParts(model)
end

function PlayerTankSpawner.getOrCreateRuntimePlayerTank(sourceModel, parent, tankName)
	PlayerTankSpawner.ensurePhysicalTankModel(sourceModel)

	local existing = parent:FindFirstChild(tankName)

	if existing ~= nil and existing:IsA("Model") then
		return waitForTankParts(existing), false
	end

	local clone = sourceModel:Clone()
	clone.Name = tankName
	clone.Parent = parent

	return waitForTankParts(clone), true
end

function PlayerTankSpawner.getDynamicPlayerTankName(player)
	return "PlayerTank_" .. tostring(player.UserId)
end

function PlayerTankSpawner.getOrCreatePlayerTankForPlayer(sourceModel, parent, player)
	return PlayerTankSpawner.getOrCreateRuntimePlayerTank(
		sourceModel,
		parent,
		PlayerTankSpawner.getDynamicPlayerTankName(player)
	)
end

return PlayerTankSpawner
