local RoundMatchService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
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

RoundMatchService.ROUND_STATE_PLAYING = "Playing"
RoundMatchService.ROUND_STATE_ROUND_END = "RoundEnd"
RoundMatchService.ROUND_STATE_MATCH_END = "MatchEnd"

RoundMatchService.MATCH_MODE_TRAINING = "Training"
RoundMatchService.MATCH_MODE_PVP = "PvP"

local MATCH_SERIES_ENABLED = MatchConfig.EnableMatchSeries == true
local MATCH_TARGET_WINS = math.max(1, math.floor(tonumber(MatchConfig.TargetWins) or 3))
local ROUND_RESET_DELAY = math.max(0, tonumber(MatchConfig.RoundResetDelay) or 0)
local MATCH_RESULT_DELAY = math.max(0, tonumber(MatchConfig.MatchResultDelay) or ROUND_RESET_DELAY)

local root = nil
local gameState = RoundMatchService.GAME_STATE_MENU
local matchMode = RoundMatchService.MATCH_MODE_TRAINING
local lastLoggedMatchMode = nil

local roundState = {
	Ended = false,
	State = RoundMatchService.ROUND_STATE_PLAYING,
	Result = RoundMatchService.ROUND_RESULT_PLAYING,
	WinnerTankId = "",
	LoserTankId = "",
	WinnerSide = "",
	ResetAt = 0,
	MatchResultAt = 0,
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
local matchResultReadyAt = 0
local roundResetToken = 0
local matchResultToken = 0
local lastResetDelayLogTime = 0
local isRoundResetting = false
local lastRoundResetCompletedAt = 0
local ROUND_RESET_REENTRY_GUARD_SECONDS = 0.25

local callbacks = {
	onGameStateChanged = nil,
	onRoundReset = nil,
	onDestroyAllProjectiles = nil,
	onConfigureParticipants = nil,
	onRestoreColors = nil,
	onResetCombatAttributes = nil,
	onApplySpawn = nil,
	getSpawnTransforms = nil,
	onFinalMatchRewards = nil,
	onMatchEnded = nil,
	getDefaultPlayerParticipant = nil,
	getDefaultDuelOpponentParticipant = nil,
	getDefaultTrainingOpponentParticipant = nil,
}

local function getPlayerSideParticipant()
	if activeMatch ~= nil and activeMatch.PlayerParticipant ~= nil then
		return activeMatch.PlayerParticipant
	end

	if callbacks.getDefaultPlayerParticipant ~= nil then
		return callbacks.getDefaultPlayerParticipant()
	end

	return nil
end

local function getOpponentSideParticipant()
	if activeMatch ~= nil and activeMatch.OpponentParticipant ~= nil then
		return activeMatch.OpponentParticipant
	end

	if matchMode == RoundMatchService.MATCH_MODE_PVP then
		if callbacks.getDefaultDuelOpponentParticipant ~= nil then
			return callbacks.getDefaultDuelOpponentParticipant()
		end

		return nil
	end

	if callbacks.getDefaultTrainingOpponentParticipant ~= nil then
		return callbacks.getDefaultTrainingOpponentParticipant()
	end

	return nil
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

local function getServerTimeNow()
	local success, serverTime = pcall(function()
		return Workspace:GetServerTimeNow()
	end)

	if success and typeof(serverTime) == "number" then
		return serverTime
	end

	return os.clock()
end

local function getParticipantSide(participant)
	if participant == nil then
		return ""
	end

	if participant == getPlayerSideParticipant() then
		return "PlayerSide"
	end

	if participant == getOpponentSideParticipant() then
		return "OpponentSide"
	end

	return ""
end

local function getParticipantSideByTankId(tankId)
	if tankId == nil or tankId == "" then
		return ""
	end

	return getParticipantSide(TankParticipantRegistry.getParticipantById(tankId))
end

local function setActiveMatchParticipantsControllable(isControllable)
	for _, participant in ipairs(getActiveMatchParticipants()) do
		TankParticipantRegistry.setParticipantControllable(participant, isControllable)
	end
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
	RoundMatchService.setRoundResult(RoundMatchService.ROUND_RESULT_PLAYING)
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

	if participant == getPlayerSideParticipant() then
		return getOpponentSideParticipant()
	end

	return getPlayerSideParticipant()
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

local function publishRoundAttributes()
	root:SetAttribute("RoundResult", roundState.Result)
	root:SetAttribute("RoundEnded", roundState.Ended)
	root:SetAttribute("RoundState", roundState.State)
	root:SetAttribute("RoundWinner", roundState.WinnerSide)
	root:SetAttribute("RoundWinnerTankId", roundState.WinnerTankId)
	root:SetAttribute("RoundLoserTankId", roundState.LoserTankId)
	root:SetAttribute("RoundResetAt", roundState.ResetAt)
	root:SetAttribute("MatchResultAt", roundState.MatchResultAt)
	root:SetAttribute(
		"NextRoundStartsIn",
		roundState.State == RoundMatchService.ROUND_STATE_ROUND_END and ROUND_RESET_DELAY or 0
	)
	root:SetAttribute(
		"ResultStartsIn",
		roundState.State == RoundMatchService.ROUND_STATE_MATCH_END and MATCH_RESULT_DELAY or 0
	)
end

function RoundMatchService.setRoundResult(result)
	roundState.Result = result
	roundState.Ended = result ~= RoundMatchService.ROUND_RESULT_PLAYING

	if result == RoundMatchService.ROUND_RESULT_PLAYING then
		roundState.State = RoundMatchService.ROUND_STATE_PLAYING
		roundState.WinnerTankId = ""
		roundState.LoserTankId = ""
		roundState.WinnerSide = ""
		roundState.ResetAt = 0
		roundState.MatchResultAt = 0
	end

	publishRoundAttributes()
end

function RoundMatchService.setMatchAttributes()
	root:SetAttribute("MatchMode", matchMode)
	root:SetAttribute("ActiveMatchId", activeMatch ~= nil and activeMatch.MatchId or nil)
	root:SetAttribute("PlayerSideTankId", getPlayerSideParticipant() ~= nil and getPlayerSideParticipant().TankId or "")
	root:SetAttribute("OpponentSideTankId", getOpponentSideParticipant() ~= nil and getOpponentSideParticipant().TankId or "")
	root:SetAttribute("PlayerWins", matchState.PlayerWins)
	root:SetAttribute("DummyWins", matchState.DummyWins)
	root:SetAttribute("PlayerSideScore", matchState.PlayerWins)
	root:SetAttribute("OpponentSideScore", matchState.DummyWins)
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

local function scheduleRoundReset()
	roundResetToken += 1
	local token = roundResetToken

	task.delay(ROUND_RESET_DELAY, function()
		if token ~= roundResetToken then
			return
		end

		if gameState ~= RoundMatchService.GAME_STATE_PLAYING
			or roundState.State ~= RoundMatchService.ROUND_STATE_ROUND_END
			or roundState.Ended ~= true
			or matchState.MatchEnded == true
		then
			return
		end

		RoundMatchService.resetRound()
	end)
end

local function publishFullMatchResult(matchId, token)
	if token ~= matchResultToken then
		return
	end

	if activeMatch == nil
		or activeMatch.MatchId ~= matchId
		or matchState.MatchEnded ~= true
		or roundState.State ~= RoundMatchService.ROUND_STATE_MATCH_END
		or gameState ~= RoundMatchService.GAME_STATE_PLAYING
	then
		return
	end

	RoundMatchService.setGameState(RoundMatchService.GAME_STATE_RESULT)

	if callbacks.onDestroyAllProjectiles then
		task.defer(callbacks.onDestroyAllProjectiles)
	end

	if callbacks.onMatchEnded then
		task.defer(callbacks.onMatchEnded, activeMatch, matchState)
	end
end

local function scheduleFullMatchResult()
	matchResultToken += 1
	local token = matchResultToken
	local matchId = activeMatch ~= nil and activeMatch.MatchId or nil

	task.delay(MATCH_RESULT_DELAY, function()
		publishFullMatchResult(matchId, token)
	end)
end

function RoundMatchService.endRound(result)
	if roundState.Ended then
		return
	end

	roundState.Result = result
	roundState.Ended = true

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

	roundState.WinnerSide = getParticipantSideByTankId(roundState.WinnerTankId)
	setActiveMatchParticipantsControllable(false)

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

		if callbacks.onFinalMatchRewards then
			callbacks.onFinalMatchRewards(activeMatch, matchState)
		end
	end

	RoundMatchService.setMatchAttributes()

	if matchState.MatchEnded then
		roundState.State = RoundMatchService.ROUND_STATE_MATCH_END
		roundState.ResetAt = 0
		roundState.MatchResultAt = getServerTimeNow() + MATCH_RESULT_DELAY
		roundResetReadyAt = 0
		matchResultReadyAt = os.clock() + MATCH_RESULT_DELAY

		if activeMatch ~= nil then
			activeMatch.IsFinished = true
		end

		scheduleFullMatchResult()
	else
		roundState.State = RoundMatchService.ROUND_STATE_ROUND_END
		roundState.ResetAt = getServerTimeNow() + ROUND_RESET_DELAY
		roundState.MatchResultAt = 0
		roundResetReadyAt = os.clock() + ROUND_RESET_DELAY
		matchResultReadyAt = 0
		scheduleRoundReset()
	end

	publishRoundAttributes()
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

	if matchState.MatchEnded then
		return
	end

	local now = os.clock()

	if isRoundResetting then
		return
	end

	if not roundState.Ended and now - lastRoundResetCompletedAt < ROUND_RESET_REENTRY_GUARD_SECONDS then
		return
	end

	if roundState.Ended and now < roundResetReadyAt then
		if now - lastResetDelayLogTime > 0.5 then
			lastResetDelayLogTime = now
			print("[ROUND] reset delayed for VFX")
		end

		return
	end

	isRoundResetting = true

	roundResetToken += 1
	matchResultToken += 1
	roundResetReadyAt = 0
	matchResultReadyAt = 0

	if callbacks.onDestroyAllProjectiles then
		callbacks.onDestroyAllProjectiles()
	end
	
	if callbacks.onConfigureParticipants then
		callbacks.onConfigureParticipants()
	end

	if roundState.Ended then
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
	lastRoundResetCompletedAt = os.clock()
	isRoundResetting = false
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
	roundResetToken += 1
	matchResultToken += 1
	roundResetReadyAt = 0
	matchResultReadyAt = 0
	isRoundResetting = false
	lastRoundResetCompletedAt = 0
	RoundMatchService.setRoundResult(RoundMatchService.ROUND_RESULT_PLAYING)
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

	roundResetToken += 1
	matchResultToken += 1
	roundResetReadyAt = 0
	matchResultReadyAt = 0
	isRoundResetting = false
	lastRoundResetCompletedAt = 0

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
