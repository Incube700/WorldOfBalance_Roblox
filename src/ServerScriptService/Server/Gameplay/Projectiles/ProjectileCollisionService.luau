local ProjectileCollisionService = {}

local ARMOR_HITBOX_NAMES = {
	FrontArmor = true,
	RearArmor = true,
	LeftArmor = true,
	RightArmor = true,
}

local function cloneTargets(targets)
	local cloned = {}

	for _, target in ipairs(targets or {}) do
		if target ~= nil and target.Parent ~= nil then
			table.insert(cloned, target)
		end
	end

	return cloned
end

local function ensureArmorHitboxesQueryable(hitboxes)
	if hitboxes == nil then
		return
	end

	for _, descendant in ipairs(hitboxes:GetDescendants()) do
		if descendant:IsA("BasePart") and ARMOR_HITBOX_NAMES[descendant.Name] == true then
			descendant.CanQuery = true
		end
	end
end

function ProjectileCollisionService.GetProjectileRaycastTargets(projectile, mapRaycastTargets, tankParticipantRegistry)
	local targets = cloneTargets(mapRaycastTargets)

	for _, participant in ipairs(tankParticipantRegistry.getParticipants()) do
		local physicalModel = tankParticipantRegistry.getParticipantPhysicalModel(participant)
		local hitboxes = participant.Hitboxes

		if (hitboxes == nil or hitboxes.Parent == nil) and physicalModel ~= nil then
			hitboxes = physicalModel:FindFirstChild("Hitboxes", true)
			participant.Hitboxes = hitboxes
		end

		local canHitParticipant = participant.IsActive ~= false
			and hitboxes ~= nil
			and (participant ~= projectile.OwnerParticipant or projectile.CanHitOwner)

		if canHitParticipant then
			ensureArmorHitboxesQueryable(hitboxes)
			table.insert(targets, hitboxes)
		end
	end

	return targets
end

function ProjectileCollisionService.CastSweptRay(workspace, projectile, deltaTime, raycastParams, raycastTargets)
	local distance = projectile.Speed * deltaTime
	local previousPosition = projectile.Position
	local displacement = projectile.Direction * distance
	local nextPosition = previousPosition + displacement

	projectile.PreviousPosition = previousPosition
	projectile.NextPosition = nextPosition

	raycastParams.FilterDescendantsInstances = raycastTargets

	return workspace:Raycast(previousPosition, displacement, raycastParams), nextPosition, distance
end

return ProjectileCollisionService
