-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode if ReplicatedStorage/Shared/Assets/VFX is missing before adding Toolbox templates.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[WOB VFX] Run this command outside Play Mode.")
	return
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil then
		if not existing:IsA(className) then
			warn(("[WOB VFX] %s exists but is %s, expected %s."):format(existing:GetFullName(), existing.ClassName, className))
			return nil
		end

		print("[WOB VFX] Kept " .. existing:GetFullName())
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	print("[WOB VFX] Created " .. instance:GetFullName())
	return instance
end

local shared = getOrCreate(ReplicatedStorage, "Folder", "Shared")

if shared == nil then
	return
end

local assets = getOrCreate(shared, "Folder", "Assets")

if assets == nil then
	return
end

local vfx = getOrCreate(assets, "Folder", "VFX")

if vfx == nil then
	return
end

print("[WOB VFX] VFX template folder ready at ReplicatedStorage/Shared/Assets/VFX. Add Toolbox templates there, then File -> Save to File.")
