local Workspace = game:GetService("Workspace")

local TankMovementService = {}

-- Constants
local TANK_MOVEMENT_CAST_PADDING = 0.35
local TANK_MOVEMENT_CAST_HEIGHT = 3.8
local TANK_MOVEMENT_CAST_Y_OFFSET = 1.9
local TANK_MOVEMENT_EPSILON = 0.03
local TANK_UNSTICK_DISTANCE_EPSILON = 0.02
local OBSTACLE_CACHE_SECONDS = 1

local boundaryWallNames = {
	Wall_North = true,
	Wall_South = true,
	Wall_East = true,
	Wall_West = true,
}

local movementObstacleFolderNames = {
	ArenaBoundary = true,
	Boundaries = true,
	Boundary = true,
	BoundaryWalls = true,
	Cover = true,
	MovementObstacles = true,
	Obstacles = true,
	Railings = true,
	RicochetWalls = true,
}

local movementObstacleAttributeNames = {
	IsMovementObstacle = true,
	MovementObstacle = true,
	WOBMovementObstacle = true,
}

-- State variables (initialized via init)
local root = nil
local map = nil
local body = nil
local tankModels = {} -- table of models to ignore (playerTank, player2Tank, dummyTank)
local runtime = nil
local tankMovementRaycastParams = nil
local tankMovementOverlapParams = nil
local collisionBoxSize = nil
local collisionBoxYOffset = TANK_MOVEMENT_CAST_Y_OFFSET
local collisionSkinWidth = TANK_MOVEMENT_CAST_PADDING
local worldBoundsMinX = -240
local worldBoundsMaxX = 240
local worldBoundsMinZ = -240
local worldBoundsMaxZ = 240
local debugMovementCollisions = false

local obstaclePartsCache = nil
local obstaclePartsCacheTime = 0
local warnedKeys = {}
local lastDebugBlockLogTime = 0

function TankMovementService.init(params)
	root = params.root or (params.map ~= nil and params.map.Parent or nil)
	map = params.map
	body = params.body
	tankModels = params.tankModels or {}
	runtime = params.runtime
	tankMovementRaycastParams = params.tankMovementRaycastParams
	tankMovementOverlapParams = params.tankMovementOverlapParams
	collisionBoxSize = typeof(params.collisionBoxSize) == "Vector3" and params.collisionBoxSize or nil
	collisionBoxYOffset = tonumber(params.collisionBoxYOffset) or TANK_MOVEMENT_CAST_Y_OFFSET
	collisionSkinWidth = tonumber(params.collisionSkinWidth) or TANK_MOVEMENT_CAST_PADDING
	worldBoundsMinX = tonumber(params.worldBoundsMinX) or -240
	worldBoundsMaxX = tonumber(params.worldBoundsMaxX) or 240
	worldBoundsMinZ = tonumber(params.worldBoundsMinZ) or -240
	worldBoundsMaxZ = tonumber(params.worldBoundsMaxZ) or 240
	debugMovementCollisions = params.debugCollision == true

	obstaclePartsCache = nil
	obstaclePartsCacheTime = 0

	if root ~= nil then
		root.DescendantAdded:Connect(function()
			obstaclePartsCache = nil
		end)

		root.DescendantRemoving:Connect(function()
			obstaclePartsCache = nil
		end)
	end
end

local function isObstacleName(name)
	return boundaryWallNames[name] == true
		or string.match(name, "^RicochetWall_") ~= nil
		or string.match(name, "^Cover_Block_") ~= nil
		or string.match(name, "^LobbyRailing_") ~= nil
		or string.match(name, "^LobbyWall_") ~= nil
		or string.match(name, "^BoundaryWall_") ~= nil
		or string.match(name, "^ArenaBoundary_") ~= nil
end

local function warnOnce(key, message)
	if warnedKeys[key] == true then
		return
	end

	warnedKeys[key] = true
	warn(message)
end

local function getRoot()
	return root or (map ~= nil and map.Parent or nil)
end

local function hasMovementObstacleAttribute(instance)
	for attributeName, _ in pairs(movementObstacleAttributeNames) do
		if instance:GetAttribute(attributeName) == true then
			return true
		end
	end

	return false
end

local function isDescendantOfObstacleFolder(instance)
	local current = instance.Parent
	local generatedRoot = getRoot()
	local stopParent = generatedRoot ~= nil and generatedRoot.Parent or nil

	while current ~= nil and current ~= stopParent do
		if movementObstacleFolderNames[current.Name] == true then
			return true
		end

		current = current.Parent
	end

	return false
end

local function collectMovementObstacleRoots()
	local searchRoots = {}
	local seen = {}
	local generatedRoot = getRoot()

	local function addSearchRoot(instance)
		if instance == nil or seen[instance] == true then
			return
		end

		seen[instance] = true
		table.insert(searchRoots, instance)
	end

	if generatedRoot ~= nil then
		addSearchRoot(generatedRoot)

		local lobby = generatedRoot:FindFirstChild("Lobby")

		if lobby == nil then
			warnOnce("missingLobby", "[MOVEMENT] Workspace/WOB_Generated/Lobby not found; lobby railings cannot block tanks.")
		elseif lobby:FindFirstChild("Railings") == nil then
			warnOnce("missingLobbyRailings", "[MOVEMENT] Workspace/WOB_Generated/Lobby/Railings not found; lobby containment may be incomplete.")
		end
	end

	if map ~= nil then
		addSearchRoot(map)

		if map:FindFirstChild("RicochetWalls") == nil then
			warnOnce("missingRicochetWalls", "[MOVEMENT] Map/RicochetWalls not found; relying on named wall parts only.")
		end

		if map:FindFirstChild("Cover") == nil then
			warnOnce("missingCover", "[MOVEMENT] Map/Cover not found; cover blocks may be missing from movement collision.")
		end
	end

	return searchRoots
end

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "nil"
	end

	return ("(%.1f, %.1f, %.1f)"):format(vector.X, vector.Y, vector.Z)
end

local function debugMovementBlocked(obstaclePart, reason, debugContext)
	if not debugMovementCollisions or obstaclePart == nil then
		return
	end

	local now = os.clock()

	if now - lastDebugBlockLogTime < 0.75 then
		return
	end

	lastDebugBlockLogTime = now
	local tankId = "unknown"

	if typeof(debugContext) == "table" and debugContext.TankId ~= nil then
		tankId = tostring(debugContext.TankId)
	end

	print(
		("[MOVE BLOCKED] tank=%s obstacle=%s reason=%s obstaclePos=%s obstacleSize=%s WOBMovementObstacle=%s CanCollide=%s CanQuery=%s Transparency=%.2f"):format(
			tankId,
			obstaclePart:GetFullName(),
			tostring(reason or "unknown"),
			formatVector3(obstaclePart.Position),
			formatVector3(obstaclePart.Size),
			tostring(obstaclePart:GetAttribute("WOBMovementObstacle") == true),
			tostring(obstaclePart.CanCollide),
			tostring(obstaclePart.CanQuery),
			obstaclePart.Transparency
		)
	)
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

	if hasMovementObstacleAttribute(instance) then
		return true
	end

	if isDescendantOfObstacleFolder(instance) then
		return true
	end

	return isObstacleName(instance.Name)
end

function TankMovementService.getTankMovementObstacleParts()
	local now = os.clock()

	if obstaclePartsCache ~= nil and now - obstaclePartsCacheTime < OBSTACLE_CACHE_SECONDS then
		return obstaclePartsCache
	end

	local obstacleParts = {}
	local seen = {}
	local searchRoots = collectMovementObstacleRoots()

	for _, searchRoot in ipairs(searchRoots) do
		if searchRoot:IsA("BasePart") and TankMovementService.isTankMovementObstacle(searchRoot) and seen[searchRoot] ~= true then
			seen[searchRoot] = true
			table.insert(obstacleParts, searchRoot)
		end

		for _, descendant in ipairs(searchRoot:GetDescendants()) do
			if seen[descendant] ~= true and TankMovementService.isTankMovementObstacle(descendant) then
				seen[descendant] = true
				table.insert(obstacleParts, descendant)
			end
		end
	end

	if #obstacleParts == 0 then
		warnOnce("noMovementObstacles", "[MOVEMENT] No movement obstacle parts found. Check CanQuery on arena walls, cover, boundaries, and lobby railings.")
	end

	obstaclePartsCache = obstacleParts
	obstaclePartsCacheTime = now

	return obstacleParts
end

function TankMovementService.collectMovementObstacleRoots()
	return collectMovementObstacleRoots()
end

local function getBodySize()
	if body ~= nil and body:IsA("BasePart") then
		return body.Size
	end

	return Vector3.new(8, 3, 11)
end

local function configureRaycastParamsForObstacles(obstacleParts)
	if tankMovementRaycastParams == nil then
		return
	end

	tankMovementRaycastParams.FilterType = Enum.RaycastFilterType.Include
	tankMovementRaycastParams.FilterDescendantsInstances = obstacleParts
	tankMovementRaycastParams.IgnoreWater = true
end

local function configureOverlapParamsForObstacles(obstacleParts)
	if tankMovementOverlapParams == nil then
		return
	end

	tankMovementOverlapParams.FilterType = Enum.RaycastFilterType.Include
	tankMovementOverlapParams.FilterDescendantsInstances = obstacleParts
end

function TankMovementService.getTankMovementCastSize()
	local bodySize = getBodySize()
	local baseSize = collisionBoxSize or Vector3.new(
		bodySize.X,
		math.max(TANK_MOVEMENT_CAST_HEIGHT, bodySize.Y + 0.8),
		bodySize.Z
	)
	local flatSkin = math.max(0, collisionSkinWidth)

	return Vector3.new(
		math.max(1, baseSize.X + flatSkin * 2),
		math.max(TANK_MOVEMENT_CAST_HEIGHT, baseSize.Y),
		math.max(1, baseSize.Z + flatSkin * 2)
	)
end

function TankMovementService.getTankMovementCastCFrame(position, bodyYaw)
	return CFrame.new(position + Vector3.new(0, collisionBoxYOffset, 0)) * CFrame.Angles(0, bodyYaw, 0)
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
	local obstacleParts = TankMovementService.getTankMovementObstacleParts()

	if #obstacleParts == 0 then
		return nil
	end

	configureRaycastParamsForObstacles(obstacleParts)

	local castCFrame = TankMovementService.getTankMovementCastCFrame(fromPosition, bodyYaw)
	local success, result = pcall(function()
		return Workspace:Blockcast(
			castCFrame,
			TankMovementService.getTankMovementCastSize(),
			movement,
			tankMovementRaycastParams
		)
	end)

	if not success then
		warnOnce("blockcastFailed", "[MOVEMENT] Workspace:Blockcast failed for tank movement.")
		return nil
	end

	if result == nil then
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

	configureOverlapParamsForObstacles(obstacleParts)

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

function TankMovementService.isTankPoseValid(position, bodyYaw)
	return TankMovementService.findTankOverlapObstacle(position, bodyYaw) == nil
end

function TankMovementService.isTankMovementBlocked(fromPosition, bodyYaw, movement, debugContext)
	if movement.Magnitude <= TANK_MOVEMENT_EPSILON then
		return false, nil
	end

	local blockcastObstacle = TankMovementService.findTankBlockcastObstacle(fromPosition, bodyYaw, movement)

	if blockcastObstacle ~= nil then
		if isMovementAwayFromObstacle(fromPosition, movement, blockcastObstacle) then
			return false, nil
		end

		debugMovementBlocked(blockcastObstacle, "blockcast", debugContext)
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

		debugMovementBlocked(overlapObstacle, "overlap", debugContext)
		return true, overlapObstacle
	end

	return false, nil
end

function TankMovementService.clampTankPosition(position)
	return Vector3.new(
		math.clamp(position.X, worldBoundsMinX, worldBoundsMaxX),
		position.Y,
		math.clamp(position.Z, worldBoundsMinZ, worldBoundsMaxZ)
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

local function tryPose(fromPosition, bodyYaw, movement, debugContext)
	if movement.Magnitude > TANK_MOVEMENT_EPSILON then
		local blocked, blockingPart = TankMovementService.isTankMovementBlocked(fromPosition, bodyYaw, movement, debugContext)

		if blocked then
			return nil, blockingPart
		end
	end

	local candidatePosition = fromPosition + movement
	local overlapObstacle = TankMovementService.findTankOverlapObstacle(candidatePosition, bodyYaw)

	if overlapObstacle ~= nil then
		debugMovementBlocked(overlapObstacle, "poseOverlap", debugContext)
		return nil, overlapObstacle
	end

	return candidatePosition, nil
end

function TankMovementService.resolveTankPose(fromPosition, currentBodyYaw, desiredMove, desiredBodyYaw, debugContext)
	local fullMove = TankMovementService.clampTankPosition(fromPosition + desiredMove) - fromPosition
	local targetBodyYaw = desiredBodyYaw or currentBodyYaw
	local blockingPart = nil

	-- 1. fullMove + new bodyYaw
	local fullPosition, fullBlockingPart = tryPose(fromPosition, targetBodyYaw, fullMove, debugContext)

	if fullPosition ~= nil then
		return fullPosition, targetBodyYaw, nil
	end

	blockingPart = fullBlockingPart

	-- 2. fullMove + current bodyYaw
	local movementOnlyPosition, movementOnlyBlockingPart = tryPose(fromPosition, currentBodyYaw, fullMove, debugContext)

	if movementOnlyPosition ~= nil then
		return movementOnlyPosition, currentBodyYaw, nil
	end

	blockingPart = blockingPart or movementOnlyBlockingPart

	-- 3. Only rotation, no movement
	local rotationOnlyPosition, rotationOnlyBlockingPart = tryPose(fromPosition, targetBodyYaw, Vector3.zero, debugContext)

	if rotationOnlyPosition ~= nil then
		return rotationOnlyPosition, targetBodyYaw, nil
	end

	blockingPart = blockingPart or rotationOnlyBlockingPart

	-- 4. Wall sliding: project fullMove onto the wall plane
	-- Normal is computed as the XZ direction from the blocking part centre to the tank.
	local wallBlockingPart = blockingPart
	if wallBlockingPart ~= nil and fullMove.Magnitude > TANK_MOVEMENT_EPSILON then
		local toTank = fromPosition - wallBlockingPart.Position
		local toTankFlat = Vector3.new(toTank.X, 0, toTank.Z)

		if toTankFlat.Magnitude > TANK_MOVEMENT_EPSILON then
			local wallNormal = toTankFlat.Unit
			local dot = fullMove:Dot(wallNormal)
			local slideMove = Vector3.new(
				fullMove.X - wallNormal.X * dot,
				0,
				fullMove.Z - wallNormal.Z * dot
			)

			if slideMove.Magnitude > TANK_MOVEMENT_EPSILON then
				local slidePosition, slideBlockPart = tryPose(fromPosition, currentBodyYaw, slideMove, debugContext)

				if slidePosition ~= nil then
					return slidePosition, currentBodyYaw, nil
				end

				blockingPart = blockingPart or slideBlockPart
			end
		end
	end

	-- 5. Fallback: separate X / Z movement
	local xMove = Vector3.new(fullMove.X, 0, 0)
	local zMove = Vector3.new(0, 0, fullMove.Z)

	for _, yaw in ipairs({ targetBodyYaw, currentBodyYaw }) do
		if xMove.Magnitude > TANK_MOVEMENT_EPSILON then
			local xPosition, xBlockingPart = tryPose(fromPosition, yaw, xMove, debugContext)

			if xPosition ~= nil then
				return xPosition, yaw, nil
			end

			blockingPart = blockingPart or xBlockingPart
		end

		if zMove.Magnitude > TANK_MOVEMENT_EPSILON then
			local zPosition, zBlockingPart = tryPose(fromPosition, yaw, zMove, debugContext)

			if zPosition ~= nil then
				return zPosition, yaw, nil
			end

			blockingPart = blockingPart or zBlockingPart
		end
	end

	-- 6. Wall nudge: tiny push away from the wall to free a corner-stuck tank
	if wallBlockingPart ~= nil then
		local toTank = fromPosition - wallBlockingPart.Position
		local toTankFlat = Vector3.new(toTank.X, 0, toTank.Z)

		if toTankFlat.Magnitude > TANK_MOVEMENT_EPSILON then
			local nudgeMove = toTankFlat.Unit * 0.05
			local nudgePosition, _ = tryPose(fromPosition, currentBodyYaw, nudgeMove, debugContext)

			if nudgePosition ~= nil then
				return nudgePosition, currentBodyYaw, blockingPart
			end
		end
	end

	return fromPosition, currentBodyYaw, blockingPart
end

return TankMovementService
