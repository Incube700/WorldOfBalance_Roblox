local PlayerPossessionService = {}

local Players = game:GetService("Players")
local TankParticipantRegistry = require(script.Parent.Parent:WaitForChild("TankParticipantRegistry"))
local PersistentPlayerStatsService = require(script.Parent.Parent:WaitForChild("Stats"):WaitForChild("PersistentPlayerStatsService"))

local playerParticipantByPlayer = {}
local inputByPlayer = {}
local controllingPlayer = nil
local DEBUG_POSSESSION = false
local callbacks = {
	getOrCreateParticipantForPlayer = nil,
	onParticipantAssigned = nil,
}

function PlayerPossessionService.init(options)
	callbacks = options or {}
end

function PlayerPossessionService.suppressCharacter(player, character)
	if character == nil then
		return
	end

	if character:GetAttribute("WOBCharacterSuppressed") == true then
		return
	end

	character:SetAttribute("WOBCharacterSuppressed", true)

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid ~= nil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Anchored = true
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end

	pcall(function()
		character:PivotTo(CFrame.new(0, -10000, 0))
	end)

	pcall(function()
		character:Destroy()
	end)

	if DEBUG_POSSESSION then
		print("[PVP] character removed/suppressed for " .. player.Name)
	end
end

function PlayerPossessionService.setInitialInputForParticipant(player, participant)
	local state = participant.ControlState or { Position = Vector3.new(0,0,0) }

	inputByPlayer[player] = {
		Throttle = 0,
		Steer = 0,
		AimPosition = state.Position + Vector3.new(0, 0, -20),
	}
end

function PlayerPossessionService.assignPlayer(player)
	task.spawn(function()
		PersistentPlayerStatsService.loadPlayer(player)
	end)

	if playerParticipantByPlayer[player] ~= nil then
		return
	end

	local assignedParticipant = nil

	if callbacks.getOrCreateParticipantForPlayer then
		assignedParticipant = callbacks.getOrCreateParticipantForPlayer(player)
	end

	if assignedParticipant == nil then
		assignedParticipant = TankParticipantRegistry.getAvailablePlayerParticipant()
	end

	if assignedParticipant == nil then
		warn("[PVP] No player tank participant available for " .. player.Name)
		return
	end

	if controllingPlayer == nil then
		controllingPlayer = player
	end

	playerParticipantByPlayer[player] = assignedParticipant
	TankParticipantRegistry.setPlayerParticipant(player, assignedParticipant)
	TankParticipantRegistry.setParticipantOwner(assignedParticipant, player)
	local physicalModel = TankParticipantRegistry.getParticipantPhysicalModel(assignedParticipant)
	if physicalModel ~= nil then
		physicalModel:SetAttribute("OwnerUserId", player.UserId)
		physicalModel:SetAttribute("OwnerName", player.Name)
	end
	PlayerPossessionService.setInitialInputForParticipant(player, assignedParticipant)
	
	if callbacks.onParticipantAssigned then
		callbacks.onParticipantAssigned(player, assignedParticipant)
	end

	player.CharacterAdded:Connect(function(character)
		PlayerPossessionService.suppressCharacter(player, character)
	end)

	if player.Character ~= nil then
		PlayerPossessionService.suppressCharacter(player, player.Character)
	end

	print("[PVP] assigned " .. player.Name .. " -> " .. assignedParticipant.TankId)
end

function PlayerPossessionService.removePlayer(player)
	local assignedParticipant = playerParticipantByPlayer[player]

	inputByPlayer[player] = nil
	playerParticipantByPlayer[player] = nil
	TankParticipantRegistry.setPlayerParticipant(player, nil)

	if assignedParticipant ~= nil then
		TankParticipantRegistry.clearParticipantOwner(assignedParticipant)
	end

	if controllingPlayer == player then
		controllingPlayer = nil

		for _, participant in ipairs(TankParticipantRegistry.getPlayerParticipants()) do
			if participant.OwnerPlayer ~= nil then
				controllingPlayer = participant.OwnerPlayer
				break
			end
		end
	end
	
	if callbacks.onParticipantAssigned then
		callbacks.onParticipantAssigned(player, nil)
	end
end

function PlayerPossessionService.getInputByPlayer()
	return inputByPlayer
end

function PlayerPossessionService.getControllingPlayer()
	return controllingPlayer
end

function PlayerPossessionService.getPlayerParticipantByPlayer(player)
	return playerParticipantByPlayer[player]
end

return PlayerPossessionService
