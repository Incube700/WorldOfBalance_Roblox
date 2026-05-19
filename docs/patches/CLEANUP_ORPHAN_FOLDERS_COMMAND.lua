-- Roblox Studio Command Bar helper.
-- Moves reviewed orphan folders into Workspace.WOB_EditorOnly_AssetDonors.OrphanBackups.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] Cleanup is disabled. Run audit first and enable manually only after review.")
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if RunService:IsRunning() then
	warn("[WOB FOLDER CLEAN] Run this command outside Play Mode.")
	return
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		warn("[WOB FOLDER CLEAN] " .. folder:GetFullName() .. " is " .. folder.ClassName .. ", expected Folder.")
		return nil
	end

	return folder
end

local function findPath(root, pathParts)
	local current = root

	for _, name in ipairs(pathParts) do
		if current == nil then
			return nil
		end

		current = current:FindFirstChild(name)
	end

	return current
end

local function uniqueName(parent, baseName)
	local candidate = baseName
	local index = 1

	while parent:FindFirstChild(candidate) ~= nil do
		index += 1
		candidate = baseName .. "_" .. tostring(index)
	end

	return candidate
end

local donors = getOrCreateFolder(Workspace, "WOB_EditorOnly_AssetDonors")
local backups = donors ~= nil and getOrCreateFolder(donors, "OrphanBackups") or nil

if backups == nil then
	return
end

local function moveFolder(instance, reason)
	if instance == nil then
		return false
	end

	if not instance:IsA("Folder") then
		warn("[WOB FOLDER CLEAN] skipped non-folder " .. instance:GetFullName())
		return false
	end

	if instance == backups or instance:IsDescendantOf(backups) then
		return false
	end

	local originalPath = instance:GetFullName()
	instance:SetAttribute("WOBOrphanOriginalPath", originalPath)
	instance:SetAttribute("WOBOrphanReason", reason)
	instance.Name = uniqueName(backups, instance.Name .. "_Orphan")
	instance.Parent = backups
	print("[WOB FOLDER CLEAN] moved " .. originalPath .. " -> " .. instance:GetFullName() .. " reason=" .. reason)
	return true
end

local shared = ReplicatedStorage:FindFirstChild("Shared")

local orphanSpecs = {
	{ ReplicatedStorage, { "Assets" }, "ReplicatedStorage.Assets outside Shared.Assets" },
	{ ReplicatedStorage, { "UI" }, "ReplicatedStorage.UI outside Shared.Assets" },
	{ ReplicatedStorage, { "VFX" }, "ReplicatedStorage.VFX outside Shared.Assets" },
	{ ReplicatedStorage, { "UX" }, "ReplicatedStorage.UX outside Shared.Assets" },
	{ shared, { "UI" }, "ReplicatedStorage.Shared.UI outside Shared.Assets" },
	{ shared, { "VFX" }, "ReplicatedStorage.Shared.VFX outside Shared.Assets" },
	{ shared, { "UX" }, "ReplicatedStorage.Shared.UX outside Shared.Assets" },
	{ Workspace, { "Assets" }, "Workspace.Assets should not hold WOB assets" },
	{ Workspace, { "UI" }, "Workspace.UI should not hold WOB UI" },
	{ Workspace, { "VFX" }, "Workspace.VFX should use Workspace.WOB_Runtime.VFX" },
	{ Workspace, { "UX" }, "Workspace.UX should not hold WOB UI" },
	{ Workspace, { "Runtime" }, "Workspace.Runtime should use Workspace.WOB_Runtime" },
	{ Workspace, { "Client" }, "Workspace.Client should use Workspace.WOB_Runtime.Client" },
	{ Workspace, { "HealthBarAnchors" }, "health anchors should use Workspace.WOB_Runtime.Client.HealthBarAnchors" },
	{ Workspace, { "WOB_ClientHealthBarAnchors" }, "legacy health anchors should use Workspace.WOB_Runtime.Client.HealthBarAnchors" },
	{ Workspace, { "WOBLocalDamageFlash" }, "damage flash should use Workspace.WOB_Runtime.Client.Visuals.DamageFlash" },
	{ Workspace, { "WOB_LocalVisuals" }, "local visuals should use Workspace.WOB_Runtime.Client.Visuals" },
	{ Workspace, { "WOB_Runtime", "Client", "LocalVisuals" }, "legacy local visuals should use Workspace.WOB_Runtime.Client.Visuals" },
	{ Workspace, { "WOB_Generated", "Runtime", "VFX" }, "legacy runtime VFX should use Workspace.WOB_Runtime.VFX" },
}

local movedCount = 0

for _, spec in ipairs(orphanSpecs) do
	local root = spec[1]
	local pathParts = spec[2]
	local reason = spec[3]
	local instance = root ~= nil and findPath(root, pathParts) or nil

	if moveFolder(instance, reason) then
		movedCount += 1
	end
end

print("[WOB FOLDER CLEAN] complete moved=" .. tostring(movedCount) .. ". File -> Save to File after reviewing backups.")
