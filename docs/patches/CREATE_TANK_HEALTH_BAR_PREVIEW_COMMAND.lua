-- Run this in Studio Command Bar outside Play Mode.
-- Creates a disposable world preview clone for ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard.

local ENABLE_MUTATION = false

if ENABLE_MUTATION ~= true then
	warn("[DISABLED PATCH] This script can overwrite manually tuned scene/UI/VFX. Read docs/SAFE_PATCH_WORKFLOW.md and set ENABLE_MUTATION=true manually if you really need it.")
	return
end


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PREVIEW_PART_NAME = "HPBarPreviewPart"
local PREVIEW_CLONE_NAME = "TankHealthBillboardPreview"

local function getRequired(parent, name)
	local child = parent:FindFirstChild(name)

	if child == nil then
		error(parent:GetFullName() .. "." .. name .. " was not found")
	end

	return child
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		error(parent:GetFullName() .. "." .. name .. " exists but is " .. folder.ClassName .. ", expected Folder")
	end

	return folder
end

local function getPreviewCFrame()
	local camera = Workspace.CurrentCamera

	if camera ~= nil then
		return camera.CFrame * CFrame.new(0, -1.25, -14)
	end

	local generated = Workspace:FindFirstChild("WOB_Generated")
	local lobby = generated ~= nil and generated:FindFirstChild("Lobby") or nil

	if lobby ~= nil then
		return lobby:GetPivot() * CFrame.new(0, 4, -18)
	end

	return CFrame.new(0, 6, -18)
end

local shared = getRequired(ReplicatedStorage, "Shared")
local assets = getRequired(shared, "Assets")
local ui = getRequired(assets, "UI")
local template = getRequired(ui, "TankHealthBillboard")

if not template:IsA("BillboardGui") then
	error(template:GetFullName() .. " is " .. template.ClassName .. ", expected BillboardGui")
end

local debugFolder = getOrCreateFolder(Workspace, "WOB_Debug")
local previewFolder = getOrCreateFolder(debugFolder, "UiPreview")

for _, child in ipairs(previewFolder:GetChildren()) do
	child:Destroy()
end

local previewPart = Instance.new("Part")
previewPart.Name = PREVIEW_PART_NAME
previewPart.Anchored = true
previewPart.CanCollide = false
previewPart.CanQuery = false
previewPart.CanTouch = false
previewPart.Color = Color3.fromRGB(80, 120, 180)
previewPart.Material = Enum.Material.Neon
previewPart.Size = Vector3.new(4, 0.35, 4)
previewPart.Transparency = 0.35
previewPart.CFrame = getPreviewCFrame()
previewPart.Parent = previewFolder

local previewClone = template:Clone()
previewClone.Name = PREVIEW_CLONE_NAME
previewClone.Adornee = previewPart
previewClone.Parent = previewPart

print("[HP BAR PREVIEW] Preview clone created at", previewPart:GetFullName())
print("[HP BAR PREVIEW] Edit template in ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard, then rerun preview.")
