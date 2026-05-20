local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local HudConfig = require(configs:WaitForChild("HudConfig"))

local worldHealthBarsConfig = HudConfig.WorldHealthBars or {}
local SHOW_RELOAD_BAR = worldHealthBarsConfig.Enabled ~= false and worldHealthBarsConfig.ShowReloadBar ~= false

local WorldHealthBarsConfig = {
	GUI_NAME = "WOBTankWorldHealthBars",
	RUNTIME_ROOT_NAME = "WOB_Runtime",
	CLIENT_RUNTIME_FOLDER_NAME = "Client",
	ANCHOR_FOLDER_NAME = "HealthBarAnchors",
	LEGACY_ANCHOR_FOLDER_NAME = "WOB_ClientHealthBarAnchors",
	TEMPLATE_NAME = "TankHealthBillboard",

	SHOW_RELOAD_BAR = SHOW_RELOAD_BAR,
	BILLBOARD_SIZE = SHOW_RELOAD_BAR and UDim2.fromOffset(68, 14) or UDim2.fromOffset(64, 8),
	HEIGHT_OFFSET = Vector3.new(0, 2.2, 0),
	WORLD_OFFSET = Vector3.new(0, 0, -7),
	MAX_DISTANCE = 180,
	DISCOVERY_INTERVAL = 1,

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
