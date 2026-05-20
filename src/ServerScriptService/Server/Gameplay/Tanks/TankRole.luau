local TankRole = {
	Player = "Player",
	DuelOpponent = "DuelOpponent",
	Dummy = "Dummy",
	Bot = "Bot",
	ArenaPlayer = "ArenaPlayer",
	ArenaBot = "ArenaBot",
}

local validRoles = {}

for _, role in pairs(TankRole) do
	validRoles[role] = true
end

function TankRole.IsValid(role)
	return validRoles[role] == true
end

return table.freeze(TankRole)
