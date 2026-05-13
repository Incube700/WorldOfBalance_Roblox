local RoundMatchService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local MatchConfig = require(configs:WaitForChild("MatchConfig"))

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local MatchStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("MatchStatsService"))

RoundMatchService.ROUND_RESULT_PLAYING = "Playing"
RoundMatchService.ROUND_RESULT_WIN = "Win"
RoundMatchService.ROUND_RESULT_LOSE = "Lose"

RoundMatchService.MATCH_RESULT_PLAYER_WIN = "PlayerMatchWin"
RoundMatchService.MATCH_RESULT_DUMMY_WIN = "DummyMatchWin"

RoundMatchService.GAME_STATE_MENU = "Menu"
RoundMatchService.GAME_STATE_PLAYING = "Playing"
RoundMatchService.GAME_STATE_RESULT = "Result"

RoundMatchService.MATCH_MODE_TRAINING = "Training"
RoundMatchService.MATCH_MODE_PVP = "PvP"

local MATCH_SERIES_ENABLED = MatchConfig.EnableMatchSeries == true
local MATCH_TARGET_WINS = math.max(1, math.floor(tonumber(MatchConfig.TargetWins) or 3))
local ROUND_RESET_DELAY = math.max(0, tonumber(MatchConfig.RoundResetDelay) or 0)

local root = nil
local gameState = RoundMatchService.GAME_STATE_MENU
local matchMode = RoundMatchService.MATCH_MODE_TRAINING
local lastLoggedMatchMode = nil

local roundState = {
	Ended = false,
	Result = RoundMatchService.ROUND_RESULT_PLAYING,
	WinnerTankId = "",
	LoserTankId = "",
}

local matchState = {
	PlayerWins = 0,
	DummyWins = 0,
	RoundNumber = 1,
	TargetWins = MATCH_TARGET_WINS,
	MatchEnded = false,
	MatchResult = "",
	MatchWinnerTankId = "",
	MatchLoserTankId = "",
}

local activeMatch = nil
local roundResetReadyAt = 0
local lastResetDelayLogTime = 0

local callbacks = {
	onGameStateChanged = nil,
	onRoundReset = nil,
	onDestroyAllProjectiles = nil,
	onConfigureParticipants = nil,
	onRestoreColors = nil,
	onResetCombatAttributes = nil,
	onApplySpawn = nil,
	getSpawnTransforms = nil,
	onMatchEnded = nil,
}

local function getPlayerSideParticipant()
	if activeMatch ~= nil and activeMatch.PlayerParticipant ~= nil then
		return activeMatch.PlayerParticipant
	end

	return TankParticipantRegistry.getParticipantById("PlayerTankPrototype")
end

local function getOpponentSideParticipant()
	if activeMatch ~= nil and activeMatch.OpponentParticipant ~= nil then
		return activeMatch.OpponentParticipant
	end

	if matchMode == RoundMatchService.MATCH_MODE_PVP then
		return TankParticipantRegistry.getParticipantById("Player2TankPrototype")
	end

	return TankParticipantRegistry.getParticipantById("DummyTank")
end

local function getActiveMatchParticipants()
	if activeMatch ~= nil and activeMatch.Participants ~= nil then
		return activeMatch.Participants
	end

	local participants = {}
	local playerSideParticipant = getPlayerSideParticipant()
	local opponentSideParticipant = getOpponentSideParticipant()

	if playerSideParticipant ~= nil then
		table.insert(participants, playerSideParticipant)
	end

	if opponentSideParticipant ~= nil then
		table.insert(participants, opponentSideParticipant)
	end

	return participants
end

local function applyMatchSpawns()
	if callbacks.getSpawnTransforms == nil or callbacks.onApplySpawn == nil then
		return
	end

	local transforms = callbacks.getSpawnTransforms()
	local playerSideParticipant = getPlayerSideParticipant()
	local opponentSideParticipant = getOpponentSideParticipant()

	if playerSideParticipant ~= nil then
		callbacks.onApplySpawn(playerSideParticipant, transforms.Player)
	end

	if opponentSideParticipant ~= nil then
		if matchMode == RoundMatchService.MATCH_MODE_PVP then
			callbacks.onApplySpawn(opponentSideParticipant, transforms.Player2)
		else
			callbacks.onApplySpawn(opponentSideParticipant, transforms.Dummy)
		end
	end
end

function RoundMatchService.init(orchestratorRoot, options)
	root = orchestratorRoot
	callbacks = options

	RoundMatchService.setMatchAttributes()
	RoundMatchService.setGameState(RoundMatchService.GAME_STATE_MENU)
end

function RoundMatchService.getGameState()
	return gameState
end

function RoundMatchService.setGameState(nextGameState)
	if nextGameState ~= RoundMatchService.GAME_STATE_MENU
		and nextGameState ~= RoundMatchService.GAME_STATE_PLAYING
		and nextGameState ~= RoundMatchService.GAME_STATE_RESULT
	then
		warn("[ROUND_MATCH] Ignoring unknown state " .. tostring(nextGameState))
		return
	end

	gameState = nextGameState
	root:SetAttribute("GameState", gameState)
	
	if callbacks.onGameStateChanged then
		callbacks.onGameStateChanged(gameState)
	end
end

function RoundMatchService.getMatchMode()
	return matchMode
end

function RoundMatchService.getActiveMatch()
	return activeMatch
end

function RoundMatchService.isParticipantInActiveMatch(participant)
	if participant == nil or activeMatch == nil then
		return false
	end

	for _, activeParticipant in ipairs(activeMatch.Participants or {}) do
		if activeParticipant == participant then
			return true
		end
	end

	return false
end

function RoundMatchService.getOpponentForParticipant(participant)
	if participant == nil then
		return nil
	end

	if activeMatch ~= nil then
		if participant == activeMatch.PlayerParticipant then
			return activeMatch.OpponentParticipant
		elseif participant == activeMatch.OpponentParticipant then
			return activeMatch.PlayerParticipant
		end
	end

	if participant == TankParticipantRegistry.getParticipantById("PlayerTankPrototype") then
		return getOpponentSideParticipant()
	end

	return TankParticipantRegistry.getParticipantById("PlayerTankPrototype")
end

function RoundMatchService.getRoundResultForDestroyedParticipant(participant)
	if participant == getPlayerSideParticipant() then
		return RoundMatchService.ROUND_RESULT_LOSE
	end

	return RoundMatchService.ROUND_RESULT_WIN
end

function RoundMatchService.updateMatchMode()
	if activeMatch ~= nil and activeMatch.MatchMode ~= nil then
		matchMode = activeMatch.MatchMode
		root:SetAttribute("MatchMode", matchMode)

		if lastLoggedMatchMode ~= matchMode then
			lastLoggedMatchMode = matchMode
			print("[PVP] mode = " .. matchMode)
		end

		return
	end

	local playerCount = 0
	for _, participant in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
		if participant.OwnerPlayer ~= nil then
			playerCount += 1
		end
	end

	if playerCount >= 2 then
		matchMode = RoundMatchService.MATCH_MODE_PVP
	else
		matchMode = RoundMatchService.MATCH_MODE_TRAINING
	end

	root:SetAttribute("MatchMode", matchMode)

	if lastLoggedMatchMode ~= matchMode then
		lastLoggedMatchMode = matchMode
		print("[PVP] mode = " .. matchMode)
	end
end

function RoundMatchService.setRoundResult(result)
	roundState.Result = result
	roundState.Ended = result ~= RoundMatchService.ROUND_RESULT_PLAYING

	if result == RoundMatchService.ROUND_RESULT_PLAYING then
		roundState.WinnerTankId = ""
		roundState.LoserTankId = ""
	end

	root:SetAttribute("RoundResult", result)
	root:SetAttribute("RoundEnded", roundState.Ended)
	root:SetAttribute("RoundWinnerTankId", roundState.WinnerTankId)
	root:SetAttribute("RoundLoserTankId", roundState.LoserTankId)
end

function RoundMatchService.setMatchAttributes()
	root:SetAttribute("MatchMode", matchMode)
	root:SetAttribute("ActiveMatchId", activeMatch ~= nil and activeMatch.MatchId or nil)
	root:SetAttribute("PlayerSideTankId", getPlayerSideParticipant() ~= nil and getPlayerSideParticipant().TankId or "")
	root:SetAttribute("OpponentSideTankId", getOpponentSideParticipant() ~= nil and getOpponentSideParticipant().TankId or "")
	root:SetAttribute("PlayerWins", matchState.PlayerWins)
	root:SetAttribute("DummyWins", matchState.DummyWins)
	root:SetAttribute("RoundNumber", matchState.RoundNumber)
	root:SetAttribute("TargetWins", matchState.TargetWins)
	root:SetAttribute("MatchEnded", matchState.MatchEnded)
	root:SetAttribute("MatchResult", matchState.MatchResult)
	root:SetAttribute("MatchWinnerTankId", matchState.MatchWinnerTankId)
	root:SetAttribute("MatchLoserTankId", matchState.MatchLoserTankId)
end

function RoundMatchService.resetMatchState()
	matchState.PlayerWins = 0
	matchState.DummyWins = 0
	matchState.RoundNumber = 1
	matchState.TargetWins = MATCH_TARGET_WINS
	matchState.MatchEnded = false
	matchState.MatchResult = ""
	matchState.MatchWinnerTankId = ""
	matchState.MatchLoserTankId = ""

	MatchStatsService.resetRuntimeMatchStats(activeMatch ~= nil and getActiveMatchParticipants() or nil)
	RoundMatchService.setMatchAttributes()
end

local function getOpponentTankId()
	local opponentParticipant = getOpponentSideParticipant()

	if opponentParticipant ~= nil then
		return opponentParticipant.TankId
	end

	return ""
end

local function getParticipantMatchResult(participant)
	if participant.TankId == matchState.MatchWinnerTankId then
		return RoundMatchService.ROUND_RESULT_WIN
	end

	if participant.TankId == matchState.MatchLoserTankId then
		return RoundMatchService.ROUND_RESULT_LOSE
	end

	return ""
end

local function printMatchScore(prefix)
	print(
		prefix
			.. " round="
			.. matchState.RoundNumber
			.. " score=PlayerSide "
			.. matchState.PlayerWins
			.. " / OpponentSide "
			.. matchState.DummyWins
			.. " firstTo="
			.. matchState.TargetWins
	)
end

function RoundMatchService.endRound(result)
	if roundState.Ended then
		return
	end

	RoundMatchService.setRoundResult(result)
	roundResetReadyAt = os.clock() + ROUND_RESET_DELAY

	if MATCH_SERIES_ENABLED then
		if result == RoundMatchService.ROUND_RESULT_WIN then
			matchState.PlayerWins += 1
		elseif result == RoundMatchService.ROUND_RESULT_LOSE then
			matchState.DummyWins += 1
		end

		local playerSideParticipant = getPlayerSideParticipant()
		local playerSideTankId = playerSideParticipant ~= nil and playerSideParticipant.TankId or ""
		local opponentTankId = getOpponentTankId()

		if matchState.PlayerWins >= matchState.TargetWins then
			matchState.MatchEnded = true
			matchState.MatchResult = RoundMatchService.MATCH_RESULT_PLAYER_WIN
			matchState.MatchWinnerTankId = playerSideTankId
			matchState.MatchLoserTankId = opponentTankId
		elseif matchState.DummyWins >= matchState.TargetWins then
			matchState.MatchEnded = true
			matchState.MatchResult = RoundMatchService.MATCH_RESULT_DUMMY_WIN
			matchState.MatchWinnerTankId = opponentTankId
			matchState.MatchLoserTankId = playerSideTankId
		end
	end

	MatchStatsService.recordRoundStats(
		roundState.WinnerTankId,
		roundState.LoserTankId,
		getActiveMatchParticipants()
	)

	if matchState.MatchEnded then
		MatchStatsService.setMatchStat("StatsMatchResult", matchState.MatchResult)

		for _, participant in ipairs(getActiveMatchParticipants()) do
			if participant.OwnerPlayer ~= nil then
				local participantMatchResult = getParticipantMatchResult(participant)

				if participantMatchResult ~= "" then
					MatchStatsService.setParticipantMatchResult(participant, participantMatchResult)
					MatchStatsService.persistFinalMatchStats(participant, participantMatchResult)
				end
			end
		end
	end

	RoundMatchService.setMatchAttributes()

	if matchState.MatchEnded then
		if activeMatch ~= nil then
			activeMatch.IsFinished = true
		end

		RoundMatchService.setGameState(RoundMatchService.GAME_STATE_RESULT)
		if callbacks.onDestroyAllProjectiles then
			task.defer(callbacks.onDestroyAllProjectiles)
		end

		if callbacks.onMatchEnded then
			task.defer(callbacks.onMatchEnded, activeMatch, matchState)
		end
	end

	printMatchScore("[ROUND] " .. result)

	if matchState.MatchEnded then
		print("[MATCH] " .. matchState.MatchResult)
	end
end

function RoundMatchService.getRoundState()
	return roundState
end

function RoundMatchService.resetRound()
	if gameState ~= RoundMatchService.GAME_STATE_PLAYING then
		return
	end

	if roundState.Ended and os.clock() < roundResetReadyAt then
		if os.clock() - lastResetDelayLogTime > 0.5 then
			lastResetDelayLogTime = os.clock()
			print("[ROUND] reset delayed for VFX")
		end

		return
	end

	if callbacks.onDestroyAllProjectiles then
		callbacks.onDestroyAllProjectiles()
	end
	
	if callbacks.onConfigureParticipants then
		callbacks.onConfigureParticipants()
	end

	if matchState.MatchEnded then
		RoundMatchService.resetMatchState()
		print("[MATCH] reset")
	elseif roundState.Ended then
		matchState.RoundNumber += 1
		RoundMatchService.setMatchAttributes()
	else
		print("[ROUND] current round reset")
	end

	if callbacks.onRestoreColors then
		callbacks.onRestoreColors()
	end
	
	if callbacks.onResetCombatAttributes then
		callbacks.onResetCombatAttributes()
	end

	applyMatchSpawns()

	print("[ROUND] reset")
end

function RoundMatchService.setActivePvPMatch(matchId, playerSideParticipant, opponentParticipant)
	activeMatch = {
		MatchId = matchId,
		MatchMode = RoundMatchService.MATCH_MODE_PVP,
		PlayerParticipant = playerSideParticipant,
		OpponentParticipant = opponentParticipant,
		Participants = { playerSideParticipant, opponentParticipant },
		IsDuel = true,
		IsFinished = false,
	}
	matchMode = RoundMatchService.MATCH_MODE_PVP
	RoundMatchService.setMatchAttributes()
end

function RoundMatchService.setActiveTrainingMatch(matchId, playerSideParticipant, dummyParticipant)
	activeMatch = {
		MatchId = matchId,
		MatchMode = RoundMatchService.MATCH_MODE_TRAINING,
		PlayerParticipant = playerSideParticipant,
		OpponentParticipant = dummyParticipant,
		Participants = { playerSideParticipant, dummyParticipant },
		IsDuel = false,
		IsFinished = false,
	}
	matchMode = RoundMatchService.MATCH_MODE_TRAINING
	RoundMatchService.setMatchAttributes()
end

function RoundMatchService.clearActiveMatch(matchId)
	if activeMatch == nil then
		return
	end

	if matchId ~= nil and activeMatch.MatchId ~= matchId then
		return
	end

	activeMatch = nil
	RoundMatchService.setMatchAttributes()
end

function RoundMatchService.startPvPMatch(matchId, playerSideParticipant, opponentParticipant)
	RoundMatchService.setActivePvPMatch(matchId, playerSideParticipant, opponentParticipant)
	RoundMatchService.startNewMatch()
end

function RoundMatchService.startTrainingMatch(matchId, playerSideParticipant, dummyParticipant)
	RoundMatchService.setActiveTrainingMatch(matchId, playerSideParticipant, dummyParticipant)
	RoundMatchService.startNewMatch()
end

function RoundMatchService.startNewMatch()
	if activeMatch ~= nil then
		activeMatch.IsFinished = false
	end

	roundResetReadyAt = 0

	if callbacks.onDestroyAllProjectiles then
		callbacks.onDestroyAllProjectiles()
	end
	
	if callbacks.onConfigureParticipants then
		callbacks.onConfigureParticipants()
	end
	
	RoundMatchService.resetMatchState()

	if callbacks.onRestoreColors then
		callbacks.onRestoreColors()
	end
	
	if callbacks.onResetCombatAttributes then
		callbacks.onResetCombatAttributes()
	end

	applyMatchSpawns()

	RoundMatchService.setGameState(RoundMatchService.GAME_STATE_PLAYING)
	print("[SERVER] Match started -> Playing mode=" .. matchMode)
end

return RoundMatchService
