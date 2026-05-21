local ProjectileCollisionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebugCombatConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("DebugCombatConfig")
)

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

-- Resolves the hitbox folder for a participant.
-- Prefers "ArmorZones" (BaseTankTemplate) over legacy "Hitboxes".
-- Falls back to deep search when participant.Hitboxes is stale/nil.
local function resolveHitboxFolder(participant, physicalModel)
	local hitboxes = participant.Hitboxes

	if hitboxes ~= nil and hitboxes.Parent ~= nil then
		return hitboxes
	end

	if physicalModel == nil then
		return nil
	end

	-- ArmorZones first (BaseTankTemplate contract), then Hitboxes (legacy).
	local armorZones = physicalModel:FindFirstChild("ArmorZones", true)
	if armorZones ~= nil and armorZones:IsA("Folder") then
		participant.Hitboxes = armorZones
		return armorZones
	end

	local legacyHitboxes = physicalModel:FindFirstChild("Hitboxes", true)
	if legacyHitboxes ~= nil and legacyHitboxes:IsA("Folder") then
		participant.Hitboxes = legacyHitboxes
		return legacyHitboxes
	end

	return nil
end

function ProjectileCollisionService.GetProjectileRaycastTargets(projectile, mapRaycastTargets, tankParticipantRegistry)
	local targets = cloneTargets(mapRaycastTargets)
	local debugEnabled = DebugCombatConfig.ProjectileDebug == true

	if debugEnabled then
		print(("[PROJECTILE COLLISION] building targets for projectile owner=%s"):format(
			tostring(projectile.OwnerParticipant ~= nil and projectile.OwnerParticipant.TankId or "none")
		))
	end

	for _, participant in ipairs(tankParticipantRegistry.getParticipants()) do
		local physicalModel = tankParticipantRegistry.getParticipantPhysicalModel(participant)
		local hitboxes = resolveHitboxFolder(participant, physicalModel)

		local canHitParticipant = participant.IsActive ~= false
			and hitboxes ~= nil
			and (participant ~= projectile.OwnerParticipant or projectile.CanHitOwner)

		if canHitParticipant then
			ensureArmorHitboxesQueryable(hitboxes)
			table.insert(targets, hitboxes)

			if debugEnabled then
				print(("[PROJECTILE COLLISION] target=%s hitboxFolder=%s active=%s"):format(
					tostring(participant.TankId),
					tostring(hitboxes.Name),
					tostring(participant.IsActive)
				))
			end
		elseif debugEnabled then
			print(("[PROJECTILE COLLISION] skip=%s active=%s hitboxes=%s isOwner=%s"):format(
				tostring(participant.TankId),
				tostring(participant.IsActive),
				tostring(hitboxes ~= nil and hitboxes.Name or "nil"),
				tostring(participant == projectile.OwnerParticipant)
			))
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
