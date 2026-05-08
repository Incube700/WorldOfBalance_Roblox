local PlayerTankSpawner = {}

local REQUIRED_CHILDREN = {
	"Body",
	"Turret",
	"Barrel",
	"ShootPoint",
	"Hitboxes",
}

local function waitForTankParts(model)
	local parts = {
		Model = model,
	}

	for _, childName in ipairs(REQUIRED_CHILDREN) do
		parts[childName] = model:WaitForChild(childName)
	end

	return parts
end

function PlayerTankSpawner.getOrCreateRuntimePlayerTank(sourceModel, parent, tankName)
	local existing = parent:FindFirstChild(tankName)

	if existing ~= nil and existing:IsA("Model") then
		return waitForTankParts(existing), false
	end

	local clone = sourceModel:Clone()
	clone.Name = tankName
	clone.Parent = parent

	return waitForTankParts(clone), true
end

return PlayerTankSpawner
