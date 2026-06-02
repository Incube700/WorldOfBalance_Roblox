--!nocheck
--[[
	BuildVfxTemplates.commandbar.luau   (ONE-SHOT, safe to re-run)

	Создаёт КРАСИВЫЕ многослойные шаблоны частиц для 4 пустых VFX-слотов прямо в
	ReplicatedStorage/Shared/Assets/VFX. Каждый шаблон = anchored Part, внутри несколько
	ParticleEmitter'ов (ядро + искры + дым/кольцо). CombatVfxService:emitAllParticles эмитит
	ВСЕ эмиттеры внутри по их атрибуту EmitCount, так что многослойность работает из коробки.

	Создаёт:
	  * RailGunShot_Default      — электрически-синяя вспышка спавна (ядро + лучи-искры + кольцо)
	  * RocketShot_Default       — алый/оранжевый пуск (огонь + искры + дым)
	  * Repair_Default           — зелёное лечение (поднимающиеся искры + мягкая вспышка)
	  * UpgradeSelect_Default    — золотой апгрейд (взлёт вверх + кольцо)

	Как использовать:
	1. View → Command Bar, вставь весь файл, Enter. (Ничего выделять не нужно.)
	2. Проверь Output — должно быть "[VFX BUILD] Готово: 4 шаблона".
	3. В VfxRegistry.luau у RailGunShot/RocketShot/Repair/UpgradeSelect убери `Missing = true`
	   (скрипт напомнит). После этого процедурный fallback заменяется этими шаблонами.

	Это СТАРТОВЫЕ, уже неплохо выглядящие шаблоны — крути частицы в Studio как захочешь,
	реестр находит их по ИМЕНИ объекта.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("Shared")
folder = folder and folder:FindFirstChild("Assets")
folder = folder and folder:FindFirstChild("VFX")
if folder == nil then
	warn("[VFX BUILD] ReplicatedStorage/Shared/Assets/VFX не найдена. Ничего не создано.")
	return
end

-- Текстуры частиц (стоковые Roblox). Замени на свои при желании.
local SOFT = "rbxassetid://243660364"  -- мягкое круглое пятно
local SPARK = "rbxassetid://6101755940" -- искра/полоска
local RING = "rbxassetid://7341974965" -- кольцо (если недоступно — будет мягкое пятно)

-- Создаёт пустой anchored-носитель шаблона.
local function newHolder(name)
	local existing = folder:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("VfxTemplateType", "Burst")

	local att = Instance.new("Attachment")
	att.Name = "Origin"
	att.Parent = part
	return part, att
end

-- Добавляет один слой-эмиттер. Поля spec опциональны (есть дефолты).
local function addLayer(att, layerName, spec)
	local e = Instance.new("ParticleEmitter")
	e.Name = layerName
	e.Texture = spec.texture or SOFT
	e.Color = spec.color
	e.Size = NumberSequence.new(spec.sizeSeq or {
		NumberSequenceKeypoint.new(0, spec.size or 1.5),
		NumberSequenceKeypoint.new(1, (spec.size or 1.5) * (spec.endSizeScale or 0.15)),
	})
	e.Transparency = NumberSequence.new(spec.transparencySeq or {
		NumberSequenceKeypoint.new(0, spec.startTransparency or 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(spec.lifeMin or 0.35, spec.lifeMax or 0.6)
	e.Speed = NumberRange.new(spec.speedMin or 6, spec.speedMax or 12)
	e.SpreadAngle = Vector2.new(spec.spread or 180, spec.spread or 180)
	e.Rotation = NumberRange.new(spec.rotMin or -180, spec.rotMax or 180)
	e.RotSpeed = NumberRange.new(spec.rotSpeed and -spec.rotSpeed or 0, spec.rotSpeed or 0)
	e.LightEmission = spec.glow or 0.7
	e.LightInfluence = 0
	e.Drag = spec.drag or 0
	if spec.accel then
		e.Acceleration = spec.accel
	end
	e.Rate = 0 -- эмитим вручную (CombatVfxService:emitAllParticles)
	e:SetAttribute("EmitCount", spec.emit or 18) -- сколько частиц на одно срабатывание
	e.Parent = att
	return e
end

-- ---------------------------------------------------------------------------
-- 1) RAILGUN — электрически-синяя вспышка спавна. Ядро + радиальные лучи + кольцо.
-- ---------------------------------------------------------------------------
do
	local _, att = newHolder("RailGunShot_Default")
	addLayer(att, "Core", {
		color = ColorSequence.new(Color3.fromRGB(210, 245, 255), Color3.fromRGB(70, 175, 255)),
		texture = SOFT, size = 2.4, endSizeScale = 0.1, lifeMin = 0.12, lifeMax = 0.22,
		speedMin = 2, speedMax = 5, spread = 30, glow = 1, emit = 10,
	})
	addLayer(att, "Sparks", {
		color = ColorSequence.new(Color3.fromRGB(180, 235, 255), Color3.fromRGB(40, 150, 255)),
		texture = SPARK, size = 1.4, endSizeScale = 0.05, lifeMin = 0.18, lifeMax = 0.34,
		speedMin = 26, speedMax = 40, spread = 22, glow = 1, emit = 22, drag = 6,
	})
	addLayer(att, "Ring", {
		color = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 130, 255)),
		texture = RING, size = 1.2, endSizeScale = 5, lifeMin = 0.22, lifeMax = 0.3,
		speedMin = 0, speedMax = 0, spread = 0, glow = 0.9, emit = 1, rotSpeed = 30,
	})
end

-- ---------------------------------------------------------------------------
-- 2) ROCKET — алый/оранжевый пуск. Огненное ядро + алые искры + серый дым.
-- ---------------------------------------------------------------------------
do
	local _, att = newHolder("RocketShot_Default")
	addLayer(att, "Fire", {
		color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 90, 40)),
		texture = SOFT, size = 2.2, endSizeScale = 0.2, lifeMin = 0.2, lifeMax = 0.4,
		speedMin = 4, speedMax = 10, spread = 45, glow = 0.95, emit = 16,
	})
	addLayer(att, "Sparks", {
		color = ColorSequence.new(Color3.fromRGB(255, 120, 80), Color3.fromRGB(220, 30, 25)),
		texture = SPARK, size = 1.2, endSizeScale = 0.05, lifeMin = 0.25, lifeMax = 0.5,
		speedMin = 14, speedMax = 26, spread = 60, glow = 0.85, emit = 18, drag = 3,
	})
	addLayer(att, "Smoke", {
		color = ColorSequence.new(Color3.fromRGB(120, 110, 105), Color3.fromRGB(60, 55, 55)),
		texture = SOFT, size = 2.6, endSizeScale = 1.8, lifeMin = 0.6, lifeMax = 1.0,
		speedMin = 2, speedMax = 5, spread = 70, glow = 0, emit = 10,
		startTransparency = 0.5, accel = Vector3.new(0, 6, 0),
	})
end

-- ---------------------------------------------------------------------------
-- 3) REPAIR — зелёное лечение. Мягкая вспышка + поднимающиеся искры + кольцо.
-- ---------------------------------------------------------------------------
do
	local _, att = newHolder("Repair_Default")
	addLayer(att, "Glow", {
		color = ColorSequence.new(Color3.fromRGB(170, 255, 190), Color3.fromRGB(60, 215, 120)),
		texture = SOFT, size = 2.0, endSizeScale = 0.3, lifeMin = 0.3, lifeMax = 0.5,
		speedMin = 1, speedMax = 3, spread = 40, glow = 0.8, emit = 10,
	})
	addLayer(att, "Rise", {
		color = ColorSequence.new(Color3.fromRGB(140, 255, 170), Color3.fromRGB(70, 230, 130)),
		texture = SPARK, size = 0.9, endSizeScale = 0.05, lifeMin = 0.5, lifeMax = 0.9,
		speedMin = 6, speedMax = 11, spread = 25, glow = 0.9, emit = 18,
		accel = Vector3.new(0, 14, 0),
	})
	addLayer(att, "Ring", {
		color = ColorSequence.new(Color3.fromRGB(120, 245, 150)),
		texture = RING, size = 1.0, endSizeScale = 4, lifeMin = 0.3, lifeMax = 0.4,
		speedMin = 0, speedMax = 0, spread = 0, glow = 0.8, emit = 1, rotSpeed = 20,
	})
end

-- ---------------------------------------------------------------------------
-- 4) UPGRADE SELECT — золотая вспышка апгрейда. Ядро + взлёт вверх + кольцо.
-- ---------------------------------------------------------------------------
do
	local _, att = newHolder("UpgradeSelect_Default")
	addLayer(att, "Core", {
		color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(250, 200, 80)),
		texture = SOFT, size = 2.2, endSizeScale = 0.2, lifeMin = 0.2, lifeMax = 0.4,
		speedMin = 3, speedMax = 7, spread = 50, glow = 0.95, emit = 14,
	})
	addLayer(att, "Rise", {
		color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(245, 190, 70)),
		texture = SPARK, size = 1.1, endSizeScale = 0.05, lifeMin = 0.4, lifeMax = 0.8,
		speedMin = 10, speedMax = 18, spread = 30, glow = 1, emit = 20,
		accel = Vector3.new(0, 18, 0), drag = 2,
	})
	addLayer(att, "Ring", {
		color = ColorSequence.new(Color3.fromRGB(255, 215, 110), Color3.fromRGB(230, 170, 50)),
		texture = RING, size = 1.2, endSizeScale = 5, lifeMin = 0.25, lifeMax = 0.35,
		speedMin = 0, speedMax = 0, spread = 0, glow = 0.9, emit = 1, rotSpeed = 40,
	})
end

print("[VFX BUILD] Готово: 4 шаблона созданы в " .. folder:GetFullName()
	.. " (RailGunShot_Default, RocketShot_Default, Repair_Default, UpgradeSelect_Default).")
print("[VFX BUILD] Теперь в VfxRegistry.luau убери `Missing = true` у этих четырёх эффектов.")
