--!nocheck
--[[
	CreateWinnerPodiums.commandbar.luau   (ONE-SHOT)

	Создаёт ДВА постамента победителей в лобби, которые читает WinnerPodiumService:
	  • ArenaChampionPodium — чемпион арены (макс уровень)
	  • DuelKingPodium       — король дуэлей (число дуэлей)

	Как использовать:
	1. (Желательно) выдели часть пола ЛОББИ, чтобы постаменты встали рядом с ней.
	   Если ничего не выделено — встанут у Workspace.WOB_Generated.Lobby (или у 0,0,0).
	2. View → Command Bar, вставь этот файл, Enter.

	Что создаётся в Workspace.WOB_Generated.Lobby:
	  Папка "WinnerPodiums" с двумя моделями. В каждой:
	    - Base (постамент, неоновая окантовка),
	    - TankAnchor (пустой Part, куда WinnerPodiumService сможет ставить модель танка),
	    - BillboardGui с именем/статом (его сервис обновляет в рантайме).
	Запуск повторно — пересоздаёт набор начисто.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local generated = Workspace:FindFirstChild("WOB_Generated")
local lobby = generated and generated:FindFirstChild("Lobby")
if lobby == nil then
	warn("[PODIUMS] Workspace.WOB_Generated.Lobby не найден. Создаю постаменты прямо в WOB_Generated.")
	lobby = generated or Workspace
end

-- Базовая точка: над выделенной частью пола, иначе центр лобби, иначе origin.
local basePos = Vector3.new(0, 3, 0)
local sel = Selection:Get()
if #sel == 1 and sel[1]:IsA("BasePart") then
	local p = sel[1]
	basePos = p.Position + Vector3.new(0, p.Size.Y * 0.5 + 2, 0)
elseif lobby:IsA("Model") then
	local ok, cf = pcall(function()
		return (lobby:GetBoundingBox())
	end)
	if ok and typeof(cf) == "CFrame" then
		basePos = cf.Position + Vector3.new(0, 3, 0)
	end
end

local existing = lobby:FindFirstChild("WinnerPodiums")
if existing then
	existing:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "WinnerPodiums"
folder.Parent = lobby

-- side: -1 (left) / +1 (right). partName должен совпадать с WinnerPodiumService.PODIUMS.
local function buildPodium(partName, title, accent, side)
	local model = Instance.new("Model")
	model.Name = partName .. "_Model"
	model.Parent = folder

	local pos = basePos + Vector3.new(side * 10, 0, 0)

	-- Постамент-цилиндр.
	local base = Instance.new("Part")
	base.Name = partName -- ВАЖНО: это имя ищет WinnerPodiumService
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(2, 8, 8)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromRGB(34, 42, 54)
	base.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = model

	local ring = Instance.new("SelectionBox")
	ring.Adornee = base
	ring.Color3 = accent
	ring.LineThickness = 0.08
	ring.Transparency = 0.2
	ring.Parent = base

	-- Якорь для модели танка победителя (сервис может PivotTo сюда).
	local tankAnchor = Instance.new("Part")
	tankAnchor.Name = "TankAnchor"
	tankAnchor.Size = Vector3.new(1, 1, 1)
	tankAnchor.Transparency = 1
	tankAnchor.Anchored = true
	tankAnchor.CanCollide = false
	tankAnchor.CanQuery = false
	tankAnchor.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
	tankAnchor.Parent = model

	-- Табличка (сервис обновит Title/WinnerName/WinnerValue).
	local gui = Instance.new("BillboardGui")
	gui.Name = "WinnerPodiumPlate"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = base
	gui.Parent = base

	local function label(name, yScale, sizeY, color, text)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.new(0, 0, yScale, 0)
		l.Size = UDim2.new(1, 0, 0, sizeY)
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.4
		l.Text = text
		l.Parent = gui
	end
	label("Title", 0, 22, accent, title)
	label("WinnerName", 0.4, 22, Color3.fromRGB(240, 246, 255), "—")
	label("WinnerValue", 0.78, 14, Color3.fromRGB(180, 205, 235), "")

	model.PrimaryPart = base
end

buildPodium("ArenaChampionPodium", "ARENA CHAMPION", Color3.fromRGB(250, 205, 90), -1)
buildPodium("DuelKingPodium", "DUEL KING", Color3.fromRGB(120, 200, 255), 1)

print("[PODIUMS] Созданы ArenaChampionPodium и DuelKingPodium в " .. folder:GetFullName())
