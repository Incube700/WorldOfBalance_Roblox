local Players = game:GetService("Players")

local ArenaReviveService = {}
ArenaReviveService.__index = ArenaReviveService

function ArenaReviveService.new(config)
	return setmetatable({
		_config = config or {},
		_walletService = nil,
	}, ArenaReviveService)
end

function ArenaReviveService:SetWalletService(walletService)
	self._walletService = walletService
end

function ArenaReviveService:GetReviveConfig()
	return self._config.Revive or {}
end

function ArenaReviveService:IsReviveEnabled()
	return self:GetReviveConfig().Enabled == true
end

function ArenaReviveService:GetMaxRevivesPerRun()
	return math.max(0, math.floor(tonumber(self:GetReviveConfig().MaxRevivesPerRun) or 0))
end

function ArenaReviveService:GetReviveCost(session)
	local reviveConfig = self:GetReviveConfig()
	local reviveCount = math.max(0, math.floor(tonumber(session ~= nil and session.ReviveCount) or 0))
	local baseCost = tonumber(reviveConfig.CostBase)
		or tonumber(reviveConfig.CostBaseBolts)
		or 5
	local perRevive = tonumber(reviveConfig.CostPerRevive)
		or tonumber(reviveConfig.CostAdditiveBolts)
		or 0
	local multiplier = tonumber(reviveConfig.CostMultiplier) or 1
	local scaledCost = (baseCost + perRevive * reviveCount) * (multiplier ^ reviveCount)

	return math.max(1, math.floor(scaledCost + 0.5))
end

function ArenaReviveService:GetReviveRestoreHpPercent()
	local reviveConfig = self:GetReviveConfig()
	local percent = tonumber(reviveConfig.RestoreHpPercent)
		or tonumber(reviveConfig.ReviveHpPercent)
		or 0.5

	return math.clamp(percent, 0.05, 1)
end

function ArenaReviveService:IsFreeRespawnEnabled()
	return self:GetReviveConfig().FreeRespawnEnabled == true
end

function ArenaReviveService:ShouldFreeRespawnResetRun()
	return self:GetReviveConfig().FreeRespawnResetsRun ~= false
end

function ArenaReviveService:GetFreeRespawnRestoreHpPercent()
	local percent = tonumber(self:GetReviveConfig().FreeRespawnRestoreHpPercent) or 1

	return math.clamp(percent, 0.05, 1)
end

function ArenaReviveService:CanOfferRevive(session)
	return self:IsReviveEnabled()
		and session ~= nil
		and session.IsBotSession ~= true
		and session.Player ~= nil
		and (tonumber(session.ReviveCount) or 0) < self:GetMaxRevivesPerRun()
end

function ArenaReviveService:CanOfferFreeRespawn(session)
	return self:IsFreeRespawnEnabled()
		and session ~= nil
		and session.IsBotSession ~= true
		and session.Player ~= nil
end

function ArenaReviveService:CanAffordRevive(session)
	if session == nil or session.Player == nil or self._walletService == nil then
		return false
	end

	local getBalance = self._walletService.getBoltsBalance

	if getBalance == nil then
		return false
	end

	return getBalance(session.Player) >= self:GetReviveCost(session)
end

function ArenaReviveService:ClearRevivePending(session)
	if session == nil then
		return
	end

	session.RevivePending = false
	session.ReviveCost = 0
	session.ReviveLastError = ""
end

function ArenaReviveService:ClearFreeRespawnPending(session)
	if session == nil then
		return
	end

	session.FreeRespawnPending = false
	session.FreeRespawnLastError = ""
end

function ArenaReviveService:ResetRunState(session)
	if session == nil then
		return
	end

	session.ReviveCount = 0
	self:ClearRevivePending(session)
	self:ClearFreeRespawnPending(session)
end

function ArenaReviveService:BeginRevivePending(session)
	if not self:CanOfferRevive(session) then
		return false
	end

	session.RevivePending = true
	session.ReviveCost = self:GetReviveCost(session)
	session.ReviveLastError = ""

	return true
end

function ArenaReviveService:BeginFreeRespawnPending(session)
	if not self:CanOfferFreeRespawn(session) then
		return false
	end

	session.FreeRespawnPending = true
	session.FreeRespawnLastError = ""

	return true
end

function ArenaReviveService:_isValidPlayerSession(session, player)
	return session ~= nil
		and player ~= nil
		and player.Parent == Players
		and session.Player == player
		and session.IsBotSession ~= true
end

function ArenaReviveService:TryConsumeRevive(session, player, expectedPlayerMode)
	if not self:_isValidPlayerSession(session, player) then
		return {
			Success = false,
			Publish = false,
		}
	end

	if session.RevivePending ~= true then
		session.ReviveLastError = "NotPending"
		return {
			Success = false,
			Publish = true,
		}
	end

	if session.Participant == nil or player:GetAttribute("PlayerMode") ~= expectedPlayerMode then
		session.ReviveLastError = "InvalidState"
		return {
			Success = false,
			Publish = true,
		}
	end

	if not self:CanOfferRevive(session) then
		session.ReviveLastError = "LimitReached"
		return {
			Success = false,
			Publish = true,
		}
	end

	if self._walletService == nil or self._walletService.trySpendBolts == nil then
		session.ReviveLastError = "WalletUnavailable"
		return {
			Success = false,
			Publish = true,
		}
	end

	local cost = self:GetReviveCost(session)
	local spent = self._walletService.trySpendBolts(player, cost, "BattleArenaRevive")

	if not spent then
		session.ReviveLastError = "NotEnoughBolts"
		session.ReviveCost = cost
		return {
			Success = false,
			Publish = true,
		}
	end

	session.ReviveCount = math.max(0, math.floor(tonumber(session.ReviveCount) or 0)) + 1
	session.ReviveCost = 0
	session.ReviveLastError = ""

	return {
		Success = true,
		RestoreHpPercent = self:GetReviveRestoreHpPercent(),
	}
end

function ArenaReviveService:TryConsumeFreeRespawn(session, player, expectedPlayerMode)
	if not self:_isValidPlayerSession(session, player) then
		return {
			Success = false,
			Publish = false,
		}
	end

	if session.FreeRespawnPending ~= true
		or session.Participant == nil
		or player:GetAttribute("PlayerMode") ~= expectedPlayerMode
	then
		session.FreeRespawnLastError = "InvalidState"
		return {
			Success = false,
			Publish = true,
		}
	end

	if not self:CanOfferFreeRespawn(session) then
		session.FreeRespawnLastError = "Unavailable"
		return {
			Success = false,
			Publish = true,
		}
	end

	return {
		Success = true,
		ResetRun = self:ShouldFreeRespawnResetRun(),
		RestoreHpPercent = self:GetFreeRespawnRestoreHpPercent(),
	}
end

return ArenaReviveService
