# Start Here: Ricochet Tanks

Ты делаешь простую Roblox-игру: танк сверху, стены, снаряды и рикошеты.

Сейчас часть игры живет в Roblox Studio внутри `.rbxl`, а часть уже синкается через Rojo из `src/`. В этом спринте есть реальные видимые изменения через Rojo.

## 1. Что уже работает

- Танк игрока ездит на `WASD`.
- Башня целится мышью отдельно от корпуса.
- Левая кнопка мыши стреляет.
- Снаряд летит и рикошетит от стен.
- Dummy получает урон.
- HUD показывает dummy HP и reload.

## 2. Что видно сразу через Rojo

Эти файлы лежат в mapped папке `src/StarterPlayer/StarterPlayerScripts/Client`:

- `WOBTankDirectionIndicator.client.luau`
- `WOBProjectileReadabilityOverlay.client.luau`
- `WOBImpactFeedbackOverlay.client.luau`

После `rojo serve` и `Connect` в Roblox Studio должно быть видно:

- яркий индикатор направления корпуса танка;
- подсветку под снарядом;
- короткий pulse на bounce/hit VFX.

Для этого не нужно менять `.rbxl` вручную.

## 3. Что требует ручной вставки patch

Танк все еще проходит сквозь стены, потому что `WOBGameplayServer` пока Studio-owned внутри `.rbxl`.

Для wall blocking нужен ручной patch:

- `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`

Куда вставить:

1. Roblox Studio.
2. `ServerScriptService/Services/WOBGameplayServer`.
3. Заменить весь Source на содержимое patch-файла.

Подробнее:

- `docs/patches/README_VISIBLE_SPRINT.md`

## 4. Что проверить в Play Mode

Сначала Rojo-visible часть:

- Танк ездит как раньше.
- Башня целится мышью отдельно.
- Перед корпусом виден direction marker.
- Снаряд летит как раньше.
- Под снарядом видна подсветка.
- Рикошеты работают.
- Dummy получает урон.
- Bounce/hit стали заметнее.
- В Output нет ошибок.

После ручного wall blocking patch:

- Танк не проходит через `Wall_North`, `Wall_South`, `Wall_East`, `Wall_West`.
- Танк не проходит через `RicochetWall_*`.
- Танк не проходит через `Cover_Block_*`.
- WASD, mouse aim, shooting, ricochet, dummy damage and HUD still work.

## 5. Порядок работы

1. Запусти `rojo serve`.
2. Подключи Rojo plugin в Studio.
3. Проверь visible scripts: direction marker, projectile glow, impact pulse.
4. Если это работает, вставь wall blocking patch в `WOBGameplayServer`.
5. Проверь Play Mode checklist.
6. Если patch применен вручную и все работает, сохрани сцену через `File -> Save to File`.
7. Потом делай коммит.

Не надо сейчас переписывать весь проект. Этот sprint только про видимость и базовую блокировку стен.
