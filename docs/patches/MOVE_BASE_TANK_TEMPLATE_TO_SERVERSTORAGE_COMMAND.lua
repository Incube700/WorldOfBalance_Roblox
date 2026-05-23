--[[
	MOVE_BASE_TANK_TEMPLATE_TO_SERVERSTORAGE_COMMAND.lua

	Назначение: перенести единственный префаб BaseTankTemplate со сцены
	(Workspace.WOB_Generated.TestObjects) в ServerStorage.TankTemplates, чтобы он
	не мешал на дуэли/арене, но оставался доступен серверу для клонирования.

	Это безопасно вместе с правкой TankTemplateProvider: провайдер теперь сначала
	ищет префаб в ServerStorage.TankTemplates, и только потом — в TestObjects.

	ServerStorage не реплицируется клиентам и не существует в мире, поэтому префаб
	физически исчезает со сцены, но фабрика по-прежнему его клонирует.

	Как запустить: Studio → View → Command Bar → вставить содержимое → Enter.
	Откатить: Ctrl+Z.
]]

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BASE_TEMPLATE_NAME = "BaseTankTemplate"
local STORAGE_FOLDER_NAME = "TankTemplates"

local root = workspace:FindFirstChild("WOB_Generated")
local testObjects = root and root:FindFirstChild("TestObjects")

-- Папка-хранилище в ServerStorage (создаём, если её ещё нет).
local storage = ServerStorage:FindFirstChild(STORAGE_FOLDER_NAME)

local alreadyThere = storage and storage:FindFirstChild(BASE_TEMPLATE_NAME)
if alreadyThere ~= nil and alreadyThere:IsA("Model") then
	print("[MOVE] BaseTankTemplate уже в ServerStorage." .. STORAGE_FOLDER_NAME .. " — ничего делать не нужно.")
	return
end

local template = testObjects and testObjects:FindFirstChild(BASE_TEMPLATE_NAME)
if template == nil or not template:IsA("Model") then
	warn("[MOVE] BaseTankTemplate не найден ни в ServerStorage." .. STORAGE_FOLDER_NAME
		.. ", ни в Workspace.WOB_Generated.TestObjects. Перенос отменён.")
	return
end

local recording = ChangeHistoryService:TryBeginRecording("MoveBaseTankTemplateToServerStorage")

if storage == nil then
	storage = Instance.new("Folder")
	storage.Name = STORAGE_FOLDER_NAME
	storage.Parent = ServerStorage
	print("[MOVE] Создана папка ServerStorage." .. STORAGE_FOLDER_NAME)
end

template.Parent = storage

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print("[MOVE] Готово. BaseTankTemplate перенесён в ServerStorage." .. STORAGE_FOLDER_NAME
	.. ". Нажми Play и проверь, что танки в Training/дуэли спавнятся как раньше.")
