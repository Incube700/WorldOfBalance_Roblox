# Arena Upgrade HUD refactor ready pack

Что внутри:

1. `BattleArenaUpgradeHud.luau`
   - новый модуль для upgrade UI арены;
   - мобильный выбор апгрейда — компактный bottom-center belt;
   - desktop может показывать более крупные карточки;
   - active upgrade strip показывает до 5 иконок и `+N`.

2. `apply_arena_upgrade_hud_refactor.py`
   - создаёт модуль в `src/StarterPlayer/StarterPlayerScripts/Client/Hud/`;
   - вырезает старый inline upgrade UI из `WOBBattleArenaOverlay.client.luau`;
   - подключает новый модуль;
   - оставляет remotes/server logic без изменений.

Как применить из корня проекта:

```bash
python3 apply_arena_upgrade_hud_refactor.py
git diff --check
rojo build default.project.json --output /tmp/wob-arena-upgrade-hud-module-check.rbxm
```

Потом Studio Play:
- Battle Arena запускается;
- upgrade offer появляется как маленькая панель между контролами;
- 3 кнопки квадратные и тапабельные;
- после выбора появляется/возвращается strip активных апгрейдов;
- joystick/fire/reverse не перекрыты;
- Training/Duel не затронуты.

Если скрипт выдаст `Pattern not found`, значит локальный `WOBBattleArenaOverlay.client.luau` отличается от версии, под которую сделан автоматический рефактор. Тогда используй `BattleArenaUpgradeHud.luau` вручную.
