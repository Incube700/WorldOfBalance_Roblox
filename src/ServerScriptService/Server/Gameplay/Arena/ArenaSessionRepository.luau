local ArenaSessionRepository = {}
ArenaSessionRepository.__index = ArenaSessionRepository

function ArenaSessionRepository.new()
	return setmetatable({
		_sessionsByPlayer = {},
		_sessionsByParticipant = {},
	}, ArenaSessionRepository)
end

function ArenaSessionRepository:Get(player)
	if player == nil then
		return nil
	end

	return self._sessionsByPlayer[player]
end

function ArenaSessionRepository:Has(player)
	return self:Get(player) ~= nil
end

function ArenaSessionRepository:GetByParticipant(participant)
	if participant == nil then
		return nil
	end

	return self._sessionsByParticipant[participant]
end

function ArenaSessionRepository:HasParticipant(participant)
	return self:GetByParticipant(participant) ~= nil
end

function ArenaSessionRepository:GetCurrentForSession(session)
	if session == nil then
		return nil
	end

	if session.Player ~= nil then
		local playerSession = self:Get(session.Player)

		if playerSession ~= nil then
			return playerSession
		end
	end

	return self:GetByParticipant(session.Participant)
end

function ArenaSessionRepository:GetOrCreate(player, createData)
	local existingSession = self:Get(player)

	if existingSession ~= nil then
		return existingSession
	end

	local session = nil

	if typeof(createData) == "function" then
		session = createData(player)
	elseif typeof(createData) == "table" then
		session = createData
	end

	if session == nil then
		return nil
	end

	return self:Set(player, session)
end

function ArenaSessionRepository:Set(player, session)
	if player == nil or session == nil then
		return nil
	end

	local existingSession = self._sessionsByPlayer[player]

	if existingSession ~= nil and existingSession ~= session and existingSession.Participant ~= nil then
		self._sessionsByParticipant[existingSession.Participant] = nil
	end

	self._sessionsByPlayer[player] = session

	if session.Participant ~= nil then
		self._sessionsByParticipant[session.Participant] = session
	end

	return session
end

function ArenaSessionRepository:SetByParticipant(participant, session)
	if participant == nil or session == nil then
		return nil
	end

	local existingSession = self._sessionsByParticipant[participant]

	if existingSession ~= nil and existingSession ~= session and existingSession.Player ~= nil then
		self._sessionsByPlayer[existingSession.Player] = nil
	end

	self._sessionsByParticipant[participant] = session

	if session.Player ~= nil then
		self._sessionsByPlayer[session.Player] = session
	end

	return session
end

function ArenaSessionRepository:Remove(player)
	local session = self:Get(player)

	if session == nil then
		return nil
	end

	self._sessionsByPlayer[player] = nil

	if session.Participant ~= nil and self._sessionsByParticipant[session.Participant] == session then
		self._sessionsByParticipant[session.Participant] = nil
	end

	return session
end

function ArenaSessionRepository:RemoveByParticipant(participant)
	local session = self:GetByParticipant(participant)

	if session == nil then
		return nil
	end

	self._sessionsByParticipant[participant] = nil

	if session.Player ~= nil and self._sessionsByPlayer[session.Player] == session then
		self._sessionsByPlayer[session.Player] = nil
	end

	return session
end

function ArenaSessionRepository:Clear()
	table.clear(self._sessionsByPlayer)
	table.clear(self._sessionsByParticipant)
end

function ArenaSessionRepository:ForEach(callback)
	for player, session in pairs(self._sessionsByPlayer) do
		callback(player, session)
	end
end

function ArenaSessionRepository:ForEachParticipant(callback)
	for participant, session in pairs(self._sessionsByParticipant) do
		callback(participant, session)
	end
end

function ArenaSessionRepository:Count()
	local count = 0

	for _player, _session in pairs(self._sessionsByPlayer) do
		count += 1
	end

	return count
end

return ArenaSessionRepository
