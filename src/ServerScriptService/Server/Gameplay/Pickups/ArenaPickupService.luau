-- ArenaPickupService (Update 0.2): ground pickups that lie on the arena floor.
--
-- IMPORTANT: pickups are arena-scoped. They are spawned only when an arena session
-- begins (via ArenaSessionLifecycle) and torn down when the session ends. The floor
-- finder searches inside the CALLER-PROVIDED arena container only and never falls
-- back to the Lobby or the world Baseplate -- that was the root cause of pickups
-- appearing in the lobby in the previous pass.
--
-- Collection is SERVER-AUTHORITATIVE via a throttled proximity check (every 0.2s,
-- 7-stud radius). Tanks here are CFrame-moved, so anchored parts do not reliably
-- raise .Touched events; proximity is the correct primitive.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local WeaponCatalog = require(configs:WaitForChild("WeaponCatalog"))

local ArenaPickupService = {}

local RUNTIME_ROOT_NAME = "WOB_Runtime"
local ARENA_MODE_FOLDER = "ArenaMode" -- all runtime arena objects nest under WOB_Runtime/ArenaMode.
local PICKUPS_FOLDER_NAME = "ArenaPickups"
local ACTIVE_LAYOUT_NAME = "ActiveArenaLayout"
local PICKUP_SPAWNS_FOLDER = "PickupSpawns"

-- Maps an authored marker's WOBPickupType / name token to a WeaponCatalog.Pickups id.
-- "Repair" is the author-facing word; the catalog entry is "Health".
local PICKUP_TYPE_TO_ID = {
	Repair = "Health",
	Health = "Health",
	MachineGun = "MachineGun",
	Rocket = "Rocket",
	PhaseShot = "PhaseShot",
	RailGun = "RailGun",
	Shotgun = "Shotgun",
	Shield = "Shield",
}
local CHECK_INTERVAL_SECONDS = 0.2
local COLLECT_RADIUS = 7
local ICON_HOVER_HEIGHT = 0.45 -- low YOffset so items read as lying on the floor.
local ICON_SPIN_SPEED = 1.6

local deps = {}
local pickupRecords = {}
local accumulator = 0
local spinPhase = 0
local heartbeatConnection = nil
local activeFolder = nil
local activeContainer = nil

-- ---------------------------------------------------------------------------
-- Floor discovery (arena-container-scoped). Never scans outside `container`.
-- ---------------------------------------------------------------------------
local function isFloorLike(part)
	if not part:IsA("BasePart") then
		return false
	end

	local name = string.lower(part.Name)
	local size = part.Size

	return string.find(name, "floor", 1, true) ~= nil
		or string.find(name, "ground", 1, true) ~= nil
		or string.find(name, "baseplate", 1, true) ~= nil
		or (size.Y <= 4 and size.X >= 40 and size.Z >= 40)
end

local function findContainerFloor(container)
	if container == nil then
		return nil
	end

	local best = nil
	local bestArea = 0

	for _, descendant in ipairs(container:GetDescendants()) do
		if isFloorLike(descendant) then
			local area = descendant.Size.X * descendant.Size.Z
			if area > bestArea then
				bestArea = area
				best = descendant
			end
		end
	end

	if best == nil then
		return nil
	end

	return {
		Center = best.Position,
		HalfX = best.Size.X * 0.5,
		HalfZ = best.Size.Z * 0.5,
		TopY = best.Position.Y + best.Size.Y * 0.5,
	}
end

-- ---------------------------------------------------------------------------
-- Visual construction.
-- ---------------------------------------------------------------------------
local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function getRuntimeRoot()
	local runtime = getOrCreateFolder(Workspace, RUNTIME_ROOT_NAME)
	return getOrCreateFolder(runtime, ARENA_MODE_FOLDER)
end

-- Resolves WOB_Runtime/ArenaMode/ActiveArenaLayout without creating folders (read-only
-- lookup used by marker collection).
local function findActiveLayout()
	local runtimeRoot = Workspace:FindFirstChild(RUNTIME_ROOT_NAME)
	if runtimeRoot == nil then
		return nil
	end

	local arenaMode = runtimeRoot:FindFirstChild(ARENA_MODE_FOLDER)
	if arenaMode == nil then
		return nil
	end

	return arenaMode:FindFirstChild(ACTIVE_LAYOUT_NAME)
end

-- ---------------------------------------------------------------------------
-- Layout marker discovery (Update 0.2.x). Pickup positions come EXCLUSIVELY from the
-- active authored layout's PickupSpawns markers. There is no fraction fallback: if no
-- usable markers exist, no pickups spawn (the caller warns and no-ops).
-- ---------------------------------------------------------------------------
local function resolveMarkerPickupId(marker)
	local attrType = marker:GetAttribute("WOBPickupType")
	if typeof(attrType) == "string" and PICKUP_TYPE_TO_ID[attrType] ~= nil then
		return PICKUP_TYPE_TO_ID[attrType]
	end

	-- Fall back to the name token: PickupSpawn_<Type>_<suffix>.
	local token = string.match(marker.Name, "^PickupSpawn_([%a]+)")
	if token ~= nil and PICKUP_TYPE_TO_ID[token] ~= nil then
		return PICKUP_TYPE_TO_ID[token]
	end

	return nil
end

-- Collects pickup markers from a PickupSpawns folder anywhere under `root`.
local function collectFromRoot(root, spawns)
	if root == nil then
		return
	end

	-- Find a PickupSpawns folder directly under root, else search descendants.
	local markersFolder = root:FindFirstChild(PICKUP_SPAWNS_FOLDER)
	if markersFolder == nil then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant.Name == PICKUP_SPAWNS_FOLDER then
				markersFolder = descendant
				break
			end
		end
	end

	if markersFolder == nil then
		return
	end

	for _, marker in ipairs(markersFolder:GetDescendants()) do
		if marker:IsA("BasePart") then
			local pickupId = resolveMarkerPickupId(marker)
			if pickupId ~= nil then
				local pickupConfig = WeaponCatalog.getPickup(pickupId)
				if pickupConfig ~= nil and WeaponCatalog.isPickupEnabled(pickupConfig) then
					table.insert(spawns, { Config = pickupConfig, Position = marker.Position })
				end
			end
		end
	end
end

-- Returns a list of { Config = pickupConfig, Position = Vector3 } from markers, filtered by
-- each pickup's feature flag. Source priority:
--   1. The cloned runtime layout (WOB_Runtime/ArenaMode/ActiveArenaLayout) -- used when the
--      arena loads from a saved .rbxm template (MazeEnabled path).
--   2. FALLBACK: PickupSpawns authored DIRECTLY in the live arena container (e.g.
--      WOB_Generated/BattleArena/PickupSpawns) -- so a hand-built arena with no saved
--      template still spawns its pickups. No fraction/procedural fallback either way.
local function collectMarkerSpawns(arenaContainer)
	local spawns = {}

	collectFromRoot(findActiveLayout(), spawns)

	if #spawns == 0 then
		collectFromRoot(arenaContainer, spawns)
	end

	return spawns
end

local function configureVisualPart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("WOBVisualOnly", true)
end

local function buildPickupModel(parent, pickupConfig, position)
	local model = Instance.new("Model")
	model.Name = "Pickup_" .. pickupConfig.Id

	-- Flat glow ring lying on the floor (small YOffset to avoid z-fighting).
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 4.8, 4.8)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = pickupConfig.AccentColor
	ring.Transparency = 0.35
	configureVisualPart(ring)
	ring.Parent = model

	-- Small icon sitting just above the floor (NOT a giant floating chip).
	local icon = Instance.new("Part")
	icon.Name = "Icon"
	icon.Shape = Enum.PartType.Block
	icon.Size = Vector3.new(1.5, 1.5, 1.5)
	icon.CFrame = CFrame.new(position + Vector3.new(0, ICON_HOVER_HEIGHT + 0.75, 0))
	icon.Material = Enum.Material.Neon
	icon.Color = pickupConfig.IconColor or pickupConfig.AccentColor
	icon.Transparency = 0.1
	configureVisualPart(icon)
	icon.Parent = model

	local light = Instance.new("PointLight")
	light.Color = pickupConfig.AccentColor
	light.Brightness = 2
	light.Range = 8
	light.Parent = icon

	model.PrimaryPart = icon
	model.Parent = parent

	return model, icon
end

local function setPickupVisible(record, visible)
	if record.Model == nil or record.Model.Parent == nil then
		return
	end

	for _, descendant in ipairs(record.Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and (descendant.Name == "Ring" and 0.35 or 0.1) or 1
		elseif descendant:IsA("PointLight") then
			descendant.Enabled = visible
		end
	end

	record.Available = visible
end

-- ---------------------------------------------------------------------------
-- Participant helpers.
-- ---------------------------------------------------------------------------
local function getParticipantPosition(participant)
	local registry = deps.tankParticipantRegistry
	local model = registry.getParticipantPhysicalModel(participant)

	if model == nil then
		return nil
	end

	if participant.PrimaryPart ~= nil and participant.PrimaryPart.Parent ~= nil then
		return participant.PrimaryPart.Position
	end

	if participant.Body ~= nil and participant.Body.Parent ~= nil then
		return participant.Body.Position
	end

	local ok, pivot = pcall(function()
		return model:GetPivot().Position
	end)

	return ok and pivot or nil
end

local function notify(participant, text, color)
	if deps.notify ~= nil then
		deps.notify(participant, text, color)
	end
end

-- ---------------------------------------------------------------------------
-- Collection effects.
-- ---------------------------------------------------------------------------
local function tryCollectHeal(record, participant)
	local registry = deps.tankParticipantRegistry
	local maxHealth = registry.getParticipantMaxHealth(participant)
	local currentHealth = registry.getParticipantHealth(participant)
	local config = record.Config

	if currentHealth >= maxHealth and config.ConsumeWhenFull ~= true then
		return false
	end

	local newHealth = math.min(maxHealth, currentHealth + (config.HealAmount or 0))
	registry.setParticipantHealth(participant, newHealth)
	notify(participant, config.NotifyText or "Repair!", config.IconColor or config.AccentColor)

	return true
end

local function tryCollectWeapon(record, participant)
	if deps.temporaryWeaponService == nil then
		return false
	end

	return deps.temporaryWeaponService.grant(participant, record.Config.WeaponId) == true
end

-- Shield pickup: grants ReflectShield charge(s) to the arena session. Only consumed if a
-- charge was actually added (not already full).
local function tryCollectShield(record, participant)
	if deps.grantReflectShieldCharges == nil then
		return false
	end

	local amount = tonumber(record.Config.ShieldCharges) or 1
	local granted = deps.grantReflectShieldCharges(participant, amount) == true

	if granted then
		notify(participant, record.Config.NotifyText or "Shield!", record.Config.IconColor or record.Config.AccentColor)
	end

	return granted
end

local function tryCollect(record, participant)
	local config = record.Config

	if config.Kind == "Heal" then
		return tryCollectHeal(record, participant)
	elseif config.Kind == "Weapon" then
		return tryCollectWeapon(record, participant)
	elseif config.Kind == "Shield" then
		return tryCollectShield(record, participant)
	end

	return false
end

local function onCollected(record, participant)
	setPickupVisible(record, false)

	if deps.playPickupFX ~= nil then
		deps.playPickupFX(record.Position, record.Config)
	end

	local respawnSeconds = math.max(2, tonumber(record.Config.RespawnSeconds) or 16)
	record.RespawnAt = os.clock() + respawnSeconds
end

-- ---------------------------------------------------------------------------
-- Main update loop (throttled).
-- ---------------------------------------------------------------------------
local function updateSpin(deltaTime)
	spinPhase += deltaTime * ICON_SPIN_SPEED

	for _, record in ipairs(pickupRecords) do
		if record.Available and record.Icon ~= nil and record.Icon.Parent ~= nil then
			record.Icon.CFrame = CFrame.new(record.Position + Vector3.new(0, ICON_HOVER_HEIGHT + 0.75, 0))
				* CFrame.Angles(0, spinPhase, 0)
		end
	end
end

local function updateCollection()
	local registry = deps.tankParticipantRegistry

	if registry == nil then
		return
	end

	local now = os.clock()

	for _, record in ipairs(pickupRecords) do
		if not record.Available and record.RespawnAt ~= nil and now >= record.RespawnAt then
			record.RespawnAt = nil
			setPickupVisible(record, true)
		end

		if record.Available then
			-- Players AND arena bots can collect (bots use the same grant paths). Only living,
			-- active arena participants are eligible.
			for _, participant in ipairs(registry.getParticipants()) do
				local isArenaParticipant = participant.OwnerPlayer ~= nil
					or (participant.IsBot == true and participant.ParticipantState == "InBattleArena")

				if isArenaParticipant
					and not registry.getParticipantIsDead(participant)
					and participant.IsActive ~= false
				then
					local position = getParticipantPosition(participant)

					if position ~= nil then
						local flatDelta = Vector3.new(
							position.X - record.Position.X,
							0,
							position.Z - record.Position.Z
						)

						if flatDelta.Magnitude <= COLLECT_RADIUS then
							if tryCollect(record, participant) then
								onCollected(record, participant)
								break
							end
						end
					end
				end
			end
		end
	end
end

local function onHeartbeat(deltaTime)
	updateSpin(deltaTime)

	accumulator += deltaTime

	if accumulator < CHECK_INTERVAL_SECONDS then
		return
	end

	accumulator = 0
	updateCollection()
end

-- ---------------------------------------------------------------------------
-- Lifecycle.
-- ---------------------------------------------------------------------------
function ArenaPickupService.init(options)
	deps = options or {}
end

function ArenaPickupService.start(arenaContainer)
	-- Idempotent: a second start() with the same container is a no-op; with a
	-- different container, the previous session is cleaned first.
	if activeContainer == arenaContainer and #pickupRecords > 0 then
		return
	end

	ArenaPickupService.stop()

	if not WeaponCatalog.isUpdate02ArenaLayerEnabled() then
		warn("[PICKUPS] Update02ArenaLayerEnabled=false; pickups not spawned.")
		return
	end

	if WeaponCatalog.Flags.PickupsEnabled ~= true then
		print("[PICKUPS] Disabled via WeaponCatalog.Flags.PickupsEnabled.")
		return
	end

	if arenaContainer == nil then
		warn("[PICKUPS] start() called without an arena container; skipping.")
		return
	end

	local floorInfo = findContainerFloor(arenaContainer)

	if floorInfo == nil then
		warn(("[PICKUPS] No floor found inside arena container '%s'; pickups not spawned."):format(arenaContainer:GetFullName()))
		return
	end

	activeContainer = arenaContainer

	-- MARKERS ONLY. Pickup positions come exclusively from the authored layout's
	-- PickupSpawns markers. There is no fraction fallback: if the layout or its markers
	-- are missing, we spawn nothing and warn -- "prefer no spawn over a wrong spawn".
	local markerSpawns = collectMarkerSpawns(arenaContainer)

	if #markerSpawns == 0 then
		activeContainer = nil
		warn("[PICKUPS] No PickupSpawns markers found (checked ActiveArenaLayout and the live arena container); no pickups spawned.")
		return
	end

	activeFolder = getOrCreateFolder(getRuntimeRoot(), PICKUPS_FOLDER_NAME)
	activeFolder:ClearAllChildren()
	pickupRecords = {}

	local spawnList = {}
	for _, spawn in ipairs(markerSpawns) do
		-- Snap pickups onto the floor surface (marker XZ, floor top Y) so they read
		-- as lying on the ground rather than floating.
		table.insert(spawnList, {
			Config = spawn.Config,
			Position = Vector3.new(spawn.Position.X, floorInfo.TopY, spawn.Position.Z),
		})
	end
	print(("[PICKUPS] Using %d authored layout PickupSpawns markers."):format(#markerSpawns))

	for _, spawn in ipairs(spawnList) do
		local model, icon = buildPickupModel(activeFolder, spawn.Config, spawn.Position)

		table.insert(pickupRecords, {
			Config = spawn.Config,
			Position = spawn.Position,
			Model = model,
			Icon = icon,
			Available = true,
			RespawnAt = nil,
		})
	end

	heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	print(("[PICKUPS] Spawned %d pickups in arena '%s'."):format(#pickupRecords, arenaContainer.Name))
end

function ArenaPickupService.stop()
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if activeFolder ~= nil and activeFolder.Parent ~= nil then
		activeFolder:Destroy()
	end

	activeFolder = nil
	activeContainer = nil
	pickupRecords = {}
	accumulator = 0
end

return ArenaPickupService
