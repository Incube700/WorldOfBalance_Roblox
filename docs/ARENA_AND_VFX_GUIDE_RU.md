# Гайд: арена, VFX, пикапы и оружие (по шагам)

Это памятка по всему, что мы настраивали. Читается сверху вниз. Все «инструменты» —
это файлы из папки `tools/studio/`, которые ты **вставляешь в Command Bar** в Studio
(меню `View → Command Bar`) и жмёшь Enter. Они ничего не ломают: работают только с тем,
что ты выделил.

---

## 0. Один раз: подготовка

1. Открой проект в Studio через Rojo (как обычно синхронизируешь).
2. Если Studio ругается, что VFX-файлы «только для чтения» — в терминале в папке проекта:
   ```
   chmod -R u+rw,go+r "src/ReplicatedStorage/Shared/Assets/VFX"
   ```
3. Command Bar: `View → Command Bar`. Туда вставляются все инструменты ниже.

---

## 1. Где хранятся VFX и как добавлять новые

**Главная папка эффектов (единая база):**
`ReplicatedStorage → Shared → Assets → VFX`

Это плоская папка — складывай все шаблоны эффектов прямо сюда, без вложенных деревьев.

**Переключатель и список вариантов:** файл `VfxRegistry` в той же папке
(`Shared/Assets/VFX/VfxRegistry.luau`). В нём две важные таблицы:

- `Active` — какой вариант эффекта активен сейчас. Меняешь строку — меняется эффект во
  всей игре. Пример: `MuzzleFlash = "Flash"`.
- `Variants` — список всех вариантов каждого эффекта. `Template = "ИмяОбъекта"` — это имя
  объекта внутри папки `Shared/Assets/VFX`.

### Как добавить НОВЫЙ эффект-вариант (например, новую вспышку выстрела)
1. В Studio положи готовый эффект (Model/ParticleEmitter/Part) в
   `Shared → Assets → VFX`. Дай понятное имя, например `MuzzleFlash_Plasma`.
2. Открой `VfxRegistry.luau`, найди блок `MuzzleFlash` в `Variants`, добавь строку:
   ```lua
   Plasma = { Template = "MuzzleFlash_Plasma" },
   ```
3. Чтобы включить его как активный — в таблице `Active` поставь:
   ```lua
   MuzzleFlash = "Plasma",
   ```
4. Сохрани, синкни Rojo. Готово.

### Как «дозаполнить» пустой эффект (например, починку Repair)
Сейчас у `Repair` и `UpgradeSelect` нет файла-ассета (помечены `Missing = true`).
1. Сделай/переименуй эффект в Studio, перетащи в `Shared/Assets/VFX`, имя — `Repair_Default`.
2. В `VfxRegistry.luau` в блоке `Repair` убери `Missing = true`:
   ```lua
   Repair = { Default = { Template = "Repair_Default" } },
   ```
3. Сохрани. Если переименовал во что-то другое — просто впиши это имя в `Template`.

> Правило: имя в `Template` ДОЛЖНО совпадать с именем объекта внутри `Shared/Assets/VFX`.

> Старое дерево `Assets/FX/...` пока оставлено как запас и для косметики. Туда лазить не
> надо — всё новое кладём в плоскую `Shared/Assets/VFX`.

---

## 2. Покрасить арену (неоновые стены)

Инструмент: `tools/studio/ApplyArenaVisualStyle.commandbar.luau`

1. В Explorer выдели пол, стены, cover арены (или папки `CollisionWalls`/`RicochetWalls`/`Cover`).
2. Открой файл инструмента, вверху задай:
   - `STYLE = "DarkNeon"` — пресет (`DarkNeon` / `TeamColors` / `ArcadeBright`).
   - `ADD_NEON_TRIM = true` — неоновые полосы по верху стен.
3. Скопируй ВЕСЬ файл → вставь в Command Bar → Enter.
4. Перекрасить иначе — поменяй `STYLE`, запусти снова (старый неон заменяется, не копится).

Цвета запекаются в Edit Mode — в игре выглядит так же.

---

## 3. Спавн-поинты подбора оружия

Инструмент: `tools/studio/PlacePickupSpawns.commandbar.luau`

1. Выдели свою арену-Model (или её папку `PickupSpawns`).
2. Вверху файла:
   - `PICKUP_TYPE = "Rocket"` — тип (`Rocket` / `MachineGun` / `RailGun` / `Repair` / `Shield` / `PhaseShot`).
   - `COUNT = 1` — сколько точек создать за раз.
3. Вставь в Command Bar → Enter. Появятся неоновые диски-маркеры. Двигай их куда нужно.
4. Поменяй `PICKUP_TYPE`, запусти ещё — для других типов. Индексы не перетираются.

> Пикапы уже ВКЛЮЧЕНЫ (`Update02ArenaLayerEnabled = true`, `PickupsEnabled = true`).
> Активны: Rocket, MachineGun, RailGun, Repair. Shield и PhaseShot выключены флагами.

---

## 4. Теги ролей арены (обязательно для арены)

Инструмент: `tools/studio/TagArenaRoles.commandbar.luau`

Нужно, чтобы движок понимал «это BattleArena», а Duel/Lobby оставались чистыми.

1. Выдели контейнер арены (`WOB_Generated/BattleArena`).
2. В файле: `ROLE = "BattleArena"`, `TARGET = "Container"`. Вставь → Enter.
3. Выдели пол арены, поставь `TARGET = "Floor"`, запусти снова.
4. (По желанию) так же помечай Duel/Lobby ролями `"Duel"`/`"Lobby"` — они не получат арену.

---

## 5. Как пикапы реально появляются в игре (важно!)

Движок берёт пикапы НЕ из авторинг-папки напрямую, а из **сохранённого шаблона арены**,
который при старте клонируется в `WOB_Runtime/ArenaMode/ActiveArenaLayout`.

Путь сейчас такой:
1. Авторишь арену + маркеры в `WOB_Authoring/ArenaLayouts/RicochetMaze_01`.
2. ПКМ по этой Model → **Save to File…** →
   `src/ReplicatedStorage/Assets/ArenaLayouts/RicochetMaze_01.rbxm`.
3. Синк Rojo. На старте Training/BattleArena движок клонирует шаблон, и пикапы спавнятся
   на твоих маркерах.

> Если хочешь, чтобы маркеры читались ПРЯМО из `BattleArena` без сохранения шаблона —
> скажи, добавлю такой режим (это правка одного сервиса).

---

## 6. Оружие сейчас

- **Rocket** — взрывной, рикошетит.
- **MachineGun** — стреляет ВЕЕРОМ (5 дробин). С апгрейдом Double Shot = два веера.
- **RailGun** — быстрый дальнобойный мощный выстрел (новое).
- **Repair** — лечит +60.
- **PhaseShot** — пробивает 1 врага (выключен флагом).
- **Shield** — заготовка, выключен (ждёт доработки выдачи).

Включать/выключать — флаги в `Shared/Configs/WeaponCatalog.luau` → `Flags`
(`RocketEnabled`, `MachineGunEnabled`, `RailGunEnabled`, `PhaseShotEnabled`, `ShieldPickupEnabled`).

---

## 7. Дуло в арене

Сейчас дуло снова **свободно вращается** к прицелу (как в дуэли). Это в коде сервера, в
Studio ничего жать не нужно.

---

## Короткий чек-лист «сделать нормальную арену»

1. Покрасить стены — инструмент из §2.
2. Расставить маркеры оружия — инструмент из §3 (Rocket, MachineGun, RailGun, Repair).
3. Протегать роли — инструмент из §4 (BattleArena на контейнер и пол).
4. Сохранить арену в шаблон `.rbxm` — §5.
5. Синк Rojo → зайти в BattleArena → проверить, что пикапы на местах и эффекты играют.
