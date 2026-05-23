--[[
	REMOVE_LEGACY_TANK_PREFABS_COMMAND.lua

	Назначение: оставить ОДИН префаб (BaseTankTemplate) как единственный источник
	для сборки всех танков, и убрать неиспользуемые легаси-модели из
	Workspace.WOB_Generated.TestObjects.

	Почему это безопасно: TankTemplateProvider:GetTemplateForRole() уже выбирает
	BaseTankTemplate как Priority 1 для ВСЕХ ролей (игрок, дамми, дуэльный
	оппонент, бот, арена-бот). Легаси-модели — это лишь fallback, который
	срабатывает, только если BaseTankTemplate отсутствует.

	Защита: скрипт НИЧЕГО не удалит, если BaseTankTemplate не найден — чтобы у
	фабрики гарантированно остался шаблон для клонирования.

	Как запустить: Studio → View → Command Bar → вставить содержимое → Enter.
	Откатить: Ctrl+Z (операция попадает в историю изменений).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BASE_TEMPLATE_NAME = "BaseTankTemplate"
local LEGACY_NAMES = {
	"PlayerTankPrototype",
	"Player2TankPrototype",
	"DummyTank",
}

local root = workspace:FindFirstChild("WOB_Generated")
local testObjects = root and root:FindFirstChild("TestObjects")

if testObjects == nil then
	warn("[CLEANUP] Не найден Workspace.WOB_Generated.TestObjects — ничего не делаю.")
	return
end

local base = testObjects:FindFirstChild(BASE_TEMPLATE_NAME)

if base == nil or not base:IsA("Model") then
	warn("[CLEANUP] BaseTankTemplate не найден в TestObjects. Удаление ОТМЕНЕНО, "
		.. "чтобы не остаться без шаблона для спавна танков.")
	return
end

local recording = ChangeHistoryService:TryBeginRecording("RemoveLegacyTankPrefabs")
local removed = {}

for _, name in ipairs(LEGACY_NAMES) do
	local model = testObjects:FindFirstChild(name)

	if model ~= nil and model:IsA("Model") then
		model:Destroy()
		table.insert(removed, name)
		print("[CLEANUP] Удалён легаси-префаб: " .. name)
	else
		print("[CLEANUP] Пропущено (не найдено): " .. name)
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(string.format(
	"[CLEANUP] Готово. Все танки теперь собираются только из '%s'. Удалено моделей: %d.",
	BASE_TEMPLATE_NAME,
	#removed
))
