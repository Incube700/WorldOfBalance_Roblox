local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local AudioConfig = require(configs:WaitForChild("AudioConfig"))
local AudioCatalog = require(configs:WaitForChild("AudioCatalog"))

if AudioConfig.Enabled ~= true then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatFeedbackEvent = remotes:FindFirstChild("CombatFeedbackEvent")
local runtimeVfxFolder = nil
local lastRewardSequence = tonumber(localPlayer:GetAttribute("LastBoltsRewardSequence")) or 0
local lastCrystalRewardSequence = tonumber(localPlayer:GetAttribute("LastCrystalsRewardSequence")) or 0
local lastRoundResult = nil
local rng = Random.new()
local playedSoundTimes = {}
local lastPlayedByCategory = {}

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	elseif not folder:IsA("Folder") then
		return nil
	end

	return folder
end

local function getRuntimeVfxFolder()
	if runtimeVfxFolder ~= nil and runtimeVfxFolder.Parent ~= nil then
		return runtimeVfxFolder
	end

	local wobRuntime = Workspace:FindFirstChild("WOB_Runtime") or Workspace:WaitForChild("WOB_Runtime", 2)

	if wobRuntime == nil then
		wobRuntime = getOrCreateFolder(Workspace, "WOB_Runtime")
	end

	runtimeVfxFolder = wobRuntime ~= nil and getOrCreateFolder(wobRuntime, "VFX") or nil

	if runtimeVfxFolder ~= nil then
		return runtimeVfxFolder
	end

	local root = Workspace:FindFirstChild("WOB_Generated")
	local runtime = root ~= nil and root:FindFirstChild("Runtime") or nil
	runtimeVfxFolder = runtime ~= nil and runtime:FindFirstChild("VFX") or nil

	return runtimeVfxFolder or Workspace
end

-- Etap 3: if a specialised category has no SoundId yet, fall back to its base category so
-- the event still gets a sound (per-weapon shots -> generic Shot, etc.).
local CATEGORY_FALLBACK = {
	ShotRocket = "Shot",
	ShotMachineGun = "Shot",
	ShotRailGun = "Shot",
}

local function resolveSoundDefinition(category, payload)
	if typeof(category) ~= "string" or category == "" then
		return nil, nil
	end

	-- TODO: later resolve owner/custom sound by payload.OwnerUserId and validated player loadout attributes.
	local defaultSoundIds = AudioCatalog.DefaultSoundIds or {}
	local sounds = AudioCatalog.Sounds or {}
	local soundKey = defaultSoundIds[category]
	local soundDefinition = soundKey ~= nil and sounds[soundKey] or nil

	-- If this category resolves to an empty-id sound, try its fallback category instead.
	local hasId = soundDefinition ~= nil
		and typeof(soundDefinition.SoundId) == "string"
		and soundDefinition.SoundId ~= ""

	if not hasId and CATEGORY_FALLBACK[category] ~= nil then
		local fbKey = defaultSoundIds[CATEGORY_FALLBACK[category]]
		local fbDef = fbKey ~= nil and sounds[fbKey] or nil
		if fbDef ~= nil then
			return fbKey, fbDef
		end
	end

	if soundDefinition == nil then
		return nil, nil
	end

	return soundKey, soundDefinition
end

local function canPlay(soundDefinition)
	return AudioConfig.Enabled == true
		and soundDefinition ~= nil
		and typeof(soundDefinition.SoundId) == "string"
		and soundDefinition.SoundId ~= ""
end

local function canPlayNow(category, soundDefinition)
	local now = os.clock()
	local maxSoundsPerSecond = math.max(1, math.floor(tonumber(AudioConfig.MaxSoundsPerSecond) or 24))

	while #playedSoundTimes > 0 and now - playedSoundTimes[1] > 1 do
		table.remove(playedSoundTimes, 1)
	end

	if #playedSoundTimes >= maxSoundsPerSecond then
		return false
	end

	local throttleSeconds = math.max(0, tonumber(soundDefinition.ThrottleSeconds) or 0)
	local lastPlayedAt = lastPlayedByCategory[category]

	if throttleSeconds > 0 and typeof(lastPlayedAt) == "number" and now - lastPlayedAt < throttleSeconds then
		return false
	end

	table.insert(playedSoundTimes, now)
	lastPlayedByCategory[category] = now

	return true
end

local function getVolume(soundDefinition, is2D)
	local channelVolume = is2D and (AudioConfig.UIVolume or 1) or (AudioConfig.CombatVolume or 1)
	return (AudioConfig.MasterVolume or 1) * channelVolume * (soundDefinition.Volume or 1)
end

local function getPlaybackSpeed(soundDefinition)
	local baseSpeed = tonumber(soundDefinition.PlaybackSpeed) or 1
	local pitchJitter = math.max(0, tonumber(AudioConfig.PitchJitter) or 0)
	return baseSpeed * (1 + rng:NextNumber(-pitchJitter, pitchJitter))
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

local function configureSound(sound, soundDefinition, is2D)
	sound.SoundId = soundDefinition.SoundId
	sound.Volume = getVolume(soundDefinition, is2D)
	sound.PlaybackSpeed = getPlaybackSpeed(soundDefinition)

	if is2D ~= true then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = soundDefinition.RollOffMaxDistance or 120
	end
end

local function play2DSound(category, payload)
	local soundKey, soundDefinition = resolveSoundDefinition(category, payload)

	if not canPlay(soundDefinition) then
		if AudioConfig.Debug == true then
			print("[AUDIO] skipped " .. tostring(category))
		end

		return
	end

	if not canPlayNow(category, soundDefinition) then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "WOB_" .. tostring(soundKey)
	configureSound(sound, soundDefinition, true)
	sound.Parent = SoundService
	sound:Play()
	cleanupSound(sound, nil, math.max(2, sound.TimeLength + 1))
end

local function play3DSound(category, worldPosition, payload)
	local soundKey, soundDefinition = resolveSoundDefinition(category, payload)

	if not canPlay(soundDefinition) then
		if AudioConfig.Debug == true then
			print("[AUDIO] skipped " .. tostring(category))
		end

		return
	end

	if soundDefinition.Is2D == true or typeof(worldPosition) ~= "Vector3" then
		play2DSound(category, payload)
		return
	end

	if not canPlayNow(category, soundDefinition) then
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
	configureSound(sound, soundDefinition, false)
	sound.Parent = holder
	sound:Play()
	cleanupSound(sound, holder, math.max(3, sound.TimeLength + 1))
end

local function upperText(value)
	return string.upper(tostring(value or ""))
end

local function chooseSoundCategory(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	local explicitCategory = payload.SoundCategory or payload.AudioCategory or payload.Category

	if typeof(explicitCategory) == "string" and (AudioCatalog.DefaultSoundIds or {})[explicitCategory] ~= nil then
		return explicitCategory
	end

	local payloadType = tostring(payload.Type or "")
	local text = upperText(payload.Text)

	if payloadType == "Shot" then
		-- Per-weapon shot variant when the payload names a weapon (falls back to Shot if its
		-- SoundId is empty, handled in resolveSoundDefinition).
		local weapon = tostring(payload.WeaponId or "")
		if weapon == "Rocket" then
			return "ShotRocket"
		elseif weapon == "MachineGun" then
			return "ShotMachineGun"
		elseif weapon == "RailGun" then
			return "ShotRailGun"
		end
		return "Shot"
	elseif payloadType == "Pickup" or payloadType == "PickupCollect" then
		return "PickupCollect"
	elseif payloadType == "Ricochet" or payloadType == "ArmorRicochet" then
		return "RicochetImpact"
	elseif payloadType == "Damage" then
		return "ProjectileImpact"
	elseif payloadType == "NoPenetration" then
		return "NoPenetration"
	elseif payloadType == "TankDestroyed" then
		return "TankExplosion"
	elseif payloadType == "ShieldReflect" then
		return "ReflectShield"
	elseif payloadType == "UpgradeSelect" then
		return "UpgradeSelect"
	elseif payloadType == "LevelUp" then
		return "LevelUp"
	elseif payloadType == "Repair" then
		return "Repair"
	elseif payloadType == "BlockedShot" or payloadType == "BarrelBlocked" then
		return "BarrelBlocked"
	end

	if string.find(text, "BARREL BLOCKED", 1, true) ~= nil then
		return "BarrelBlocked"
	elseif string.find(text, "RICOCHET", 1, true) ~= nil then
		return "RicochetImpact"
	elseif string.find(text, "NO PEN", 1, true) ~= nil or string.find(text, "NO PENETRATION", 1, true) ~= nil then
		return "NoPenetration"
	elseif string.find(text, "REFLECT", 1, true) ~= nil then
		return "ReflectShield"
	elseif string.find(text, "DESTROYED", 1, true) ~= nil then
		return "TankExplosion"
	elseif string.find(text, "HIT", 1, true) ~= nil or string.match(text, "^%-?%d+") ~= nil then
		return "ProjectileImpact"
	end

	return nil
end

local function handleCombatFeedback(payload)
	local soundCategory = chooseSoundCategory(payload)

	if soundCategory == nil then
		return
	end

	play3DSound(soundCategory, typeof(payload.Position) == "Vector3" and payload.Position or nil, payload)
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

local function handleCrystalReward()
	local nextSequence = tonumber(localPlayer:GetAttribute("LastCrystalsRewardSequence")) or 0

	if nextSequence == lastCrystalRewardSequence then
		return
	end

	lastCrystalRewardSequence = nextSequence

	if (tonumber(localPlayer:GetAttribute("LastCrystalsRewardAmount")) or 0) > 0 then
		play2DSound("CrystalReward")
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
localPlayer:GetAttributeChangedSignal("LastCrystalsRewardSequence"):Connect(handleCrystalReward)
localPlayer:GetAttributeChangedSignal("LastCrystalsRewardAmount"):Connect(function()
	if tonumber(localPlayer:GetAttribute("LastCrystalsRewardSequence")) == nil then
		if (tonumber(localPlayer:GetAttribute("LastCrystalsRewardAmount")) or 0) > 0 then
			play2DSound("CrystalReward")
		end
	end
end)
localPlayer:GetAttributeChangedSignal("RoundResult"):Connect(handleRoundResult)

print("[WOB] Audio controller started")
