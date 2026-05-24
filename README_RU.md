# Arena Upgrade HUD refactor ready pack

## Актуальная точка входа в документацию

Этот файл — исторический ready-pack для старого рефактора BattleArena upgrade HUD. Он сохранен как контекст и не должен считаться главным источником текущего workflow.

Для текущего состояния проекта начинай отсюда:

- [Индекс документации](docs/DOCS_INDEX.md) — карта актуальных, справочных и исторических документов.
- [Текущее состояние проекта](docs/CURRENT_PROJECT_STATE.md) — что сейчас playable и что нельзя сломать.
- [Кандидаты на cleanup](docs/CLEANUP_CANDIDATES.md) — безопасный порядок чистки и файлы, которые нельзя удалять без подтверждения.
- [Battle Arena Progression v2](docs/BATTLE_ARENA_PROGRESSION_V2.md) — post-5 уровни, платный revive, free respawn, подготовка веток.

Инструкции ниже оставлены как исторический контекст для upgrade HUD refactor.

---

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
