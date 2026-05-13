local LobbyService = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))

LobbyService.MODE_LOBBY = "Lobby"
LobbyService.MODE_QUEUED_FOR_DUEL = "QueuedForDuel"
LobbyService.MODE_IN_MATCH = "InMatch"
LobbyService.MODE_RESULT = "Result"

local root = nil
local tankSpawnResetService = nil
local roundMatchService = nil
local projectileService = nil
local dummyParticipant = nil

local queuedPlayers = {}
local queuedByPlayer = {}
local completedMatchesById = {}
local rematchVotesByMatchId = {}
local spawnIndexByUserId = {}
local nextSpawnIndex = 1
local elapsedSincePadPoll = 0
local duelCountdownRemaining = nil
local duelCountdownPlayers = nil

local PAD_POLL_INTERVAL = 0.12
local DUEL_QUEUE_REQUIRED = 2
local DUEL_COUNTDOWN_SECONDS = 3
local DUEL_STATE_IDLE = "Idle"
local DUEL_STATE_WAITING = "Waiting"
local DUEL_STATE_COUNTDOWN = "Countdown"

local function getPlayerFromParticipant(participant)
	return participant ~= nil and participant.OwnerPlayer or nil
end

local function getMode(player)
	return player ~= nil and player:GetAttribute("PlayerMode") or nil
end

local function getParticipantMode(participant)
	if participant == nil then
		return nil
	end

	return participant.ParticipantState
end

local function getLobby()
	return root ~= nil and root:FindFirstChild("Lobby") or nil
end

local function getDuelPad()
	local lobby = getLobby()
	local duelPad = lobby ~= nil and lobby:FindFirstChild("DuelPad") or nil

	if duelPad ~= nil and duelPad:IsA("BasePart") then
		return duelPad
	end

	return nil
end

local function setDuelPadAttributes(queueCount, duelState, countdown)
	local lobby = getLobby()
	local duelPad = getDuelPad()
	local attributes = {
		DuelQueueCount = math.max(0, queueCount or 0),
		DuelQueueRequired = DUEL_QUEUE_REQUIRED,
		DuelCountdown = math.max(0, countdown or 0),
		DuelState = duelState or DUEL_STATE_IDLE,
	}

	for _, instance in ipairs({ root, lobby, duelPad }) do
		if instance ~= nil then
			for attributeName, value in pairs(attributes) do
				instance:SetAttribute(attributeName, value)
			end
		end
	end
end

local function getLobbySpawnParts()
	local lobby = getLobby()
	local spawnFolder = lobby ~= nil and lobby:FindFirstChild("SpawnPoints") or nil
	local spawnParts = {}

	if spawnFolder ~= nil then
		for _, child in ipairs(spawnFolder:GetChildren()) do
			if child:IsA("BasePart") and string.match(child.Name, "^LobbySpawn%d+$") ~= nil then
				table.insert(spawnParts, child)
			end
		end
	end

	table.sort(spawnParts, function(a, b)
		return a.Name < b.Name
	end)

	return spawnParts
end

local function getYawFromLookVector(lookVector)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLook.Magnitude < 0.001 then
		return 0
	end

	local unit = flatLook.Unit
	return math.atan2(-unit.X, -unit.Z)
end

local function makeSpawnTransform(position, yaw, source)
	return {
		Position = position,
		BodyYaw = yaw,
		TurretYaw = yaw,
		Source = source,
	}
end

local function getFallbackLobbySpawnTransform(player)
	local userOffset = 0

	if player ~= nil then
		userOffset = math.abs(player.UserId % 8)
	end

	local angle = (math.pi * 2) * (userOffset / 8)
	local radius = 34 + math.floor(nextSpawnIndex / 8) * 14
	local position = Vector3.new(math.cos(angle) * radius, 0, 130 + math.sin(angle) * radius)

	return makeSpawnTransform(position, math.pi, "LobbyFallback")
end

local function getLobbySpawnTransform(player)
	local spawnParts = getLobbySpawnParts()

	if #spawnParts == 0 then
		return getFallbackLobbySpawnTransform(player)
	end

	local assignedIndex = spawnIndexByUserId[player.UserId]

	if assignedIndex == nil then
		assignedIndex = nextSpawnIndex
		spawnIndexByUserId[player.UserId] = assignedIndex
		nextSpawnIndex += 1
	end

	local spawnPart = spawnParts[((assignedIndex - 1) % #spawnParts) + 1]
	local cycle = math.floor((assignedIndex - 1) / #spawnParts)
	local offset = Vector3.new(cycle * 18, 0, cycle * 18)

	return makeSpawnTransform(spawnPart.Position + offset, getYawFromLookVector(spawnPart.CFrame.LookVector), spawnPart.Name)
end

local function setPlayerMode(player, participant, mode, matchId, opponentTankId)
	if player ~= nil then
		local previousMode = player:GetAttribute("PlayerMode")

		player:SetAttribute("PlayerMode", mode)
		player:SetAttribute("MatchId", matchId)
		player:SetAttribute("TankId", participant ~= nil and participant.TankId or nil)
		player:SetAttribute("OpponentTankId", opponentTankId)

		if previousMode ~= mode then
			print("[LOBBY] player mode " .. player.Name .. " -> " .. mode)
		end
	end

	TankParticipantRegistry.setParticipantMatchState(participant, mode, matchId, opponentTankId)
end

local function resetRematchStatus(player)
	if player ~= nil then
		player:SetAttribute("RematchStatus", "")
	end
end

local function setRematchStatus(player, status)
	if player ~= nil then
		player:SetAttribute("RematchStatus", status)
	end
end

local function getMatchParticipants(matchId)
	local completedMatch = completedMatchesById[matchId]

	if completedMatch ~= nil then
		return completedMatch.Participants
	end

	local activeMatch = roundMatchService ~= nil and roundMatchService.getActiveMatch() or nil

	if activeMatch ~= nil and activeMatch.MatchId == matchId then
		return activeMatch.Participants
	end

	return nil
end

local function clearQueuedPlayer(player, reason)
	if player == nil or queuedByPlayer[player] ~= true then
		return
	end

	if duelCountdownPlayers ~= nil then
		for _, countdownPlayer in ipairs(duelCountdownPlayers) do
			if countdownPlayer == player then
				duelCountdownRemaining = nil
				duelCountdownPlayers = nil
				print("[LOBBY] duel countdown cancelled reason=" .. tostring(reason or "QueueChanged"))
				break
			end
		end
	end

	queuedByPlayer[player] = nil

	for index = #queuedPlayers, 1, -1 do
		if queuedPlayers[index] == player then
			table.remove(queuedPlayers, index)
		end
	end

	local participant = TankParticipantRegistry.getPlayerParticipant(player)

	if participant ~= nil and getParticipantMode(participant) == LobbyService.MODE_QUEUED_FOR_DUEL then
		setPlayerMode(player, participant, LobbyService.MODE_LOBBY, nil, nil)
	end

	if reason ~= nil then
		print("[LOBBY] player left duel queue " .. player.Name)
	end
end

local function clearQueuedPlayersExcept(keptPlayers, reason)
	local kept = {}

	for _, player in ipairs(keptPlayers or {}) do
		kept[player] = true
	end

	for index = #queuedPlayers, 1, -1 do
		local player = queuedPlayers[index]

		if kept[player] ~= true then
			clearQueuedPlayer(player, reason)
		end
	end
end

local function resetParticipantForLobby(participant)
	if participant == nil then
		return
	end

	TankParticipantRegistry.setParticipantModelVisible(participant, true)
	TankParticipantRegistry.resetParticipantHealth(participant)
end

function LobbyService.spawnPlayerInLobby(player, participant)
	if player == nil or participant == nil then
		return
	end

	resetParticipantForLobby(participant)
	tankSpawnResetService.applySpawnToParticipant(participant, getLobbySpawnTransform(player))
	print("[LOBBY] player spawned in lobby " .. player.Name .. " -> " .. participant.TankId)
end

local function returnParticipantsToLobby(matchId, reason)
	local participants = getMatchParticipants(matchId)

	if participants == nil then
		return
	end

	if rematchVotesByMatchId[matchId] ~= nil then
		print("[REMATCH] cancelled reason=" .. reason .. " matchId=" .. tostring(matchId))
	end

	rematchVotesByMatchId[matchId] = nil

	if projectileService ~= nil then
		projectileService.destroyAllProjectiles()
	end

	for _, participant in ipairs(participants) do
		local player = getPlayerFromParticipant(participant)

		if player ~= nil and player.Parent == Players then
			resetRematchStatus(player)
			setPlayerMode(player, participant, LobbyService.MODE_LOBBY, nil, nil)
			LobbyService.spawnPlayerInLobby(player, participant)
		else
			TankParticipantRegistry.setParticipantMatchState(participant, nil, nil, nil)

			if participant.IsPlayerTank ~= true then
				TankParticipantRegistry.setParticipantModelVisible(participant, false)
			end
		end
	end

	completedMatchesById[matchId] = nil

	if roundMatchService ~= nil then
		roundMatchService.clearActiveMatch(matchId)
		roundMatchService.setGameState(roundMatchService.GAME_STATE_MENU)
	end
end

local function startDuel(playerA, participantA, playerB, participantB, matchId)
	matchId = matchId or ("Duel_" .. string.gsub(HttpService:GenerateGUID(false), "-", ""))

	clearQueuedPlayer(playerA)
	clearQueuedPlayer(playerB)
	resetRematchStatus(playerA)
	resetRematchStatus(playerB)

	setPlayerMode(playerA, participantA, LobbyService.MODE_IN_MATCH, matchId, participantB.TankId)
	setPlayerMode(playerB, participantB, LobbyService.MODE_IN_MATCH, matchId, participantA.TankId)

	print("[LOBBY] duel match starting " .. playerA.Name .. " vs " .. playerB.Name .. " matchId=" .. matchId)
	roundMatchService.startPvPMatch(matchId, participantA, participantB)
end

local function startTraining(player, participant)
	if roundMatchService.getActiveMatch() ~= nil then
		print("[LOBBY] duel queue cancelled reason=ActiveMatch")
		return
	end

	if dummyParticipant == nil then
		warn("[LOBBY] Training start ignored: DummyTank participant missing")
		return
	end

	local matchId = "Training_" .. tostring(player.UserId) .. "_" .. tostring(math.floor(os.clock() * 1000))
	clearQueuedPlayer(player)
	resetRematchStatus(player)
	setPlayerMode(player, participant, LobbyService.MODE_IN_MATCH, matchId, dummyParticipant.TankId)
	TankParticipantRegistry.setParticipantMatchState(dummyParticipant, LobbyService.MODE_IN_MATCH, matchId, participant.TankId)
	roundMatchService.startTrainingMatch(matchId, participant, dummyParticipant)
end

local function participantIsOnDuelPad(participant, duelPad)
	if participant == nil or duelPad == nil or participant.Body == nil then
		return false
	end

	local localPosition = duelPad.CFrame:PointToObjectSpace(participant.Body.Position)
	local halfSize = duelPad.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function queuePlayer(player, participant)
	if queuedByPlayer[player] == true then
		return
	end

	queuedByPlayer[player] = true
	table.insert(queuedPlayers, player)
	setPlayerMode(player, participant, LobbyService.MODE_QUEUED_FOR_DUEL, nil, nil)
	print("[LOBBY] player entered duel queue " .. player.Name)
end

local function getQueuedDuelCandidates(duelPad)
	local candidates = {}

	for _, player in ipairs(queuedPlayers) do
		local participant = TankParticipantRegistry.getPlayerParticipant(player)

		if player.Parent == Players
			and participant ~= nil
			and getMode(player) == LobbyService.MODE_QUEUED_FOR_DUEL
			and participantIsOnDuelPad(participant, duelPad)
		then
			table.insert(candidates, {
				Player = player,
				Participant = participant,
			})
		end

		if #candidates >= DUEL_QUEUE_REQUIRED then
			break
		end
	end

	return candidates
end

local function sameCountdownPlayers(candidates)
	if duelCountdownPlayers == nil or #duelCountdownPlayers < DUEL_QUEUE_REQUIRED then
		return false
	end

	for index = 1, DUEL_QUEUE_REQUIRED do
		if duelCountdownPlayers[index] ~= candidates[index].Player then
			return false
		end
	end

	return true
end

local function cancelDuelCountdown(reason)
	if duelCountdownRemaining ~= nil then
		print("[LOBBY] duel countdown cancelled reason=" .. tostring(reason or "QueueChanged"))
	end

	duelCountdownRemaining = nil
	duelCountdownPlayers = nil
end

local function tryStartQueuedDuel(deltaTime, duelPad)
	if roundMatchService.getActiveMatch() ~= nil then
		cancelDuelCountdown("ActiveMatch")
		setDuelPadAttributes(#queuedPlayers, #queuedPlayers > 0 and DUEL_STATE_WAITING or DUEL_STATE_IDLE, 0)
		return
	end

	local candidates = getQueuedDuelCandidates(duelPad)

	if #candidates < DUEL_QUEUE_REQUIRED then
		cancelDuelCountdown("NotEnoughPlayers")
		setDuelPadAttributes(#queuedPlayers, #queuedPlayers > 0 and DUEL_STATE_WAITING or DUEL_STATE_IDLE, 0)
		return
	end

	if candidates[1].Participant == candidates[2].Participant then
		cancelDuelCountdown("InvalidQueuedPlayers")
		setDuelPadAttributes(#queuedPlayers, DUEL_STATE_WAITING, 0)
		return
	end

	if not sameCountdownPlayers(candidates) then
		duelCountdownRemaining = DUEL_COUNTDOWN_SECONDS
		duelCountdownPlayers = { candidates[1].Player, candidates[2].Player }
		print("[LOBBY] duel countdown started")
	else
		duelCountdownRemaining = math.max(0, (duelCountdownRemaining or DUEL_COUNTDOWN_SECONDS) - deltaTime)
	end

	setDuelPadAttributes(#queuedPlayers, DUEL_STATE_COUNTDOWN, math.ceil(duelCountdownRemaining or DUEL_COUNTDOWN_SECONDS))

	if duelCountdownRemaining == nil or duelCountdownRemaining > 0 then
		return
	end

	local playerA = candidates[1].Player
	local participantA = candidates[1].Participant
	local playerB = candidates[2].Player
	local participantB = candidates[2].Participant

	duelCountdownRemaining = nil
	duelCountdownPlayers = nil
	clearQueuedPlayersExcept({ playerA, playerB }, "DuelStarted")
	startDuel(playerA, participantA, playerB, participantB)
	setDuelPadAttributes(0, DUEL_STATE_IDLE, 0)
end

local function updateDuelPadQueue(deltaTime)
	local duelPad = getDuelPad()

	if duelPad == nil then
		cancelDuelCountdown("MissingDuelPad")
		setDuelPadAttributes(0, DUEL_STATE_IDLE, 0)
		return
	end

	for _, participant in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
		local player = getPlayerFromParticipant(participant)

		if player ~= nil then
			local mode = getMode(player)
			local eligible = mode == LobbyService.MODE_LOBBY or mode == LobbyService.MODE_QUEUED_FOR_DUEL
			local onPad = eligible and participantIsOnDuelPad(participant, duelPad)

			if onPad then
				queuePlayer(player, participant)
			elseif queuedByPlayer[player] == true then
				clearQueuedPlayer(player, "LeftPad")
			end
		end
	end

	tryStartQueuedDuel(deltaTime, duelPad)
end

function LobbyService.init(options)
	root = options.root
	tankSpawnResetService = options.tankSpawnResetService
	roundMatchService = options.roundMatchService
	projectileService = options.projectileService
	dummyParticipant = options.dummyParticipant

	setDuelPadAttributes(0, DUEL_STATE_IDLE, 0)
	print("[LOBBY] lobby free drive enabled")
	print("[LOBBY] lobby projectile no-damage mode")
end

function LobbyService.playerAssigned(player, participant)
	if player == nil or participant == nil then
		return
	end

	resetRematchStatus(player)
	setPlayerMode(player, participant, LobbyService.MODE_LOBBY, nil, nil)
	LobbyService.spawnPlayerInLobby(player, participant)
end

function LobbyService.playerRemoving(player)
	clearQueuedPlayer(player, "PlayerLeft")

	local matchId = player:GetAttribute("MatchId")

	if matchId ~= nil and matchId ~= "" then
		print("[REMATCH] cancelled reason=PlayerLeft matchId=" .. tostring(matchId))
		returnParticipantsToLobby(matchId, "PlayerLeft")
	end
end

function LobbyService.handleStartMatchRequest(player)
	local participant = TankParticipantRegistry.getPlayerParticipant(player)

	if participant == nil then
		return
	end

	if getMode(player) == LobbyService.MODE_RESULT then
		LobbyService.handleRematchRequest(player)
		return
	end

	startTraining(player, participant)
end

function LobbyService.handleReturnToLobbyRequest(player)
	local participant = TankParticipantRegistry.getPlayerParticipant(player)

	if participant == nil then
		return
	end

	local matchId = player:GetAttribute("MatchId")

	if matchId ~= nil and matchId ~= "" then
		if getMode(player) ~= LobbyService.MODE_RESULT then
			return
		end

		returnParticipantsToLobby(matchId, "ReturnToLobby")
	else
		clearQueuedPlayer(player, "ReturnToLobby")
		setPlayerMode(player, participant, LobbyService.MODE_LOBBY, nil, nil)
		LobbyService.spawnPlayerInLobby(player, participant)
	end
end

function LobbyService.handleRematchRequest(player)
	local participant = TankParticipantRegistry.getPlayerParticipant(player)

	if participant == nil then
		return
	end

	local matchId = player:GetAttribute("MatchId")

	if getMode(player) ~= LobbyService.MODE_RESULT then
		return
	end

	if matchId == nil or matchId == "" then
		startTraining(player, participant)
		return
	end

	local participants = getMatchParticipants(matchId)

	if participants == nil or #participants < 2 then
		print("[REMATCH] cancelled reason=MissingMatch matchId=" .. tostring(matchId))
		LobbyService.handleReturnToLobbyRequest(player)
		return
	end

	local participantA = participants[1]
	local participantB = participants[2]
	local activeMatch = roundMatchService.getActiveMatch()

	if activeMatch ~= nil and activeMatch.MatchId == matchId and activeMatch.IsDuel ~= true then
		roundMatchService.clearActiveMatch(matchId)
		completedMatchesById[matchId] = nil
		startTraining(player, participant)
		return
	end

	local playerA = getPlayerFromParticipant(participantA)
	local playerB = getPlayerFromParticipant(participantB)

	if playerA == nil or playerB == nil or playerA.Parent ~= Players or playerB.Parent ~= Players then
		print("[REMATCH] cancelled reason=PlayerLeft matchId=" .. tostring(matchId))
		returnParticipantsToLobby(matchId, "PlayerLeft")
		return
	end

	local votes = rematchVotesByMatchId[matchId]

	if votes == nil then
		votes = {}
		rematchVotesByMatchId[matchId] = votes
	end

	votes[player.UserId] = true
	setRematchStatus(player, "Waiting")
	print("[REMATCH] vote player=" .. player.Name .. " matchId=" .. tostring(matchId))

	if votes[playerA.UserId] == true and votes[playerB.UserId] == true then
		print("[REMATCH] accepted both players, restarting matchId=" .. tostring(matchId))
		rematchVotesByMatchId[matchId] = nil
		completedMatchesById[matchId] = nil
		startDuel(playerA, participantA, playerB, participantB, matchId)
	else
		print("[REMATCH] waiting for opponent matchId=" .. tostring(matchId))
	end
end

function LobbyService.onMatchEnded(activeMatch)
	if activeMatch == nil then
		return
	end

	completedMatchesById[activeMatch.MatchId] = {
		Participants = activeMatch.Participants,
		IsDuel = activeMatch.IsDuel == true,
	}

	for _, participant in ipairs(activeMatch.Participants or {}) do
		local player = getPlayerFromParticipant(participant)
		local opponent = roundMatchService.getOpponentForParticipant(participant)

		if player ~= nil then
			resetRematchStatus(player)
			setPlayerMode(
				player,
				participant,
				LobbyService.MODE_RESULT,
				activeMatch.MatchId,
				opponent ~= nil and opponent.TankId or nil
			)
		else
			TankParticipantRegistry.setParticipantMatchState(
				participant,
				LobbyService.MODE_RESULT,
				activeMatch.MatchId,
				opponent ~= nil and opponent.TankId or nil
			)
		end
	end
end

function LobbyService.canParticipantDrive(participant)
	if participant == nil
		or participant.IsControllable == false
		or participant.CanMove == false
		or TankParticipantRegistry.getParticipantIsDead(participant)
	then
		return false
	end

	local mode = getParticipantMode(participant)

	if mode == LobbyService.MODE_IN_MATCH then
		local roundState = roundMatchService.getRoundState()

		if roundState ~= nil and roundState.Ended == true then
			return false
		end
	end

	return mode == LobbyService.MODE_LOBBY
		or mode == LobbyService.MODE_QUEUED_FOR_DUEL
		or mode == LobbyService.MODE_IN_MATCH
end

function LobbyService.canParticipantShoot(participant)
	if participant == nil
		or participant.IsControllable == false
		or participant.CanShoot == false
		or TankParticipantRegistry.getParticipantIsDead(participant)
	then
		return false
	end

	local mode = getParticipantMode(participant)

	if mode == LobbyService.MODE_LOBBY or mode == LobbyService.MODE_QUEUED_FOR_DUEL then
		return true
	end

	if mode ~= LobbyService.MODE_IN_MATCH then
		return false
	end

	local roundState = roundMatchService.getRoundState()
	return roundState == nil or roundState.Ended ~= true
end

function LobbyService.isNoDamageProjectile(participant)
	if getParticipantMode(participant) ~= LobbyService.MODE_IN_MATCH then
		return true
	end

	local activeMatch = roundMatchService.getActiveMatch()

	return activeMatch == nil
		or activeMatch.IsFinished == true
		or participant.MatchId == nil
		or participant.MatchId ~= activeMatch.MatchId
end

function LobbyService.shouldRecordShot(participant)
	return LobbyService.isNoDamageProjectile(participant) ~= true
end

function LobbyService.canDamageParticipant(projectile, targetParticipant)
	if projectile == nil or targetParticipant == nil or projectile.NoDamage == true then
		return false
	end

	local activeMatch = roundMatchService.getActiveMatch()

	if activeMatch == nil or activeMatch.IsFinished == true then
		return false
	end

	return projectile.MatchId == activeMatch.MatchId
		and targetParticipant.MatchId == activeMatch.MatchId
		and roundMatchService.isParticipantInActiveMatch(projectile.OwnerParticipant)
		and roundMatchService.isParticipantInActiveMatch(targetParticipant)
end

function LobbyService.areProjectilesEnabled()
	return true
end

function LobbyService.update(deltaTime)
	elapsedSincePadPoll += deltaTime

	if elapsedSincePadPoll < PAD_POLL_INTERVAL then
		return
	end

	local pollDeltaTime = elapsedSincePadPoll
	elapsedSincePadPoll = 0
	updateDuelPadQueue(pollDeltaTime)
end

return LobbyService
