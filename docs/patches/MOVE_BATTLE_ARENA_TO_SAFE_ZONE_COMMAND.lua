-- One-time Roblox Studio Command Bar helper.
-- Run outside Play Mode. Moves the existing BattleArena as a whole into a safe XZ zone.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if RunService:IsRunning() then
	warn("[ARENA MOVE] Run this command outside Play Mode.")
	return
end

local ROOT_NAME = "WOB_Generated"
local DEFAULT_SAFE_CENTER = Vector3.new(-340, 0, 320)

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "nil"
	end

	return ("(%.1f, %.1f, %.1f)"):format(vector.X, vector.Y, vector.Z)
end

local function collectBaseParts(root)
	local parts = {}

	if root:IsA("BasePart") then
		table.insert(parts, root)
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function getPartsBounds(parts)
	if #parts == 0 then
		return nil, nil
	end

	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5
		minX = math.min(minX, part.Position.X - halfSize.X)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)
	end

	local minVector = Vector3.new(minX, minY, minZ)
	local maxVector = Vector3.new(maxX, maxY, maxZ)

	return CFrame.new((minVector + maxVector) * 0.5), maxVector - minVector
end

local function getSafeCenterFromConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configs = shared ~= nil and shared:FindFirstChild("Configs") or nil
	local configModule = configs ~= nil and configs:FindFirstChild("BattleArenaConfig") or nil

	if configModule ~= nil and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)

		if ok and typeof(config) == "table" and typeof(config.SafeArenaCenter) == "Vector3" then
			return config.SafeArenaCenter
		end
	end

	return DEFAULT_SAFE_CENTER
end

local function findFloor(battleArena)
	local floor = battleArena:FindFirstChild("Floor")

	if floor ~= nil and floor:IsA("BasePart") then
		return floor
	end

	return nil
end

local root = Workspace:FindFirstChild(ROOT_NAME)

if root == nil then
	warn("[ARENA MOVE] Workspace/" .. ROOT_NAME .. " was not found.")
	return
end

local battleArena = root:FindFirstChild("BattleArena")

if battleArena == nil then
	warn("[ARENA MOVE] Workspace/" .. ROOT_NAME .. "/BattleArena was not found.")
	return
end

local parts = collectBaseParts(battleArena)

if #parts == 0 then
	warn("[ARENA MOVE] BattleArena has no BasePart descendants.")
	return
end

local floor = findFloor(battleArena)
local currentCenter = nil

if floor ~= nil then
	currentCenter = Vector3.new(floor.Position.X, floor.Position.Y + floor.Size.Y * 0.5, floor.Position.Z)
else
	local boundsCFrame = getPartsBounds(parts)
	currentCenter = boundsCFrame ~= nil and boundsCFrame.Position or nil
end

if typeof(currentCenter) ~= "Vector3" then
	warn("[ARENA MOVE] Could not estimate BattleArena center.")
	return
end

local safeConfigCenter = getSafeCenterFromConfig()
local targetCenter = Vector3.new(safeConfigCenter.X, currentCenter.Y, safeConfigCenter.Z)
local delta = targetCenter - currentCenter

if delta.Magnitude < 0.01 then
	print("[ARENA MOVE] BattleArena already at safe center " .. formatVector3(currentCenter))
	return
end

print("[ARENA MOVE] BattleArena oldCenter=" .. formatVector3(currentCenter) .. " targetCenter=" .. formatVector3(targetCenter) .. " delta=" .. formatVector3(delta))

for _, part in ipairs(parts) do
	part.CFrame = part.CFrame + delta
end

battleArena:SetAttribute("ArenaCenter", targetCenter)

local boundsCFrame, boundsSize = getPartsBounds(parts)
print("[ARENA MOVE] Moved " .. tostring(#parts) .. " parts. New boundsCenter=" .. formatVector3(boundsCFrame ~= nil and boundsCFrame.Position or nil) .. " boundsSize=" .. formatVector3(boundsSize))
print("[ARENA MOVE] Next: run docs/patches/AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua and docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua, then File -> Save to File.")
