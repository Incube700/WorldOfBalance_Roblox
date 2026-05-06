# Start Here: Ricochet Tanks

Ты хотел простую Roblox-идею: танк сверху, стены, снаряды с рикошетами.

Сейчас проект в переходном состоянии: часть кода уже лежит в `src/`, но главные игровые скрипты все еще живут внутри `.rbxl` сцены в Roblox Studio. Поэтому не все изменения автоматически видны как обычные файлы.

## Что уже есть

- Танк игрока ездит на `WASD`.
- Башня целится мышью.
- Танк стреляет.
- Снаряд летит и рикошетит.
- Dummy получает урон.
- Есть базовый HUD для dummy.

## Чего пока не хватает

- Танк игрока не должен проходить сквозь стены и cover.
- Снаряд слишком быстрый и его сложно читать сверху.
- Нет нормального player health.
- Нет полноценной победы/поражения.
- Нет полного restart матча.
- Главные скрипты еще не перенесены в Rojo `src/`.

## Что я подготовил сейчас

Файлы патчей:

- `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`
- `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau`

Config для glow:

- `src/ReplicatedStorage/Shared/Configs/ProjectileVisualConfig.luau`

## Что сделать вручную в Roblox Studio

1. Открой `ServerScriptService/Services/WOBGameplayServer`.
2. Замени весь Source на содержимое:
   `docs/patches/WOBGameplayServer_tank_wall_blocking.server.luau`
3. Открой `ServerScriptService/Services/WOBProjectileVisualEnhancer`.
4. Замени весь Source на содержимое:
   `docs/patches/WOBProjectileVisualEnhancer_ground_glow.server.luau`
5. Нажми Play и проверь:
   - танк ездит;
   - башня целится;
   - танк не проходит через стены/cover;
   - снаряд рикошетит как раньше;
   - под снарядом видна подсветка;
   - в Output нет ошибок.

## Самый простой следующий план

1. Сначала добиться, чтобы танк не проходил сквозь стены.
2. Потом сделать снаряд читаемым.
3. Потом добавить здоровье игрока.
4. Потом добавить победу/поражение.
5. Потом уже переносить большие Studio-скрипты в `src/`.

Не надо сейчас переписывать весь проект. Двигаемся маленькими кусками.
