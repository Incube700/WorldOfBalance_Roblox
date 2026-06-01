-- TemporaryWeaponService: tracks the temporary pickup weapon a participant is
-- currently holding (Update 0.2). State lives on `participant.TempWeapon` so the
-- ProjectileService can read it without a hard require (avoids module cycles).
--
-- This module is a leaf: it only requires WeaponCatalog and never touches the
-- default-weapon path. When a participant has no temp weapon, every consumer falls
-- back to the existing default cannon behavior.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local WeaponCatalog = require(configs:WaitForChild("WeaponCatalog"))

local TemporaryWeaponService = {}

local callbacks = {
	-- notify(participant, text, color) -> shows player-facing feedback (optional).
	notify = nil,
}

function TemporaryWeaponService.init(options)
	callbacks = options or {}
end

local function getOwnerPlayer(participant)
	return participant ~= nil and participant.OwnerPlayer or nil
end

local function publishHudAttributes(participant)
	local player = getOwnerPlayer(participant)

	if player == nil then
		return
	end

	local temp = participant.TempWeapon

	if temp == nil then
		player:SetAttribute("ArenaWeaponName", WeaponCatalog.DefaultWeaponDisplayName)
		player:SetAttribute("ArenaWeaponAmmo", 0)
		player:SetAttribute("ArenaWeaponIsTemporary", false)
	else
		player:SetAttribute("ArenaWeaponName", temp.Config.DisplayName or temp.WeaponId)
		player:SetAttribute("ArenaWeaponAmmo", temp.AmmoLeft)
		player:SetAttribute("ArenaWeaponIsTemporary", true)
	end
end

local function notify(participant, text, color)
	if callbacks.notify ~= nil and text ~= nil then
		callbacks.notify(participant, text, color)
	end
end

-- Returns true if the participant currently holds a temporary weapon.
function TemporaryWeaponService.isActive(participant)
	return participant ~= nil and participant.TempWeapon ~= nil
end

-- Returns the active weapon override config (frozen catalog entry) or nil.
function TemporaryWeaponService.getActiveConfig(participant)
	if participant == nil or participant.TempWeapon == nil then
		return nil
	end

	return participant.TempWeapon.Config
end

-- Grants a temporary weapon to a participant. Returns true on success.
function TemporaryWeaponService.grant(participant, weaponId)
	if participant == nil then
		return false
	end

	local weaponConfig = WeaponCatalog.getWeapon(weaponId)

	if weaponConfig == nil then
		warn("[TEMP WEAPON] Unknown weapon id: " .. tostring(weaponId))
		return false
	end

	participant.TempWeapon = {
		WeaponId = weaponId,
		Config = weaponConfig,
		AmmoLeft = math.max(1, math.floor(tonumber(weaponConfig.Ammo) or 1)),
	}

	publishHudAttributes(participant)
	notify(participant, weaponConfig.NotifyText or (weaponConfig.DisplayName .. "!"), weaponConfig.ProjectileColor)

	return true
end

-- Consumes one shot of the active temp weapon. Reverts to default when depleted.
function TemporaryWeaponService.consumeShot(participant)
	local temp = participant ~= nil and participant.TempWeapon or nil

	if temp == nil then
		return
	end

	temp.AmmoLeft -= 1

	if temp.AmmoLeft <= 0 then
		TemporaryWeaponService.resetParticipant(participant, "Depleted")
	else
		publishHudAttributes(participant)
	end
end

-- Clears any temporary weapon and restores the default cannon. Safe to call on
-- death, respawn, run reset, and lobby exit (idempotent).
function TemporaryWeaponService.resetParticipant(participant, reason)
	if participant == nil then
		return
	end

	local hadWeapon = participant.TempWeapon ~= nil
	participant.TempWeapon = nil
	publishHudAttributes(participant)

	if hadWeapon and reason == "Depleted" then
		notify(participant, "Out of ammo", WeaponCatalog.Pickups.Health.IconColor)
	end
end

return TemporaryWeaponService
