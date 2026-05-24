local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local HudConfig = require(configs:WaitForChild("HudConfig"))
local PerformanceConfig = require(configs:WaitForChild("PerformanceConfig"))

local worldHealthBarsConfig = HudConfig.WorldHealthBars or {}
local diagnosticsConfig = PerformanceConfig.Diagnostics or {}
local enabledOverride = diagnosticsConfig.WorldHealthBarsEnabledOverride
local enabled = worldHealthBarsConfig.Enabled ~= false

if typeof(enabledOverride) == "boolean" then
	enabled = enabledOverride
end

local SHOW_RELOAD_BAR = enabled and worldHealthBarsConfig.ShowReloadBar ~= false
local maxDistance = math.max(80, tonumber(worldHealthBarsConfig.MaxDistance) or 120)
local discoveryInterval = math.max(1, tonumber(worldHealthBarsConfig.DiscoveryInterval) or 1)
local smoothingEnabled = enabled and worldHealthBarsConfig.SmoothingEnabled ~= false
local positionSmoothingSpeed = math.max(1, tonumber(worldHealthBarsConfig.PositionSmoothingSpeed) or 18)

local WorldHealthBarsConfig = {
	GUI_NAME = "WOBTankWorldHealthBars",
	RUNTIME_ROOT_NAME = "WOB_Runtime",
	CLIENT_RUNTIME_FOLDER_NAME = "Client",
	ANCHOR_FOLDER_NAME = "HealthBarAnchors",
	LEGACY_ANCHOR_FOLDER_NAME = "WOB_ClientHealthBarAnchors",
	TEMPLATE_NAME = "TankHealthBillboard",

	ENABLED = enabled,
	SHOW_RELOAD_BAR = SHOW_RELOAD_BAR,
	SMOOTHING_ENABLED = smoothingEnabled,
	POSITION_SMOOTHING_SPEED = positionSmoothingSpeed,
	BILLBOARD_SIZE = SHOW_RELOAD_BAR and UDim2.fromOffset(68, 14) or UDim2.fromOffset(64, 8),
	HEIGHT_OFFSET = Vector3.new(0, 2.2, 0),
	WORLD_OFFSET = Vector3.new(0, 0, -7),
	MAX_DISTANCE = maxDistance,
	DISCOVERY_INTERVAL = discoveryInterval,

	HEALTH_ATTRIBUTES = { "CurrentHealth", "HP", "Health" },

	TRACKED_ATTRIBUTES = {
		"CurrentHealth",
		"HP",
		"Health",
		"MaxHealth",
		"IsDead",
		"IsAlive",
		"IsActive",
		"TankParticipantId",
		"LastShotAtServerTime",
		"ReloadDuration",
		"ReloadProgress",
		"ReloadReady",
	},
}

return table.freeze(WorldHealthBarsConfig)
