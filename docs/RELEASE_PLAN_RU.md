# План доведения игры до апдейта (World of Balance)

Цель: довести BattleArena до интересного, цельного релиза, навести порядок в коде, добавить
звук/эффекты, прогрессию и социальные фишки (имена, kill-feed, рекорд уровня). После релиза —
заморозить игру и вернуться в Unity.

Документ — живой. Галочки по мере выполнения. Порядок = приоритет (сверху делаем раньше).

---

## ЭТАП 0 — Стабилизация и уборка (фундамент, без него нельзя релизить)
- [ ] **Чистка мёртвых настроек/файлов.** Удалить/пометить deprecated: `WeaponCatalog.PickupLayout/MazeLayout/BreakableLayout`, `UseAuthoredLayout`, `.rbxmx.bak`, пустые ветки `Assets/FX/...` без ассетов. Ничего рабочего не трогаем.
- [ ] **VFX в одну базу.** Доперенести оставшееся в `Shared/Assets/VFX`, дозаполнить пустые (`Repair`, `UpgradeSelect`), всё переключать через `VfxRegistry`. (см. `ARENA_AND_VFX_GUIDE_RU.md`)
- [ ] **Убрать диагностические трейсы** (`[TRAINING TRACE]`, лишние print) — оставить только полезные warn.
- [ ] **Финальная арена в сцене:** покрасить стены (ApplyArenaVisualStyle), расставить маркеры оружия в `BattleArena/PickupSpawns`, протегать роли (TagArenaRoles).
- [ ] Проверка: `rojo build` чистый, Output без красного.

## ЭТАП 1 — Прогрессия апгрейдов  ✅ ГОТОВО
- [x] **Убран ReflectShield из апгрейдов по уровню** (из `UPGRADE_ORDER` и пула; spawn-щит как механика остался).
- [x] **Базовые статы стакаются по нескольку раз:** DamageUp 5, FireRateUp 5, MoveSpeedUp 5, RicochetUp 3.
- [x] **3 новых апгрейда:** Lifesteal (+18 HP за килл, x3), Piercing (пробитие +1 врага, x2), Overcharge (+18% урон / −12% скорострельность, x3).
- [x] Иконки: добавлены записи (fallback-символы ♥/➹/⚡, пока без PNG).
- [ ] (опц.) Нарисовать PNG-иконки для Lifesteal/Piercing/Overcharge и вписать assetid.

## ЭТАП 2 — Социальные/UI фишки  ✅ ГОТОВО
- [x] **Имена игроков у HP-бара** — TextLabel `PlayerName` в биллборде, берётся из атрибута `OwnerDisplayName` (TankFactory пишет имя владельца, боты = "BOT").
- [x] **Имя над танком** — тот же биллборд виден во всех режимах, где включён (вкл. лобби).
- [x] **Kill-feed** — `KillFeedEvent` (FireAllClients) + клиентский оверлей `WOBKillFeedOverlay`: "Killer ⚔ Victim" сверху, авто-фейд через 4.5с, до 5 строк.
- [x] **Значки оружия** в kill-feed (Rocket/MG/RailGun/PhaseShot/обычный).
- [ ] (опц.) Картиночные иконки оружия вместо текстовых глифов.

## ЭТАП 3 — Звук и эффекты  ✅ ИНФРАСТРУКТУРА ГОТОВА (нужны ассеты)
- [x] **Хуки звука на всё событие подключены:** выстрел (теперь с WeaponId → per-weapon), попадание, рикошет, взрыв, **подбор пикапа** (новая категория + хук), левелап, апгрейд, клик, win/lose. Все идут через `AudioController`/`CombatFeedbackEvent`.
- [x] **Per-weapon выстрелы:** категории ShotRocket/ShotMachineGun/ShotRailGun с авто-фолбэком на обычный Shot, если SoundId пустой.
- [x] **VFX на всё** уже идёт через `CombatFXService`/`VfxRegistry` (muzzle/trail/impact/ricochet/explosion). Отдельные хуки не нужны.
- [ ] **ВПИСАТЬ assetid:** у новых и многих старых звуков `SoundId = ""` (UpgradeSelect, LevelUp, Repair, ReflectShield, Win/Lose, Pickup, per-weapon shots и т.д.). Импортировать звуки и вписать `rbxassetid` в `AudioCatalog`. Пока пусто — событие просто молчит, без ошибок.
- [ ] Дозаполнить пустые VFX-шаблоны в `Shared/Assets/VFX` (Repair, UpgradeSelect).
- [ ] Проверить, что эффекты не лагают на MobileLow.

## ЭТАП 4 — Ачивки и рекорды  ✅ ГОТОВО
- [x] **leaderstats:** Bolts / Kills / Best Level (`AchievementService.ensureLeaderstats`, Bolts зеркалится из кошелька).
- [x] **Рекорд уровня (BestLevel)** — макс уровень за все сессии, персист в DataStore (`WOBAchievementsV1`), деградирует в памяти без публикации.
- [x] **5 ачивок:** First Blood, On a Roll (10 киллов/сессия), Veteran (5 ур.), Trick Shot (килл рикошетом), Sniper (килл рейлганом) — в `AchievementCatalog`, награда Bolts, факт unlock сохраняется.
- [x] **Всплывашка "Achievement unlocked"** — `AchievementToastEvent` + `WOBAchievementToast` (карточка с иконкой/наградой, очередь).
- [ ] (опц.) Нарисовать иконки ачивок вместо текстовых глифов; добавить UI-список всех ачивок в меню.

## ЭТАП 5 — Баланс и финальный полиш  ✅ КОД ГОТОВ К РЕЛИЗУ
- [x] Анти-чит пробития: pierce теперь режется бронёй (`ArmorHitResolver`).
- [x] Прогрессия: апгрейды до 15 ур., макс 30, медленная XP-кривая.
- [x] Глобальные подиумы: Arena Champion (макс. уровень) + Duel King (число дуэлей).
- [x] Debug-флаги выключены, мастер-флаги в релизном состоянии (проверено grep).
- [ ] (Studio, перед паблишем) покрасить арену, маркеры пикапов, теги ролей, 2 подиума — см. `STORE_PAGE_AND_RELEASE_RU.md`.
- [ ] (Dashboard) заменить тамбнейл на скриншоты, Genre, описание — см. `STORE_PAGE_AND_RELEASE_RU.md`.
- [ ] `rojo build` + тест на опубликованном сервере → релиз.

> Полный текст страницы, раскадровка тамбнейлов и релиз-чеклист: **docs/STORE_PAGE_AND_RELEASE_RU.md**

---

## Технические заметки (чтобы не сломать то, что работает)
- Управление: классическое (аркадный пресет выключен флагом — не трогаем).
- Дуло: свободно вращается (откатили cannon-forward).
- Камера арены: выше (×1.3), HP-бары MaxDistance=260.
- Пикапы: читаются из ActiveArenaLayout, **фолбэк — прямо из `BattleArena/PickupSpawns`**.
- Update02ArenaLayerEnabled=true, Pickups=on, Maze/Breakables=off, VisualPolish=off.
- Каждый шаг: `git diff --check` + `rojo build` локально перед коммитом.

## Порядок, который я рекомендую
0 → 1 → 2 → 3 → 4 → 5. Сначала чистка и прогрессия (ядро гейм-фила), потом социалка и звук
(ощущение «живой игры»), затем ачивки/рекорды (ретеншн), и в конце баланс + публикация.
