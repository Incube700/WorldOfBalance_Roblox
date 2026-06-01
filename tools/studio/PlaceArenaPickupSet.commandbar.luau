--!nocheck
--[[
	PlaceArenaPickupSet.commandbar.luau   (ONE-SHOT layout helper)

	Расставляет СРАЗУ ВЕСЬ набор пикапов по продуманным местам за ОДНУ вставку.
	Ничего редактировать не нужно — просто:

	1. В Explorer выдели ПОЛ арены (BasePart, обычно Workspace.WOB_Generated.BattleArena.Floor).
	2. View → Command Bar.
	3. Вставь весь этот файл, нажми Enter.

	Что произойдёт:
	  • Внутри контейнера BattleArena (родитель пола) создаётся папка "PickupSpawns".
	  • В неё кладутся маркеры по дизайну "риск/награда":
	      - 1 Rocket  — в центре (самое опасное место, мощное оружие)
	      - 2 MachineGun — на средних дистанциях слева/справа
	      - 2 RailGun — в дальних углах (награда за вылазку)
	      - 2 Repair — по бокам, чуть в стороне от центра
	  • Все позиции вычисляются ОТ пола (доля от размера), так что подходят под любой
	    размер арены. Старую папку PickupSpawns пересоздаёт заново (чистый набор).

	Двигать маркеры потом можно как угодно. Запускать повторно — просто пересоздаст набор.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local function fail(msg)
	warn("[PICKUP SET] " .. msg .. " Ничего не создано.")
end

local selected = Selection:Get()
if #selected ~= 1 or not selected[1]:IsA("BasePart") then
	return fail("Выдели РОВНО ОДИН пол арены (BasePart), например BattleArena.Floor.")
end

local floor = selected[1]
local container = floor.Parent
if container == nil then
	return fail("У выбранного пола нет родителя-контейнера.")
end

-- Цвета маркеров (совпадают с акцентами оружия) — чтобы различать в Edit Mode.
local TINTS = {
	Rocket = Color3.fromRGB(255, 130, 60),
	MachineGun = Color3.fromRGB(255, 215, 90),
	RailGun = Color3.fromRGB(120, 220, 255),
	Shotgun = Color3.fromRGB(255, 200, 110),
	Repair = Color3.fromRGB(80, 235, 140),
	Shield = Color3.fromRGB(120, 200, 255),
}

-- Набор пикапов: { тип, доляX (-1..1), доляZ (-1..1) }. 0,0 = центр пола.
local LAYOUT = {
	{ "Rocket", 0.0, 0.0 }, -- центр: рискованно, но мощно
	{ "MachineGun", -0.45, 0.0 }, -- слева на средней дистанции
	{ "MachineGun", 0.45, 0.0 }, -- справа на средней дистанции
	{ "RailGun", -0.7, -0.7 }, -- дальний угол
	{ "RailGun", 0.7, 0.7 }, -- противоположный дальний угол
	{ "Shotgun", -0.7, 0.7 }, -- ближний бой, угол
	{ "Shotgun", 0.7, -0.7 }, -- ближний бой, противоположный угол
	{ "Repair", -0.6, 0.55 }, -- бок, в стороне от центра
	{ "Repair", 0.6, -0.55 }, -- противоположный бок
	{ "Shield", 0.0, -0.6 }, -- щит у одного из краёв
	{ "Shield", 0.0, 0.6 }, -- щит у противоположного края
}

-- Пересоздаём папку PickupSpawns в контейнере (чистый набор).
local existing = container:FindFirstChild("PickupSpawns")
if existing ~= nil then
	existing:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "PickupSpawns"
folder.Parent = container

-- Геометрия пола: считаем позиции относительно его CFrame и размера.
local floorCFrame = floor.CFrame
local halfX = floor.Size.X * 0.5
local halfZ = floor.Size.Z * 0.5
local topLocalY = floor.Size.Y * 0.5 + 1 -- чуть над поверхностью

local counters = {}

local function placeMarker(pickupType, fractionX, fractionZ)
	counters[pickupType] = (counters[pickupType] or 0) + 1
	local index = counters[pickupType]

	local marker = Instance.new("Part")
	marker.Name = ("PickupSpawn_%s_%d"):format(pickupType, index)
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.4, 4, 4)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = TINTS[pickupType] or Color3.fromRGB(255, 255, 255)
	marker.Transparency = 0.45
	marker:SetAttribute("WOBPickupType", pickupType)
	marker:SetAttribute("WOBVisualOnly", true)
	-- Локальная точка на полу -> мир. Цилиндр кладём плашмя (поворот по Z на 90°).
	marker.CFrame = floorCFrame
		* CFrame.new(fractionX * halfX * 0.85, topLocalY, fractionZ * halfZ * 0.85)
		* CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = folder
end

for _, entry in ipairs(LAYOUT) do
	placeMarker(entry[1], entry[2], entry[3])
end

print(("[PICKUP SET] Создано %d маркеров в %s. Двигай их как нужно."):format(#LAYOUT, folder:GetFullName()))
