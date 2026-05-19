-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Sanitizes VFX templates so cloned effects do not run donor scripts.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[VFX CLEAN] Run this command outside Play Mode.")
	return
end

local removedCount = 0
local sanitizedPartCount = 0
local disabledEmitterCount = 0

local function sanitizeInstanceTree(root)
	local descendants = root:GetDescendants()

	for _, descendant in ipairs(descendants) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			print("[VFX CLEAN] Removed " .. descendant.ClassName .. " " .. descendant:GetFullName())
			descendant:Destroy()
			removedCount += 1
		elseif descendant:IsA("ClickDetector") then
			print("[VFX CLEAN] Removed ClickDetector " .. descendant:GetFullName())
			descendant:Destroy()
			removedCount += 1
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			sanitizedPartCount += 1
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			disabledEmitterCount += 1
		end
	end

	if root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
		root.CanQuery = false
		sanitizedPartCount += 1
	elseif root:IsA("ParticleEmitter") then
		root.Enabled = false
		disabledEmitterCount += 1
	end
end

local function sanitizeVfxFolder(vfxFolder, label)
	if vfxFolder == nil then
		warn("[VFX CLEAN] " .. label .. " not found.")
		return
	end

	for _, template in ipairs(vfxFolder:GetChildren()) do
		if template:IsA("ModuleScript") then
			print("[VFX CLEAN] Skipped root ModuleScript " .. template:GetFullName())
		elseif template:IsA("Script") or template:IsA("LocalScript") then
			print("[VFX CLEAN] Removed " .. template.ClassName .. " " .. template:GetFullName())
			template:Destroy()
			removedCount += 1
		elseif template:IsA("ClickDetector") then
			print("[VFX CLEAN] Removed ClickDetector " .. template:GetFullName())
			template:Destroy()
			removedCount += 1
		else
			sanitizeInstanceTree(template)
			print("[VFX CLEAN] " .. template.Name .. " clean")
		end
	end
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil
local vfxTemplates = assets ~= nil and assets:FindFirstChild("VFX") or nil

sanitizeVfxFolder(vfxTemplates, "ReplicatedStorage.Shared.Assets.VFX")

local wobRuntime = Workspace:FindFirstChild("WOB_Runtime")
local runtimeVfx = wobRuntime ~= nil and wobRuntime:FindFirstChild("VFX") or nil

if runtimeVfx ~= nil then
	sanitizeVfxFolder(runtimeVfx, "Workspace.WOB_Runtime.VFX")
end

local generatedRoot = Workspace:FindFirstChild("WOB_Generated")
local legacyRuntime = generatedRoot ~= nil and generatedRoot:FindFirstChild("Runtime") or nil
local legacyRuntimeVfx = legacyRuntime ~= nil and legacyRuntime:FindFirstChild("VFX") or nil

if legacyRuntimeVfx ~= nil then
	sanitizeVfxFolder(legacyRuntimeVfx, "Workspace.WOB_Generated.Runtime.VFX legacy")
end

print(
	"[VFX CLEAN] Complete. removed="
		.. tostring(removedCount)
		.. " sanitizedParts="
		.. tostring(sanitizedPartCount)
		.. " disabledEmitters="
		.. tostring(disabledEmitterCount)
		.. ". File -> Save to File."
)
