local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local utils = shared:WaitForChild("Utils")
local MobileControlsConfig = require(configs:WaitForChild("MobileControlsConfig"))
local CameraConfig = require(configs:WaitForChild("CameraConfig"))
local WeaponConfig = require(configs:WaitForChild("WeaponConfig"))
local TankModelResolver = require(utils:WaitForChild("TankModelResolver"))
local WOBClientInputState = require(script.Parent:WaitForChild("Input"):WaitForChild("WOBClientInputState"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local root = Workspace:WaitForChild("WOB_Generated")

local GUI_NAME = "WOBMobileControls"
local LEFT_STICK_BASE_NAME = "LeftStickBase"
local LEFT_STICK_KNOB_NAME = "LeftStickKnob"
local RIGHT_AIM_BASE_NAME = "RightAimBase"
local RIGHT_AIM_KNOB_NAME = "RightAimKnob"
local FIRE_BUTTON_NAME = "FireButton"
local REVERSE_BUTTON_NAME = "ReverseButton"
local DEBUG_AIM_AREA_NAME = "AimAreaDebugOverlay"
local DESKTOP_HINT_TEXT_PATTERNS = {
	"w/s",
	"a/d",
	"wasd",
	"mouse",
	"lmb",
	"keyboard",
}

local PLAYER_MODE_LOBBY = "Lobby"
local PLAYER_MODE_QUEUED = "QueuedForDuel"
local PLAYER_MODE_IN_MATCH = "InMatch"
local PLAYER_MODE_RESULT = "Result"
local PLAYER_MODE_IN_BATTLE_ARENA = "InBattleArena"

local leftStickConfig = MobileControlsConfig.LeftStick or {}
local aimAreaConfig = MobileControlsConfig.AimArea or {}
local rightAimStickConfig = MobileControlsConfig.RightAimStick or {}
local fireButtonConfig = MobileControlsConfig.FireButton or {}
local reverseButtonConfig = MobileControlsConfig.ReverseButton or {}
local arcadeConfig = MobileControlsConfig.BattleArenaArcade or {}
local primaryWeaponConfig = WeaponConfig.PrimaryWeapon or {}

local STICK_RELEASE_MAGNITUDE = 0.1
local ARCADE_FULL_STEER_ANGLE = math.rad(90)
local ARCADE_SLOW_TURN_ANGLE = math.rad(45)
local ARCADE_HARD_TURN_ANGLE = math.rad(120)
local ARCADE_SLOW_TURN_THROTTLE_SCALE = 0.45
local ARCADE_HARD_TURN_THROTTLE_SCALE = 0.15
local function getPositiveNumber(value, fallback)
	local number = tonumber(value)

	if number == nil or number <= 0 then
		return fallback
	end

	return number
end

local function getOffsetButtonSize(size, fallback)
	if typeof(size) ~= "UDim2" then
		return fallback
	end

	if size.X.Scale ~= 0 or size.Y.Scale ~= 0 or size.X.Offset <= 0 or size.Y.Offset <= 0 then
		return fallback
	end

	return size
end

-- Joystick comfort tuning (Task B). Scales enlarge the stick visuals and the drag range.
local joystickConfig = MobileControlsConfig.Joystick or {}
local JOYSTICK_VISUAL_SCALE = math.clamp(tonumber(joystickConfig.VisualScale) or 1, 1, 1.6)
local JOYSTICK_TOUCH_AREA_SCALE = math.clamp(tonumber(joystickConfig.TouchAreaScale) or 1, 1, 1.6)
local FLOATING_JOYSTICKS_ENABLED = joystickConfig.FloatingEnabled ~= false
local FLOATING_ACTIVATION_MIN_Y_SCALE = math.clamp(tonumber(joystickConfig.FloatingActivationMinYScale) or 0.32, 0, 0.95)

local LEFT_STICK_SIZE = math.floor(math.clamp(getPositiveNumber(leftStickConfig.BaseSize, 110), 96, 168) * JOYSTICK_VISUAL_SCALE)
local LEFT_STICK_KNOB_SIZE = math.clamp(math.floor(getPositiveNumber(leftStickConfig.ThumbSize, 46) * JOYSTICK_VISUAL_SCALE), 40, LEFT_STICK_SIZE - 28)
local RIGHT_AIM_SIZE = math.floor(math.clamp(getPositiveNumber(rightAimStickConfig.BaseSize, 116), 96, 168) * JOYSTICK_VISUAL_SCALE)
local RIGHT_AIM_KNOB_SIZE = math.clamp(math.floor(getPositiveNumber(rightAimStickConfig.ThumbSize, 44) * JOYSTICK_VISUAL_SCALE), 40, RIGHT_AIM_SIZE - 28)
local FIRE_BUTTON_SIZE = 78
local REVERSE_BUTTON_SIZE = 58
local LEFT_STICK_INPUT_MAX_DISTANCE = math.floor(55 * JOYSTICK_TOUCH_AREA_SCALE)
local RIGHT_AIM_INPUT_MAX_DISTANCE = math.floor(58 * JOYSTICK_TOUCH_AREA_SCALE)
-- Gameplay touch layout convention:
-- Move stays bottom-left, REV sits in the right thumb area without overlapping
-- AIM/FIRE, Aim stays in the lower-right control area, Fire stays bottom-right,
-- and Menu/Pause is owned by gameplay HUDs in the top-right safe area.

local stickRadius = LEFT_STICK_SIZE / 2
local stickMaxDistance = math.min(
	tonumber(leftStickConfig.MaxDistance) or LEFT_STICK_INPUT_MAX_DISTANCE,
	LEFT_STICK_INPUT_MAX_DISTANCE
)
local stickDeadZone = math.clamp(tonumber(leftStickConfig.DeadZone) or 0.12, 0, 0.95)
local leftStickLabel = tostring(leftStickConfig.Label or "MOVE")
local rightAimRadius = RIGHT_AIM_SIZE / 2
local rightAimMaxDistance = math.min(
	tonumber(rightAimStickConfig.MaxDistance) or RIGHT_AIM_INPUT_MAX_DISTANCE,
	RIGHT_AIM_INPUT_MAX_DISTANCE
)
local rightAimDeadZone = math.clamp(tonumber(rightAimStickConfig.DeadZone) or 0.08, 0, 0.95)
local rightAimEnabled = rightAimStickConfig.Enabled ~= false
local rightAimVisible = rightAimEnabled and rightAimStickConfig.Visible ~= false
local rightAimLabel = tostring(rightAimStickConfig.Label or "AIM")
local aimTapMaxDuration = math.max(0.01, tonumber(rightAimStickConfig.TapMaxDuration) or 0.15)
local aimTapMoveTolerancePixels = math.max(0, tonumber(rightAimStickConfig.TapMoveTolerancePixels) or 6)
local aimPlaneY = tonumber(aimAreaConfig.AimPlaneY) or CameraConfig.Input.AimPlaneY or 0
local aimMinXScale = math.clamp(tonumber(aimAreaConfig.MinXScale) or 0.45, 0, 1)
local fireButtonLabel = tostring(fireButtonConfig.Label or "FIRE")
local fireButtonSize = getOffsetButtonSize(
	fireButtonConfig.Size,
	UDim2.fromOffset(FIRE_BUTTON_SIZE, FIRE_BUTTON_SIZE)
)
local reverseButtonLabel = tostring(reverseButtonConfig.Label or "REV")
local reverseButtonSize = reverseButtonConfig.Size or UDim2.fromOffset(REVERSE_BUTTON_SIZE, REVERSE_BUTTON_SIZE)
local reverseButtonPosition = reverseButtonConfig.Position or UDim2.new(1, -95, 1, -128)
local reverseButtonAnchorPoint = reverseButtonConfig.AnchorPoint or Vector2.new(1, 1)
local shootCooldown = math.max(0.05, tonumber(primaryWeaponConfig.ShootCooldown) or 0.45)

local shouldEnableMobileControls = MobileControlsConfig.Enabled == true
	and (
		UserInputService.TouchEnabled == true
		or (RunService:IsStudio() and MobileControlsConfig.ForceEnabledInStudio == true)
	)

local existingGui = playerGui:FindFirstChild(GUI_NAME)

if not shouldEnableMobileControls then
	if existingGui ~= nil then
		existingGui:Destroy()
	end

	WOBClientInputState.setMobileEnabled(false)
	return
end

WOBClientInputState.setMobileEnabled(true)

local screenGui = existingGui

if screenGui == nil then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.Parent = playerGui
else
	screenGui:ClearAllChildren()
end

screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 55
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = true

local leftStickBase = Instance.new("Frame")
leftStickBase.Name = LEFT_STICK_BASE_NAME
leftStickBase.AnchorPoint = Vector2.new(0, 1)
leftStickBase.Position = UDim2.new(0, 28, 1, -30)
leftStickBase.Size = UDim2.fromOffset(LEFT_STICK_SIZE, LEFT_STICK_SIZE)
leftStickBase.BackgroundColor3 = Color3.fromRGB(18, 24, 28)
leftStickBase.BackgroundTransparency = 0.42
leftStickBase.BorderSizePixel = 0
leftStickBase.Active = true
leftStickBase.Parent = screenGui

local leftStickBaseCorner = Instance.new("UICorner")
leftStickBaseCorner.CornerRadius = UDim.new(1, 0)
leftStickBaseCorner.Parent = leftStickBase

local leftStickBaseStroke = Instance.new("UIStroke")
leftStickBaseStroke.Color = Color3.fromRGB(210, 235, 228)
leftStickBaseStroke.Transparency = 0.58
leftStickBaseStroke.Thickness = 2
leftStickBaseStroke.Parent = leftStickBase

local leftStickKnob = Instance.new("Frame")
leftStickKnob.Name = LEFT_STICK_KNOB_NAME
leftStickKnob.AnchorPoint = Vector2.new(0.5, 0.5)
leftStickKnob.Position = UDim2.fromOffset(stickRadius, stickRadius)
leftStickKnob.Size = UDim2.fromOffset(LEFT_STICK_KNOB_SIZE, LEFT_STICK_KNOB_SIZE)
leftStickKnob.BackgroundColor3 = Color3.fromRGB(234, 255, 246)
leftStickKnob.BackgroundTransparency = 0.26
leftStickKnob.BorderSizePixel = 0
leftStickKnob.Parent = leftStickBase

local leftStickKnobCorner = Instance.new("UICorner")
leftStickKnobCorner.CornerRadius = UDim.new(1, 0)
leftStickKnobCorner.Parent = leftStickKnob

local leftStickLabelText = Instance.new("TextLabel")
leftStickLabelText.Name = "LeftStickLabel"
leftStickLabelText.AnchorPoint = Vector2.new(0.5, 0.5)
leftStickLabelText.Position = UDim2.fromScale(0.5, 0.72)
leftStickLabelText.Size = UDim2.fromScale(0.8, 0.2)
leftStickLabelText.BackgroundTransparency = 1
leftStickLabelText.Font = Enum.Font.GothamBold
leftStickLabelText.Text = leftStickLabel
leftStickLabelText.TextColor3 = Color3.fromRGB(222, 242, 236)
leftStickLabelText.TextSize = 13
leftStickLabelText.TextTransparency = 0.32
leftStickLabelText.TextWrapped = true
leftStickLabelText.Active = false
leftStickLabelText.Parent = leftStickBase

local rightAimBase = Instance.new("Frame")
rightAimBase.Name = RIGHT_AIM_BASE_NAME
rightAimBase.AnchorPoint = Vector2.new(1, 1)
rightAimBase.Position = UDim2.new(1, -144, 1, -44)
rightAimBase.Size = UDim2.fromOffset(RIGHT_AIM_SIZE, RIGHT_AIM_SIZE)
rightAimBase.BackgroundColor3 = Color3.fromRGB(14, 22, 31)
rightAimBase.BackgroundTransparency = 0.48
rightAimBase.BorderSizePixel = 0
rightAimBase.Active = true
rightAimBase.Parent = screenGui

local rightAimBaseCorner = Instance.new("UICorner")
rightAimBaseCorner.CornerRadius = UDim.new(1, 0)
rightAimBaseCorner.Parent = rightAimBase

local rightAimBaseStroke = Instance.new("UIStroke")
rightAimBaseStroke.Color = Color3.fromRGB(122, 218, 255)
rightAimBaseStroke.Transparency = 0.5
rightAimBaseStroke.Thickness = 2
rightAimBaseStroke.Parent = rightAimBase

local rightAimKnob = Instance.new("Frame")
rightAimKnob.Name = RIGHT_AIM_KNOB_NAME
rightAimKnob.AnchorPoint = Vector2.new(0.5, 0.5)
rightAimKnob.Position = UDim2.fromOffset(rightAimRadius, rightAimRadius)
rightAimKnob.Size = UDim2.fromOffset(RIGHT_AIM_KNOB_SIZE, RIGHT_AIM_KNOB_SIZE)
rightAimKnob.BackgroundColor3 = Color3.fromRGB(178, 234, 255)
rightAimKnob.BackgroundTransparency = 0.24
rightAimKnob.BorderSizePixel = 0
rightAimKnob.Parent = rightAimBase

local rightAimKnobCorner = Instance.new("UICorner")
rightAimKnobCorner.CornerRadius = UDim.new(1, 0)
rightAimKnobCorner.Parent = rightAimKnob

local rightAimLabelText = Instance.new("TextLabel")
rightAimLabelText.Name = "RightAimLabel"
rightAimLabelText.AnchorPoint = Vector2.new(0.5, 0.5)
rightAimLabelText.Position = UDim2.fromScale(0.5, 0.72)
rightAimLabelText.Size = UDim2.fromScale(0.8, 0.2)
rightAimLabelText.BackgroundTransparency = 1
rightAimLabelText.Font = Enum.Font.GothamBold
rightAimLabelText.Text = rightAimLabel
rightAimLabelText.TextColor3 = Color3.fromRGB(210, 238, 255)
rightAimLabelText.TextSize = 13
rightAimLabelText.TextTransparency = 0.24
rightAimLabelText.TextWrapped = true
rightAimLabelText.Active = false
rightAimLabelText.Parent = rightAimBase

local fireButton = Instance.new("TextButton")
fireButton.Name = FIRE_BUTTON_NAME
fireButton.AnchorPoint = Vector2.new(1, 1)
fireButton.Position = UDim2.new(1, -24, 1, -28)
fireButton.Size = fireButtonSize
fireButton.BackgroundColor3 = Color3.fromRGB(194, 64, 54)
fireButton.BackgroundTransparency = 0.18
fireButton.BorderSizePixel = 0
fireButton.Font = Enum.Font.GothamBold
fireButton.Text = fireButtonLabel
fireButton.TextColor3 = Color3.fromRGB(255, 246, 236)
fireButton.TextSize = 22
fireButton.TextWrapped = true
fireButton.AutoButtonColor = true
fireButton.Active = true
fireButton.Parent = screenGui

local fireButtonCorner = Instance.new("UICorner")
fireButtonCorner.CornerRadius = UDim.new(1, 0)
fireButtonCorner.Parent = fireButton

local fireButtonStroke = Instance.new("UIStroke")
fireButtonStroke.Color = Color3.fromRGB(255, 205, 150)
fireButtonStroke.Transparency = 0.28
fireButtonStroke.Thickness = 2
fireButtonStroke.Parent = fireButton

local reverseButton = Instance.new("TextButton")
reverseButton.Name = REVERSE_BUTTON_NAME
reverseButton.AnchorPoint = reverseButtonAnchorPoint
reverseButton.Position = reverseButtonPosition
reverseButton.Size = reverseButtonSize
reverseButton.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
reverseButton.BackgroundTransparency = 0.2
reverseButton.BorderSizePixel = 0
reverseButton.Font = Enum.Font.GothamBlack
reverseButton.Text = reverseButtonLabel
reverseButton.TextColor3 = Color3.fromRGB(226, 232, 240)
reverseButton.TextSize = 17
reverseButton.TextWrapped = true
reverseButton.AutoButtonColor = false
reverseButton.Active = true
reverseButton.Parent = screenGui


local reverseButtonCorner = Instance.new("UICorner")
reverseButtonCorner.CornerRadius = UDim.new(1, 0)
reverseButtonCorner.Parent = reverseButton

local reverseButtonStroke = Instance.new("UIStroke")
reverseButtonStroke.Color = Color3.fromRGB(250, 204, 21)
reverseButtonStroke.Transparency = 0.34
reverseButtonStroke.Thickness = 2
reverseButtonStroke.Parent = reverseButton

local reverseButtonScale = Instance.new("UIScale")
reverseButtonScale.Scale = 1
reverseButtonScale.Parent = reverseButton

-- Arcade-only directional intent arrows (client-side visual only; no remotes, no gameplay).
-- Green = forward intent, red = reverse intent. Hidden unless the arcade preset is active
-- AND the matching input is engaged.
local function makeIntentArrow(name, color)
	local arrow = Instance.new("TextLabel")
	arrow.Name = name
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(52, 52)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "➤"
	arrow.TextColor3 = color
	arrow.TextSize = 46
	arrow.TextStrokeColor3 = Color3.fromRGB(8, 12, 16)
	arrow.TextStrokeTransparency = 0.35
	arrow.Visible = false
	arrow.Active = false
	arrow.ZIndex = 6
	arrow.Parent = screenGui
	return arrow
end

local forwardArrow = makeIntentArrow("ForwardIntentArrow", Color3.fromRGB(63, 212, 108))
local reverseArrow = makeIntentArrow("ReverseIntentArrow", Color3.fromRGB(235, 74, 74))

local aimDebugOverlay = nil

if MobileControlsConfig.Debug == true then
	aimDebugOverlay = Instance.new("Frame")
	aimDebugOverlay.Name = DEBUG_AIM_AREA_NAME
	aimDebugOverlay.AnchorPoint = Vector2.new(0, 0)
	aimDebugOverlay.Position = UDim2.fromScale(aimMinXScale, 0)
	aimDebugOverlay.Size = UDim2.fromScale(1 - aimMinXScale, 1)
	aimDebugOverlay.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
	aimDebugOverlay.BackgroundTransparency = 0.88
	aimDebugOverlay.BorderSizePixel = 0
	aimDebugOverlay.Active = false
	aimDebugOverlay.Parent = screenGui
end

local activeMovementTouch = nil
local activeMovementPoint = nil
local activeAimTouch = nil
local activeAimTouchStartPoint = nil
local activeAimTouchStartTime = 0
local activeAimTouchMoved = false
local activeReverseInput = nil
local reverseHeld = false
local lastMovementNormalized = Vector2.zero
local ownedTank = nil
local controlsVisible = false
local controlsEnabled = false
local shootEnabled = false
local localCooldownUntil = 0
local lastLayoutViewportSize = nil
local applyCurrentMovementState = nil

-- BattleArena arcade preset state (forward steer on left, reverse steer on right).
local activeReverseStickTouch = nil
local arcadeReverseActive = false
local arcadeReverseNormalized = Vector2.zero
local lastArcadeMode = nil
local resetReverseStick = nil
local applyArcadePresentation = nil

local function hideDesktopHintIfNeeded(instance)
	if not instance:IsA("TextLabel")
		and not instance:IsA("TextButton")
		and not instance:IsA("TextBox")
	then
		return
	end

	local hintText = string.lower(tostring(instance.Text or ""))

	for _, pattern in ipairs(DESKTOP_HINT_TEXT_PATTERNS) do
		if string.find(hintText, pattern, 1, true) ~= nil then
			instance.Visible = false
			return
		end
	end
end

local function hideDesktopHintText()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		hideDesktopHintIfNeeded(descendant)
	end
end

local function getCamera()
	local camera = Workspace.CurrentCamera

	if camera ~= nil then
		return camera
	end

	return nil
end

local function getViewportSize()
	local camera = getCamera()

	if camera ~= nil then
		return camera.ViewportSize
	end

	if screenGui.AbsoluteSize.X > 0 and screenGui.AbsoluteSize.Y > 0 then
		return screenGui.AbsoluteSize
	end

	return Vector2.new(1024, 768)
end

local function applyResponsiveLayout()
	local viewportSize = getViewportSize()

	if lastLayoutViewportSize ~= nil
		and math.abs(lastLayoutViewportSize.X - viewportSize.X) < 1
		and math.abs(lastLayoutViewportSize.Y - viewportSize.Y) < 1
	then
		return
	end

	lastLayoutViewportSize = viewportSize

	leftStickBase.AnchorPoint = Vector2.new(0, 1)
	leftStickBase.Size = UDim2.fromOffset(LEFT_STICK_SIZE, LEFT_STICK_SIZE)
	leftStickBase.Position = UDim2.new(0, 28, 1, -30)
	leftStickKnob.Size = UDim2.fromOffset(LEFT_STICK_KNOB_SIZE, LEFT_STICK_KNOB_SIZE)
	leftStickKnob.Position = UDim2.fromOffset(stickRadius, stickRadius)

	reverseButton.AnchorPoint = reverseButtonAnchorPoint
	reverseButton.Size = reverseButtonSize
	reverseButton.Position = reverseButtonPosition

	rightAimBase.AnchorPoint = Vector2.new(1, 1)
	rightAimBase.Size = UDim2.fromOffset(RIGHT_AIM_SIZE, RIGHT_AIM_SIZE)
	rightAimBase.Position = UDim2.new(1, -144, 1, -44)
	rightAimKnob.Size = UDim2.fromOffset(RIGHT_AIM_KNOB_SIZE, RIGHT_AIM_KNOB_SIZE)
	rightAimKnob.Position = UDim2.fromOffset(rightAimRadius, rightAimRadius)

	fireButton.AnchorPoint = Vector2.new(1, 1)
	fireButton.Size = fireButtonSize
	fireButton.Position = UDim2.new(1, -24, 1, -28)
end

-- ---------------------------------------------------------------------------
-- Floating joysticks (Task B): a stick's base snaps under the finger on touch and
-- returns to its home corner on release. Home positions mirror applyResponsiveLayout.
-- ---------------------------------------------------------------------------
local function resetLeftStickHome()
	leftStickBase.AnchorPoint = Vector2.new(0, 1)
	leftStickBase.Position = UDim2.new(0, 28, 1, -30)
end

local function resetRightStickHome()
	rightAimBase.AnchorPoint = Vector2.new(1, 1)
	rightAimBase.Position = UDim2.new(1, -144, 1, -44)
end

local function floatBaseToPoint(base, point)
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Position = UDim2.fromOffset(point.X, point.Y)
end

-- Activation zones: left half / right half of the screen, below the HUD-safe top band.
local function isInLeftZone(point)
	local viewportSize = getViewportSize()
	return point.X < viewportSize.X * 0.5
		and point.Y > viewportSize.Y * FLOATING_ACTIVATION_MIN_Y_SCALE
end

local function isInRightZone(point)
	local viewportSize = getViewportSize()
	return point.X >= viewportSize.X * 0.5
		and point.Y > viewportSize.Y * FLOATING_ACTIVATION_MIN_Y_SCALE
end

local function getOwnedTank()
	return TankModelResolver.findOwnedTank(root, localPlayer.UserId, true)
end

local function refreshOwnedTank()
	local nextOwnedTank = getOwnedTank()

	if ownedTank == nextOwnedTank then
		return
	end

	ownedTank = nextOwnedTank
end

local function isModeVisible()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode == PLAYER_MODE_RESULT then
		return false
	end

	if mode == PLAYER_MODE_LOBBY
		or mode == PLAYER_MODE_QUEUED
		or mode == PLAYER_MODE_IN_MATCH
		or mode == PLAYER_MODE_IN_BATTLE_ARENA
	then
		return true
	end

	return mode == nil and root:GetAttribute("GameState") == "Playing"
end

-- Arcade preset is BattleArena-only. Duel/PvP, Training, and Lobby never trigger it, so
-- their controls stay exactly as before.
local function isArcadeMode()
	return arcadeConfig.Enabled ~= false
		and localPlayer:GetAttribute("PlayerMode") == PLAYER_MODE_IN_BATTLE_ARENA
end

local function isRoundInputLocked()
	local mode = localPlayer:GetAttribute("PlayerMode")

	if mode ~= PLAYER_MODE_IN_MATCH then
		return false
	end

	return root:GetAttribute("RoundEnded") == true or root:GetAttribute("RoundState") == "RoundEnd"
end

local function isTankUsable(requireShoot)
	refreshOwnedTank()

	if ownedTank == nil or ownedTank.Parent == nil then
		return false
	end

	if ownedTank:GetAttribute("IsDead") == true
		or ownedTank:GetAttribute("IsControllable") == false
	then
		return false
	end

	if requireShoot then
		return ownedTank:GetAttribute("CanShoot") ~= false
	end

	return ownedTank:GetAttribute("CanMove") ~= false
end

local function setReverseButtonPressed(isPressed)
	if isPressed then
		TweenService:Create(reverseButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.04,
		}):Play()
		TweenService:Create(reverseButtonStroke, TweenInfo.new(0.08), {
			Color = Color3.fromRGB(249, 115, 22),
			Transparency = 0.08,
		}):Play()
		TweenService:Create(reverseButtonScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.95,
		}):Play()
	else
		TweenService:Create(reverseButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = controlsEnabled and 0.2 or 0.68,
		}):Play()
		TweenService:Create(reverseButtonStroke, TweenInfo.new(0.12), {
			Color = Color3.fromRGB(250, 204, 21),
			Transparency = controlsEnabled and 0.34 or 0.82,
		}):Play()
		TweenService:Create(reverseButtonScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
end

local function setReverseHeld(isHeld, input)
	local nextHeld = isHeld == true and controlsVisible and controlsEnabled

	if reverseHeld == nextHeld and (nextHeld ~= true or activeReverseInput == input) then
		return
	end

	reverseHeld = nextHeld
	activeReverseInput = nextHeld and input or nil
	setReverseButtonPressed(nextHeld)

	if applyCurrentMovementState ~= nil then
		applyCurrentMovementState()
	end
end

local function resetReverseControl()
	if reverseHeld == false and activeReverseInput == nil then
		return
	end

	reverseHeld = false
	activeReverseInput = nil
	setReverseButtonPressed(false)
end

local function setControlTransparency(isEnabled)
	leftStickBase.BackgroundTransparency = isEnabled and 0.42 or 0.72
	leftStickKnob.BackgroundTransparency = isEnabled and 0.26 or 0.62
	leftStickBaseStroke.Transparency = isEnabled and 0.58 or 0.82
	leftStickLabelText.TextTransparency = isEnabled and 0.32 or 0.64
	rightAimBase.BackgroundTransparency = isEnabled and 0.48 or 0.76
	rightAimKnob.BackgroundTransparency = isEnabled and 0.24 or 0.66
	rightAimBaseStroke.Transparency = isEnabled and 0.5 or 0.82
	rightAimLabelText.TextTransparency = isEnabled and 0.24 or 0.66
	fireButton.BackgroundTransparency = shootEnabled and 0.18 or 0.66
	fireButtonStroke.Transparency = shootEnabled and 0.28 or 0.78
	fireButton.TextTransparency = shootEnabled and 0 or 0.45
	fireButton.AutoButtonColor = shootEnabled
	fireButton.Active = shootEnabled
	reverseButton.BackgroundTransparency = isEnabled and (reverseHeld and 0.04 or 0.2) or 0.68
	reverseButtonStroke.Transparency = isEnabled and (reverseHeld and 0.08 or 0.34) or 0.82
	reverseButton.TextTransparency = isEnabled and 0 or 0.45
	reverseButton.Active = isEnabled
	rightAimBase.Active = isEnabled and rightAimVisible
end

local function resetMoveStickVisual()
	leftStickKnob.Position = UDim2.fromOffset(stickRadius, stickRadius)
end

local function resetAimStickVisual()
	rightAimKnob.Position = UDim2.fromOffset(rightAimRadius, rightAimRadius)
end

local function resetMovementTouch()
	activeMovementTouch = nil
	activeMovementPoint = nil
	lastMovementNormalized = Vector2.zero

	if FLOATING_JOYSTICKS_ENABLED then
		resetLeftStickHome()
	end

	resetMoveStickVisual()

	if applyCurrentMovementState ~= nil then
		applyCurrentMovementState()
	else
		WOBClientInputState.resetMobileMovement()
	end
end

local function resetAimTouch()
	activeAimTouch = nil
	activeAimTouchStartPoint = nil
	activeAimTouchStartTime = 0
	activeAimTouchMoved = false

	if FLOATING_JOYSTICKS_ENABLED and activeReverseStickTouch == nil then
		resetRightStickHome()
	end

	resetAimStickVisual()
end

local function updateVisibility()
	local visible = isModeVisible()
	local inputLocked = isRoundInputLocked()
	local canMove = visible and not inputLocked and isTankUsable(false)
	local canShoot = visible and not inputLocked and isTankUsable(true)

	controlsVisible = visible
	controlsEnabled = canMove
	shootEnabled = canShoot

	local arcade = isArcadeMode()

	-- Apply/clear arcade presentation (relabels right stick to REVERSE, hides the classic
	-- REV button) only when the mode actually changes, to avoid per-frame churn.
	if arcade ~= lastArcadeMode then
		lastArcadeMode = arcade
		if applyArcadePresentation ~= nil then
			applyArcadePresentation(arcade)
		end
	end

	screenGui.Enabled = visible
	leftStickBase.Visible = visible
	rightAimBase.Visible = visible and rightAimVisible
	fireButton.Visible = visible
	-- In arcade mode the right stick IS the reverse control, so the classic REV button is
	-- hidden. Duel/Training keep the REV button exactly as before.
	reverseButton.Visible = visible and not arcade

	if aimDebugOverlay ~= nil then
		aimDebugOverlay.Visible = visible and MobileControlsConfig.Debug == true
	end

	setControlTransparency(canMove)

	if not visible or not canMove then
		resetReverseControl()
		resetMovementTouch()
		resetAimTouch()
		if resetReverseStick ~= nil then
			resetReverseStick()
		end
	end

	if not visible or not canShoot then
		WOBClientInputState.clearMobileShootRequest()
	end
end

local function screenPointFromInput(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function isPointInsideGui(guiObject, point)
	local absolutePosition = guiObject.AbsolutePosition
	local absoluteSize = guiObject.AbsoluteSize

	return point.X >= absolutePosition.X
		and point.X <= absolutePosition.X + absoluteSize.X
		and point.Y >= absolutePosition.Y
		and point.Y <= absolutePosition.Y + absoluteSize.Y
end

local function getTankAimOrigin()
	refreshOwnedTank()

	if ownedTank == nil or ownedTank.Parent == nil then
		return Vector3.new(0, aimPlaneY, 0)
	end

	if ownedTank:IsA("Model") then
		local position = ownedTank:GetPivot().Position
		return Vector3.new(position.X, aimPlaneY, position.Z)
	end

	if ownedTank:IsA("BasePart") then
		local position = ownedTank.Position
		return Vector3.new(position.X, aimPlaneY, position.Z)
	end

	return Vector3.new(0, aimPlaneY, 0)
end

local function getFlatUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)

	if flat.Magnitude > 0.001 then
		return flat.Unit
	end

	return fallback
end

local function normalizeAngle(angle)
	local fullTurn = math.pi * 2

	return ((angle + math.pi) % fullTurn) - math.pi
end

local function getYawFromFlatDirection(direction)
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.001 then
		return nil
	end

	local unit = flat.Unit
	return math.atan2(-unit.X, -unit.Z)
end

local function getOwnedTankBodyYaw()
	if ownedTank == nil or ownedTank.Parent == nil then
		refreshOwnedTank()
	end

	if ownedTank == nil or ownedTank.Parent == nil then
		return nil
	end

	local body = ownedTank:FindFirstChild("Body", true)
		or ownedTank:FindFirstChild("Hull", true)
		or (ownedTank:IsA("Model") and ownedTank.PrimaryPart or nil)

	if body ~= nil and body:IsA("BasePart") then
		return getYawFromFlatDirection(body.CFrame.LookVector)
	end

	if ownedTank:IsA("Model") then
		return getYawFromFlatDirection(ownedTank:GetPivot().LookVector)
	elseif ownedTank:IsA("BasePart") then
		return getYawFromFlatDirection(ownedTank.CFrame.LookVector)
	end

	return nil
end

local function getWorldDirectionFromStick(normalized)
	local camera = getCamera()
	local worldRight = Vector3.new(1, 0, 0)
	local worldUp = Vector3.new(0, 0, -1)

	if camera ~= nil then
		local cameraCFrame = camera.CFrame
		worldRight = getFlatUnit(cameraCFrame.RightVector, worldRight)
		worldUp = getFlatUnit(cameraCFrame.UpVector, worldUp)

		if worldUp.Magnitude < 0.001 then
			worldUp = getFlatUnit(cameraCFrame.LookVector, Vector3.new(0, 0, -1))
		end
	end

	local direction = worldRight * normalized.X + worldUp * -normalized.Y

	if direction.Magnitude < 0.001 then
		return nil
	end

	return direction.Unit
end

local function getAimDirectionFromStick(normalized)
	return getWorldDirectionFromStick(normalized)
end

local function updateAimFromPoint(point)
	local center = rightAimBase.AbsolutePosition + rightAimBase.AbsoluteSize * 0.5
	local delta = point - center
	local distance = delta.Magnitude
	local clamped = delta

	if distance > rightAimMaxDistance and distance > 0 then
		clamped = delta.Unit * rightAimMaxDistance
	end

	local normalized = Vector2.new(
		rightAimMaxDistance > 0 and clamped.X / rightAimMaxDistance or 0,
		rightAimMaxDistance > 0 and clamped.Y / rightAimMaxDistance or 0
	)

	if normalized.Magnitude < rightAimDeadZone then
		normalized = Vector2.zero
		clamped = Vector2.zero
	end

	rightAimKnob.Position = UDim2.fromOffset(rightAimRadius + clamped.X, rightAimRadius + clamped.Y)

	local aimDirection = getAimDirectionFromStick(normalized)

	if aimDirection == nil then
		return nil
	end

	local origin = getTankAimOrigin()
	local aimWorldPoint = origin + aimDirection * 100

	if aimWorldPoint ~= nil then
		WOBClientInputState.setMobileAimWorldPoint(aimWorldPoint)
	end

	return aimWorldPoint
end

local function getArcadeThrottleScale(absSignedAngle)
	if absSignedAngle < ARCADE_SLOW_TURN_ANGLE then
		return 1
	elseif absSignedAngle < ARCADE_HARD_TURN_ANGLE then
		return ARCADE_SLOW_TURN_THROTTLE_SCALE
	end

	return ARCADE_HARD_TURN_THROTTLE_SCALE
end

applyCurrentMovementState = function()
	local magnitude = lastMovementNormalized.Magnitude
	local localStickY = math.clamp(lastMovementNormalized.Y, -1, 1)
	local localStickX = math.clamp(lastMovementNormalized.X, -1, 1)
	local isActive = magnitude >= STICK_RELEASE_MAGNITUDE

	-- Arcade reverse-steer (BattleArena right stick). Backs the tank away while gently
	-- rotating its body toward the drag direction (rear leads). No instant 180 flip: we only
	-- emit a steer signal, the same mechanism the classic REV button uses, so collision and
	-- movement bounds are untouched.
	if arcadeReverseActive then
		local reverseMagnitude = arcadeReverseNormalized.Magnitude

		if reverseMagnitude < rightAimDeadZone then
			-- No drag direction: straight back along the current facing.
			local straight = -math.clamp(tonumber(arcadeConfig.ReverseStraightThrottle) or 1, 0, 1)
			WOBClientInputState.setMobileMovement(straight, 0, true)
			return
		end

		local dragDirection = getWorldDirectionFromStick(arcadeReverseNormalized)
		local currentBodyYaw = getOwnedTankBodyYaw()
		local steer = math.clamp(arcadeReverseNormalized.X, -1, 1)

		if dragDirection ~= nil and currentBodyYaw ~= nil then
			-- Want the tank to back TOWARD the drag, so its forward should point opposite.
			local desiredForwardYaw = getYawFromFlatDirection(-dragDirection)
			if desiredForwardYaw ~= nil then
				local signedAngle = normalizeAngle(desiredForwardYaw - currentBodyYaw)
				steer = -math.clamp(signedAngle / ARCADE_FULL_STEER_ANGLE, -1, 1)
			end
		end

		WOBClientInputState.setMobileMovement(-math.clamp(reverseMagnitude, 0, 1), steer, true)
		return
	end

	if reverseHeld then
		local throttle = isActive and -math.clamp(magnitude, 0, 1) or -1
		local steer = isActive and localStickX or 0
		WOBClientInputState.setMobileMovement(throttle, steer, true)
		return
	end

	if not isActive then
		WOBClientInputState.setMobileMovement(0, 0, false)
		return
	end

	-- Mobile arcade movement:
	-- the left stick chooses a desired world direction, the tank turns toward
	-- that direction and keeps moving forward. Reverse is explicit on the REV
	-- button, so joystick direction never flips into reverse by itself.
	local desiredDirection = getWorldDirectionFromStick(Vector2.new(localStickX, localStickY))
	local currentBodyYaw = getOwnedTankBodyYaw()
	local desiredYaw = desiredDirection ~= nil and getYawFromFlatDirection(desiredDirection) or nil
	local steer = localStickX
	local throttleScale = 1

	if currentBodyYaw ~= nil and desiredYaw ~= nil then
		local signedAngle = normalizeAngle(desiredYaw - currentBodyYaw)
		steer = -math.clamp(signedAngle / ARCADE_FULL_STEER_ANGLE, -1, 1)
		throttleScale = getArcadeThrottleScale(math.abs(signedAngle))
	end

	local throttle = math.clamp(magnitude * throttleScale, 0, 1)
	WOBClientInputState.setMobileMovement(throttle, steer, true)
end

local function updateReverseStickFromPoint(point)
	local center = rightAimBase.AbsolutePosition + rightAimBase.AbsoluteSize * 0.5
	local delta = point - center
	local distance = delta.Magnitude
	local clamped = delta

	if distance > rightAimMaxDistance and distance > 0 then
		clamped = delta.Unit * rightAimMaxDistance
	end

	local normalized = Vector2.new(
		rightAimMaxDistance > 0 and clamped.X / rightAimMaxDistance or 0,
		rightAimMaxDistance > 0 and clamped.Y / rightAimMaxDistance or 0
	)

	rightAimKnob.Position = UDim2.fromOffset(rightAimRadius + clamped.X, rightAimRadius + clamped.Y)

	arcadeReverseActive = true
	arcadeReverseNormalized = normalized
	applyCurrentMovementState()
end

-- Assigned to the forward-declared local so earlier functions (updateVisibility) can call it.
resetReverseStick = function()
	if activeReverseStickTouch == nil and not arcadeReverseActive then
		return
	end

	activeReverseStickTouch = nil
	arcadeReverseActive = false
	arcadeReverseNormalized = Vector2.zero

	if FLOATING_JOYSTICKS_ENABLED then
		resetRightStickHome()
	end

	resetAimStickVisual()

	if applyCurrentMovementState ~= nil then
		applyCurrentMovementState()
	end
end

-- Relabels/recolors the right stick as REVERSE in arcade mode and clears stale aim/reverse
-- state. Restores the classic AIM styling otherwise. Visual only.
applyArcadePresentation = function(isArcade)
	resetReverseStick()
	resetAimTouch()

	if isArcade then
		rightAimLabelText.Text = "REVERSE"
		rightAimBaseStroke.Color = Color3.fromRGB(235, 74, 74)
		rightAimKnob.BackgroundColor3 = Color3.fromRGB(255, 178, 178)
		-- Arcade shoots along the body forward, so drop any latched aim point immediately.
		WOBClientInputState.clearMobileAimWorldPoint()
	else
		rightAimLabelText.Text = rightAimLabel
		rightAimBaseStroke.Color = Color3.fromRGB(122, 218, 255)
		rightAimKnob.BackgroundColor3 = Color3.fromRGB(178, 234, 255)
		forwardArrow.Visible = false
		reverseArrow.Visible = false
	end
end

local function updateArcadeIndicators()
	local arcadeActive = isArcadeMode() and controlsVisible and controlsEnabled

	local showForward = arcadeActive
		and arcadeConfig.ForwardIndicatorEnabled ~= false
		and not arcadeReverseActive
		and lastMovementNormalized.Magnitude >= STICK_RELEASE_MAGNITUDE

	forwardArrow.Visible = showForward
	if showForward then
		local n = lastMovementNormalized
		forwardArrow.Rotation = math.deg(math.atan2(n.Y, n.X))
		local c = leftStickBase.AbsolutePosition + leftStickBase.AbsoluteSize * 0.5
		forwardArrow.Position = UDim2.fromOffset(c.X, c.Y - leftStickBase.AbsoluteSize.Y * 0.5 - 30)
	end

	local showReverse = arcadeActive
		and arcadeConfig.ReverseIndicatorEnabled ~= false
		and arcadeReverseActive

	reverseArrow.Visible = showReverse
	if showReverse then
		local n = arcadeReverseNormalized
		if n.Magnitude < 0.001 then
			n = Vector2.new(0, 1) -- straight back: point the arrow down on screen.
		end
		reverseArrow.Rotation = math.deg(math.atan2(n.Y, n.X))
		local c = rightAimBase.AbsolutePosition + rightAimBase.AbsoluteSize * 0.5
		reverseArrow.Position = UDim2.fromOffset(c.X, c.Y - rightAimBase.AbsoluteSize.Y * 0.5 - 30)
	end
end

local function updateMovementFromPoint(point)
	activeMovementPoint = point
	local center = leftStickBase.AbsolutePosition + leftStickBase.AbsoluteSize * 0.5
	local delta = point - center
	local distance = delta.Magnitude
	local clamped = delta

	if distance > stickMaxDistance and distance > 0 then
		clamped = delta.Unit * stickMaxDistance
	end

	local normalized = Vector2.new(
		stickMaxDistance > 0 and clamped.X / stickMaxDistance or 0,
		stickMaxDistance > 0 and clamped.Y / stickMaxDistance or 0
	)

	if normalized.Magnitude < stickDeadZone then
		normalized = Vector2.zero
		clamped = Vector2.zero
	end

	leftStickKnob.Position = UDim2.fromOffset(stickRadius + clamped.X, stickRadius + clamped.Y)
	lastMovementNormalized = normalized
	applyCurrentMovementState()
end

local function requestShoot()
	if not controlsVisible or not shootEnabled then
		return
	end

	if os.clock() < localCooldownUntil then
		return
	end

	WOBClientInputState.requestMobileShoot()

	if fireButtonConfig.CooldownVisual ~= false then
		localCooldownUntil = os.clock() + shootCooldown
	end
end

fireButton.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch
		and input.UserInputType ~= Enum.UserInputType.MouseButton1
	then
		return
	end

	requestShoot()
end)

reverseButton.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch
		and input.UserInputType ~= Enum.UserInputType.MouseButton1
	then
		return
	end

	setReverseHeld(true, input)
end)

reverseButton.InputEnded:Connect(function(input)
	if input == activeReverseInput then
		setReverseHeld(false, nil)
	end
end)

UserInputService.InputBegan:Connect(function(input, _gameProcessedEvent)
	if not controlsVisible then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local point = screenPointFromInput(input)

	if isPointInsideGui(fireButton, point) then
		return
	end

	if isPointInsideGui(reverseButton, point) then
		return
	end

	-- Floating: pick up the LEFT stick anywhere in the left activation zone and snap its base
	-- under the finger. Non-floating: keep the original "touch inside the base" behavior.
	local leftStickHit = FLOATING_JOYSTICKS_ENABLED and isInLeftZone(point) or isPointInsideGui(leftStickBase, point)

	if controlsEnabled and activeMovementTouch == nil and leftStickHit then
		if FLOATING_JOYSTICKS_ENABLED then
			floatBaseToPoint(leftStickBase, point)
		end
		activeMovementTouch = input
		updateMovementFromPoint(point)
		return
	end

	local rightStickHit = FLOATING_JOYSTICKS_ENABLED and isInRightZone(point) or isPointInsideGui(rightAimBase, point)

	if controlsEnabled
		and rightAimVisible
		and rightStickHit
	then
		if FLOATING_JOYSTICKS_ENABLED then
			floatBaseToPoint(rightAimBase, point)
		end
		if isArcadeMode() then
			-- Arcade: the right stick is REVERSE steer, not aim.
			if activeReverseStickTouch == nil then
				activeReverseStickTouch = input
				updateReverseStickFromPoint(point)
			end
		elseif activeAimTouch == nil then
			activeAimTouch = input
			activeAimTouchStartPoint = point
			activeAimTouchStartTime = os.clock()
			activeAimTouchMoved = false
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == activeMovementTouch then
		if controlsEnabled then
			updateMovementFromPoint(screenPointFromInput(input))
		else
			resetMovementTouch()
		end
	elseif input == activeReverseStickTouch then
		if controlsEnabled and isArcadeMode() then
			updateReverseStickFromPoint(screenPointFromInput(input))
		else
			resetReverseStick()
		end
	elseif input == activeAimTouch then
		if controlsEnabled then
			local point = screenPointFromInput(input)
			local movedDistance = activeAimTouchStartPoint ~= nil and (point - activeAimTouchStartPoint).Magnitude or 0

			if activeAimTouchMoved or movedDistance > aimTapMoveTolerancePixels then
				activeAimTouchMoved = true
				updateAimFromPoint(point)
			end
		else
			resetAimTouch()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeMovementTouch then
		resetMovementTouch()
	elseif input == activeAimTouch then
		local duration = os.clock() - activeAimTouchStartTime

		if controlsVisible
			and shootEnabled
			and not activeAimTouchMoved
			and duration <= aimTapMaxDuration
		then
			WOBClientInputState.enqueueMobileShootRequest(WOBClientInputState.getMobileAimWorldPoint())
		end

		resetAimTouch()
	elseif input == activeReverseStickTouch then
		resetReverseStick()
	elseif input == activeReverseInput then
		setReverseHeld(false, nil)
	end
end)

RunService.RenderStepped:Connect(function()
	applyResponsiveLayout()
	updateVisibility()

	-- Arcade fires along the tank body forward: keep any stale aim point cleared so the
	-- input controller falls back to the forward vector every frame.
	if isArcadeMode() then
		WOBClientInputState.clearMobileAimWorldPoint()
	end

	if activeMovementTouch ~= nil and controlsEnabled and activeMovementPoint ~= nil then
		updateMovementFromPoint(activeMovementPoint)
	end

	updateArcadeIndicators()

	if fireButtonConfig.CooldownVisual ~= false and os.clock() < localCooldownUntil then
		local remaining = math.max(0, localCooldownUntil - os.clock())
		fireButton.Text = tostring(math.ceil(remaining * 10) / 10)
		fireButton.BackgroundTransparency = 0.58
	elseif shootEnabled then
		fireButton.Text = fireButtonLabel
	else
		fireButton.Text = fireButtonLabel
	end
end)

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(updateVisibility)
root:GetAttributeChangedSignal("GameState"):Connect(updateVisibility)
root:GetAttributeChangedSignal("RoundState"):Connect(updateVisibility)
root:GetAttributeChangedSignal("RoundEnded"):Connect(updateVisibility)
playerGui.DescendantAdded:Connect(hideDesktopHintIfNeeded)

hideDesktopHintText()
updateVisibility()
