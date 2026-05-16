local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local AudioConfig = require(configs:WaitForChild("AudioConfig"))

if AudioConfig.Enabled ~= true then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatFeedbackEvent = remotes:FindFirstChild("CombatFeedbackEvent")
local runtimeVfxFolder = nil
local lastRewardSequence = tonumber(localPlayer:GetAttribute("LastBoltsRewardSequence")) or 0
local lastRoundResult = nil

local function getRuntimeVfxFolder()
	if runtimeVfxFolder ~= nil and runtimeVfxFolder.Parent ~= nil then
		return runtimeVfxFolder
	end

	local root = Workspace:FindFirstChild("WOB_Generated")
	local runtime = root ~= nil and root:FindFirstChild("Runtime") or nil
	runtimeVfxFolder = runtime ~= nil and runtime:FindFirstChild("VFX") or nil

	return runtimeVfxFolder or Workspace
end

local function getSoundConfig(soundKey)
	local sounds = AudioConfig.Sounds or {}
	return sounds[soundKey]
end

local function canPlay(soundConfig)
	return AudioConfig.Enabled == true
		and soundConfig ~= nil
		and typeof(soundConfig.SoundId) == "string"
		and soundConfig.SoundId ~= ""
end

local function getVolume(soundConfig, is2D)
	local channelVolume = is2D and (AudioConfig.UIVolume or 1) or (AudioConfig.CombatVolume or 1)
	return (AudioConfig.MasterVolume or 1) * channelVolume * (soundConfig.Volume or 1)
end

local function getPlaybackSpeed(soundConfig)
	local baseSpeed = tonumber(soundConfig.PlaybackSpeed) or 1
	return baseSpeed * (1 + Random.new():NextNumber(-0.03, 0.03))
end

local function cleanupSound(sound, holder, fallbackLifetime)
	local cleaned = false

	local function cleanup()
		if cleaned then
			return
		end

		cleaned = true

		if holder ~= nil and holder.Parent ~= nil then
			holder:Destroy()
		elseif sound ~= nil and sound.Parent ~= nil then
			sound:Destroy()
		end
	end

	sound.Ended:Connect(cleanup)
	Debris:AddItem(holder or sound, fallbackLifetime or 6)
end

local function configureSound(sound, soundConfig, is2D)
	sound.SoundId = soundConfig.SoundId
	sound.Volume = getVolume(soundConfig, is2D)
	sound.PlaybackSpeed = getPlaybackSpeed(soundConfig)

	if is2D ~= true then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = soundConfig.RollOffMaxDistance or 120
	end
end

local function play2DSound(soundKey)
	local soundConfig = getSoundConfig(soundKey)

	if not canPlay(soundConfig) then
		if AudioConfig.Debug == true then
			print("[AUDIO] skipped " .. tostring(soundKey))
		end

		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "WOB_" .. tostring(soundKey)
	configureSound(sound, soundConfig, true)
	sound.Parent = SoundService
	sound:Play()
	cleanupSound(sound, nil, math.max(2, sound.TimeLength + 1))
end

local function play3DSound(soundKey, worldPosition)
	local soundConfig = getSoundConfig(soundKey)

	if not canPlay(soundConfig) then
		if AudioConfig.Debug == true then
			print("[AUDIO] skipped " .. tostring(soundKey))
		end

		return
	end

	if soundConfig.Is2D == true or typeof(worldPosition) ~= "Vector3" then
		play2DSound(soundKey)
		return
	end

	local holder = Instance.new("Part")
	holder.Name = "WOB_Audio_" .. tostring(soundKey)
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = worldPosition
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Parent = getRuntimeVfxFolder()

	local sound = Instance.new("Sound")
	sound.Name = tostring(soundKey)
	configureSound(sound, soundConfig, false)
	sound.Parent = holder
	sound:Play()
	cleanupSound(sound, holder, math.max(3, sound.TimeLength + 1))
end

local function upperText(value)
	return string.upper(tostring(value or ""))
end

local function chooseSoundKey(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	local payloadType = tostring(payload.Type or "")
	local text = upperText(payload.Text)

	if payloadType == "Shot" then
		return "Shot"
	elseif payloadType == "Ricochet" or payloadType == "ArmorRicochet" then
		return "Ricochet"
	elseif payloadType == "Damage" then
		return "Hit"
	elseif payloadType == "NoPenetration" then
		return "NoPenetration"
	elseif payloadType == "TankDestroyed" then
		return "TankDestroyed"
	elseif payloadType == "BlockedShot" or payloadType == "BarrelBlocked" then
		return "BarrelBlocked"
	end

	if string.find(text, "BARREL BLOCKED", 1, true) ~= nil then
		return "BarrelBlocked"
	elseif string.find(text, "RICOCHET", 1, true) ~= nil then
		return "Ricochet"
	elseif string.find(text, "NO PEN", 1, true) ~= nil or string.find(text, "NO PENETRATION", 1, true) ~= nil then
		return "NoPenetration"
	elseif string.find(text, "DESTROYED", 1, true) ~= nil then
		return "TankDestroyed"
	elseif string.find(text, "HIT", 1, true) ~= nil or string.match(text, "^%-?%d+") ~= nil then
		return "Hit"
	end

	return nil
end

local function handleCombatFeedback(payload)
	local soundKey = chooseSoundKey(payload)

	if soundKey == nil then
		return
	end

	play3DSound(soundKey, typeof(payload.Position) == "Vector3" and payload.Position or nil)
end

local function handleBoltReward()
	local nextSequence = tonumber(localPlayer:GetAttribute("LastBoltsRewardSequence")) or 0

	if nextSequence == lastRewardSequence then
		return
	end

	lastRewardSequence = nextSequence

	if (tonumber(localPlayer:GetAttribute("LastBoltsRewardAmount")) or 0) > 0 then
		play2DSound("BoltReward")
	end
end

local function handleRoundResult()
	local result = tostring(localPlayer:GetAttribute("RoundResult") or "")

	if result == "" or result == lastRoundResult then
		return
	end

	lastRoundResult = result

	if result == "Win" then
		play2DSound("Win")
	elseif result == "Lose" then
		play2DSound("Lose")
	end
end

if combatFeedbackEvent ~= nil then
	combatFeedbackEvent.OnClientEvent:Connect(handleCombatFeedback)
end

localPlayer:GetAttributeChangedSignal("LastBoltsRewardSequence"):Connect(handleBoltReward)
localPlayer:GetAttributeChangedSignal("LastBoltsRewardAmount"):Connect(function()
	if tonumber(localPlayer:GetAttribute("LastBoltsRewardSequence")) == nil then
		if (tonumber(localPlayer:GetAttribute("LastBoltsRewardAmount")) or 0) > 0 then
			play2DSound("BoltReward")
		end
	end
end)
localPlayer:GetAttributeChangedSignal("RoundResult"):Connect(handleRoundResult)

print("[WOB] Audio controller started")
