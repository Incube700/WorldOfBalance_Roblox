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
}

local callbacks = {
	onGameStateChanged = nil,
	onRoundReset = nil,
	onDestroyAllProjectiles = nil,
	onConfigureParticipants = nil,
	onRestoreColors = nil,
	onResetCombatAttributes = nil,
	onApplySpawn = nil,
	getSpawnTransforms = nil,
}

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

function RoundMatchService.updateMatchMode()
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
	root:SetAttribute("PlayerWins", matchState.PlayerWins)
	root:SetAttribute("DummyWins", matchState.DummyWins)
	root:SetAttribute("RoundNumber", matchState.RoundNumber)
	root:SetAttribute("TargetWins", matchState.TargetWins)
	root:SetAttribute("MatchEnded", matchState.MatchEnded)
	root:SetAttribute("MatchResult", matchState.MatchResult)
end

function RoundMatchService.resetMatchState()
	matchState.PlayerWins = 0
	matchState.DummyWins = 0
	matchState.RoundNumber = 1
	matchState.TargetWins = MATCH_TARGET_WINS
	matchState.MatchEnded = false
	matchState.MatchResult = ""

	MatchStatsService.resetRuntimeMatchStats()
	RoundMatchService.setMatchAttributes()
end

local function printMatchScore(prefix)
	print(
		prefix
			.. " round="
			.. matchState.RoundNumber
			.. " score=Player "
			.. matchState.PlayerWins
			.. " / Dummy "
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

	if MATCH_SERIES_ENABLED then
		if result == RoundMatchService.ROUND_RESULT_WIN then
			matchState.PlayerWins += 1
		elseif result == RoundMatchService.ROUND_RESULT_LOSE then
			matchState.DummyWins += 1
		end

		if matchState.PlayerWins >= matchState.TargetWins then
			matchState.MatchEnded = true
			matchState.MatchResult = RoundMatchService.MATCH_RESULT_PLAYER_WIN
		elseif matchState.DummyWins >= matchState.TargetWins then
			matchState.MatchEnded = true
			matchState.MatchResult = RoundMatchService.MATCH_RESULT_DUMMY_WIN
		end
	end

	MatchStatsService.recordRoundStats(result, RoundMatchService.ROUND_RESULT_WIN, RoundMatchService.ROUND_RESULT_LOSE)

	if matchState.MatchEnded then
		MatchStatsService.setMatchStat("StatsMatchResult", matchState.MatchResult)

		for _, participant in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
			if participant.OwnerPlayer ~= nil then
				MatchStatsService.persistFinalMatchStats(participant, matchState.MatchResult)
			end
		end
	end

	RoundMatchService.setMatchAttributes()

	if matchState.MatchEnded then
		RoundMatchService.setGameState(RoundMatchService.GAME_STATE_RESULT)
		if callbacks.onDestroyAllProjectiles then
			task.defer(callbacks.onDestroyAllProjectiles)
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

	if callbacks.getSpawnTransforms and callbacks.onApplySpawn then
		local transforms = callbacks.getSpawnTransforms()
		
		local playerParticipant = TankParticipantRegistry.getParticipantById("PlayerTankPrototype")
		local player2Participant = TankParticipantRegistry.getParticipantById("Player2TankPrototype")
		local dummyParticipant = TankParticipantRegistry.getParticipantById("DummyTank")
		
		if playerParticipant then
			callbacks.onApplySpawn(playerParticipant, transforms.Player)
		end

		if matchMode == RoundMatchService.MATCH_MODE_PVP then
			if player2Participant then
				callbacks.onApplySpawn(player2Participant, transforms.Player2)
			end
		else
			if dummyParticipant then
				callbacks.onApplySpawn(dummyParticipant, transforms.Dummy)
			end
		end
	end

	print("[ROUND] reset")
end

function RoundMatchService.startNewMatch()
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

	if callbacks.getSpawnTransforms and callbacks.onApplySpawn then
		local transforms = callbacks.getSpawnTransforms()
		
		local playerParticipant = TankParticipantRegistry.getParticipantById("PlayerTankPrototype")
		local player2Participant = TankParticipantRegistry.getParticipantById("Player2TankPrototype")
		local dummyParticipant = TankParticipantRegistry.getParticipantById("DummyTank")
		
		if playerParticipant then
			callbacks.onApplySpawn(playerParticipant, transforms.Player)
		end

		if matchMode == RoundMatchService.MATCH_MODE_PVP then
			if player2Participant then
				callbacks.onApplySpawn(player2Participant, transforms.Player2)
			end
		else
			if dummyParticipant then
				callbacks.onApplySpawn(dummyParticipant, transforms.Dummy)
			end
		end
	end

	RoundMatchService.setGameState(RoundMatchService.GAME_STATE_PLAYING)
	print("[SERVER] Match started -> Playing mode=" .. matchMode)
end

return RoundMatchService
