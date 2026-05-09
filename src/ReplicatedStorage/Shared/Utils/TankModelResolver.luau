local TankModelResolver = {}

local DEFAULT_FOCUS_PART_NAMES = {
	"Body",
	"Hull",
	"Root",
}

local HITBOX_FOLDER_NAME = "Hitboxes"

local function getSearchRoots(root)
	local searchRoots = {}
	local testObjects = root:FindFirstChild("TestObjects")
	local runtime = root:FindFirstChild("Runtime")

	if testObjects ~= nil then
		table.insert(searchRoots, testObjects)
	end

	if runtime ~= nil then
		table.insert(searchRoots, runtime)
	end

	table.insert(searchRoots, root)

	return searchRoots
end

local function getInstanceFromFullName(fullName)
	if typeof(fullName) ~= "string" or fullName == "" then
		return nil
	end

	local current = game
	local isFirstSegment = true

	for segment in string.gmatch(fullName, "[^%.]+") do
		if isFirstSegment then
			isFirstSegment = false

			if segment == "game" then
				current = game
			else
				local success, service = pcall(function()
					return game:GetService(segment)
				end)

				if success and service ~= nil then
					current = service
				else
					current = game:FindFirstChild(segment)
				end
			end
		else
			current = current ~= nil and current:FindFirstChild(segment) or nil
		end

		if current == nil then
			return nil
		end
	end

	return current
end

local function findNamedBasePart(model, partName)
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

local function isInsideHitboxes(instance)
	local current = instance.Parent

	while current ~= nil do
		if current.Name == HITBOX_FOLDER_NAME then
			return true
		end

		if current:IsA("Model") then
			return false
		end

		current = current.Parent
	end

	return false
end

local function findFirstPhysicalBasePart(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and not isInsideHitboxes(descendant) then
			return descendant
		end
	end

	return nil
end

function TankModelResolver.countBaseParts(model)
	if model == nil then
		return 0
	end

	local count = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

function TankModelResolver.findFocusPart(model)
	if model == nil then
		return nil
	end

	if model:IsA("BasePart") then
		return model
	end

	if not model:IsA("Model") then
		return nil
	end

	if model.PrimaryPart ~= nil and not isInsideHitboxes(model.PrimaryPart) then
		return model.PrimaryPart
	end

	for _, partName in ipairs(DEFAULT_FOCUS_PART_NAMES) do
		local part = findNamedBasePart(model, partName)

		if part ~= nil then
			return part
		end
	end

	return findFirstPhysicalBasePart(model)
end

function TankModelResolver.hasBasePart(model)
	return TankModelResolver.findFocusPart(model) ~= nil
end

local function findPhysicalModelByTankId(root, tankId)
	if tankId == nil or tankId == "" then
		return nil
	end

	for _, searchRoot in ipairs(getSearchRoots(root)) do
		local named = searchRoot:FindFirstChild(tankId, true)

		if named ~= nil and named:IsA("Model") and TankModelResolver.hasBasePart(named) then
			return named
		end

		for _, descendant in ipairs(searchRoot:GetDescendants()) do
			if descendant:IsA("Model")
				and descendant:GetAttribute("TankId") == tankId
				and TankModelResolver.hasBasePart(descendant)
			then
				return descendant
			end
		end
	end

	return nil
end

function TankModelResolver.resolvePhysicalModel(root, model)
	if model == nil or not model:IsA("Model") then
		return nil
	end

	if TankModelResolver.hasBasePart(model) then
		return model
	end

	local physicalModelPath = model:GetAttribute("PhysicalModelPath")
	local physicalModel = getInstanceFromFullName(physicalModelPath)

	if physicalModel ~= nil and physicalModel:IsA("Model") and TankModelResolver.hasBasePart(physicalModel) then
		return physicalModel
	end

	return findPhysicalModelByTankId(root, model:GetAttribute("TankId") or model.Name)
end

function TankModelResolver.findOwnedTank(root, userId, requirePhysical)
	local fallback = nil

	for _, searchRoot in ipairs(getSearchRoots(root)) do
		for _, descendant in ipairs(searchRoot:GetDescendants()) do
			if descendant:IsA("Model")
				and descendant:GetAttribute("IsPlayerTank") == true
				and descendant:GetAttribute("OwnerUserId") == userId
			then
				local physicalModel = TankModelResolver.resolvePhysicalModel(root, descendant)

				if physicalModel ~= nil then
					return physicalModel
				end

				fallback = fallback or descendant
			end
		end
	end

	if requirePhysical == true then
		return nil
	end

	return fallback
end

function TankModelResolver.findTankByTankId(root, tankId, requirePhysical)
	local fallback = nil

	for _, searchRoot in ipairs(getSearchRoots(root)) do
		for _, descendant in ipairs(searchRoot:GetDescendants()) do
			if descendant:IsA("Model")
				and (descendant:GetAttribute("TankId") == tankId or descendant.Name == tankId)
			then
				local physicalModel = TankModelResolver.resolvePhysicalModel(root, descendant)

				if physicalModel ~= nil then
					return physicalModel
				end

				fallback = fallback or descendant
			end
		end
	end

	if requirePhysical == true then
		return nil
	end

	return fallback
end

function TankModelResolver.findEnemyTank(root, userId)
	local ownedTank = TankModelResolver.findOwnedTank(root, userId, true)
	local opponentTankId = ownedTank ~= nil and ownedTank:GetAttribute("OpponentTankId") or nil

	if opponentTankId ~= nil and opponentTankId ~= "" then
		local opponentTank = TankModelResolver.findTankByTankId(root, opponentTankId, true)

		if opponentTank ~= nil then
			return opponentTank
		end
	end

	local matchMode = root:GetAttribute("MatchMode")

	if matchMode == "PvP" then
		for _, searchRoot in ipairs(getSearchRoots(root)) do
			for _, descendant in ipairs(searchRoot:GetDescendants()) do
				if descendant:IsA("Model")
					and descendant:GetAttribute("IsPlayerTank") == true
					and descendant:GetAttribute("IsActive") ~= false
					and descendant:GetAttribute("OwnerUserId") ~= nil
					and descendant:GetAttribute("OwnerUserId") ~= userId
				then
					local physicalModel = TankModelResolver.resolvePhysicalModel(root, descendant)

					if physicalModel ~= nil then
						return physicalModel
					end
				end
			end
		end
	end

	return TankModelResolver.findTankByTankId(root, "DummyTank", true)
end

return TankModelResolver
