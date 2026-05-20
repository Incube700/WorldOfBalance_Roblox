local HudVisibilityRules = {}

local MODE_IN_MATCH = "InMatch"
local MODE_LOBBY = "Lobby"
local MODE_RESULT = "Result"
local MODE_IN_BATTLE_ARENA = "InBattleArena"
local MODE_ARENA_RESPAWNING = "ArenaRespawning"
local MATCH_MODE_DUEL = "PvP"
local MATCH_MODE_TRAINING = "Training"

local function getWorldHealthBarsConfig(hudConfig)
	return (hudConfig ~= nil and hudConfig.WorldHealthBars) or {}
end

local function getCombatHudConfig(hudConfig)
	return (hudConfig ~= nil and hudConfig.CombatHud) or {}
end

local function getContext(contextOrPlayerMode, isMobile, hudConfig, matchMode)
	if typeof(contextOrPlayerMode) == "table" then
		return contextOrPlayerMode
	end

	return {
		PlayerMode = contextOrPlayerMode,
		IsMobile = isMobile == true,
		HudConfig = hudConfig,
		MatchMode = matchMode,
	}
end

function HudVisibilityRules.ShouldShowLegacyHpPanels(contextOrPlayerMode, isMobile, hudConfig, matchMode)
	local context = getContext(contextOrPlayerMode, isMobile, hudConfig, matchMode)
	local worldHealthBarsConfig = getWorldHealthBarsConfig(context.HudConfig)

	if worldHealthBarsConfig.Enabled ~= true then
		return true
	end

	local playerMode = context.PlayerMode

	if playerMode == MODE_IN_BATTLE_ARENA or playerMode == MODE_ARENA_RESPAWNING then
		return worldHealthBarsConfig.HideTopHpPanelsInBattleArena ~= true
	end

	if context.IsMobile == true and worldHealthBarsConfig.HideTopHpPanelsOnMobile == true then
		return false
	end

	if playerMode == MODE_IN_MATCH and context.MatchMode == MATCH_MODE_DUEL then
		return worldHealthBarsConfig.HideTopHpPanelsInDuel ~= true
	end

	if playerMode == MODE_IN_MATCH and context.MatchMode == MATCH_MODE_TRAINING then
		return worldHealthBarsConfig.HideTopHpPanelsInTraining ~= true
	end

	return true
end

function HudVisibilityRules.ShouldShowLegacyReloadPanel(contextOrPlayerMode, isMobile, hudConfig, matchMode)
	local context = getContext(contextOrPlayerMode, isMobile, hudConfig, matchMode)
	local worldHealthBarsConfig = getWorldHealthBarsConfig(context.HudConfig)
	local combatHudConfig = getCombatHudConfig(context.HudConfig)

	if worldHealthBarsConfig.Enabled ~= true or worldHealthBarsConfig.ShowReloadBar ~= true then
		return true
	end

	if combatHudConfig.HideLargeReloadPanelWhenWorldReloadEnabled == false then
		return true
	end

	local playerMode = context.PlayerMode

	if playerMode == MODE_IN_MATCH
		or playerMode == MODE_IN_BATTLE_ARENA
		or playerMode == MODE_ARENA_RESPAWNING
	then
		return false
	end

	return context.IsMobile ~= true
end

function HudVisibilityRules.ShouldShowRoundScore(contextOrPlayerMode)
	local context = getContext(contextOrPlayerMode)

	return context.PlayerMode == MODE_IN_MATCH
end

function HudVisibilityRules.ShouldShowResultPanel(contextOrPlayerMode)
	local context = getContext(contextOrPlayerMode)

	return context.PlayerMode == MODE_IN_MATCH or context.PlayerMode == MODE_RESULT
end

function HudVisibilityRules.ShouldShowResult(contextOrPlayerMode)
	return HudVisibilityRules.ShouldShowResultPanel(contextOrPlayerMode)
end

function HudVisibilityRules.ShouldShowBattleArenaStats(contextOrPlayerMode)
	local context = getContext(contextOrPlayerMode)
	local playerMode = context.PlayerMode

	return playerMode == MODE_IN_BATTLE_ARENA or playerMode == MODE_ARENA_RESPAWNING
end

function HudVisibilityRules.ShouldUseCompactMobileStats(contextOrPlayerMode)
	local context = getContext(contextOrPlayerMode)

	return context.IsMobile == true
end

function HudVisibilityRules.ShouldHideHudInLobby(contextOrPlayerMode)
	local context = getContext(contextOrPlayerMode)

	return context.PlayerMode == nil or context.PlayerMode == MODE_LOBBY
end

return HudVisibilityRules
