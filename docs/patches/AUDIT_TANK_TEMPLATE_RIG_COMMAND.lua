-- AUDIT_TANK_TEMPLATE_RIG_COMMAND.lua
-- Studio Command Script (NOT a server/client script — run manually in Studio Command Bar).
--
-- PURPOSE:
--   Read-only inspection of the BaseTankTemplate and all runtime tank models
--   in Workspace.WOB_Generated.TestObjects and Workspace (PlayerTank_*, ArenaBot_*).
--   Checks:
--     • BaseTankTemplate exists in TestObjects
--     • Startup_* models: IsActive, visible parts, CanQuery/CanCollide summary
--     • PlayerTank_* and ArenaBot_* tanks: TemplateSourceName, Body state,
--       ArmorZones count, ArmorZones CanQuery count, Visuals CanQuery count,
--       PrimaryPart
--     • Registered participant attributes (reads from model attributes)
--     • Warnings for common rig problems
--
-- HOW TO USE:
--   1. Enter Play Mode first so runtime tanks are present.
--   2. Open this file, select all text, paste into the Studio Command Bar, press Enter.
--   3. Read the output in the Output panel.
--   4. Exit Play Mode when done — this script makes NO changes.
--
-- SAFETY:
--   - Read-only: does NOT create, move, rename, or delete anything.
--   - Does NOT touch VFX / UI / Rojo source files.
--   - Does NOT run automatically — you must paste it manually.

local Workspace = game:GetService("Workspace")

-- ── Helpers ───────────────────────────────────────────────────────────────

local function attr(instance, name)
	local v = instance:GetAttribute(name)
	if v == nil then return "(none)" end
	return tostring(v)
end

local function findArmorFolder(model)
	-- Deep search: ArmorZones preferred (BaseTankTemplate), then Hitboxes (legacy)
	local az = model:FindFirstChild("ArmorZones")
	if az == nil then
		for _, d in ipairs(model:GetDescendants()) do
			if d.Name == "ArmorZones" and d:IsA("Folder") then az = d; break end
		end
	end
	if az ~= nil then return az, "ArmorZones" end

	local hb = model:FindFirstChild("Hitboxes")
	if hb == nil then
		for _, d in ipairs(model:GetDescendants()) do
			if d.Name == "Hitboxes" and d:IsA("Folder") then hb = d; break end
		end
	end
	if hb ~= nil then return hb, "Hitboxes" end
	return nil, nil
end

local ARMOR_NAMES = { "FrontArmor", "RearArmor", "LeftArmor", "RightArmor" }

local function countArmorParts(armorFolder, predicate)
	if armorFolder == nil then return 0 end
	local count = 0
	for _, name in ipairs(ARMOR_NAMES) do
		local part = armorFolder:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") and predicate(part) then
			count += 1
		end
	end
	return count
end

local function auditModel(model, label)
	local isActive = model:GetAttribute("IsActive")
	local isAlive  = model:GetAttribute("IsAlive")
	local tankId   = attr(model, "TankId")
	local role     = attr(model, "TankRole")
	local src      = attr(model, "TemplateSourceName")

	print("────────────────────────────────────────────────────────")
	print(("[RIG AUDIT] %s  %s"):format(label or model.Name, model:GetFullName()))
	print(("  TankId             : %s"):format(tankId))
	print(("  TankRole           : %s"):format(role))
	print(("  TemplateSourceName : %s"):format(src))
	print(("  IsActive           : %s"):format(tostring(isActive)))
	print(("  IsAlive            : %s"):format(tostring(isAlive)))

	-- PrimaryPart
	if model.PrimaryPart ~= nil then
		print("  PrimaryPart        : " .. model.PrimaryPart.Name .. " ✓")
	else
		warn("  PrimaryPart        : MISSING ← set to Body in Properties")
	end

	-- Body checks
	local body = model:FindFirstChild("Body")
	if body == nil then
		for _, d in ipairs(model:GetDescendants()) do
			if d.Name == "Body" and d:IsA("BasePart") then body = d; break end
		end
	end

	if body ~= nil and body:IsA("BasePart") then
		local flags = ""
		if body.Anchored then flags = flags .. " [Anchored=true ← tank cannot move!]" end
		if not body.CanQuery then flags = flags .. " [CanQuery=false]" end
		print(("  Body               : ✓ CanCollide=%s CanQuery=%s Anchored=%s%s"):format(
			tostring(body.CanCollide), tostring(body.CanQuery), tostring(body.Anchored), flags))
	else
		warn("  Body               : MISSING")
	end

	-- Structural parts
	for _, partName in ipairs({"Turret", "Barrel", "ShootPoint"}) do
		local part = model:FindFirstChild(partName)
		if part == nil then
			for _, d in ipairs(model:GetDescendants()) do
				if d.Name == partName and d:IsA("BasePart") then part = d; break end
			end
		end
		if part ~= nil then
			print(("  %-18s: ✓"):format(partName))
		else
			warn(("  %-18s: MISSING"):format(partName))
		end
	end

	-- Armor folder
	local armorFolder, folderName = findArmorFolder(model)
	if armorFolder ~= nil then
		local queryCount  = countArmorParts(armorFolder, function(p) return p.CanQuery end)
		local totalArmor  = #ARMOR_NAMES
		print(("  Armor folder       : %s  CanQuery=%d/%d"):format(folderName, queryCount, totalArmor))

		for _, name in ipairs(ARMOR_NAMES) do
			local part = armorFolder:FindFirstChild(name)
			if part ~= nil and part:IsA("BasePart") then
				local flags = ""
				if not part.CanQuery then flags = flags .. " [CanQuery=false ← projectiles won't hit!]" end
				if not part.Massless  then flags = flags .. " [Massless=false]" end
				if part.Anchored      then flags = flags .. " [Anchored=true]" end
				print(("    %-14s: ✓%s"):format(name, flags))
			else
				warn(("    %-14s: MISSING from %s"):format(name, folderName))
			end
		end

		-- Warning: active tank with zero queryable armor zones
		if isActive == true and queryCount == 0 then
			warn(("  [WARN] %s is active but has 0 ArmorZones with CanQuery=true — projectiles will pass through!"):format(model.Name))
		end
	else
		warn("  Armor folder       : MISSING (no ArmorZones or Hitboxes)")
		if isActive == true then
			warn(("  [WARN] %s is active but has no hitbox folder — projectiles will pass through!"):format(model.Name))
		end
	end

	-- Visuals folder (should have CanQuery=false on all parts)
	local visuals = model:FindFirstChild("Visuals")
	if visuals ~= nil then
		local visualQueryCount = 0
		local visualTotal = 0
		for _, child in ipairs(visuals:GetDescendants()) do
			if child:IsA("BasePart") then
				visualTotal += 1
				if child.CanQuery then
					visualQueryCount += 1
					warn(("    Visuals.%s.CanQuery=true ← should be false (visual-only part)"):format(child.Name))
				end
			end
		end
		print(("  Visuals            : ✓ (%d parts, %d have CanQuery=true)"):format(visualTotal, visualQueryCount))
	else
		print("  Visuals            : (no Visuals folder — OK)")
	end

	-- Startup / inactive tank warnings
	local tankName = model.Name
	local isStartup = string.match(tankName, "^Startup_")
	if isStartup then
		-- Check if any parts are visible/queryable on an inactive startup tank
		local visiblePartCount = 0
		local queryablePartCount = 0
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				if desc.Transparency < 1 then visiblePartCount += 1 end
				if desc.CanQuery       then queryablePartCount += 1 end
			end
		end
		if visiblePartCount > 0 then
			warn(("  [WARN] Startup tank %s has %d visible part(s) — should be fully transparent when inactive"):format(tankName, visiblePartCount))
		else
			print(("  Startup visibility : ✓ all parts transparent (%d total)"):format(visiblePartCount))
		end
		if queryablePartCount > 0 then
			warn(("  [WARN] Startup tank %s has %d CanQuery part(s) — inactive tanks should have CanQuery=false"):format(tankName, queryablePartCount))
		end
	end
end

-- ── Locate TestObjects ─────────────────────────────────────────────────────

local wobGenerated = Workspace:FindFirstChild("WOB_Generated")
local testObjects  = wobGenerated ~= nil and wobGenerated:FindFirstChild("TestObjects") or nil

print("══════════════════════════════════════════════════════")
print("[RIG AUDIT] BaseTankTemplate + Runtime Tank Audit")
print("══════════════════════════════════════════════════════")

-- Check BaseTankTemplate
if testObjects ~= nil then
	local base = testObjects:FindFirstChild("BaseTankTemplate")
	if base ~= nil and base:IsA("Model") then
		print("[RIG AUDIT] BaseTankTemplate : ✓ found in TestObjects")
	else
		warn("[RIG AUDIT] BaseTankTemplate : NOT FOUND in TestObjects — factory will fall back to legacy prototypes!")
	end
else
	warn("[RIG AUDIT] Workspace.WOB_Generated.TestObjects not found — is Play Mode active?")
end

-- ── Startup_* models (TestObjects) ─────────────────────────────────────────
local startupCount = 0
if testObjects ~= nil then
	for _, child in ipairs(testObjects:GetChildren()) do
		if child:IsA("Model") and string.match(child.Name, "^Startup_") then
			startupCount += 1
			auditModel(child, "STARTUP")
		end
	end
end

if startupCount == 0 then
	print("[RIG AUDIT] No Startup_* models found in TestObjects (may not have spawned yet)")
end

-- ── PlayerTank_* models (TestObjects or Runtime) ────────────────────────────
local playerTankCount = 0
if testObjects ~= nil then
	for _, child in ipairs(testObjects:GetChildren()) do
		if child:IsA("Model") and string.match(child.Name, "^PlayerTank_") then
			playerTankCount += 1
			auditModel(child, "PLAYER")
		end
	end
end

if playerTankCount == 0 then
	print("[RIG AUDIT] No PlayerTank_* models found (join a server with a player or check Runtime folder)")
end

-- ── ArenaBot_* models ────────────────────────────────────────────────────────
local arenaBotCount = 0
if wobGenerated ~= nil then
	for _, folder in ipairs(wobGenerated:GetChildren()) do
		for _, child in ipairs(folder:GetDescendants()) do
			if child:IsA("Model") and string.match(child.Name, "^ArenaBot_") then
				arenaBotCount += 1
				auditModel(child, "ARENABOT")
			end
		end
	end
end

if arenaBotCount == 0 then
	print("[RIG AUDIT] No ArenaBot_* models found (start a BattleArena match to check)")
end

-- ── Summary ────────────────────────────────────────────────────────────────
print("────────────────────────────────────────────────────────")
print(("[RIG AUDIT] Done. Startup=%d  PlayerTank=%d  ArenaBot=%d"):format(startupCount, playerTankCount, arenaBotCount))
print("[RIG AUDIT] TemplateSourceName='BaseTankTemplate' → editable template ✓")
print("[RIG AUDIT] TemplateSourceName='PlayerTankPrototype'/other → legacy fallback")
print("[RIG AUDIT] TemplateSourceName='reused' → factory reused existing model")
print("")
print("[RIG AUDIT] Quick collision checklist:")
print("  1. Active tank ArmorZones: all 4 parts CanQuery=true")
print("  2. Startup tanks: all parts Transparent=1, CanQuery=false")
print("  3. Body: Anchored=false (or true if CFrame-driven), CanCollide=true")
print("  4. Visuals: CanQuery=false on all parts")
print("  5. TemplateSourceName=BaseTankTemplate → correct hitbox contract")
print("  6. If projectiles pass through: check ArmorZones exists, CanQuery=true, IsActive=true")
print("══════════════════════════════════════════════════════")
