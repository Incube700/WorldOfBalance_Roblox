-- CREATE_BASE_TANK_TEMPLATE_PREVIEW_COMMAND.lua
-- Studio Command Script (NOT a server/client script — run manually in Studio Command Bar).
--
-- PURPOSE:
--   Copies PlayerTankPrototype → BaseTankTemplate inside
--   Workspace.WOB_Generated.TestObjects, then adds empty ArmorZones and Visuals
--   folders if they are missing.
--
-- HOW TO USE:
--   1. Make a backup of your .rbxl first (File → Save to File as backup copy).
--   2. Stop Play Mode if it is running.
--   3. Open this file, set ENABLE_MUTATION = true.
--   4. Select all text, paste into the Studio Command Bar, and press Enter.
--   5. Read the output carefully.
--   6. Manually inspect the created BaseTankTemplate in the Explorer.
--   7. Set BaseTankTemplate.PrimaryPart = Body.
--   8. Move armor parts into ArmorZones folder, decor into Visuals folder.
--   9. Verify the tank works in Play Mode.
--  10. File → Save to File.
--  11. Commit the .rbxl as a separate commit from Luau source changes.
--  12. Set ENABLE_MUTATION back to false before sharing this file.
--
-- SAFETY:
--   - Does NOT delete PlayerTankPrototype / Player2TankPrototype / DummyTank.
--   - Does NOT touch Duel / Arena / Training scene layout.
--   - Does NOT modify VFX / UI templates.
--   - Does NOT modify any Rojo-managed scripts.
--   - Does NOT run automatically — you must paste it manually.

local ENABLE_MUTATION = true

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] Set ENABLE_MUTATION = true manually after making a backup if you want to create BaseTankTemplate preview.")
	warn("[DISABLED PATCH] Read the instructions at the top of this file before enabling.")
	return
end

-- ── Locate TestObjects ─────────────────────────────────────────────────────

local testObjects = workspace:FindFirstChild("WOB_Generated")
	and workspace.WOB_Generated:FindFirstChild("TestObjects")

if testObjects == nil then
	warn("[PATCH] Could not find Workspace.WOB_Generated.TestObjects — aborting.")
	return
end

-- ── Guard: do not overwrite an existing BaseTankTemplate ──────────────────

local BASE_TEMPLATE_NAME = "BaseTankTemplate"

if testObjects:FindFirstChild(BASE_TEMPLATE_NAME) ~= nil then
	warn("[PATCH] " .. BASE_TEMPLATE_NAME .. " already exists in TestObjects — aborting to avoid overwrite.")
	warn("[PATCH] Delete it manually first if you want to regenerate it.")
	return
end

-- ── Find source prototype ─────────────────────────────────────────────────

local prototype = testObjects:FindFirstChild("PlayerTankPrototype")

if prototype == nil or not prototype:IsA("Model") then
	warn("[PATCH] PlayerTankPrototype not found in TestObjects — aborting.")
	return
end

-- ── Clone and rename ──────────────────────────────────────────────────────

local baseTankTemplate = prototype:Clone()
baseTankTemplate.Name = BASE_TEMPLATE_NAME
baseTankTemplate.Parent = testObjects

print("[PATCH] Created " .. BASE_TEMPLATE_NAME .. " from PlayerTankPrototype.")

-- ── Add ArmorZones folder if missing ──────────────────────────────────────

local armorZonesFolder = baseTankTemplate:FindFirstChild("ArmorZones")

if armorZonesFolder == nil then
	armorZonesFolder = Instance.new("Folder")
	armorZonesFolder.Name = "ArmorZones"
	armorZonesFolder.Parent = baseTankTemplate
	print("[PATCH] Added empty ArmorZones folder. Move FrontArmor/RearArmor/LeftArmor/RightArmor into it manually, or they will be picked up from the Hitboxes folder at runtime.")
else
	print("[PATCH] ArmorZones folder already exists — skipped.")
end

-- ── Add Visuals folder if missing ─────────────────────────────────────────

local visualsFolder = baseTankTemplate:FindFirstChild("Visuals")

if visualsFolder == nil then
	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "Visuals"
	visualsFolder.Parent = baseTankTemplate
	print("[PATCH] Added empty Visuals folder. Move or create decoration parts inside it.")
else
	print("[PATCH] Visuals folder already exists — skipped.")
end

-- ── Instructions ─────────────────────────────────────────────────────────

print("")
print("══════════════════════════════════════════════════════")
print("[PATCH] BaseTankTemplate created. MANUAL STEPS REQUIRED:")
print("  1. In Explorer: select BaseTankTemplate → Properties → PrimaryPart → set to Body.")
print("  2. Move FrontArmor / RearArmor / LeftArmor / RightArmor into ArmorZones folder.")
print("     (Or leave them in Hitboxes — TankArmorPartsService supports both.)")
print("  3. Move / create decoration parts inside Visuals folder.")
print("  4. Set CanCollide=false / CanQuery=false / Massless=true on Visuals parts.")
print("  5. DO NOT edit runtime PlayerTank_<UserId> models — those are live clones.")
print("  6. Enter Play Mode and verify the tank spawns and works.")
print("  7. File → Save to File (saves .rbxl with BaseTankTemplate).")
print("  8. Commit .rbxl separately from Luau source changes.")
print("══════════════════════════════════════════════════════")
