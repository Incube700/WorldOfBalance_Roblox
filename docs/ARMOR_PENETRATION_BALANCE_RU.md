# Баланс брони и пробития

Документ описывает текущую рабочую формулу брони/пробития в Ricochet Tanks и дает ориентиры для будущей настройки Battle Arena / `Царь горы`.

## Где сейчас живет логика

Активный боевой путь:

- `ProjectileService` создает снаряд из `ProjectileCatalog`.
- `ProjectileCollisionService` рейкастит по стенам и папкам `ArmorZones` / `Hitboxes`.
- `TankParticipantRegistry.getArmorZoneFromHitbox` дает подсказку зоны по имени детали: `FrontArmor`, `RearArmor`, `LeftArmor`, `RightArmor`.
- `ProjectileCombatService` вызывает `ArmorHitResolver.ResolveHit`.
- `ArmorHitResolver` берет боевые числа из `TankArmorConfig.Default`.

Важно: `TankConfig.Armor` содержит старые/визуальные параметры для геометрии хитбоксов. Текущие боевые значения брони берутся не оттуда, а из `TankArmorConfig.Default.Zones`.

## Текущие боевые значения

Снаряд `DefaultRicochetShell`:

- `Damage = 110`
- `PenetrationPower = 70`
- `Penetration = 45` — legacy alias, не главный параметр
- `MaxRicochets = 3`
- `BounceSpeedMultiplier = 0.72`
- `DamageMultiplierPerBounce = 0.75`
- `Speed = 180`
- `Lifetime = 3.6`

Броня:

- Лоб: `Armor = 80`, `DamageMultiplier = 0.65`, `RicochetAngleDegrees = 60`
- Борт: `Armor = 55`, `DamageMultiplier = 0.9`, `RicochetAngleDegrees = 62`
- Корма: `Armor = 35`, `DamageMultiplier = 1.15`, `RicochetAngleDegrees = 65`
- Угол корпуса: `Armor = 90`, `DamageMultiplier = 0.5`, `RicochetAngleDegrees = 45`
- `EffectiveArmorMinCos = 0.25`
- `NoPenDamage = 0`
- `MinPenetrationDamage = 1`

## Что такое зоны брони

Лобовая броня — самая крепкая зона. В текущих моделях перед танка смотрит в локальный `-Z`, и деталь `FrontArmor` ставится спереди. Стрелять в лоб хуже, потому что базовая броня там выше, а урон после пробития дополнительно умножается на `0.65`.

Бортовая броня — средняя зона. Детали `LeftArmor` и `RightArmor` считаются зоной `Side`. Пробить борт заметно легче, чем лоб, но угол попадания все еще важен.

Кормовая броня — слабая зона. `RearArmor` имеет меньше брони и множитель урона `1.15`, поэтому заход в спину должен ощущаться как сильная тактическая награда.

Угол корпуса — отдельная зона `Corner`. Если попадание близко и к боковой, и к передней/задней границе корпуса, зона повышается до `Corner`. Угол имеет высокую броню и низкий порог рикошета, поэтому ромбование корпуса должно работать.

## Как определяется зона попадания

Сначала код пытается использовать подсказку от хитбокса:

- `FrontArmor` -> `Front`
- `RearArmor` -> `Rear`
- `LeftArmor` / `RightArmor` -> `Side`

Затем `ArmorHitResolver.DetectArmorZone` проверяет локальную точку попадания относительно корпуса. Если попадание находится рядом с углом корпуса, зона становится `Corner`, даже если исходный хитбокс дал подсказку `Front`, `Side` или `Rear`.

Если подсказки нет, зона выбирается по локальной точке попадания: больше смещение по Z — лоб/корма, больше смещение по X — борт.

## Угол попадания и эффективная броня

Угол в коде называется `ImpactAngleDegrees`:

- `0` градусов — снаряд входит почти перпендикулярно броне.
- `90` градусов — снаряд скользит почти параллельно поверхности.

Формула:

```text
EffectiveArmor = BaseArmor / max(cos(ImpactAngleDegrees), EffectiveArmorMinCos)
```

То есть чем более косое попадание, тем выше эффективная броня. При слишком косом попадании снаряд не просто получает большую броню, а может уйти в авторикошет.

## Авторикошет

Авторикошет происходит до проверки пробития:

```text
if ImpactAngleDegrees >= RicochetAngleDegrees:
    Result = Ricochet
elseif PenetrationPower < EffectiveArmor:
    Result = NoPen
else:
    Result = Penetration
```

Порог рикошета зависит от зоны. Например, у лба сейчас `60` градусов, у угла корпуса `45`. Это значит, что угол корпуса намного охотнее отправляет снаряд в рикошет.

## Что делает PenetrationPower

`PenetrationPower` — главный параметр пробития для активного боя. Он сравнивается с `EffectiveArmor`.

Если `PenetrationPower` меньше эффективной брони, получается `NoPen`: урон равен `NoPenDamage`, сейчас это `0`.

Если `PenetrationPower` равен или больше эффективной брони, получается `Penetration`: урон проходит и умножается на множитель зоны.

Пример:

```text
Лобовая броня = 80
Угол = 0 градусов
EffectiveArmor = 80
PenetrationPower = 70
70 < 80 -> NoPen
```

## Что делает Penetration

`Penetration` в `ProjectileCatalog` сейчас legacy alias. У `DefaultRicochetShell` он равен `45`, но активный снаряд также имеет `PenetrationPower = 70`, поэтому resolver использует `70`.

Если у будущего снаряда не будет `PenetrationPower`, код возьмет `Penetration`. Новые апгрейды лучше вешать на `PenetrationPower`, чтобы не плодить две разные правды.

## Как считается урон

Пробитие не дает бонусного урона за большой запас пробития. Сейчас нет формулы типа `damage += penetrationMargin`.

После успешного пробития:

```text
FinalDamage = max(MinPenetrationDamage, ProjectileDamage * ZoneDamageMultiplier)
```

Примеры без рикошетов:

- Лоб: `110 * 0.65 = 71.5`
- Борт: `110 * 0.9 = 99`
- Корма: `110 * 1.15 = 126.5`
- Угол: `110 * 0.5 = 55`

После каждого рикошета сам снаряд теряет урон:

```text
ProjectileDamage *= DamageMultiplierPerBounce
```

Сейчас `DamageMultiplierPerBounce = 0.75`. Значит попадание после одного отскока наносит `75%` от базового урона, а затем еще умножается на множитель зоны.

## Почему +2 пробития может изменить бой

Апгрейд `+2 PenetrationPower` важен только рядом с порогом.

Если эффективная броня `71`, а снаряд имеет `PenetrationPower = 70`, будет `NoPen`. После одного стака `+2` станет `72`, и такой же выстрел уже пробьет.

С текущими числами прямой выстрел в лоб:

```text
FrontArmor = 80
PenetrationPower = 70
Нужно 80 или больше, потому что 70 < 80.
```

Один стак `+2` не пробьет прямой лоб, но пять стаков по `+2` дадут `80` и начнут пробивать прямой лоб без угла. При этом ромбованный лоб все еще может не пробиваться, потому что эффективная броня растет от угла, а при `60+` градусах будет авторикошет.

На бортах и корме `+2` может сработать раньше, особенно на косых попаданиях рядом с порогом. Это хороший дизайн: апгрейд не ломает броню сразу, но иногда открывает новые углы атаки.

## Почему это важно для режима Царь горы

В `Царь горы` лидер часто будет занимать сильную позицию и принимать лобовые/угловые попадания. Ветка пробития дает агрессивному игроку способ бросить вызов танковому лидеру напрямую, не превращая все выстрелы в гарантированный урон.

Хорошая настройка:

- первый стак иногда помогает;
- несколько стаков заметно расширяют варианты атаки;
- максимальные стаки не отменяют важность угла, борта и кормы.

## Будущая прокачка: Armor Piercing / Пробитие

Предложение:

- Upgrade id: `ArmorPiercing` или `PenetrationUp`
- Эффект за стак: `+2 PenetrationPower`
- Максимум: `5` стаков
- Итого на максимуме: `+10 PenetrationPower`

Назначение:

- слабый, но понятный первый стак;
- сильнее против лба и ромбования;
- полезен в будущем `Царь горы`;
- помогает агрессивным игрокам пробивать лидера, который держит центр.

Риск баланса:

- слишком много пробития убивает игру от брони и углов;
- слишком мало пробития ощущается бесполезным;
- лучший диапазон — когда один стак иногда меняет исход, но не превращает все попадания во все зоны в пробитие.

## Что лучше трогать для баланса

Безопаснее трогать:

- `ProjectileCatalog.DefaultRicochetShell.PenetrationPower`
- `TankArmorConfig.Default.Zones.*.Armor`
- `TankArmorConfig.Default.Zones.*.DamageMultiplier`
- `TankArmorConfig.Default.Zones.*.RicochetAngleDegrees`
- `TankArmorConfig.Default.EffectiveArmorMinCos`
- `ProjectileCatalog.DefaultRicochetShell.BounceSpeedMultiplier`
- `ProjectileCatalog.DefaultRicochetShell.DamageMultiplierPerBounce`

Для танкового чувства:

- `TankConfig.Movement.MaxSpeed`
- `TankConfig.Movement.ReverseMaxSpeed`
- `TankConfig.Movement.Acceleration`
- `TankConfig.Movement.Deceleration`
- `TankConfig.Movement.BodyTurnSpeedDegrees`
- `TankConfig.Movement.TurretTurnSpeedDegrees`
- `TankConfig.Movement.ShotRecoilImpulse`
- `WeaponConfig.PrimaryWeapon.ShootCooldown`

## Что опасно трогать без тестов

Опасные параметры:

- `ProjectileCombatService` и `ArmorHitResolver` — это уже изменение формулы боя.
- `ProjectileCollisionService` — легко сломать попадания по броне и стенам.
- `ReflectShield` — отдельная механика отражения, не часть этого баланса.
- `FireRateMultiplier` — при новом базовом cooldown `1.5` текущие `0.85` дают `1.275` секунды; слишком низкий множитель быстро вернет спам.
- `TankConfig.Armor.FrontArmor/SideArmor/RearArmor` — сейчас это не активная таблица урона. Для боевой брони надо менять `TankArmorConfig.Default.Zones`.

Сомнительные/неактивные поля, найденные при аудите:

- `TankArmorConfig.Default.GlancingAngleDegrees`
- `TankArmorConfig.Default.NoPenAngleBelowRicochet`
- `TankArmorConfig.Default.Zones.Corner.ForceRicochetBias`
- `TankConfig.Armor.AutoRicochetAngleDegrees`

Эти поля выглядят как дизайн-намерение или старый слой, но текущий активный resolver не использует их напрямую. Не настраивать их как баланс-ручки без отдельного кода-аудита.
