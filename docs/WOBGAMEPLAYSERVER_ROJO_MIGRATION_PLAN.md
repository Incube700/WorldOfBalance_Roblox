# WOBGameplayServer Rojo Migration Plan

Дата: 2026-05-07.

## Цель

Перевести `WOBGameplayServer` из Studio-owned script внутри `.rbxl` в Rojo-managed script внутри `src`, чтобы будущие изменения gameplay-кода шли через Git/Rojo, без ручной вставки `Source` в Roblox Studio после каждого patch.

Этот документ только планирует миграцию. Он не меняет `.rbxl`, не меняет `default.project.json` и не включает новый gameplay script.

## Текущее Состояние

Активный gameplay server сейчас находится внутри сцены:

```text
ServerScriptService/Services/WOBGameplayServer
```

Из-за этого файл не является обычным source-файлом в репозитории:

- Codex не может менять активный `WOBGameplayServer` напрямую;
- изменения готовятся как patch-файлы в `docs/patches/`;
- patch нужно вручную вставлять в Roblox Studio в поле `Source`;
- после ручной вставки нужно делать `File -> Save to File`, чтобы `.rbxl` сохранил Studio-owned change.

Это нормально для раннего прототипа, но становится неудобно, когда gameplay-код меняется часто.

## Почему Rojo Решит Проблему

Если `WOBGameplayServer` станет Rojo-managed script:

- активный source будет лежать в `src`;
- Codex сможет менять обычный `.luau` файл;
- Git будет видеть gameplay changes как нормальный code diff;
- Rojo будет синхронизировать script в Roblox Studio;
- manual patch insertion больше не понадобится для изменений внутри `WOBGameplayServer`.

Текущий `default.project.json` уже маппит:

```text
src/ServerScriptService/Server -> ServerScriptService/Server
```

Значит replacement можно создать внутри уже Rojo-owned зоны без изменения mapping.

## Главные Риски

Нельзя запускать два `WOBGameplayServer` одновременно.

Если одновременно включены:

```text
ServerScriptService/Services/WOBGameplayServer
ServerScriptService/Server/Gameplay/WOBGameplayServer
```

то оба server scripts могут:

- слушать одни и те же RemoteEvents;
- двигать один и тот же `PlayerTankPrototype`;
- создавать projectiles/VFX;
- наносить dummy damage;
- писать конфликтующие значения в runtime state.

Другие риски:

- старый Studio-owned `WOBGameplayServer` нужно отключить перед включением replacement;
- нельзя добавлять Rojo mapping на всю `ServerScriptService/Services`, иначе Rojo может взять ownership над Studio-owned папкой;
- нельзя мигрировать всю `Services` папку одним шагом;
- нужен отдельный Play Mode test именно для migration step;
- после отключения старого Studio-owned script нужно один раз сохранить `.rbxl`, иначе при следующем открытии он снова может быть enabled.

## Безопасная Стратегия

Предпочтительный путь для replacement:

```text
src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau
```

Почему этот путь:

- он уже попадает в существующий Rojo mapping;
- он не требует менять `default.project.json`;
- он не пытается забрать ownership над `ServerScriptService/Services`;
- по имени `Gameplay` понятно, что это active gameplay logic, а не Studio-owned legacy `Services`.

Альтернативный допустимый путь:

```text
src/ServerScriptService/Server/Services/WOBGameplayServer.server.luau
```

Он тоже внутри existing Rojo-owned `ServerScriptService/Server`, но может визуально путаться со старой Studio-owned папкой `ServerScriptService/Services`. Поэтому `Gameplay` лучше для первого шага.

## Пошаговая Миграция

### Step 1 — Prepare Rojo-managed replacement

Создать Rojo-managed copy:

```text
src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau
```

Источник для первого файла:

- текущий working full-source patch, если он уже проверен в Play Mode;
- либо текущий Studio-owned `WOBGameplayServer` Source, если patch еще не принят.

Важно: на этом шаге не менять RemoteEvent contracts, gameplay rules, projectile logic, turret aim или damage.

Для защиты от duplicate run можно выбрать один из двух вариантов:

- создать replacement disabled через Rojo meta file, если используем property sync;
- либо оставить в верхней части script временный migration guard, который не запускает gameplay до ручного включения.

Цель шага: файл существует в `src`, но игра еще не запускает два gameplay server одновременно.

### Step 2 — Sync with Rojo

Запустить Rojo и подключить Studio plugin.

Ожидаемый Studio path:

```text
ServerScriptService/Server/Gameplay/WOBGameplayServer
```

Проверить, что `default.project.json` не менялся.

### Step 3 — Disable old Studio-owned script

В Roblox Studio вручную отключить старый script:

```text
ServerScriptService/Services/WOBGameplayServer.Enabled = false
```

Не удалять старый script в первом migration pass. Он остается rollback reference.

### Step 4 — Enable Rojo-managed replacement

Включить replacement только после отключения старого script.

Активным должен быть ровно один gameplay server:

```text
ServerScriptService/Server/Gameplay/WOBGameplayServer
```

### Step 5 — Play Mode test

Проверить:

- WASD работает;
- корпус поворачивается;
- башня целится мышью отдельно;
- стрельба работает;
- projectile летит и рикошетит;
- dummy получает урон;
- wall blocking работает;
- HUD работает;
- Output без красных ошибок;
- нет двойных projectile spawn, двойных damage print или двойных `[WOB] Gameplay server started`.

### Step 6 — Save to File one time

Если Play Mode test прошел:

```text
File -> Save to File
```

Это нужно один раз, чтобы `.rbxl` запомнил:

- старый `ServerScriptService/Services/WOBGameplayServer` отключен;
- сцена больше не требует ручной вставки active gameplay source.

После этого дальнейшие изменения `WOBGameplayServer` идут через `src`.

## Что Всё Еще Требует Manual Save

Rojo-managed gameplay code не отменяет необходимость сохранять сцену для Studio-owned objects.

Manual `File -> Save to File` все еще нужен для:

- изменений карты;
- добавления, удаления или перемещения Parts;
- изменения UI, созданного в Studio;
- отключения старых Studio-owned scripts;
- добавления/изменения RemoteEvents в Studio-owned tree;
- любых изменений самой `.rbxl` сцены.

## Что Больше Не Требует Manual Save

После успешной миграции manual Source paste больше не нужен для:

- изменения Luau-кода `WOBGameplayServer`;
- правок wall blocking logic;
- правок movement/shooting/projectile server code внутри migrated script;
- изменений configs в `src/ReplicatedStorage/Shared/Configs`;
- client overlays в `src/StarterPlayer/StarterPlayerScripts/Client`;
- будущих server services, если они тоже создаются внутри Rojo-managed `src/ServerScriptService/Server`.

## Rollback

Если replacement ломает Play Mode:

1. Остановить Play Mode.
2. Отключить Rojo-managed `ServerScriptService/Server/Gameplay/WOBGameplayServer`.
3. Включить старый `ServerScriptService/Services/WOBGameplayServer`.
4. Проверить Play Mode.
5. Не сохранять `.rbxl`, пока не понятно, какой вариант должен остаться active.

## Следующая Задача

Recommended next task:

```text
Prepare WOBGameplayServer Rojo-managed replacement, without enabling duplicate.
```

Scope следующей задачи:

- создать replacement file внутри `src/ServerScriptService/Server/Gameplay/`;
- не менять `default.project.json`;
- не менять `.rbxl`;
- не включать два `WOBGameplayServer`;
- описать точные manual steps для переключения active script в Studio;
- не рефакторить монолит одновременно с миграцией.

Рекомендуемый коммит для этого planning step:

```text
Add WOBGameplayServer Rojo migration plan
```
