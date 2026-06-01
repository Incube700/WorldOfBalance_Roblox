-- VfxRegistry: SINGLE source of truth for gameplay VFX.
--
-- Goal (Update 0.2.x VFX consolidation):
--   * ONE base per effect ("Active" variant), selectable from one place.
--   * ALL other variants kept (never deleted) and switchable via the Active table below.
--   * Everything lives in the main flat folder ReplicatedStorage/Shared/Assets/VFX
--     (no deep per-category trees needed at runtime -- resolve() looks up by Instance name).
--
-- HOW TO SWITCH AN EFFECT:
--   Change the value in VfxRegistry.Active to any key listed under that effect's Variants.
--   Example: Active.MuzzleFlash = "Blue"  -> uses Variants.MuzzleFlash.Blue.
--
-- This module is additive and non-breaking: existing catalogs/services keep working until
-- they are migrated to read from here. Variants point to the Instance NAME inside the main
-- VFX folder; assets still physically located in other trees are marked NeedsMove = true and
-- should be moved into Shared/Assets/VFX in the follow-up flatten step (verified with rojo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxRegistry = {}

VfxRegistry.Version = 1

-- The single flat folder all VFX templates resolve from.
VfxRegistry.FolderPath = { "Shared", "Assets", "VFX" }

-- ---------------------------------------------------------------------------
-- THE SWITCH: one active variant key per effect. Change a value to swap the
-- effect game-wide. Each value MUST be a key under the matching Variants entry.
-- ---------------------------------------------------------------------------
VfxRegistry.Active = {
	MuzzleFlash = "Default",
	ProjectileTrail = "Default",
	ProjectileImpact = "Default",
	RicochetImpact = "Default",
	TankExplosion = "Default",
	Repair = "Default",
	ReflectShield = "Default",
	UpgradeSelect = "Default",
	LevelUp = "Default",
}

-- ---------------------------------------------------------------------------
-- All known variants per effect. "Template" = Instance name to resolve inside
-- the main VFX folder. NeedsMove flags assets that still live in a nested tree
-- (Assets/FX/...) and should be moved into Shared/Assets/VFX during the flatten.
-- Nothing here is deleted -- every variant stays available to switch back to.
-- ---------------------------------------------------------------------------
VfxRegistry.Variants = {
	MuzzleFlash = {
		Default = { Template = "MuzzleEffectTemplate" },
		Flash = { Template = "MuzzleFlashTemplate" },
		Canonical = { Template = "MuzzleFlash_Default" }, -- moved into flat folder
		LegacyFallback = { Template = "MuzzleFlash_LegacyFallback" }, -- moved into flat folder
	},
	-- Per-weapon muzzle/shot FX. No asset yet -> procedural fallback fires (see CombatFXService).
	-- Drop a template named below into Shared/Assets/VFX and it'll be used automatically.
	RailGunShot = {
		Default = { Template = "RailGunShot_Default", Missing = true },
	},
	RocketShot = {
		Default = { Template = "RocketShot_Default", Missing = true },
	},
	-- Rocket detonation FX: reuses the ProjectileImpact burst, scaled up bigger (see
	-- GameplayFXCatalog.RocketExplosion ScaleMultiplier/EmitCount). Swap Template to a
	-- dedicated RocketExplosion_Default later if you author one.
	RocketExplosion = {
		Default = { Template = "ProjectileImpact_Default" },
	},
	ProjectileTrail = {
		-- NOTE: legacy asset name is misspelled ("Deafult"); kept as a variant so old refs work.
		Default = { Template = "ProjectileTrail_Default" }, -- moved into flat folder (correct spelling)
		Legacy = { Template = "ProjectileTrail_Deafult" },
	},
	ProjectileImpact = {
		Default = { Template = "ProjectileImpact_Default" }, -- moved into flat folder
		Legacy = { Template = "ProjectileImpactVFX" },
		Sparks = { Template = "ImpactSparksTemplate" },
	},
	RicochetImpact = {
		Default = { Template = "RicochetImpact_Default" },
		Template = { Template = "RicochetTemplate" },
	},
	TankExplosion = {
		Default = { Template = "TankExplosion_Default" }, -- moved into flat folder
		Legacy = { Template = "TankExplosionVFX" },
		Template = { Template = "TankExplosionTemplate" },
		SFX = { Template = "ExplosionTankSFX" },
	},
	Repair = {
		-- No asset file exists yet (only an empty FX folder); procedural until authored.
		Default = { Template = "Repair_Default", Missing = true },
	},
	ReflectShield = {
		Default = { Template = "ReflectShield_Default" },
	},
	UpgradeSelect = {
		-- No asset file exists yet (only an empty FX folder); procedural until authored.
		Default = { Template = "UpgradeSelect_Default", Missing = true },
	},
	LevelUp = {
		Default = { Template = "LevelUp_Default" }, -- moved into flat folder
		Legacy = { Template = "LevelUpFX" },
	},
}

-- Returns the active variant descriptor for an effect, or nil + reason.
function VfxRegistry.getActiveVariant(effectKey)
	local variants = VfxRegistry.Variants[effectKey]
	if variants == nil then
		return nil, ("unknown effect %q"):format(tostring(effectKey))
	end

	local activeKey = VfxRegistry.Active[effectKey] or "Default"
	local variant = variants[activeKey]
	if variant == nil then
		return nil, ("effect %q has no variant %q"):format(tostring(effectKey), tostring(activeKey))
	end

	return variant, nil
end

-- Resolves the main VFX folder (Shared/Assets/VFX).
function VfxRegistry.getFolder()
	local current = ReplicatedStorage
	for _, name in ipairs(VfxRegistry.FolderPath) do
		current = current ~= nil and current:FindFirstChild(name) or nil
	end
	return current
end

-- Returns the live template Instance for an effect's ACTIVE variant, or nil + reason.
function VfxRegistry.resolveActiveTemplate(effectKey)
	local variant, reason = VfxRegistry.getActiveVariant(effectKey)
	if variant == nil then
		return nil, reason
	end

	local folder = VfxRegistry.getFolder()
	if folder == nil then
		return nil, "main VFX folder ReplicatedStorage/Shared/Assets/VFX not found"
	end

	local template = folder:FindFirstChild(variant.Template)
	if template == nil then
		return nil, ("template %q not found in main VFX folder (NeedsMove=%s)"):format(
			tostring(variant.Template), tostring(variant.NeedsMove == true))
	end

	return template, nil
end

return VfxRegistry
