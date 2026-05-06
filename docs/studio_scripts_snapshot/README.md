# Studio Scripts Snapshot

Эта папка нужна для ручного сохранения исходников Script/LocalScript из `RicochetTanksPrototype.rbxl`.

Цель snapshot:

- проанализировать текущую gameplay logic без изменения игры;
- увидеть реальные зависимости между Studio-скриптами;
- подготовить будущий безопасный перенос configs/constants/helper utils в `src/`;
- не трогать оригинальные Script внутри Roblox Studio;
- не подключать эти файлы к Rojo автоматически.

Файлы в этой папке являются документационным снимком. Они не должны считаться рабочими gameplay-скриптами, пока отдельная задача явно не разрешит перенос или refactor.

## Какие скрипты нужно скопировать

Скопировать вручную исходники из Roblox Studio:

- `ServerScriptService/Services/WOBGameplayServer`
- `ServerScriptService/Services/WOBDummyRespawnServer`
- `ServerScriptService/Services/WOBPerformanceServer`
- `ServerScriptService/Services/WOBProjectileVisualEnhancer`
- `StarterGui/HUD/WOBHudController`
- `StarterPlayer/StarterPlayerScripts/WOBClientController`

Если внутри `StarterPlayer/StarterPlayerScripts/Controllers/` есть дополнительные Script/LocalScript/ModuleScript, их нужно сначала записать в `docs/PROJECT_AUDIT.md`, а затем сохранить отдельными snapshot-файлами.

## Как копировать

1. Открыть `RicochetTanksPrototype.rbxl` в Roblox Studio.
2. В Explorer найти нужный Script или LocalScript.
3. Открыть Script в Roblox Studio.
4. Выделить весь код.
5. Сохранить код в соответствующий `.luau` или `.txt` файл внутри `docs/studio_scripts_snapshot/`.
6. Не удалять оригинальный Script из Studio.
7. Не переименовывать оригинальный Script из Studio.
8. Не менять код во время копирования.
9. После сохранения snapshot проверить `git status`.

## Рекомендуемые имена файлов

```text
WOBGameplayServer.server.luau
WOBDummyRespawnServer.server.luau
WOBPerformanceServer.server.luau
WOBProjectileVisualEnhancer.server.luau
WOBHudController.client.luau
WOBClientController.client.luau
```

Если точный тип скрипта неизвестен, временно можно использовать `.txt`, например:

```text
WOBGameplayServer.txt
```

После анализа тип можно уточнить в аудите, но не нужно переименовывать snapshot без отдельной причины.

## Что нельзя делать при snapshot

- Не менять `RicochetTanksPrototype.rbxl`.
- Не переносить скрипты в `src/`.
- Не подключать snapshot-файлы через `default.project.json`.
- Не исправлять код во время копирования.
- Не удалять оригинальные Studio-скрипты.
- Не делать refactor.
- Не менять gameplay behavior.

## После копирования

После ручного snapshot нужно обновить `docs/PROJECT_AUDIT.md`:

- какие файлы snapshot добавлены;
- какие Studio-скрипты удалось скопировать;
- какие скрипты не удалось открыть или найти;
- какие зависимости видны в исходниках;
- какие части выглядят безопасными для будущего выноса.
