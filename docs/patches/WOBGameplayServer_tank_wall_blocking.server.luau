
local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tankInputEvent = remotes:WaitForChild("TankInputEvent")
local shootRequestEvent = remotes:WaitForChild("ShootRequestEvent")

local root = Workspace:WaitForChild("WOB_Generated")
local runtime = root:WaitForChild("Runtime")
local wobRuntime = Workspace:FindFirstChild("WOB_Runtime") or Instance.new("Folder")
wobRuntime.Name = "WOB_Runtime"
wobRuntime.Parent = Workspace
local map = root:WaitForChild("Map")
local testObjects = root:WaitForChild("TestObjects")
local ricochetWalls = map:FindFirstChild("RicochetWalls")
local cover = map:FindFirstChild("Cover")

local projectileFolder = runtime:FindFirstChild("Projectiles") or Instance.new("Folder")
projectileFolder.Name = "Projectiles"
projectileFolder.Parent = runtime

local vfxFolder = wobRuntime:FindFirstChild("VFX") or Instance.new("Folder")
vfxFolder.Name = "VFX"
vfxFolder.Parent = wobRuntime

local playerTank = testObjects:WaitForChild("PlayerTankPrototype")
local dummyTank = testObjects:WaitForChild("DummyTank")

local body = playerTank:WaitForChild("Body")
local turret = playerTank:WaitForChild("Turret")
local barrel = playerTank:WaitForChild("Barrel")
local shootPoint = playerTank:WaitForChild("ShootPoint")
local hitboxes = playerTank:WaitForChild("Hitboxes")

local dummyBody = dummyTank:WaitForChild("Body")
local dummyHitboxes = dummyTank:WaitForChild("Hitboxes")

local MOVE_SPEED = 34
local TURN_SPEED = math.rad(115)
local SHOOT_COOLDOWN = 0.45

local PROJECTILE_SPEED = 160
local PROJECTILE_DAMAGE = 35
local PROJECTILE_MAX_BOUNCES = 3
local PROJECTILE_DAMAGE_MULTIPLIER = 0.75
local PROJECTILE_LIFETIME = 4

local TANK_MOVEMENT_CAST_PADDING = -0.25
local TANK_MOVEMENT_CAST_HEIGHT = 1.4
local TANK_MOVEMENT_CAST_Y_OFFSET = 2
local TANK_MOVEMENT_EPSILON = 0.03
local TANK_UNSTICK_DISTANCE_EPSILON = 0.02
local WALL_BLOCK_PRINT_INTERVAL = 0.5

local controllingPlayer = nil
local lastShotTimeByPlayer = {}
local inputByPlayer = {}
local projectiles = {}
local lastWallBlockPrintTime = 0

local tankState = {
	Position = Vector3.new(-42, 0, -42),
	BodyYaw = math.rad(0),
	TurretYaw = math.rad(0),
}

local function setPartPhysics(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanQuery = true
			descendant.CastShadow = false
		end
	end
end

setPartPhysics(playerTank)
setPartPhysics(dummyTank)

local function setCharacterHidden(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
end

local function assignPlayer(player)
	if controllingPlayer ~= nil then
		return
	end

	controllingPlayer = player
	inputByPlayer[player] = {
		Throttle = 0,
		Steer = 0,
		AimPosition = tankState.Position + Vector3.new(0, 0, -20),
	}

	player.CharacterAdded:Connect(setCharacterHidden)

	if player.Character ~= nil then
		setCharacterHidden(player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	assignPlayer(player)
end

Players.PlayerAdded:Connect(assignPlayer)

Players.PlayerRemoving:Connect(function(player)
	inputByPlayer[player] = nil
	lastShotTimeByPlayer[player] = nil

	if controllingPlayer == player then
		controllingPlayer = nil
	end
end)

local function getYawFromDirection(direction)
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.001 then
		return tankState.TurretYaw
	end

	local unit = flat.Unit

	return math.atan2(-unit.X, -unit.Z)
end

local tankMovementRaycastParams = RaycastParams.new()
tankMovementRaycastParams.FilterDescendantsInstances = {
	playerTank,
	dummyTank,
	runtime,
	projectileFolder,
	vfxFolder,
}
tankMovementRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
tankMovementRaycastParams.IgnoreWater = true

local tankMovementOverlapParams = OverlapParams.new()
tankMovementOverlapParams.FilterType = Enum.RaycastFilterType.Include
tankMovementOverlapParams.MaxParts = 20

local boundaryWallNames = {
	Wall_North = true,
	Wall_South = true,
	Wall_East = true,
	Wall_West = true,
}

local function isObstacleName(name)
	return boundaryWallNames[name] == true
		or string.match(name, "^RicochetWall_") ~= nil
		or string.match(name, "^Cover_Block_") ~= nil
end

local function isTankMovementObstacle(instance)
	if instance == nil then
		return false
	end

	if not instance:IsA("BasePart") then
		return false
	end

	if not instance.CanQuery then
		return false
	end

	if instance:IsDescendantOf(playerTank)
		or instance:IsDescendantOf(dummyTank)
		or instance:IsDescendantOf(runtime)
	then
		return false
	end

	if ricochetWalls == nil then
		ricochetWalls = map:FindFirstChild("RicochetWalls")
	end

	if cover == nil then
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

local function getTankMovementObstacleParts()
	local obstacleParts = {}

	for _, descendant in ipairs(map:GetDescendants()) do
		if isTankMovementObstacle(descendant) then
			table.insert(obstacleParts, descendant)
		end
	end

	return obstacleParts
end

local function getTankMovementCastSize()
	return Vector3.new(
		math.max(1, body.Size.X + TANK_MOVEMENT_CAST_PADDING),
		TANK_MOVEMENT_CAST_HEIGHT,
		math.max(1, body.Size.Z + TANK_MOVEMENT_CAST_PADDING)
	)
end

local function getTankMovementCastCFrame(position, bodyYaw)
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

local function findTankBlockcastObstacle(fromPosition, bodyYaw, movement)
	local castCFrame = getTankMovementCastCFrame(fromPosition, bodyYaw)
	local success, result = pcall(function()
		return Workspace:Blockcast(
			castCFrame,
			getTankMovementCastSize(),
			movement,
			tankMovementRaycastParams
		)
	end)

	if not success or result == nil then
		return nil
	end

	if isTankMovementObstacle(result.Instance) then
		return result.Instance
	end

	return nil
end

local function findTankOverlapObstacle(position, bodyYaw)
	local obstacleParts = getTankMovementObstacleParts()

	if #obstacleParts == 0 then
		return nil
	end

	tankMovementOverlapParams.FilterDescendantsInstances = obstacleParts

	local overlappingParts = Workspace:GetPartBoundsInBox(
		getTankMovementCastCFrame(position, bodyYaw),
		getTankMovementCastSize(),
		tankMovementOverlapParams
	)

	for _, overlappingPart in ipairs(overlappingParts) do
		if isTankMovementObstacle(overlappingPart) then
			return overlappingPart
		end
	end

	return nil
end

local function printTankMovementBlocked(blockingPart)
	local currentTime = os.clock()

	if currentTime - lastWallBlockPrintTime < WALL_BLOCK_PRINT_INTERVAL then
		return
	end

	lastWallBlockPrintTime = currentTime

	local blockingName = "unknown"

	if blockingPart ~= nil then
		blockingName = blockingPart.Name
	end

	print("[WALL] blocked by " .. blockingName)
end

local function isTankMovementBlocked(fromPosition, bodyYaw, movement)
	if movement.Magnitude <= TANK_MOVEMENT_EPSILON then
		return false, nil
	end

	local blockcastObstacle = findTankBlockcastObstacle(fromPosition, bodyYaw, movement)

	if blockcastObstacle ~= nil then
		if isMovementAwayFromObstacle(fromPosition, movement, blockcastObstacle) then
			return false, nil
		end

		return true, blockcastObstacle
	end

	local overlapObstacle = findTankOverlapObstacle(fromPosition + movement, bodyYaw)

	if overlapObstacle ~= nil then
		local currentOverlapObstacle = findTankOverlapObstacle(fromPosition, bodyYaw)

		if currentOverlapObstacle == overlapObstacle
			and isMovementAwayFromObstacle(fromPosition, movement, overlapObstacle)
		then
			return false, nil
		end

		return true, overlapObstacle
	end

	return false, nil
end

local function clampTankPosition(position)
	return Vector3.new(
		math.clamp(position.X, -58, 58),
		0,
		math.clamp(position.Z, -58, 58)
	)
end

local function resolveTankMovement(fromPosition, bodyYaw, desiredMove)
	local fullMove = clampTankPosition(fromPosition + desiredMove) - fromPosition
	local fullBlocked, fullBlockingPart = isTankMovementBlocked(fromPosition, bodyYaw, fullMove)

	if not fullBlocked then
		return fromPosition + fullMove, nil
	end

	local xMove = Vector3.new(fullMove.X, 0, 0)
	local xBlockingPart = nil

	if xMove.Magnitude > TANK_MOVEMENT_EPSILON then
		local xBlocked
		xBlocked, xBlockingPart = isTankMovementBlocked(fromPosition, bodyYaw, xMove)

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
	zBlocked, zBlockingPart = isTankMovementBlocked(fromPosition, bodyYaw, zMove)

	if not zBlocked then
		return fromPosition + zMove, nil
	end

	return fromPosition, zBlockingPart or xBlockingPart or fullBlockingPart
end

local function layoutTank(tank, position, bodyYaw, turretYaw)
	local tankBody = tank:FindFirstChild("Body")
	local tankTurret = tank:FindFirstChild("Turret")
	local tankBarrel = tank:FindFirstChild("Barrel")
	local tankShootPoint = tank:FindFirstChild("ShootPoint")
	local tankHitboxes = tank:FindFirstChild("Hitboxes")

	if tankBody == nil or tankTurret == nil or tankBarrel == nil or tankShootPoint == nil then
		return
	end

	local bodyCFrame = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, bodyYaw, 0)
	local turretCFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, turretYaw, 0)

	tankBody.CFrame = bodyCFrame
	tankTurret.CFrame = turretCFrame
	tankBarrel.CFrame = turretCFrame * CFrame.new(0, 0, -5.8)
	tankShootPoint.CFrame = turretCFrame * CFrame.new(0, 0, -10)

	if tankHitboxes ~= nil then
		local frontArmor = tankHitboxes:FindFirstChild("FrontArmor")
		local rearArmor = tankHitboxes:FindFirstChild("RearArmor")
		local leftArmor = tankHitboxes:FindFirstChild("LeftArmor")
		local rightArmor = tankHitboxes:FindFirstChild("RightArmor")

		if frontArmor ~= nil then
			frontArmor.CFrame = bodyCFrame * CFrame.new(0, 0, -5.7)
		end

		if rearArmor ~= nil then
			rearArmor.CFrame = bodyCFrame * CFrame.new(0, 0, 5.7)
		end

		if leftArmor ~= nil then
			leftArmor.CFrame = bodyCFrame * CFrame.new(-4.2, 0, 0)
		end

		if rightArmor ~= nil then
			rightArmor.CFrame = bodyCFrame * CFrame.new(4.2, 0, 0)
		end
	end
end

layoutTank(playerTank, tankState.Position, tankState.BodyYaw, tankState.TurretYaw)
layoutTank(dummyTank, Vector3.new(42, 0, 42), math.rad(180), math.rad(180))

local function createFlash(position, color, size, lifetime)
	local flash = Instance.new("Part")
	flash.Name = "VFX_Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(size, size, size)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Parent = vfxFolder

	Debris:AddItem(flash, lifetime)

	return flash
end

local function createMuzzleFlash(position)
	createFlash(position, Color3.fromRGB(255, 220, 80), 3.2, 0.08)
end

local function createImpactFlash(position)
	createFlash(position, Color3.fromRGB(255, 130, 40), 2.5, 0.12)

	for i = 1, 3 do
		local spark = Instance.new("Part")
		spark.Name = "VFX_Spark"
		spark.Size = Vector3.new(0.25, 0.25, 1.2)
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 200, 90)
		spark.CFrame = CFrame.new(position) * CFrame.Angles(
			math.random() * math.pi,
			math.random() * math.pi,
			math.random() * math.pi
		)
		spark.Parent = vfxFolder

		Debris:AddItem(spark, 0.12)
	end
end

local function createProjectilePart(position)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 230, 120)
	part.Parent = projectileFolder

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 6
	light.Parent = part

	return part
end

local function reflect(direction, normal)
	return (direction - 2 * direction:Dot(normal) * normal).Unit
end

local function destroyProjectile(projectile)
	if projectile.Part ~= nil then
		projectile.Part:Destroy()
	end

	projectile.Destroyed = true
end

local function damageDummy(amount)
	local currentHealth = dummyTank:GetAttribute("Health") or 100
	local newHealth = math.max(0, currentHealth - amount)

	dummyTank:SetAttribute("Health", newHealth)

	print("[DAMAGE] DummyTank -" .. math.floor(amount) .. " HP: " .. math.floor(currentHealth) .. " -> " .. math.floor(newHealth))

	createImpactFlash(dummyBody.Position + Vector3.new(0, 3, 0))

	if newHealth <= 0 then
		print("[DEAD] DummyTank destroyed")

		for _, descendant in ipairs(dummyTank:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(30, 30, 30)
			end
		end
	end
end

local function createProjectile(owner, origin, direction)
	local projectilePart = createProjectilePart(origin)

	local projectile = {
		Owner = owner,
		Position = origin,
		Direction = Vector3.new(direction.X, 0, direction.Z).Unit,
		Speed = PROJECTILE_SPEED,
		Damage = PROJECTILE_DAMAGE,
		BounceCount = 0,
		MaxBounces = PROJECTILE_MAX_BOUNCES,
		DamageMultiplierPerBounce = PROJECTILE_DAMAGE_MULTIPLIER,
		LifeTime = 0,
		MaxLifeTime = PROJECTILE_LIFETIME,
		Part = projectilePart,
		Destroyed = false,
	}

	table.insert(projectiles, projectile)
	createMuzzleFlash(origin)
end

tankInputEvent.OnServerEvent:Connect(function(player, inputData)
	if player ~= controllingPlayer then
		return
	end

	if typeof(inputData) ~= "table" then
		return
	end

	local throttle = tonumber(inputData.Throttle) or 0
	local steer = tonumber(inputData.Steer) or 0
	local aimPosition = inputData.AimPosition

	if typeof(aimPosition) ~= "Vector3" then
		aimPosition = tankState.Position + Vector3.new(0, 0, -20)
	end

	inputByPlayer[player] = {
		Throttle = math.clamp(throttle, -1, 1),
		Steer = math.clamp(steer, -1, 1),
		AimPosition = aimPosition,
	}
end)

shootRequestEvent.OnServerEvent:Connect(function(player, aimPosition)
	if player ~= controllingPlayer then
		return
	end

	if typeof(aimPosition) ~= "Vector3" then
		return
	end

	local currentTime = os.clock()
	local lastShotTime = lastShotTimeByPlayer[player] or 0

	if currentTime - lastShotTime < SHOOT_COOLDOWN then
		return
	end

	lastShotTimeByPlayer[player] = currentTime

	local origin = shootPoint.Position
	local direction = Vector3.new(aimPosition.X - origin.X, 0, aimPosition.Z - origin.Z)

	if direction.Magnitude < 0.1 then
		direction = (CFrame.Angles(0, tankState.TurretYaw, 0)).LookVector
	end

	createProjectile(player, origin, direction.Unit)
end)

local function updateTank(deltaTime)
	if controllingPlayer == nil then
		return
	end

	local input = inputByPlayer[controllingPlayer]

	if input == nil then
		return
	end

	tankState.BodyYaw -= input.Steer * TURN_SPEED * deltaTime

	local bodyCFrame = CFrame.new(tankState.Position) * CFrame.Angles(0, tankState.BodyYaw, 0)
	local forward = bodyCFrame.LookVector

	local desiredMove = forward * input.Throttle * MOVE_SPEED * deltaTime
	local resolvedPosition, blockingPart = resolveTankMovement(tankState.Position, tankState.BodyYaw, desiredMove)

	if blockingPart ~= nil then
		printTankMovementBlocked(blockingPart)
	else
		tankState.Position = resolvedPosition
	end

	local aimDirection = input.AimPosition - tankState.Position
	tankState.TurretYaw = getYawFromDirection(aimDirection)

	layoutTank(playerTank, tankState.Position, tankState.BodyYaw, tankState.TurretYaw)
end

local function updateProjectiles(deltaTime)
	for i = #projectiles, 1, -1 do
		local projectile = projectiles[i]

		if projectile.Destroyed then
			table.remove(projectiles, i)
			continue
		end

		projectile.LifeTime += deltaTime

		if projectile.LifeTime >= projectile.MaxLifeTime then
			destroyProjectile(projectile)
			table.remove(projectiles, i)
			continue
		end

		local distance = projectile.Speed * deltaTime
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {
			projectileFolder,
			vfxFolder,
			playerTank,
		}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.IgnoreWater = true

		local result = Workspace:Raycast(
			projectile.Position,
			projectile.Direction * distance,
			raycastParams
		)

		if result ~= nil then
			local hitInstance = result.Instance
			local hitPosition = result.Position
			local hitNormal = result.Normal

			if hitInstance:IsDescendantOf(dummyTank) then
				damageDummy(projectile.Damage)
				destroyProjectile(projectile)
				table.remove(projectiles, i)
			else
				createImpactFlash(hitPosition)

				if projectile.BounceCount >= projectile.MaxBounces then
					destroyProjectile(projectile)
					table.remove(projectiles, i)
				else
					projectile.Direction = reflect(projectile.Direction, hitNormal)
					projectile.Position = hitPosition + projectile.Direction * 0.35
					projectile.BounceCount += 1
					projectile.Damage *= projectile.DamageMultiplierPerBounce

					print("[BOUNCE] count=" .. projectile.BounceCount .. " damage=" .. math.floor(projectile.Damage))
				end
			end
		else
			projectile.Position += projectile.Direction * distance
		end

		if projectile.Part ~= nil then
			projectile.Part.Position = projectile.Position
		end
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	updateTank(deltaTime)
	updateProjectiles(deltaTime)
end)

print("[WOB] Gameplay server started")
