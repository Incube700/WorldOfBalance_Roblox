local WOBClientInputState = {}

local mobileMoveInput = 0
local mobileTurnInput = 0
local mobileMovementActive = false
local mobileEnabled = false
local mobileAimWorldPoint = nil
local mobileShootPending = false
local mobileShootAimWorldPoint = nil

local function clampAxis(value)
	return math.clamp(tonumber(value) or 0, -1, 1)
end

function WOBClientInputState.setMobileEnabled(isEnabled)
	mobileEnabled = isEnabled == true

	if not mobileEnabled then
		WOBClientInputState.resetMobileInput(false)
	end
end

function WOBClientInputState.isMobileEnabled()
	return mobileEnabled
end

function WOBClientInputState.setMobileMovement(moveInput, turnInput, isActive)
	mobileMoveInput = clampAxis(moveInput)
	mobileTurnInput = clampAxis(turnInput)
	mobileMovementActive = isActive == true and (mobileMoveInput ~= 0 or mobileTurnInput ~= 0)
end

function WOBClientInputState.resetMobileMovement()
	mobileMoveInput = 0
	mobileTurnInput = 0
	mobileMovementActive = false
end

function WOBClientInputState.getMobileMovement()
	return mobileMoveInput, mobileTurnInput, mobileMovementActive
end

function WOBClientInputState.setMobileAimWorldPoint(aimWorldPoint)
	if typeof(aimWorldPoint) == "Vector3" then
		mobileAimWorldPoint = aimWorldPoint
	end
end

function WOBClientInputState.getMobileAimWorldPoint()
	return mobileAimWorldPoint
end

-- Clears any latched aim point so the input controller falls back to the tank BODY forward
-- vector (getForwardAimPosition). Used by the BattleArena arcade preset: shooting direction
-- is the tank forward/body direction, never a separate turret/aim point.
function WOBClientInputState.clearMobileAimWorldPoint()
	mobileAimWorldPoint = nil
end

function WOBClientInputState.requestMobileShoot(aimWorldPoint)
	if typeof(aimWorldPoint) == "Vector3" then
		mobileAimWorldPoint = aimWorldPoint
		mobileShootAimWorldPoint = aimWorldPoint
	else
		mobileShootAimWorldPoint = mobileAimWorldPoint
	end

	mobileShootPending = true
end

function WOBClientInputState.enqueueMobileShootRequest(aimWorldPoint)
	WOBClientInputState.requestMobileShoot(aimWorldPoint)
end

function WOBClientInputState.consumeMobileShootRequest()
	if not mobileShootPending then
		return false, nil
	end

	mobileShootPending = false
	local aimWorldPoint = mobileShootAimWorldPoint
	mobileShootAimWorldPoint = nil
	return true, aimWorldPoint
end

function WOBClientInputState.clearMobileShootRequest()
	mobileShootPending = false
	mobileShootAimWorldPoint = nil
end

function WOBClientInputState.resetMobileInput(clearAim)
	WOBClientInputState.resetMobileMovement()
	WOBClientInputState.clearMobileShootRequest()

	if clearAim == true then
		mobileAimWorldPoint = nil
	end
end

return table.freeze(WOBClientInputState)
