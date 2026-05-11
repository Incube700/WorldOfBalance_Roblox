local Workspace = game:GetService("Workspace")

local TankMovementService = {}

-- Constants
local TANK_MOVEMENT_CAST_PADDING = -0.25
local TANK_MOVEMENT_CAST_HEIGHT = 1.4
local TANK_MOVEMENT_CAST_Y_OFFSET = 2
local TANK_MOVEMENT_EPSILON = 0.03
local TANK_UNSTICK_DISTANCE_EPSILON = 0.02

local boundaryWallNames = {
	Wall_North = true,
	Wall_South = true,
	Wall_East = true,
	Wall_West = true,
}

-- State variables (initialized via init)
local map = nil
local body = nil
local tankModels = {} -- table of models to ignore (playerTank, player2Tank, dummyTank)
local runtime = nil
local tankMovementRaycastParams = nil
local tankMovementOverlapParams = nil

-- Cache for isTankMovementObstacle
local ricochetWalls = nil
local cover = nil

function TankMovementService.init(params)
	map = params.map
	body = params.body
	tankModels = params.tankModels or {}
	runtime = params.runtime
	tankMovementRaycastParams = params.tankMovementRaycastParams
	tankMovementOverlapParams = params.tankMovementOverlapParams
end

local function isObstacleName(name)
	return boundaryWallNames[name] == true
		or string.match(name, "^RicochetWall_") ~= nil
		or string.match(name, "^Cover_Block_") ~= nil
end

function TankMovementService.isTankMovementObstacle(instance)
	if instance == nil then
		return false
	end

	if not instance:IsA("BasePart") then
		return false
	end

	if not instance.CanQuery then
		return false
	end

	for _, tankModel in ipairs(tankModels) do
		if instance:IsDescendantOf(tankModel) then
			return false
		end
	end

	if runtime ~= nil and instance:IsDescendantOf(runtime) then
		return false
	end

	if ricochetWalls == nil and map ~= nil then
		ricochetWalls = map:FindFirstChild("RicochetWalls")
	end

	if cover == nil and map ~= nil then
		cover = map:FindFirstChild("Cover")
	end

	if ricochetWalls ~= nil and instance:IsDescendantOf(ricochetWalls) then
		return true
	end

	if cover ~= nil and instance:IsDescendantOf(cover) then
		return true
	end

	return isObstacleName(instance.Name)
end

function TankMovementService.getTankMovementObstacleParts()
	local obstacleParts = {}

	if map == nil then return obstacleParts end

	for _, descendant in ipairs(map:GetDescendants()) do
		if TankMovementService.isTankMovementObstacle(descendant) then
			table.insert(obstacleParts, descendant)
		end
	end

	return obstacleParts
end

function TankMovementService.getTankMovementCastSize()
	return Vector3.new(
		math.max(1, body.Size.X + TANK_MOVEMENT_CAST_PADDING),
		TANK_MOVEMENT_CAST_HEIGHT,
		math.max(1, body.Size.Z + TANK_MOVEMENT_CAST_PADDING)
	)
end

function TankMovementService.getTankMovementCastCFrame(position, bodyYaw)
	return CFrame.new(position + Vector3.new(0, TANK_MOVEMENT_CAST_Y_OFFSET, 0)) * CFrame.Angles(0, bodyYaw, 0)
end

local function getFlatSeparationSquaredFromPart(position, obstaclePart)
	local localPoint = obstaclePart.CFrame:PointToObjectSpace(Vector3.new(position.X, obstaclePart.Position.Y, position.Z))
	local halfSize = obstaclePart.Size * 0.5
	local clampedX = math.clamp(localPoint.X, -halfSize.X, halfSize.X)
	local clampedZ = math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	local deltaX = localPoint.X - clampedX
	local deltaZ = localPoint.Z - clampedZ

	return deltaX * deltaX + deltaZ * deltaZ
end

local function isMovementAwayFromObstacle(fromPosition, movement, obstaclePart)
	if obstaclePart == nil then
		return false
	end

	local beforeDistance = getFlatSeparationSquaredFromPart(fromPosition, obstaclePart)
	local afterDistance = getFlatSeparationSquaredFromPart(fromPosition + movement, obstaclePart)

	return afterDistance >= beforeDistance - TANK_UNSTICK_DISTANCE_EPSILON
end

function TankMovementService.findTankBlockcastObstacle(fromPosition, bodyYaw, movement)
	local castCFrame = TankMovementService.getTankMovementCastCFrame(fromPosition, bodyYaw)
	local success, result = pcall(function()
		return Workspace:Blockcast(
			castCFrame,
			TankMovementService.getTankMovementCastSize(),
			movement,
			tankMovementRaycastParams
		)
	end)

	if not success or result == nil then
		return nil
	end

	if TankMovementService.isTankMovementObstacle(result.Instance) then
		return result.Instance
	end

	return nil
end

function TankMovementService.findTankOverlapObstacle(position, bodyYaw)
	local obstacleParts = TankMovementService.getTankMovementObstacleParts()

	if #obstacleParts == 0 then
		return nil
	end

	tankMovementOverlapParams.FilterDescendantsInstances = obstacleParts

	local overlappingParts = Workspace:GetPartBoundsInBox(
		TankMovementService.getTankMovementCastCFrame(position, bodyYaw),
		TankMovementService.getTankMovementCastSize(),
		tankMovementOverlapParams
	)

	for _, overlappingPart in ipairs(overlappingParts) do
		if TankMovementService.isTankMovementObstacle(overlappingPart) then
			return overlappingPart
		end
	end

	return nil
end

function TankMovementService.isTankMovementBlocked(fromPosition, bodyYaw, movement)
	if movement.Magnitude <= TANK_MOVEMENT_EPSILON then
		return false, nil
	end

	local blockcastObstacle = TankMovementService.findTankBlockcastObstacle(fromPosition, bodyYaw, movement)

	if blockcastObstacle ~= nil then
		if isMovementAwayFromObstacle(fromPosition, movement, blockcastObstacle) then
			return false, nil
		end

		return true, blockcastObstacle
	end

	local overlapObstacle = TankMovementService.findTankOverlapObstacle(fromPosition + movement, bodyYaw)

	if overlapObstacle ~= nil then
		local currentOverlapObstacle = TankMovementService.findTankOverlapObstacle(fromPosition, bodyYaw)

		if currentOverlapObstacle == overlapObstacle
			and isMovementAwayFromObstacle(fromPosition, movement, overlapObstacle)
		then
			return false, nil
		end

		return true, overlapObstacle
	end

	return false, nil
end

function TankMovementService.clampTankPosition(position)
	return Vector3.new(
		math.clamp(position.X, -240, 240),
		position.Y,
		math.clamp(position.Z, -240, 240)
	)
end

function TankMovementService.resolveTankMovement(fromPosition, bodyYaw, desiredMove)
	local fullMove = TankMovementService.clampTankPosition(fromPosition + desiredMove) - fromPosition
	local fullBlocked, fullBlockingPart = TankMovementService.isTankMovementBlocked(fromPosition, bodyYaw, fullMove)

	if not fullBlocked then
		return fromPosition + fullMove, nil
	end

	local xMove = Vector3.new(fullMove.X, 0, 0)
	local xBlockingPart = nil

	if xMove.Magnitude > TANK_MOVEMENT_EPSILON then
		local xBlocked
		xBlocked, xBlockingPart = TankMovementService.isTankMovementBlocked(fromPosition, bodyYaw, xMove)

		if not xBlocked then
			return fromPosition + xMove, nil
		end
	end

	local zMove = Vector3.new(0, 0, fullMove.Z)
	local zBlockingPart = nil

	if zMove.Magnitude <= TANK_MOVEMENT_EPSILON then
		return fromPosition, xBlockingPart or fullBlockingPart
	end

	local zBlocked
	zBlocked, zBlockingPart = TankMovementService.isTankMovementBlocked(fromPosition, bodyYaw, zMove)

	if not zBlocked then
		return fromPosition + zMove, nil
	end

	return fromPosition, zBlockingPart or xBlockingPart or fullBlockingPart
end

return TankMovementService
