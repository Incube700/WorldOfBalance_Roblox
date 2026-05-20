local TankModelScanner = {}

local function getNumberAttribute(instance, names)
	for _, name in ipairs(names) do
		local value = instance:GetAttribute(name)

		if typeof(value) == "number" then
			return value
		end
	end

	return nil
end

local function findBasePart(model, name)
	local child = model:FindFirstChild(name)

	if child ~= nil and child:IsA("BasePart") then
		return child
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == name and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

function TankModelScanner.GetBodyPart(model)
	local body = findBasePart(model, "Body")

	if body ~= nil then
		return body
	end

	if model.PrimaryPart ~= nil and model.PrimaryPart:IsDescendantOf(model) then
		return model.PrimaryPart
	end

	return findBasePart(model, "Hull")
end

function TankModelScanner.IsTankModel(model, config)
	if not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("IsActive") == false then
		return false
	end

	local hasHealth = getNumberAttribute(model, config.HEALTH_ATTRIBUTES) ~= nil
	local hasMaxHealth = getNumberAttribute(model, { "MaxHealth" }) ~= nil
	local hasParticipant = model:GetAttribute("TankParticipantId") ~= nil
	local hasBody = TankModelScanner.GetBodyPart(model) ~= nil

	return hasBody and (hasHealth or hasMaxHealth or hasParticipant)
end

local function scanRoot(scanRoot, config, models)
	if scanRoot == nil then
		return
	end

	for _, descendant in ipairs(scanRoot:GetDescendants()) do
		if descendant:IsA("Model") and TankModelScanner.IsTankModel(descendant, config) then
			table.insert(models, descendant)
		end
	end
end

function TankModelScanner.ScanGenerated(generated, config)
	local models = {}

	if generated == nil then
		return models
	end

	scanRoot(generated:FindFirstChild("TestObjects"), config, models)
	scanRoot(generated:FindFirstChild("BattleArena"), config, models)

	return models
end

return table.freeze(TankModelScanner)
