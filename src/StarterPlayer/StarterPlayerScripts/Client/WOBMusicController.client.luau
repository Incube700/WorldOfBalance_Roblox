local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local root = Workspace:WaitForChild("WOB_Generated")
local shared = ReplicatedStorage:WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local AudioConfig = require(configs:WaitForChild("AudioConfig"))
local AudioCatalog = require(configs:WaitForChild("AudioCatalog"))

if AudioConfig.Enabled ~= true then
	return
end

local MUSIC_SOUND_NAME = "WOB_Music"
local DEFAULT_MODE = "Lobby"
local DEFAULT_TRACK_NAME = "LobbyTheme"

local DEFAULT_MUSIC_BY_STATE = table.freeze({
	Lobby = "LobbyTheme",
	QueuedForDuel = "LobbyTheme",
	InBattleArena = "ArenaBattle",
	ArenaRespawning = "ArenaBattle",
	InMatch = "DuelBattle",
})

local activeTween = nil
local currentTrackName = nil
local currentFadeOutSeconds = 0
local lastStingerKey = nil
local playbackToken = 0
local updateMusicForPlayerMode = nil

local function debugPrint(...)
	if AudioConfig.Debug == true then
		print("[MUSIC]", ...)
	end
end

local function getMusicSound()
	local existing = SoundService:FindFirstChild(MUSIC_SOUND_NAME)

	if existing ~= nil and existing:IsA("Sound") then
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = MUSIC_SOUND_NAME
	sound.Parent = SoundService

	return sound
end

local function getMusicTable()
	return typeof(AudioCatalog.Music) == "table" and AudioCatalog.Music or nil
end

local function getTracks()
	local music = getMusicTable()
	return music ~= nil and typeof(music.Tracks) == "table" and music.Tracks or nil
end

local function getStingers()
	local music = getMusicTable()
	return music ~= nil and typeof(music.Stingers) == "table" and music.Stingers or nil
end

local function getMusicByState()
	return typeof(AudioCatalog.MusicByState) == "table" and AudioCatalog.MusicByState or DEFAULT_MUSIC_BY_STATE
end

local function getNumber(value, fallback)
	local numberValue = tonumber(value)

	if numberValue == nil then
		return fallback
	end

	return numberValue
end

local function getTargetVolume(trackDefinition)
	return (AudioConfig.MasterVolume or 1) * getNumber(trackDefinition.Volume, 1)
end

local function cancelActiveTween()
	if activeTween == nil then
		return
	end

	activeTween:Cancel()
	activeTween = nil
end

local function tweenVolume(sound, targetVolume, duration)
	cancelActiveTween()

	if duration <= 0 then
		sound.Volume = targetVolume
		return
	end

	local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Volume = targetVolume,
	})
	activeTween = tween

	tween.Completed:Connect(function()
		if activeTween == tween then
			activeTween = nil
		end
	end)

	tween:Play()
end

local function stopMusic(sound, fadeOutSeconds, token)
	cancelActiveTween()

	if not sound.IsPlaying then
		sound.Volume = 0
		currentTrackName = nil
		currentFadeOutSeconds = 0
		return true
	end

	local duration = math.max(0, getNumber(fadeOutSeconds, 0))

	if duration > 0 then
		local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Volume = 0,
		})
		activeTween = tween
		tween:Play()
		tween.Completed:Wait()

		if activeTween == tween then
			activeTween = nil
		end
	end

	if token ~= nil and token ~= playbackToken then
		return false
	end

	sound:Stop()
	sound.Volume = 0
	currentTrackName = nil
	currentFadeOutSeconds = 0

	return true
end

local function getTrackDefinition(trackName)
	local tracks = getTracks()

	if typeof(tracks) ~= "table" then
		debugPrint("missing AudioCatalog.Music.Tracks")
		return nil
	end

	local trackDefinition = tracks[trackName]

	if typeof(trackDefinition) ~= "table" then
		debugPrint("missing track", trackName)
		return nil
	end

	if typeof(trackDefinition.SoundId) ~= "string" or trackDefinition.SoundId == "" then
		debugPrint("track has no SoundId", trackName)
		return nil
	end

	return trackDefinition
end

local function getStingerDefinition(stingerName)
	local stingers = getStingers()

	if typeof(stingers) ~= "table" then
		debugPrint("missing AudioCatalog.Music.Stingers")
		return nil
	end

	local stingerDefinition = stingers[stingerName]

	if typeof(stingerDefinition) ~= "table" then
		debugPrint("missing stinger", stingerName)
		return nil
	end

	if typeof(stingerDefinition.SoundId) ~= "string" or stingerDefinition.SoundId == "" then
		debugPrint("stinger has no SoundId", stingerName)
		return nil
	end

	return stingerDefinition
end

local function resolveTrackNameForMode(mode)
	local normalizedMode = typeof(mode) == "string" and mode or ""

	if normalizedMode == "" then
		normalizedMode = DEFAULT_MODE
	end

	local musicByState = getMusicByState()
	local trackName = musicByState[normalizedMode] or DEFAULT_MUSIC_BY_STATE[normalizedMode]

	if typeof(trackName) == "string" and trackName ~= "" then
		return trackName, normalizedMode
	end

	debugPrint("unmapped PlayerMode, using default", normalizedMode)
	return DEFAULT_TRACK_NAME, normalizedMode
end

local function playTrack(trackName)
	playbackToken += 1
	local token = playbackToken
	local trackDefinition = getTrackDefinition(trackName)
	local sound = getMusicSound()

	if trackDefinition == nil then
		stopMusic(sound, currentFadeOutSeconds, token)
		return
	end

	local targetVolume = getTargetVolume(trackDefinition)
	local playbackSpeed = getNumber(trackDefinition.PlaybackSpeed, 1)
	local fadeInSeconds = math.max(0, getNumber(trackDefinition.FadeInSeconds, 0))
	local fadeOutSeconds = math.max(0, getNumber(trackDefinition.FadeOutSeconds, 0))
	local looped = trackDefinition.Looped ~= false

	if currentTrackName == trackName and sound.SoundId == trackDefinition.SoundId and sound.IsPlaying then
		sound.PlaybackSpeed = playbackSpeed
		sound.Looped = looped
		currentFadeOutSeconds = fadeOutSeconds
		tweenVolume(sound, targetVolume, 0)
		debugPrint("already playing", trackName)
		return
	end

	if sound.IsPlaying then
		if not stopMusic(sound, currentFadeOutSeconds, token) then
			return
		end
	end

	if token ~= playbackToken then
		return
	end

	currentTrackName = trackName
	currentFadeOutSeconds = fadeOutSeconds

	sound.SoundId = trackDefinition.SoundId
	sound.PlaybackSpeed = playbackSpeed
	sound.Looped = looped
	sound.Volume = fadeInSeconds > 0 and 0 or targetVolume
	sound.TimePosition = 0
	sound:Play()

	if fadeInSeconds > 0 then
		tweenVolume(sound, targetVolume, fadeInSeconds)
	end

	debugPrint("playing", trackName, trackDefinition.SoundId)
end

local function playStinger(stingerName)
	playbackToken += 1
	local token = playbackToken
	local stingerDefinition = getStingerDefinition(stingerName)
	local sound = getMusicSound()

	if stingerDefinition == nil then
		return
	end

	if sound.IsPlaying then
		if not stopMusic(sound, currentFadeOutSeconds, token) then
			return
		end
	end

	if token ~= playbackToken then
		return
	end

	local targetVolume = getTargetVolume(stingerDefinition)
	local playbackSpeed = getNumber(stingerDefinition.PlaybackSpeed, 1)
	local fadeInSeconds = math.max(0, getNumber(stingerDefinition.FadeInSeconds, 0))

	currentTrackName = nil
	currentFadeOutSeconds = math.max(0, getNumber(stingerDefinition.FadeOutSeconds, 0))

	sound.SoundId = stingerDefinition.SoundId
	sound.PlaybackSpeed = playbackSpeed
	sound.Looped = false
	sound.Volume = fadeInSeconds > 0 and 0 or targetVolume
	sound.TimePosition = 0
	sound:Play()

	if fadeInSeconds > 0 then
		tweenVolume(sound, targetVolume, fadeInSeconds)
	end

	local connection = nil
	connection = sound.Ended:Connect(function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end

		if token == playbackToken and updateMusicForPlayerMode ~= nil then
			currentTrackName = nil
			currentFadeOutSeconds = 0
			updateMusicForPlayerMode()
		end
	end)

	debugPrint("stinger", stingerName, stingerDefinition.SoundId)
end

local function getLocalMatchResult()
	local tankId = localPlayer:GetAttribute("TankId")
	local winnerTankId = root:GetAttribute("MatchWinnerTankId")
	local loserTankId = root:GetAttribute("MatchLoserTankId")
	local matchResult = tostring(root:GetAttribute("MatchResult") or "")

	if tankId ~= nil and winnerTankId == tankId then
		return "Win", matchResult, winnerTankId, loserTankId
	end

	if tankId ~= nil and loserTankId == tankId then
		return "Loss", matchResult, winnerTankId, loserTankId
	end

	if matchResult == "PlayerMatchWin" then
		return tankId == root:GetAttribute("OpponentSideTankId") and "Loss" or "Win",
			matchResult,
			winnerTankId,
			loserTankId
	elseif matchResult == "DummyMatchWin" then
		return tankId == root:GetAttribute("OpponentSideTankId") and "Win" or "Loss",
			matchResult,
			winnerTankId,
			loserTankId
	end

	return "", matchResult, winnerTankId, loserTankId
end

local function handleMatchResultStinger()
	local localResult, matchResult, winnerTankId, loserTankId = getLocalMatchResult()

	if localResult == "" then
		return
	end

	local stingerKey = table.concat({
		localResult,
		tostring(matchResult or ""),
		tostring(winnerTankId or ""),
		tostring(loserTankId or ""),
	}, ":")

	if stingerKey == lastStingerKey then
		return
	end

	lastStingerKey = stingerKey

	if localResult == "Win" then
		playStinger("Victory")
	elseif localResult == "Lose" or localResult == "Loss" then
		playStinger("Defeat")
	end
end

updateMusicForPlayerMode = function()
	local trackName, mode = resolveTrackNameForMode(localPlayer:GetAttribute("PlayerMode"))
	debugPrint("mode", mode, "track", trackName)
	playTrack(trackName)
end

local function scheduleMatchResultStinger()
	task.defer(handleMatchResultStinger)
end

localPlayer:GetAttributeChangedSignal("PlayerMode"):Connect(updateMusicForPlayerMode)
localPlayer:GetAttributeChangedSignal("TankId"):Connect(scheduleMatchResultStinger)
root:GetAttributeChangedSignal("MatchResult"):Connect(scheduleMatchResultStinger)
root:GetAttributeChangedSignal("MatchWinnerTankId"):Connect(scheduleMatchResultStinger)
root:GetAttributeChangedSignal("MatchLoserTankId"):Connect(scheduleMatchResultStinger)
updateMusicForPlayerMode()
