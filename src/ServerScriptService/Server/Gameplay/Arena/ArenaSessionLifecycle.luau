-- ArenaSessionLifecycle (Update 0.2.x): the single source of truth for "is an arena
-- session active right now?" -- maze, pickups, and breakable cover are spawned only
-- while the answer is yes, and torn down the moment it goes back to no.
--
-- TWO activation signals combine into one "active" state:
--   * BattleArena: ArenaCombatService reports each Enter/Leave (battleArenaPlayers > 0).
--   * Training match: RoundMatchService reports GameState + matchMode transitions.
--
-- DUEL MUST STAY CLEAN. The hard rule of this module: prefer NO spawn over a WRONG
-- spawn. Three independent guards enforce that Duel (matchMode "PvP") never gets maze,
-- pickups, or breakables:
--
--   1. Allowlist (Task B/C): the match path activates ONLY for matchMode == "Training".
--      A bare GameState == "Playing" is NOT enough -- Duel AND Training both reach
--      "Playing", so the mode string is mandatory. "PvP", nil, and any unknown mode are
--      treated as forbidden -> no-op.
--   2. Explicit container resolution (Task D): runtime objects are cloned only into a
--      specifically named arena container under WOB_Generated (Training -> "Map",
--      BattleArena -> "BattleArena"). There is NO generic "largest floor anywhere"
--      fallback and NO Lobby/Duel fallback. If the named container is absent, nothing
--      spawns.
--   3. Hard cleanup on Duel/PvP (Task F): when a forbidden mode reaches "Playing", the
--      whole WOB_Runtime/ArenaMode subtree is destroyed defensively, so any object left
--      over from a previous Training session can never bleed into a Duel.
--
-- All runtime objects live under Workspace/WOB_Runtime/ArenaMode (Task E), so a single
-- subtree destroy is a complete teardown.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local WeaponCatalog = require(configs:WaitForChild("WeaponCatalog"))

local ROLE_ATTRS = WeaponCatalog.RoleAttributes
local ROLES = WeaponCatalog.Roles

local ArenaSessionLifecycle = {}

local GENERATED_ROOT_NAME = "WOB_Generated"
local RUNTIME_ROOT_NAME = "WOB_Runtime"
local ARENA_MODE_FOLDER = "ArenaMode"

-- Explicit, mode-specific container names under WOB_Generated. These are the ONLY
-- containers the runtime is ever allowed to spawn into. No generic fallback list.
local TRAINING_CONTAINER_NAME = "Map"
local BATTLE_ARENA_CONTAINER_NAME = "BattleArena"

-- Allowlist of match modes that may start the runtime via the match path.
-- BattleArena is NOT a matchMode -- it activates through its own Enter/Leave signal.
local TRAINING_MODE = "Training"
local ALLOWED_MATCH_MODES = {
	[TRAINING_MODE] = true,
}

local deps = {
	mazeService = nil,
	pickupService = nil,
	breakableService = nil,
	refreshProjectileTargets = nil,
}

local battleArenaPlayers = 0
local matchActive = false
local activeContainer = nil

-- ---------------------------------------------------------------------------
-- Studio-only logging (Task G). Per-transition only -- never per-frame.
-- ---------------------------------------------------------------------------
local function studioLog(fmt, ...)
	if RunService:IsStudio() then
		print(("[ARENA LIFECYCLE] " .. fmt):format(...))
	end
end

local function studioWarn(fmt, ...)
	if RunService:IsStudio() then
		warn(("[ARENA LIFECYCLE] " .. fmt):format(...))
	end
end

local function isArenaLayerEnabled()
	return WeaponCatalog.isUpdate02ArenaLayerEnabled()
end

-- ---------------------------------------------------------------------------
-- Explicit container resolution (Task D).
-- Resolves ONLY the named child of WOB_Generated. Returns nil if absent -- callers
-- treat nil as "do not spawn". No Lobby/Duel fallback, no largest-floor inference.
-- ---------------------------------------------------------------------------
local function getArenaContainer(requiredName)
	if requiredName == nil then
		return nil
	end

	local root = Workspace:FindFirstChild(GENERATED_ROOT_NAME)
	if root == nil then
		return nil
	end

	return root:FindFirstChild(requiredName)
end

-- Role-attribute guard (Task I), layered on top of the mode/signal allowlist as
-- defense-in-depth. If a resolved container is EXPLICITLY tagged as a Duel/Lobby role, or
-- explicitly disallows the arena layer (WOBAllowArenaMode == false), it is REFUSED even
-- though its name/signal matched. Untagged containers are allowed: the mode/signal path
-- already guarantees we only resolve "Map" for Training and "BattleArena" for BattleArena,
-- and tagging is an optional Studio step (see tools/studio/TagArenaRoles.commandbar.luau).
-- Returns: allowed (bool), reason (string|nil).
local function containerAllowsArenaMode(container)
	local role = container:GetAttribute(ROLE_ATTRS.Role)

	if role == ROLES.Duel or role == ROLES.Lobby then
		return false, ("container is tagged WOBArenaRole=%q"):format(tostring(role))
	end

	if container:GetAttribute(ROLE_ATTRS.AllowArenaMode) == false then
		return false, "container has WOBAllowArenaMode=false"
	end

	return true, nil
end

local function refreshProjectileTargets()
	if deps.refreshProjectileTargets ~= nil then
		deps.refreshProjectileTargets()
	end
end

-- Forward declaration: startServices() calls purgeArenaModeSubtree() (role-guard sweep),
-- but the definition lives below. Declaring the local here keeps the reference in scope.
local purgeArenaModeSubtree

-- ---------------------------------------------------------------------------
-- Combined active state.
-- ---------------------------------------------------------------------------
local function isActive()
	if not isArenaLayerEnabled() then
		return false
	end

	return battleArenaPlayers > 0 or matchActive == true
end

local function startServices(requiredContainerName, source)
	if activeContainer ~= nil then
		return
	end

	local container = getArenaContainer(requiredContainerName)

	if container == nil then
		-- Prefer no-op over wrong spawn: if the explicit container is missing, spawn
		-- NOTHING (rather than falling back to a shared/global field).
		studioWarn(
			"Denied start (source=%s): required container Workspace/%s/%s not found; nothing spawned.",
			tostring(source), GENERATED_ROOT_NAME, tostring(requiredContainerName))
		return
	end

	-- Defense-in-depth role guard (Task I): refuse a container explicitly tagged Duel/Lobby
	-- or explicitly opted out. Also sweep any orphaned ArenaMode subtree so a mis-tagged
	-- container can never inherit leftover objects.
	local allowed, denyReason = containerAllowsArenaMode(container)
	if not allowed then
		studioWarn(
			"Denied start (source=%s) in '%s': %s; nothing spawned.",
			tostring(source), container:GetFullName(), tostring(denyReason))
		purgeArenaModeSubtree("RoleGuardDenied:" .. tostring(source))
		return
	end

	activeContainer = container

	if deps.mazeService ~= nil then
		deps.mazeService.start(container)
	end

	if deps.breakableService ~= nil then
		deps.breakableService.start(container)
	end

	if deps.pickupService ~= nil then
		deps.pickupService.start(container)
	end

	-- Maze walls must be added to ProjectileService's bounce surface list.
	refreshProjectileTargets()

	studioLog(
		"Started (source=%s) in '%s' (battleArenaPlayers=%d, matchActive=%s).",
		tostring(source), container:GetFullName(), battleArenaPlayers, tostring(matchActive))
end

-- Destroys the WOB_Runtime/ArenaMode subtree outright. Safe to call even when nothing
-- is active -- this is the defensive purge used on Duel/PvP start (Task F).
-- (Assigns to the local forward-declared above so startServices can call it.)
function purgeArenaModeSubtree(reason)
	local runtimeRoot = Workspace:FindFirstChild(RUNTIME_ROOT_NAME)
	if runtimeRoot == nil then
		return false
	end

	local arenaMode = runtimeRoot:FindFirstChild(ARENA_MODE_FOLDER)
	if arenaMode == nil then
		return false
	end

	arenaMode:Destroy()
	studioWarn("Hard cleanup: destroyed Workspace/%s/%s (reason=%s).", RUNTIME_ROOT_NAME, ARENA_MODE_FOLDER, tostring(reason))
	return true
end

local function stopServices(reason)
	local hadActiveContainer = activeContainer ~= nil

	if deps.pickupService ~= nil then
		deps.pickupService.stop()
	end

	if deps.breakableService ~= nil then
		deps.breakableService.stop()
	end

	if deps.mazeService ~= nil then
		deps.mazeService.stop()
	end

	activeContainer = nil

	-- Defensive: ensure the whole ArenaMode subtree is gone, not just the per-service
	-- folders, so nothing can linger into the next (possibly Duel) session.
	local purged = purgeArenaModeSubtree(reason or "StopServices")

	if hadActiveContainer or purged then
		refreshProjectileTargets()
	end

	if hadActiveContainer or purged then
		studioLog("Stopped; runtime objects cleaned (reason=%s).", tostring(reason))
	end
end

local function reconcile(requiredContainerName, source)
	if not isArenaLayerEnabled() then
		stopServices("Update02Disabled:" .. tostring(source))
		studioWarn(
			"Update02ArenaLayerEnabled=false; denied arena layer start (source=%s).",
			tostring(source))
		return
	end

	if isActive() then
		startServices(requiredContainerName, source)
	else
		stopServices(source)
	end
end

-- ---------------------------------------------------------------------------
-- Signal handlers (wired from WOBGameplayServer).
-- ---------------------------------------------------------------------------
function ArenaSessionLifecycle.init(options)
	deps = options or {}
	battleArenaPlayers = 0
	matchActive = false
	activeContainer = nil
	stopServices("Init")
end

-- Called when ArenaCombatService.EnterArena successfully registers a new session.
-- BattleArena uses its OWN named container, never the Training "Map" field.
function ArenaSessionLifecycle.onBattleArenaEnter()
	if not isArenaLayerEnabled() then
		battleArenaPlayers = 0
		matchActive = false
		stopServices("Update02Disabled:BattleArenaEnter")
		studioWarn("Update02ArenaLayerEnabled=false; BattleArena arena layer start ignored.")
		return
	end

	battleArenaPlayers += 1
	reconcile(BATTLE_ARENA_CONTAINER_NAME, "BattleArenaEnter")
end

-- Called when ArenaCombatService.LeaveArena removes a session.
function ArenaSessionLifecycle.onBattleArenaLeave()
	battleArenaPlayers = math.max(0, battleArenaPlayers - 1)

	if isArenaLayerEnabled() and battleArenaPlayers > 0 then
		return
	end

	stopServices("BattleArenaLeave")
end

-- Called from RoundMatchService.onGameStateChanged.
--
-- DUEL GUARD (Task B/C): RoundMatchService drives BOTH Training and Duel through the
-- same "Playing" GameState, so the matchMode string is mandatory. ONLY "Training" is
-- allowed to start the runtime layer. "PvP" (Duel), nil, and any unknown mode are
-- forbidden -> no-op, AND we hard-purge any leftover ArenaMode subtree so a Duel can
-- never inherit Training's objects.
function ArenaSessionLifecycle.onGameStateChanged(gameState, matchMode)
	if gameState ~= "Playing" then
		-- Menu / Result / etc: match layer inactive.
		matchActive = false
		stopServices("GameState:" .. tostring(gameState))
		return
	end

	if not isArenaLayerEnabled() then
		matchActive = false
		stopServices("Update02Disabled:GameStatePlaying")
		studioWarn(
			"Update02ArenaLayerEnabled=false; match-path arena layer start ignored (matchMode=%s).",
			tostring(matchMode))
		return
	end

	if ALLOWED_MATCH_MODES[matchMode] == true then
		matchActive = true
		reconcile(TRAINING_CONTAINER_NAME, "TrainingPlaying")
	else
		-- Forbidden / unknown / nil. Prefer no spawn over wrong spawn.
		matchActive = false
		studioWarn(
			"Denied match-path start: gameState='Playing' but matchMode=%s is not allowlisted (allowed: Training).",
			tostring(matchMode))

		-- Hard cleanup: Duel/PvP must destroy the arena subtree even if stale state says
		-- another arena signal is active.
		stopServices("ForbiddenMatchMode:" .. tostring(matchMode))
	end
end

function ArenaSessionLifecycle.isActive()
	return isActive()
end

function ArenaSessionLifecycle.getActiveContainer()
	return activeContainer
end

return ArenaSessionLifecycle
