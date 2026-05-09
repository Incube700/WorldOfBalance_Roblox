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

local PAD_POLL_INTERVAL = 0.12

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
		Position = Vector3.new(position.X, 0, position.Z),
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

local function tryStartQueuedDuel()
	if roundMatchService.getActiveMatch() ~= nil then
		return
	end

	while #queuedPlayers >= 2 do
		local playerA = table.remove(queuedPlayers, 1)
		local playerB = table.remove(queuedPlayers, 1)
		queuedByPlayer[playerA] = nil
		queuedByPlayer[playerB] = nil

		local participantA = TankParticipantRegistry.getPlayerParticipant(playerA)
		local participantB = TankParticipantRegistry.getPlayerParticipant(playerB)

		if playerA.Parent == Players
			and playerB.Parent == Players
			and participantA ~= nil
			and participantB ~= nil
			and participantA ~= participantB
			and getMode(playerA) == LobbyService.MODE_QUEUED_FOR_DUEL
			and getMode(playerB) == LobbyService.MODE_QUEUED_FOR_DUEL
		then
			startDuel(playerA, participantA, playerB, participantB)
			return
		end

		print("[LOBBY] duel queue cancelled reason=InvalidQueuedPlayers")
	end
end

local function updateDuelPadQueue()
	local duelPad = getDuelPad()

	if duelPad == nil then
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

	tryStartQueuedDuel()
end

function LobbyService.init(options)
	root = options.root
	tankSpawnResetService = options.tankSpawnResetService
	roundMatchService = options.roundMatchService
	projectileService = options.projectileService
	dummyParticipant = options.dummyParticipant

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
	local mode = getParticipantMode(participant)

	return mode == LobbyService.MODE_LOBBY
		or mode == LobbyService.MODE_QUEUED_FOR_DUEL
		or mode == LobbyService.MODE_IN_MATCH
end

function LobbyService.canParticipantShoot(participant)
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

	elapsedSincePadPoll = 0
	updateDuelPadQueue()
end

return LobbyService
