-- WOBWeaponHud (Update 0.2): tiny weapon/ammo readout for temporary pickup weapons.
-- Shows nothing while the default cannon is active; appears only while a pickup
-- weapon is held, then hides again on revert. Positioned at the top of the screen
-- so it does not overlap mobile controls (bottom of screen) or upgrade cards (which
-- pop up around the center).

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WOBWeaponHud"
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "WeaponFrame"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 12)
frame.Size = UDim2.new(0, 220, 0, 36)
frame.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 200, 240)
stroke.Thickness = 1
stroke.Transparency = 0.4
stroke.Parent = frame

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "WeaponName"
nameLabel.AnchorPoint = Vector2.new(0, 0.5)
nameLabel.Position = UDim2.new(0, 12, 0.5, 0)
nameLabel.Size = UDim2.new(1, -80, 1, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = ""
nameLabel.TextColor3 = Color3.fromRGB(230, 240, 255)
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextYAlignment = Enum.TextYAlignment.Center
nameLabel.Font = Enum.Font.GothamMedium
nameLabel.TextSize = 16
nameLabel.Parent = frame

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "WeaponAmmo"
ammoLabel.AnchorPoint = Vector2.new(1, 0.5)
ammoLabel.Position = UDim2.new(1, -12, 0.5, 0)
ammoLabel.Size = UDim2.new(0, 70, 1, 0)
ammoLabel.BackgroundTransparency = 1
ammoLabel.Text = ""
ammoLabel.TextColor3 = Color3.fromRGB(255, 230, 130)
ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
ammoLabel.TextYAlignment = Enum.TextYAlignment.Center
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 16
ammoLabel.Parent = frame

local function refresh()
	local isTemporary = localPlayer:GetAttribute("ArenaWeaponIsTemporary") == true
	frame.Visible = isTemporary

	if not isTemporary then
		return
	end

	local name = localPlayer:GetAttribute("ArenaWeaponName")
	local ammo = localPlayer:GetAttribute("ArenaWeaponAmmo")

	nameLabel.Text = tostring(name or "")
	if typeof(ammo) == "number" and ammo > 0 then
		ammoLabel.Text = ("x%d"):format(ammo)
	else
		ammoLabel.Text = ""
	end
end

refresh()
localPlayer:GetAttributeChangedSignal("ArenaWeaponIsTemporary"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("ArenaWeaponName"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("ArenaWeaponAmmo"):Connect(refresh)
