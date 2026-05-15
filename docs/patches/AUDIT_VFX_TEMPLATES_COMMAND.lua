-- Roblox Studio Command Bar VFX template audit.
-- Run outside Play Mode before Save to File, Publish, or Rojo sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[VFX AUDIT] Stop Play Mode first.")
	return
end

local EXPECTED_TEMPLATES = {
	"TankExplosionTemplate",
	"TankBurningTemplate",
	"RicochetTemplate",
	"ImpactSparksTemplate",
	"MuzzleEffectTemplate",
	"SmokeTemplate",
}

local function isScriptInstance(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function isLightInstance(instance)
	return instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
end

local function findVfxFolder()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil

	return assets ~= nil and assets:FindFirstChild("VFX") or nil
end

local function collectInfo(rootInstance)
	local info = {
		ParticleEmitters = 0,
		Sounds = 0,
		Beams = 0,
		Trails = 0,
		Lights = 0,
		BaseParts = 0,
		MeshParts = 0,
		SpecialMeshes = 0,
		Decals = 0,
		Textures = 0,
		Scripts = 0,
		ClickDetectors = 0,
		VfxElementCount = 0,
	}

	local function inspect(instance)
		if instance:IsA("ParticleEmitter") then
			info.ParticleEmitters += 1
			info.VfxElementCount += 1
		elseif instance:IsA("Sound") then
			info.Sounds += 1
			info.VfxElementCount += 1
		elseif instance:IsA("Beam") then
			info.Beams += 1
			info.VfxElementCount += 1
		elseif instance:IsA("Trail") then
			info.Trails += 1
			info.VfxElementCount += 1
		elseif isLightInstance(instance) then
			info.Lights += 1
			info.VfxElementCount += 1
		elseif instance:IsA("MeshPart") then
			info.MeshParts += 1
			info.BaseParts += 1
			info.VfxElementCount += 1
		elseif instance:IsA("BasePart") then
			info.BaseParts += 1
		elseif instance:IsA("SpecialMesh") then
			info.SpecialMeshes += 1
			info.VfxElementCount += 1
		elseif instance:IsA("Decal") then
			info.Decals += 1
			info.VfxElementCount += 1
		elseif instance:IsA("Texture") then
			info.Textures += 1
			info.VfxElementCount += 1
		elseif isScriptInstance(instance) then
			info.Scripts += 1
		elseif instance:IsA("ClickDetector") then
			info.ClickDetectors += 1
		end
	end

	inspect(rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		inspect(descendant)
	end

	return info
end

local function formatInfo(info)
	return "ParticleEmitters="
		.. tostring(info.ParticleEmitters)
		.. " Sounds="
		.. tostring(info.Sounds)
		.. " Beams="
		.. tostring(info.Beams)
		.. " Trails="
		.. tostring(info.Trails)
		.. " Lights="
		.. tostring(info.Lights)
		.. " BaseParts="
		.. tostring(info.BaseParts)
		.. " Scripts="
		.. tostring(info.Scripts)
		.. " ClickDetectors="
		.. tostring(info.ClickDetectors)
end

local function looksLikeDonor(instance)
	local lowerName = string.lower(instance.Name)

	return string.find(lowerName, "donor", 1, true) ~= nil
		or string.find(lowerName, "backup", 1, true) ~= nil
		or string.find(lowerName, "quarantine", 1, true) ~= nil
		or string.find(lowerName, "unclassified", 1, true) ~= nil
		or string.find(lowerName, "resources explosion", 1, true) ~= nil
end

local vfxFolder = findVfxFolder()

if vfxFolder == nil then
	warn("[VFX AUDIT] Missing ReplicatedStorage.Shared.Assets.VFX")
	return
end

print("[VFX AUDIT] Folder: " .. vfxFolder:GetFullName())

for _, templateName in ipairs(EXPECTED_TEMPLATES) do
	local template = vfxFolder:FindFirstChild(templateName)

	if template == nil then
		warn("[VFX AUDIT] Missing " .. templateName)
	else
		local info = collectInfo(template)
		print("[VFX AUDIT] Present " .. templateName .. " " .. template.ClassName .. " " .. formatInfo(info))

		if info.VfxElementCount <= 0 then
			warn("[VFX AUDIT] Empty template " .. template:GetFullName())
		end

		if info.Scripts > 0 then
			warn("[VFX AUDIT] Template has scripts " .. template:GetFullName() .. " count=" .. tostring(info.Scripts))
		end

		if info.ClickDetectors > 0 then
			warn("[VFX AUDIT] Template has ClickDetector " .. template:GetFullName() .. " count=" .. tostring(info.ClickDetectors))
		end
	end
end

for _, child in ipairs(vfxFolder:GetChildren()) do
	if child:IsA("ModuleScript") and child.Name == "VfxTemplateCatalog" then
		print("[VFX AUDIT] Catalog module present: " .. child:GetFullName())
	elseif looksLikeDonor(child) then
		warn("[VFX AUDIT] Donor object in final folder " .. child:GetFullName())
	else
		local info = collectInfo(child)

		if info.Scripts > 0 then
			warn("[VFX AUDIT] Template has scripts " .. child:GetFullName() .. " count=" .. tostring(info.Scripts))
		end

		if info.ClickDetectors > 0 then
			warn("[VFX AUDIT] Template has ClickDetector " .. child:GetFullName() .. " count=" .. tostring(info.ClickDetectors))
		end

		if not child:IsA("ModuleScript") and info.VfxElementCount <= 0 then
			warn("[VFX AUDIT] Empty or non-VFX child in final folder " .. child:GetFullName())
		end
	end
end

print("[VFX AUDIT] Remember to Save to File as .rbxmx for each real template under src/ReplicatedStorage/Shared/Assets/VFX/<TemplateName>.rbxmx")
print("[VFX AUDIT] Studio cannot reliably prove filesystem persistence from this command script; verify the .rbxmx files in Git before commit.")
