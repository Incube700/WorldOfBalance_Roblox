local Players = game:GetService("Players")

local worldHealthBarsFolder = script.Parent:WaitForChild("WorldHealthBars")
local WorldHealthBarsController = require(worldHealthBarsFolder:WaitForChild("WorldHealthBarsController"))

local controller = WorldHealthBarsController.new(Players.LocalPlayer)
controller:Start()
