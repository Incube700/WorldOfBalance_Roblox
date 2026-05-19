-- Roblox Studio Command Bar helper.
-- Audits WOB asset/runtime folder hygiene without moving or deleting anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function printStatus(label, instance)
	if instance == nil then
		warn("[WOB FOLDER AUDIT] missing " .. label)
	else
		print("[WOB FOLDER AUDIT] ok " .. label .. " -> " .. instance:GetFullName())
	end
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

local shared = ReplicatedStorage:FindFirstChild("Shared")
local assets = shared ~= nil and shared:FindFirstChild("Assets") or nil
local vfx = assets ~= nil and assets:FindFirstChild("VFX") or nil
local ui = assets ~= nil and assets:FindFirstChild("UI") or nil
local wobRuntime = Workspace:FindFirstChild("WOB_Runtime")
local runtimeVfx = wobRuntime ~= nil and wobRuntime:FindFirstChild("VFX") or nil
local runtimeClient = wobRuntime ~= nil and wobRuntime:FindFirstChild("Client") or nil
local healthBarAnchors = runtimeClient ~= nil and runtimeClient:FindFirstChild("HealthBarAnchors") or nil
local donors = Workspace:FindFirstChild("WOB_EditorOnly_AssetDonors")

printStatus("ReplicatedStorage.Shared.Assets.VFX", vfx)
printStatus("ReplicatedStorage.Shared.Assets.UI", ui)
printStatus("Workspace.WOB_Runtime.VFX", runtimeVfx)
printStatus("Workspace.WOB_Runtime.Client", runtimeClient)
printStatus("Workspace.WOB_Runtime.Client.HealthBarAnchors", healthBarAnchors)
printStatus("Workspace.WOB_EditorOnly_AssetDonors", donors)

local orphanPaths = {
	{ ReplicatedStorage, { "Assets" } },
	{ ReplicatedStorage, { "VFX" } },
	{ ReplicatedStorage, { "UI" } },
	{ shared, { "VFX" } },
	{ shared, { "UI" } },
	{ Workspace, { "Assets" } },
	{ Workspace, { "VFX" } },
	{ Workspace, { "Runtime" } },
	{ Workspace, { "Client" } },
	{ Workspace, { "HealthBarAnchors" } },
	{ Workspace, { "WOB_ClientHealthBarAnchors" } },
	{ Workspace, { "WOBLocalDamageFlash" } },
	{ Workspace, { "WOB_LocalVisuals" } },
}

local orphanCount = 0

for _, pathInfo in ipairs(orphanPaths) do
	local root = pathInfo[1]
	local pathParts = pathInfo[2]
	local instance = root ~= nil and findPath(root, pathParts) or nil

	if instance ~= nil then
		orphanCount += 1
		warn("[WOB FOLDER AUDIT] orphan candidate " .. instance:GetFullName())
	end
end

local generated = Workspace:FindFirstChild("WOB_Generated")
local legacyRuntime = generated ~= nil and generated:FindFirstChild("Runtime") or nil
local legacyRuntimeVfx = legacyRuntime ~= nil and legacyRuntime:FindFirstChild("VFX") or nil

if legacyRuntimeVfx ~= nil then
	warn("[WOB FOLDER AUDIT] legacy runtime VFX candidate " .. legacyRuntimeVfx:GetFullName() .. " (new VFX runtime is Workspace.WOB_Runtime.VFX)")
	orphanCount += 1
end

print("[WOB FOLDER AUDIT] complete orphanCandidates=" .. tostring(orphanCount) .. ". No objects were changed.")
