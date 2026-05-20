local LobbyPadResolver = {}

local DEFAULT_PAD_Y_TOLERANCE = 6

function LobbyPadResolver.GetLobby(root)
	return root ~= nil and root:FindFirstChild("Lobby") or nil
end

function LobbyPadResolver.GetTopLobbyChild(lobby, instance)
	local current = instance
	local last = instance

	while current ~= nil and current ~= lobby do
		last = current
		current = current.Parent
	end

	if current == lobby then
		return last
	end

	return nil
end

function LobbyPadResolver.FindPadTriggerInRoot(padRoot)
	if padRoot == nil then
		return nil
	end

	local directTrigger = padRoot:FindFirstChild("Trigger")

	if directTrigger ~= nil and directTrigger:IsA("BasePart") then
		return directTrigger
	end

	for _, descendant in ipairs(padRoot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("WOBPadTrigger") == true then
			return descendant
		end
	end

	if padRoot:IsA("BasePart") then
		return padRoot
	end

	return nil
end

function LobbyPadResolver.IsUsablePadRoot(padRoot)
	return padRoot ~= nil
		and padRoot:GetAttribute("WOBPadEnabled") ~= false
		and LobbyPadResolver.FindPadTriggerInRoot(padRoot) ~= nil
end

function LobbyPadResolver.FindPadRootByTypeOrName(root, padType, padNames)
	local lobby = LobbyPadResolver.GetLobby(root)

	if lobby == nil then
		return nil
	end

	for _, padName in ipairs(padNames or {}) do
		local namedPad = lobby:FindFirstChild(padName)

		if LobbyPadResolver.IsUsablePadRoot(namedPad) then
			return namedPad
		end
	end

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:GetAttribute("WOBPadType") == padType then
			local padRoot = LobbyPadResolver.GetTopLobbyChild(lobby, descendant)

			if LobbyPadResolver.IsUsablePadRoot(padRoot) then
				return padRoot
			end
		end
	end

	return nil
end

function LobbyPadResolver.GetPadTrigger(padRoot)
	if padRoot == nil or padRoot:GetAttribute("WOBPadEnabled") == false then
		return nil
	end

	return LobbyPadResolver.FindPadTriggerInRoot(padRoot)
end

function LobbyPadResolver.ApplyPadContractAttributes(padRoot, pad, padType, requiredPlayers)
	for _, instance in ipairs({ padRoot, pad }) do
		if instance ~= nil then
			instance:SetAttribute("WOBPadType", padType)
			instance:SetAttribute("RequiredPlayers", requiredPlayers)
			instance:SetAttribute("WOBPadEnabled", true)
		end
	end

	if pad ~= nil then
		pad:SetAttribute("WOBPadTrigger", true)
	end
end

function LobbyPadResolver.GetParticipantPadProbePosition(participant, tankParticipantRegistry)
	if participant == nil then
		return nil
	end

	if participant.Body ~= nil and participant.Body.Parent ~= nil then
		return participant.Body.Position
	end

	local physicalModel = nil

	if tankParticipantRegistry ~= nil and tankParticipantRegistry.getParticipantPhysicalModel ~= nil then
		physicalModel = tankParticipantRegistry.getParticipantPhysicalModel(participant)
	end

	if physicalModel ~= nil then
		if physicalModel.PrimaryPart ~= nil then
			return physicalModel.PrimaryPart.Position
		end

		for _, descendant in ipairs(physicalModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				return descendant.Position
			end
		end
	end

	return nil
end

function LobbyPadResolver.GetParticipantPadOverlap(participant, pad, tankParticipantRegistry)
	if participant == nil or pad == nil then
		return {
			IsInside = false,
			ProbePosition = nil,
			LocalPosition = nil,
		}
	end

	local probePosition = LobbyPadResolver.GetParticipantPadProbePosition(participant, tankParticipantRegistry)

	if probePosition == nil then
		return {
			IsInside = false,
			ProbePosition = nil,
			LocalPosition = nil,
		}
	end

	local localPosition = pad.CFrame:PointToObjectSpace(probePosition)
	local halfSize = pad.Size * 0.5
	local isInside = math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
		and math.abs(localPosition.Y) <= math.max(halfSize.Y, DEFAULT_PAD_Y_TOLERANCE)

	return {
		IsInside = isInside,
		ProbePosition = probePosition,
		LocalPosition = localPosition,
	}
end

return LobbyPadResolver
