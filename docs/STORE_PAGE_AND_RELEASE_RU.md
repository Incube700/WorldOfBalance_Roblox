# Страница игры + релиз-чеклист (Ricochet Tanks)

Всё ниже — для Roblox Creator Dashboard (не код). Копируй текст как есть.

---

## 1. Описание игры (вставить в Description)

```
🔺 Ricochet Tanks — fast arcade tank arena where EVERY shot can bounce!

Aim at the walls, bank your shots around corners, and blast enemies who think
they're safe. Bounce. Predict. Destroy.

⚔ FEATURES
• Ricochet combat — angle your shots off walls for trick kills
• Pickup weapons — Rocket, Machine Gun (fan blast), Rail Gun, Repair
• Level up your tank — damage, fire rate, speed, piercing, lifesteal & more
• Battle Arena vs bots + Duels
• Achievements, kill feed, and global Champion podiums
• Climb the leaderboard: highest arena level & most duels win

More coming soon — skins, new weapons, events!

Tags: tank, ricochet, arena, shooter, pvp, battle, arcade
```

> Первые 1-2 строки самые важные — Roblox индексирует начало описания для поиска. Ключевые
> слова `tank / ricochet / arena / pvp / shooter` обязательно в первых строках.

---

## 2. Настройки страницы (Configure → Settings)

| Поле | Поставить | Почему |
|------|-----------|--------|
| **Genre** | Fighting (или Battlegrounds) | Сейчас N/A — игра не попадает в нужные категории/рекомендации |
| **Voice Chat** | Off | Танковой аркаде не нужен; Moderate + voice = меньше аудитории |
| **Devices** | Computer + Phone + Tablet | Мобильные контролы готовы — не теряй мобильный трафик |
| **Thumbnails** | 3-5 СКРИНШОТОВ ИЗ ИГРЫ | Сейчас стоит ИИ-картинка не по теме — это убивает CTR |

Иконку НЕ менять срочно — текущая (неоновый танк + рикошет) читается и в стиле.

---

## 3. Тамбнейлы — раскадровка (снять в Studio, 1280×720)

Заходишь в Play, ставишь красивый ракурс (камера уже приподнята в арене), скриншот,
обрезаешь под 1280×720. НЕ генерировать ИИ — нужны реальные кадры.

1. **Hero-кадр боя.** Арена с неоновыми стенами, 2-3 танка, в центре — летящий
   снаряд с трейлом. Это первый и главный тамбнейл.
2. **Рикошет-момент.** Снаряд отскакивает от стены под углом (виден изгиб трейла) →
   попадает во врага. Подпись поверх (по желанию): "EVERY SHOT BOUNCES".
3. **Прокачка.** Экран выбора апгрейда (3 карточки) поверх боя. Показывает глубину.
4. **Соц-фишки.** Kill-feed сверху + подиум победителя в лобби с именем.
5. (опц.) **Оружие.** Веер пулемёта или взрыв ракеты крупным планом.

Композиция: действие в центре, контраст (тёмный фон + неон), без мелкого текста.

---

## 4. Релиз-чеклист (код)

Состояние на текущий момент — ГОТОВО к сборке:
- [x] Все Debug-флаги выключены (проверено: нет `Debug = true` / `DEBUG_* = true`).
- [x] Мастер-флаги: `Update02ArenaLayerEnabled=true`, `PickupsEnabled=true`,
      `MazeEnabled=false`, `BreakablesEnabled=false`, `RuntimeVisualPolishEnabled=false`,
      `RailGunEnabled=true`, `ShieldPickupEnabled=false`.
- [x] Управление классическое, дуло свободное, камера арены выше, HP-бары видны.

Перед публикацией апдейта сделать в Studio:
- [ ] Покрасить стены арены (`ApplyArenaVisualStyle.commandbar.luau`).
- [ ] Расставить маркеры пикапов в `BattleArena/PickupSpawns` (`PlacePickupSpawns...`).
- [ ] Протегать роли (`TagArenaRoles...`): BattleArena на контейнер и пол.
- [ ] Поставить 2 подиума в лобби: `ArenaChampionPodium`, `DuelKingPodium`.
- [ ] `rojo build default.project.json` локально → 0 ошибок.
- [ ] Тест на ОПУБЛИКОВАННОМ сервере 2+ игрока: пикапы спавнятся, kill-feed,
      ачивки, рекорды/подиумы пишутся (DataStore работает только на паблише).
- [ ] Нет красных ошибок в Output.

---

## 5. После релиза (следующие апдейты, по приоритету)
1. Магазин скинов за Bolts (валюте нужен сток — сейчас Bolts некуда тратить).
2. Затухание стаков апгрейдов (чтобы лидер не был непобедим).
3. Индивидуальный танк игрока на подиуме (после скинов).
4. Дозаполнить звуки/VFX (вписать `rbxassetid` в `AudioCatalog`, шаблоны в `Shared/Assets/VFX`).
5. Новое оружие (Shotgun/Mortar/Mine — см. идеи в чате).
