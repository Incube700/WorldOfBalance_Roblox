local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

Players.CharacterAutoLoads = false

local LEGACY_INPUT_CONTROLLER_NAME = "WOBClientController"
local DEBUG_BOOTSTRAP = false
local REMOTE_EVENT_NAMES = {
	"TankInputEvent",
	"ShootRequestEvent",
	"ResetDummyRequestEvent",
	"StartMatchRequestEvent",
	"ReturnToMenuRequestEvent",
	"CombatFeedbackEvent",
	"RematchRequestEvent",
}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function ensureRemoteEvent(parent, name)
	local remoteEvent = parent:FindFirstChild(name)

	if remoteEvent == nil then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = name
		remoteEvent.Parent = parent
	end

	return remoteEvent
end

local function disableLegacyInputController(instance)
	if instance == nil or not instance:IsA("LocalScript") or instance.Name ~= LEGACY_INPUT_CONTROLLER_NAME then
		return
	end

	if instance.Enabled ~= false then
		instance.Enabled = false
		if DEBUG_BOOTSTRAP then
			print("[PVP] legacy input controller disabled: " .. instance.Name)
		end
	end
end

local function disableLegacyInputControllersIn(container)
	if container == nil then
		return
	end

	disableLegacyInputController(container:FindFirstChild(LEGACY_INPUT_CONTROLLER_NAME))

	for _, descendant in ipairs(container:GetDescendants()) do
		disableLegacyInputController(descendant)
	end
end

local remotes = ensureFolder(ReplicatedStorage, "Remotes")

for _, remoteName in ipairs(REMOTE_EVENT_NAMES) do
	ensureRemoteEvent(remotes, remoteName)
end

if DEBUG_BOOTSTRAP then
	print("[PVP] remotes bootstrapped")
end

local root = Workspace:FindFirstChild("WOB_Generated") or Workspace:WaitForChild("WOB_Generated", 20)

if root == nil then
	warn("[PVP] runtime folders bootstrap skipped: Workspace/WOB_Generated was not found")
else
	local runtime = ensureFolder(root, "Runtime")
	ensureFolder(runtime, "Projectiles")
	ensureFolder(runtime, "VFX")
	if DEBUG_BOOTSTRAP then
		print("[PVP] runtime folders bootstrapped")
	end
end

local starterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")

if starterPlayerScripts ~= nil then
	disableLegacyInputControllersIn(starterPlayerScripts)
	starterPlayerScripts.DescendantAdded:Connect(disableLegacyInputController)
end

local function suppressCharacter(player, character)
	if character == nil then
		return
	end

	if character:GetAttribute("WOBCharacterSuppressed") == true then
		return
	end

	character:SetAttribute("WOBCharacterSuppressed", true)

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid ~= nil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Anchored = true
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end

	pcall(function()
		character:PivotTo(CFrame.new(0, -10000, 0))
	end)

	pcall(function()
		character:Destroy()
	end)

	if DEBUG_BOOTSTRAP then
		print("[PVP] character removed/suppressed for " .. player.Name)
	end
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(suppressCharacter, player, character)
	end)

	if player.Character ~= nil then
		task.defer(suppressCharacter, player, player.Character)
	end

	task.defer(function()
		local playerScripts = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 10)

		if playerScripts == nil then
			return
		end

		disableLegacyInputControllersIn(playerScripts)
		playerScripts.DescendantAdded:Connect(disableLegacyInputController)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerAdded:Connect(watchPlayer)
