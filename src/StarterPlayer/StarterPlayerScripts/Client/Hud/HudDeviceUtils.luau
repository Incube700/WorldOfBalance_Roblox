local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local MobileControlsConfig = require(configs:WaitForChild("MobileControlsConfig"))

local HudDeviceUtils = {}

function HudDeviceUtils.IsMobileLayout()
	return UserInputService.TouchEnabled == true or MobileControlsConfig.ForceEnabledInStudio == true
end

return HudDeviceUtils
