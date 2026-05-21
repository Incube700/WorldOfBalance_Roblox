local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local DEBUG_AIM_AREA_NAME = "AimAreaDebugOverlay"

local PLAYER_MODE_LOBBY = "Lobby"
local PLAYER_MODE_QUEUED = "QueuedForDuel"
local PLAYER_MODE_IN_MATCH = "InMatch"
local PLAYER_MODE_RESULT = "Result"
local PLAYER_MODE_IN_BATTLE_ARENA = "InBattleArena"

local leftStickConfig = MobileControlsConfig.LeftStick or {}
local aimAreaConfig = MobileControlsConfig.AimArea or {}
local rightAimStickConfig = MobileControlsConfig.RightAimStick or {}
local fireButtonConfig = MobileControlsConfig.FireButton or {}
local primaryWeaponConfig = WeaponConfig.PrimaryWeapon or {}

local stickRadius = tonumber(leftStickConfig.Radius) or 72
local stickMaxDistance = tonumber(leftStickConfig.MaxDistance) or stickRadius
local stickDeadZone = math.clamp(tonumber(leftStickConfig.DeadZone) or 0.12, 0, 0.95)
local manualAngleMaxMagnitude = math.clamp(tonumber(leftStickConfig.ManualAngleMaxMagnitude) or 0.5, 0, 1)
local autoTurnMinMagnitude = math.clamp(tonumber(leftStickConfig.AutoTurnMinMagnitude) or 0.5, 0, 1)
local autoTurnLerpAlpha = math.clamp(tonumber(leftStickConfig.AutoTurnLerpAlpha) or 0.08, 0, 1)
local reverseStickThreshold = math.clamp(tonumber(leftStickConfig.ReverseStickThreshold) or -0.1, -1, 1)
local leftStickLabel = tostring(leftStickConfig.Label or "MOVE")
local rightAimRadius = tonumber(rightAimStickConfig.Radius) or 82
local rightAimMaxDistance = tonumber(rightAimStickConfig.MaxDistance) or rightAimRadius
local rightAimDeadZone = math.clamp(tonumber(rightAimStickConfig.DeadZone) or 0.08, 0, 0.95)
local rightAimEnabled = rightAimStickConfig.Enabled ~= false
local rightAimVisible = rightAimEnabled and rightAimStickConfig.Visible ~= false
local rightAimLabel = tostring(rightAimStickConfig.Label or "AIM")
local aimTapMaxDuration = math.max(0.01, tonumber(rightAimStickConfig.TapMaxDuration) or 0.15)
local aimTapMoveTolerancePixels = math.max(0, tonumber(rightAimStickConfig.TapMoveTolerancePixels) or 6)
local aimPlaneY = tonumber(aimAreaConfig.AimPlaneY) or CameraConfig.Input.AimPlaneY or 0
local aimMinXScale = math.clamp(tonumber(aimAreaConfig.MinXScale) or 0.45, 0, 1)
local fireButtonLabel = tostring(fireButtonConfig.Label or "FIRE")
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
leftStickBase.AnchorPoint = Vector2.new(0.5, 0.5)
leftStickBase.Position = leftStickConfig.Position or UDim2.fromScale(0.18, 0.74)
leftStickBase.Size = UDim2.fromOffset(stickRadius * 2, stickRadius * 2)
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
leftStickKnob.Size = UDim2.fromOffset(46, 46)
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
rightAimBase.AnchorPoint = Vector2.new(0.5, 0.5)
rightAimBase.Position = rightAimStickConfig.Position or UDim2.fromScale(0.78, 0.72)
rightAimBase.Size = UDim2.fromOffset(rightAimRadius * 2, rightAimRadius * 2)
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
rightAimKnob.Size = UDim2.fromOffset(44, 44)
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
fireButton.AnchorPoint = Vector2.new(0.5, 0.5)
fireButton.Position = fireButtonConfig.Position or UDim2.fromScale(0.9, 0.56)
fireButton.Size = fireButtonConfig.Size or UDim2.fromOffset(92, 92)
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
local ownedTank = nil
local controlsVisible = false
local controlsEnabled = false
local shootEnabled = false
local localCooldownUntil = 0
local smoothedAutoSteer = 0

local function getCamera()
	local camera = Workspace.CurrentCamera

	if camera ~= nil then
		return camera
	end

	return nil
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
	smoothedAutoSteer = 0
	WOBClientInputState.resetMobileMovement()
	resetMoveStickVisual()
end

local function resetAimTouch()
	activeAimTouch = nil
	activeAimTouchStartPoint = nil
	activeAimTouchStartTime = 0
	activeAimTouchMoved = false
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

	screenGui.Enabled = visible
	leftStickBase.Visible = visible
	rightAimBase.Visible = visible and rightAimVisible
	fireButton.Visible = visible

	if aimDebugOverlay ~= nil then
		aimDebugOverlay.Visible = visible and MobileControlsConfig.Debug == true
	end

	setControlTransparency(canMove)

	if not visible or not canMove then
		resetMovementTouch()
		resetAimTouch()
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
	end

	local magnitude = normalized.Magnitude
	local localStickY = math.clamp(-normalized.Y, -1, 1)
	local localStickX = math.clamp(normalized.X, -1, 1)
	local moveInput = 0
	local turnInput = 0
	local isActive = magnitude > 0

	if magnitude < stickDeadZone then
		smoothedAutoSteer = 0
	elseif localStickY < reverseStickThreshold then
		moveInput = localStickY
		turnInput = localStickX
		smoothedAutoSteer = 0
	elseif magnitude > autoTurnMinMagnitude then
		moveInput = math.clamp(magnitude, 0, 1)

		local desiredDirection = getWorldDirectionFromStick(normalized)
		local currentBodyYaw = getOwnedTankBodyYaw()
		local desiredYaw = desiredDirection ~= nil and getYawFromFlatDirection(desiredDirection) or nil

		if currentBodyYaw ~= nil and desiredYaw ~= nil then
			local yawDelta = normalizeAngle(desiredYaw - currentBodyYaw)
			local desiredSteer = -math.clamp(yawDelta / (math.pi * 0.5), -1, 1)
			smoothedAutoSteer += (desiredSteer - smoothedAutoSteer) * autoTurnLerpAlpha
			turnInput = math.clamp(smoothedAutoSteer, -1, 1)
		else
			smoothedAutoSteer = 0
		end
	elseif magnitude > 0 and magnitude <= manualAngleMaxMagnitude then
		moveInput = localStickY
		turnInput = 0
		smoothedAutoSteer = 0
	else
		smoothedAutoSteer = 0
	end

	leftStickKnob.Position = UDim2.fromOffset(stickRadius + clamped.X, stickRadius + clamped.Y)
	WOBClientInputState.setMobileMovement(moveInput, turnInput, isActive)
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

	if controlsEnabled and activeMovementTouch == nil and isPointInsideGui(leftStickBase, point) then
		activeMovementTouch = input
		updateMovementFromPoint(point)
		return
	end

	if controlsEnabled
		and rightAimVisible
		and activeAimTouch == nil
		and isPointInsideGui(rightAimBase, point)
	then
		activeAimTouch = input
		activeAimTouchStartPoint = point
		activeAimTouchStartTime = os.clock()
		activeAimTouchMoved = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == activeMovementTouch then
		if controlsEnabled then
			updateMovementFromPoint(screenPointFromInput(input))
		else
			resetMovementTouch()
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
	end
end)

RunService.RenderStepped:Connect(function()
	updateVisibility()

	if activeMovementTouch ~= nil and controlsEnabled and activeMovementPoint ~= nil then
		updateMovementFromPoint(activeMovementPoint)
	end

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

updateVisibility()
