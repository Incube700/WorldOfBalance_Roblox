-- AchievementService (Etap 4): leaderstats + arena achievements + best-level record.
--
-- Responsibilities (all server-side, display/economy only -- no combat/projectile changes):
--   * Create per-player `leaderstats` (Bolts / Kills / Best Level) for the Roblox leaderboard.
--   * Persist lifetime Kills, BestArenaLevel and unlocked achievement ids via DataStore.
--   * On a kill / level-up, evaluate achievements, grant their Bolt reward, and toast client.
--
-- DataStore is unavailable until the place is published; everything degrades gracefully
-- (in-memory only, warns once) so Studio playtests still work.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local AchievementCatalog = require(configs:WaitForChild("AchievementCatalog"))

local AchievementService = {}

local STORE_NAME = "WOBAchievementsV1"
local KEY_PREFIX = "Player_"

local deps = {}
local store = nil
local warnedNoStore = false
local stateByUserId = {} -- [userId] = { Kills, BestLevel, Unlocked = {id=true} }
local toastEvent = nil

local function getStore()
	if store ~= nil then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	if not warnedNoStore then
		warnedNoStore = true
		warn("[ACHIEVEMENT] DataStore unavailable (publish the place to persist): " .. tostring(result))
	end
	return nil
end

local function getState(player)
	local state = stateByUserId[player.UserId]
	if state == nil then
		state = { Kills = 0, BestLevel = 1, Unlocked = {} }
		stateByUserId[player.UserId] = state
	end
	return state
end

-- ---------------------------------------------------------------------------
-- leaderstats
-- ---------------------------------------------------------------------------
local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	for key, def in pairs(AchievementCatalog.Leaderstats) do
		local stat = leaderstats:FindFirstChild(def.Name)
		if stat == nil then
			stat = Instance.new("IntValue")
			stat.Name = def.Name
			stat.Value = 0
			stat.Parent = leaderstats
		end
	end

	return leaderstats
end

local function setStat(player, statName, value)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end
	local stat = leaderstats:FindFirstChild(statName)
	if stat ~= nil then
		stat.Value = math.max(0, math.floor(tonumber(value) or 0))
	end
end

local function refreshLeaderstats(player)
	local state = getState(player)
	setStat(player, AchievementCatalog.Leaderstats.Kills.Name, state.Kills)
	setStat(player, AchievementCatalog.Leaderstats.BestLevel.Name, state.BestLevel)
	-- Bolts come from the wallet (visible balance attribute), refreshed by syncBolts().
end

-- Wallet exposes the balance on a player attribute; mirror it into the Bolts leaderstat.
function AchievementService.syncBolts(player)
	if player == nil then
		return
	end
	-- Prefer the live wallet API; fall back to the persistent balance attribute.
	local balance
	if deps.getBoltsBalance ~= nil then
		balance = tonumber(deps.getBoltsBalance(player))
	end
	if balance == nil then
		balance = tonumber(player:GetAttribute("PersistentBolts"))
	end
	if balance ~= nil then
		setStat(player, AchievementCatalog.Leaderstats.Bolts.Name, balance)
	end
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------
function AchievementService.loadPlayer(player)
	ensureLeaderstats(player)
	local state = getState(player)

	local s = getStore()
	if s ~= nil then
		local ok, data = pcall(function()
			return s:GetAsync(KEY_PREFIX .. tostring(player.UserId))
		end)
		if ok and typeof(data) == "table" then
			state.Kills = math.max(0, math.floor(tonumber(data.Kills) or 0))
			state.BestLevel = math.max(1, math.floor(tonumber(data.BestLevel) or 1))
			state.Unlocked = {}
			if typeof(data.Unlocked) == "table" then
				for _, id in ipairs(data.Unlocked) do
					state.Unlocked[id] = true
				end
			end
		end
	end

	refreshLeaderstats(player)
	AchievementService.syncBolts(player)
end

function AchievementService.savePlayer(player)
	local state = stateByUserId[player.UserId]
	if state == nil then
		return
	end
	local s = getStore()
	if s == nil then
		return
	end
	local unlockedList = {}
	for id in pairs(state.Unlocked) do
		table.insert(unlockedList, id)
	end
	pcall(function()
		s:UpdateAsync(KEY_PREFIX .. tostring(player.UserId), function(old)
			old = typeof(old) == "table" and old or {}
			old.Kills = math.max(tonumber(old.Kills) or 0, state.Kills)
			old.BestLevel = math.max(tonumber(old.BestLevel) or 1, state.BestLevel)
			old.Unlocked = unlockedList
			return old
		end)
	end)
	stateByUserId[player.UserId] = nil
end

-- ---------------------------------------------------------------------------
-- Unlock evaluation
-- ---------------------------------------------------------------------------
local function unlock(player, def)
	local state = getState(player)
	if state.Unlocked[def.Id] then
		return
	end
	state.Unlocked[def.Id] = true

	-- Grant the Bolt reward through the wallet if available.
	local reward = math.max(0, math.floor(tonumber(def.RewardBolts) or 0))
	if reward > 0 and deps.grantBolts ~= nil then
		deps.grantBolts(player, reward, "Achievement:" .. def.Id)
	end

	AchievementService.syncBolts(player)

	-- Toast the client (display only).
	if toastEvent ~= nil then
		toastEvent:FireClient(player, {
			Id = def.Id,
			Title = def.Title,
			Description = def.Description,
			Icon = def.Icon,
			RewardBolts = reward,
		})
	end

	print(("[ACHIEVEMENT] %s unlocked %s (+%d Bolts)"):format(player.Name, def.Id, reward))
end

-- Called on each player kill. context = { Killer=Player, KillsInSession=number,
-- ArenaLevel=number, RicochetKill=bool, WeaponId=string }
function AchievementService.onKill(context)
	local player = context.Killer
	if player == nil or player.Parent ~= Players then
		return
	end

	local state = getState(player)
	state.Kills += 1
	setStat(player, AchievementCatalog.Leaderstats.Kills.Name, state.Kills)

	for _, def in pairs(AchievementCatalog.Achievements) do
		if not state.Unlocked[def.Id] then
			if def.Kind == "KillsTotal" and state.Kills >= def.Threshold then
				unlock(player, def)
			elseif def.Kind == "KillsInSession" and (tonumber(context.KillsInSession) or 0) >= def.Threshold then
				unlock(player, def)
			elseif def.Kind == "RicochetKill" and context.RicochetKill == true then
				unlock(player, def)
			elseif def.Kind == "WeaponKill" and context.WeaponId == def.Weapon then
				unlock(player, def)
			end
		end
	end
end

-- Called when a player's arena level changes. Updates the Best Level record + achievement.
function AchievementService.onArenaLevel(player, arenaLevel)
	if player == nil or player.Parent ~= Players then
		return
	end
	local level = math.max(1, math.floor(tonumber(arenaLevel) or 1))
	local state = getState(player)

	if level > state.BestLevel then
		state.BestLevel = level
		setStat(player, AchievementCatalog.Leaderstats.BestLevel.Name, level)
	end

	for _, def in pairs(AchievementCatalog.Achievements) do
		if def.Kind == "ArenaLevel" and not state.Unlocked[def.Id] and level >= def.Threshold then
			unlock(player, def)
		end
	end
end

function AchievementService.init(options)
	deps = options or {}
	toastEvent = deps.toastEvent

	-- Wire player lifecycle. Safe if some players are already present.
	local function bindBoltsSync(player)
		-- Mirror wallet balance into the Bolts leaderstat whenever it changes.
		player:GetAttributeChangedSignal("PersistentBolts"):Connect(function()
			AchievementService.syncBolts(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		AchievementService.loadPlayer(player)
		bindBoltsSync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		AchievementService.savePlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		AchievementService.loadPlayer(player)
	end
end

return AchievementService
