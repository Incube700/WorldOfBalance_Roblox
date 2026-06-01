--!nocheck
--[[
	TagArenaRoles.commandbar.luau

	AUTHORING UTILITY -- paste into the Roblox Studio Command Bar (View > Command Bar)
	and press Enter. It tags the CURRENTLY SELECTED objects with arena role attributes
	so the runtime knows which container is the BattleArena, which is the Duel field, and
	which is the Lobby -- and therefore where the arena layer (maze / pickups / breakables
	/ visual polish) is allowed to appear.

	THIS TOOL ONLY TAGS WHAT YOU SELECT. It creates nothing, scans nothing, moves nothing,
	and never guesses "the largest floor" or "the container at some position". If your
	selection is empty or wrong, it tells you and stops. That is intentional: tagging is a
	deliberate authoring decision, not an inference.

	-------------------------------------------------------------------------------
	HOW TO USE
	-------------------------------------------------------------------------------
	1. Set ROLE below to one of: "BattleArena", "Duel", "Lobby".
	2. Set TARGET to:
	       "Container" -- the selected Model/Folder is an arena CONTAINER
	       "Floor"     -- the selected BasePart(s) are the arena FLOOR
	3. In the Explorer, SELECT the object(s) to tag.
	4. Paste this whole file into the Command Bar and press Enter.

	Tag the CONTAINER once (with TARGET="Container") and the FLOOR once
	(with TARGET="Floor"), per arena. Re-run as needed; tagging is idempotent.

	-------------------------------------------------------------------------------
	WHAT IT WRITES  (matches WeaponCatalog.RoleAttributes / .Roles)
	-------------------------------------------------------------------------------
	Container (Model/Folder):
	    WOBArenaRole        = ROLE
	    WOBMode             = ROLE
	    WOBAllowArenaMode   = (ROLE == "BattleArena")
	    WOBAllowPickups     = (ROLE == "BattleArena")
	    WOBAllowMaze        = (ROLE == "BattleArena")
	    WOBAllowVisualPolish= (ROLE == "BattleArena")
	  -> Duel and Lobby get all four WOBAllow* = false (the arena layer is denied there).

	Floor (BasePart):
	    WOBArenaFloor       = true
	    WOBArenaRole        = ROLE
]]

local Selection = game:GetService("Selection")

-- ===========================================================================
-- EDIT THESE TWO LINES, THEN RUN.
-- ===========================================================================
local ROLE = "BattleArena" -- "BattleArena" | "Duel" | "Lobby"
local TARGET = "Container" -- "Container" | "Floor"
-- ===========================================================================

local VALID_ROLES = {
	BattleArena = true,
	Duel = true,
	Lobby = true,
}

local function fail(message)
	warn("[TAG ROLES] " .. message .. " Nothing was changed.")
end

if VALID_ROLES[ROLE] ~= true then
	return fail(("ROLE=%q is invalid; expected \"BattleArena\", \"Duel\", or \"Lobby\"."):format(tostring(ROLE)))
end

if TARGET ~= "Container" and TARGET ~= "Floor" then
	return fail(("TARGET=%q is invalid; expected \"Container\" or \"Floor\"."):format(tostring(TARGET)))
end

local selected = Selection:Get()

if #selected == 0 then
	return fail("Selection is empty. Select the object(s) to tag in the Explorer first.")
end

local allowArena = ROLE == "BattleArena"

local function tagContainer(instance)
	-- Containers should be Models or Folders. We do not force this, but warn so the
	-- author notices if they selected a stray Part instead of the arena container.
	if not (instance:IsA("Model") or instance:IsA("Folder")) then
		warn(("[TAG ROLES] '%s' is a %s, not a Model/Folder; tagging it as a container anyway -- double-check this is the arena container."):format(
			instance.Name, instance.ClassName))
	end

	instance:SetAttribute("WOBArenaRole", ROLE)
	instance:SetAttribute("WOBMode", ROLE)
	instance:SetAttribute("WOBAllowArenaMode", allowArena)
	instance:SetAttribute("WOBAllowPickups", allowArena)
	instance:SetAttribute("WOBAllowMaze", allowArena)
	instance:SetAttribute("WOBAllowVisualPolish", allowArena)
end

local function tagFloor(instance)
	if not instance:IsA("BasePart") then
		warn(("[TAG ROLES] Skipped '%s': TARGET=\"Floor\" requires a BasePart, got %s."):format(
			instance.Name, instance.ClassName))
		return false
	end

	instance:SetAttribute("WOBArenaFloor", true)
	instance:SetAttribute("WOBArenaRole", ROLE)
	return true
end

local tagged = 0

for _, instance in ipairs(selected) do
	if TARGET == "Container" then
		tagContainer(instance)
		tagged += 1
	else
		if tagFloor(instance) then
			tagged += 1
		end
	end
end

if tagged == 0 then
	return fail("No eligible objects in the selection were tagged.")
end

print(("[TAG ROLES] Tagged %d object(s) as TARGET=%s ROLE=%s (allowArenaLayer=%s)."):format(
	tagged, TARGET, ROLE, tostring(allowArena)))
