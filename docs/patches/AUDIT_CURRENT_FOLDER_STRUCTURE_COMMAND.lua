-- Roblox Studio Command Bar helper.
-- Audit-only: prints WOB asset/runtime folder structure without moving or deleting anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SUSPICIOUS_ROOT_NAMES = {
	Assets = true,
	UI = true,
	VFX = true,
	UX = true,
	Runtime = true,
}

local function childNames(instance)
	if instance == nil then
		return "<missing>"
	end

	local names = {}

	for _, child in ipairs(instance:GetChildren()) do
		table.insert(names, child.Name .. ":" .. child.ClassName)
	end

	table.sort(names)
	return table.concat(names, ", ")
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

local function printPath(label, instance)
	if instance == nil then
		warn("[WOB FOLDER AUDIT] missing " .. label)
	else
		print("[WOB FOLDER AUDIT] " .. label .. " -> " .. instance:GetFullName())
	end
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil
local runtime = Workspace:FindFirstChild("WOB_Runtime")
local runtimeClient = runtime ~= nil and runtime:FindFirstChild("Client") or nil
local donors = Workspace:FindFirstChild("WOB_EditorOnly_AssetDonors")

print("[WOB FOLDER AUDIT] ReplicatedStorage children: " .. childNames(ReplicatedStorage))
print("[WOB FOLDER AUDIT] ReplicatedStorage.Shared.Assets children: " .. childNames(assets))
print("[WOB FOLDER AUDIT] Workspace.WOB_Runtime children: " .. childNames(runtime))
print("[WOB FOLDER AUDIT] Workspace.WOB_Runtime.Client children: " .. childNames(runtimeClient))
print("[WOB FOLDER AUDIT] Workspace.WOB_EditorOnly_AssetDonors children: " .. childNames(donors))

printPath("ReplicatedStorage.Shared.Assets.UI", assets ~= nil and assets:FindFirstChild("UI") or nil)
printPath("ReplicatedStorage.Shared.Assets.VFX", assets ~= nil and assets:FindFirstChild("VFX") or nil)
printPath("Workspace.WOB_Runtime.VFX", runtime ~= nil and runtime:FindFirstChild("VFX") or nil)
printPath("Workspace.WOB_Runtime.Client.HealthBarAnchors", findPath(Workspace, { "WOB_Runtime", "Client", "HealthBarAnchors" }))
printPath("Workspace.WOB_Runtime.Client.Visuals", findPath(Workspace, { "WOB_Runtime", "Client", "Visuals" }))
printPath("Workspace.WOB_EditorOnly_AssetDonors.OrphanBackups", findPath(Workspace, { "WOB_EditorOnly_AssetDonors", "OrphanBackups" }))

local unexpectedCount = 0

for _, child in ipairs(ReplicatedStorage:GetChildren()) do
	if SUSPICIOUS_ROOT_NAMES[child.Name] == true then
		unexpectedCount += 1
		warn("[WOB FOLDER AUDIT] unexpected ReplicatedStorage." .. child.Name)
	end
end

for _, child in ipairs(Workspace:GetChildren()) do
	if SUSPICIOUS_ROOT_NAMES[child.Name] == true then
		unexpectedCount += 1
		warn("[WOB FOLDER AUDIT] unexpected Workspace." .. child.Name)
	end
end

local sharedUnexpected = {
	findPath(ReplicatedStorage, { "Shared", "UI" }),
	findPath(ReplicatedStorage, { "Shared", "VFX" }),
	findPath(ReplicatedStorage, { "Shared", "UX" }),
}

for _, instance in ipairs(sharedUnexpected) do
	if instance ~= nil then
		unexpectedCount += 1
		warn("[WOB FOLDER AUDIT] unexpected " .. instance:GetFullName())
	end
end

local legacyCandidates = {
	findPath(Workspace, { "WOB_ClientHealthBarAnchors" }),
	findPath(Workspace, { "WOBLocalDamageFlash" }),
	findPath(Workspace, { "WOB_LocalVisuals" }),
	findPath(Workspace, { "WOB_Generated", "Runtime", "VFX" }),
	findPath(Workspace, { "WOB_Runtime", "Client", "LocalVisuals" }),
}

for _, instance in ipairs(legacyCandidates) do
	if instance ~= nil then
		unexpectedCount += 1
		warn("[WOB FOLDER AUDIT] legacy folder candidate " .. instance:GetFullName())
	end
end

print("[WOB FOLDER AUDIT] complete unexpectedOrLegacy=" .. tostring(unexpectedCount) .. ". No objects were changed.")
