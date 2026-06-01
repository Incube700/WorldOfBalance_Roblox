-- CosmeticShopService (Shop v1): buy & equip tank skins with Bolts.
--
-- Responsibilities (server-authoritative):
--   * Track which skins each player OWNS + which is EQUIPPED (persisted via DataStore).
--   * Handle Buy / Equip requests from the client over remotes, validating price + ownership.
--   * Expose getEquippedSkin(player) so the spawner dresses the tank in the chosen skin.
--
-- Prices/skins come from SkinCatalog (already defined). Skins with UnlockedByDefault = true
-- are free and always owned. DataStore degrades gracefully (in-memory) until the place is
-- published, so Studio playtests work.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local SkinCatalog = require(configs:WaitForChild("SkinCatalog"))

local CosmeticShopService = {}

local STORE_NAME = "WOBCosmeticsV1"
local KEY_PREFIX = "Player_"
local DEFAULT_SKIN = SkinCatalog.DefaultSkinId or "Default"

local deps = {}
local store = nil
local warnedNoStore = false
local stateByUserId = {} -- [userId] = { Owned = {id=true}, Equipped = skinId }
local buyEvent, equipEvent, syncEvent = nil, nil, nil

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
		warn("[SHOP] DataStore unavailable (publish the place to persist): " .. tostring(result))
	end
	return nil
end

local function getState(player)
	local state = stateByUserId[player.UserId]
	if state == nil then
		state = { Owned = {}, Equipped = DEFAULT_SKIN }
		stateByUserId[player.UserId] = state
	end
	return state
end

-- A skin is owned if it's free-by-default or recorded as purchased.
local function ownsSkin(state, skinId)
	local def = SkinCatalog.Skins[skinId]
	if def == nil then
		return false
	end
	if def.UnlockedByDefault == true or (tonumber(def.Price) or 0) <= 0 then
		return true
	end
	return state.Owned[skinId] == true
end

-- Builds the catalog + ownership snapshot the client needs to render the shop.
local function buildSyncPayload(player)
	local state = getState(player)
	local items = {}
	for skinId, def in pairs(SkinCatalog.Skins) do
		-- Show: free defaults + Bolts-priced skins. Hide test skins and non-Bolts (Crystals) ones.
		local currency = def.Currency or "Bolts"
		local visible = def.ShopHidden ~= true
			and (def.UnlockedByDefault == true or (currency == "Bolts"))
		if visible then
			table.insert(items, {
				SkinId = skinId,
				DisplayName = def.DisplayName or skinId,
				Price = tonumber(def.Price) or 0,
				BodyColor = def.BodyColor,
				TurretColor = def.TurretColor,
				Owned = ownsSkin(state, skinId),
			})
		end
	end
	local bolts = 0
	if deps.getBoltsBalance ~= nil then
		bolts = tonumber(deps.getBoltsBalance(player)) or 0
	end

	return {
		Items = items,
		Equipped = state.Equipped,
		Bolts = bolts,
		Message = nil,
	}
end

local function syncToClient(player, message)
	if syncEvent ~= nil then
		local payload = buildSyncPayload(player)
		payload.Message = message
		syncEvent:FireClient(player, payload)
	end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function CosmeticShopService.getEquippedSkin(player)
	if player == nil then
		return DEFAULT_SKIN
	end
	local state = getState(player)
	-- Guard: never return a skin the player no longer owns.
	if ownsSkin(state, state.Equipped) then
		return state.Equipped
	end
	return DEFAULT_SKIN
end

function CosmeticShopService.loadPlayer(player)
	local state = getState(player)
	local s = getStore()
	if s ~= nil then
		local ok, data = pcall(function()
			return s:GetAsync(KEY_PREFIX .. tostring(player.UserId))
		end)
		if ok and typeof(data) == "table" then
			state.Owned = {}
			if typeof(data.Owned) == "table" then
				for _, id in ipairs(data.Owned) do
					state.Owned[id] = true
				end
			end
			if typeof(data.Equipped) == "string" and SkinCatalog.Skins[data.Equipped] ~= nil then
				state.Equipped = data.Equipped
			end
		end
	end
	syncToClient(player)
end

function CosmeticShopService.savePlayer(player)
	local state = stateByUserId[player.UserId]
	if state == nil then
		return
	end
	local s = getStore()
	if s ~= nil then
		local ownedList = {}
		for id in pairs(state.Owned) do
			table.insert(ownedList, id)
		end
		pcall(function()
			s:SetAsync(KEY_PREFIX .. tostring(player.UserId), {
				Owned = ownedList,
				Equipped = state.Equipped,
			})
		end)
	end
	stateByUserId[player.UserId] = nil
end

-- Buy a skin: validates it exists, isn't already owned, and the player can afford it.
function CosmeticShopService.tryBuy(player, skinId)
	local def = SkinCatalog.Skins[skinId]
	if def == nil then
		return false, "Unknown skin"
	end
	local state = getState(player)
	if ownsSkin(state, skinId) then
		syncToClient(player, "Already owned")
		return false, "Already owned"
	end
	local price = math.max(0, math.floor(tonumber(def.Price) or 0))
	if deps.trySpendBolts == nil or deps.trySpendBolts(player, price, "BuySkin:" .. skinId) ~= true then
		syncToClient(player, "Not enough Bolts (" .. price .. ")")
		return false, "Not enough Bolts"
	end
	state.Owned[skinId] = true
	state.Equipped = skinId -- auto-equip on purchase
	if deps.applySkinToCurrentTank ~= nil then
		deps.applySkinToCurrentTank(player, skinId)
	end
	syncToClient(player, "Purchased " .. (def.DisplayName or skinId) .. "!")
	print(("[SHOP] %s bought skin %s for %d Bolts"):format(player.Name, skinId, price))
	return true
end

-- Equip an owned skin (applies on next spawn; we also re-skin the current tank if present).
function CosmeticShopService.tryEquip(player, skinId)
	local state = getState(player)
	if not ownsSkin(state, skinId) then
		return false, "Not owned"
	end
	state.Equipped = skinId
	syncToClient(player)
	if deps.applySkinToCurrentTank ~= nil then
		deps.applySkinToCurrentTank(player, skinId)
	end
	return true
end

function CosmeticShopService.init(options)
	deps = options or {}
	buyEvent = deps.buyEvent
	equipEvent = deps.equipEvent
	syncEvent = deps.syncEvent

	if buyEvent ~= nil then
		buyEvent.OnServerEvent:Connect(function(player, skinId)
			-- Empty/"" skinId = a sync request (client opened the shop): push fresh data.
			if typeof(skinId) ~= "string" or skinId == "" then
				syncToClient(player)
				return
			end
			CosmeticShopService.tryBuy(player, skinId)
		end)
	end
	if equipEvent ~= nil then
		equipEvent.OnServerEvent:Connect(function(player, skinId)
			if typeof(skinId) == "string" then
				CosmeticShopService.tryEquip(player, skinId)
			end
		end)
	end

	-- Keep the shop's shown Bolts balance fresh: re-sync whenever the wallet balance changes
	-- (the wallet writes it to the PersistentBolts player attribute). Without this the shop
	-- keeps the login-time balance (often 0) and every Buy looks unaffordable.
	local function bindBalanceSync(player)
		player:GetAttributeChangedSignal("PersistentBolts"):Connect(function()
			syncToClient(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		CosmeticShopService.loadPlayer(player)
		bindBalanceSync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		CosmeticShopService.savePlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		bindBalanceSync(player)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		CosmeticShopService.loadPlayer(player)
	end
end

return CosmeticShopService
