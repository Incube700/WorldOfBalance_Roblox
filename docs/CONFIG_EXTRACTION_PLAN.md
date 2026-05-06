# World of Balance: Ricochet Tanks - Config Extraction Plan

Дата: 2026-05-07.

## Цель

Подготовить будущий вынос hard-coded constants из Studio-скриптов в read-only ModuleScript configs под Rojo.

Этот документ не меняет поведение игры. Это план будущих маленьких задач.

Ограничения:

- не менять `.rbxl`;
- не менять `src/`;
- не менять gameplay-код;
- не менять `default.project.json`;
- не подключать configs к `WOBGameplayServer` в первом коммите;
- не делать рефакторинг;
- не создавать `GameplayConfig` как свалку значений из монолита.

## Principle: Responsibility First

Конфиги группируются по будущей ответственности системы, а не по тому, где число сейчас лежит в `WOBGameplayServer`.

Правила:

- tank movement values идут в `TankConfig`;
- weapon firing values идут в `WeaponConfig`;
- projectile mechanics идут в `ProjectileCatalog`;
- projectile visuals идут в `ProjectileVisualConfig`;
- HUD formatting/display values идут в `HudConfig`;
- respawn/reset values идут в `DummyRespawnConfig`;
- lighting/performance values идут в `PerformanceConfig`;
- projectile mechanics and projectile visuals must stay separate;
- visuals may reference projectile type ids, but must not own damage, speed or ricochet rules.

`GameplayConfig` сейчас не нужен. Если позже появятся round-level values, он может содержать только global match/round values: round duration, round start delay, round end delay, score to win.

## Future Config Modules

Planned read-only modules:

```text
src/
  ReplicatedStorage/
    Shared/
      Configs/
        TankConfig.luau
        WeaponConfig.luau
        ProjectileCatalog.luau
        ProjectileVisualConfig.luau
        DummyRespawnConfig.luau
        CameraConfig.luau
        HudConfig.luau
        PerformanceConfig.luau
```

Do not create these modules in the same commit as this document.

## TankConfig

Responsibility: tank body movement, tank orientation limits, and model dependency notes.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Movement speed | `WOBGameplayServer.server.luau` | `MOVE_SPEED = 34` | `TankConfig` | High: changes movement feel and arena control. | Hold `W`/`S`; verify tank speed still feels identical and stays inside arena bounds. |
| Reverse speed | `WOBGameplayServer.server.luau` | No separate constant; reverse uses `MOVE_SPEED` with negative throttle. | `TankConfig` | Medium: future separate reverse speed changes handling. | Hold `S`; verify reverse movement matches current behavior if not intentionally changed. |
| Body turn speed | `WOBGameplayServer.server.luau` | `TURN_SPEED = math.rad(115)` | `TankConfig` | High: changes turning feel and aim geometry. | Hold `A`/`D`; verify body rotation matches current feel. |
| Turret turn speed | `WOBGameplayServer.server.luau` | No separate constant; turret snaps to `getYawFromDirection`. | `TankConfig` | High if introduced: would change aiming feel. | Move mouse around tank; turret should behave exactly as before until a separate feature changes it. |
| Tank model dependency notes | `WOBGameplayServer.server.luau`, `WOBClientController.client.luau` | `PlayerTankPrototype`, `Body`, `Turret`, `Barrel`, `ShootPoint`, `Hitboxes`, armor part names. | `TankConfig` or future `InstanceNames` | Medium: renaming breaks scripts. | Play starts without infinite yields; tank body, turret, barrel and hitboxes still align. |

Do not extract first:

- `updateTank`;
- `layoutTank`;
- `getYawFromDirection`;
- CFrame math;
- arena clamp behavior.

## WeaponConfig

Responsibility: firing rules and weapon-to-projectile selection. It does not own projectile movement, damage or visual rules.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Shoot cooldown | `WOBGameplayServer.server.luau`, duplicated in `WOBHudController.client.luau` | `SHOOT_COOLDOWN = 0.45` | `WeaponConfig` | Medium: affects fire cadence and HUD reload sync. | Click repeatedly; server fire rate and reload UI still match current timing. |
| Projectile type id | Not present | Current projectile is implicit. Suggested future id: `BasicRicochet`. | `WeaponConfig` | Low if read-only; high if wired incorrectly. | Weapon still spawns the same projectile after config is wired later. |
| Muzzle offset | `WOBGameplayServer.server.luau` | `tankShootPoint.CFrame = turretCFrame * CFrame.new(0, 0, -10)` | `WeaponConfig` or `TankConfig` depending on final ownership | High: changes spawn point and self-collision risk. | Fire forward and sideways; projectile starts at the same visible muzzle point. |
| Barrel visual offset | `WOBGameplayServer.server.luau` | `tankBarrel.CFrame = turretCFrame * CFrame.new(0, 0, -5.8)` | `TankConfig` or visual model config | Medium: visual only unless shoot point depends on it. | Barrel remains aligned with turret and shoot point. |
| Future spread/burst/reload/ammo | Not present | Not implemented. | `WeaponConfig` | High when introduced. | Not applicable until a feature task exists. |

Do not put projectile speed, damage, lifetime or ricochet rules in `WeaponConfig`.

## ProjectileCatalog

Responsibility: projectile mechanics by projectile id. This allows future projectile behavior types without changing weapon config shape.

Initial planned projectile id: `BasicRicochet`.

Supported future behavior types:

- `Ricochet`
- `Piercing`
- `Explosive`
- `Heavy`
- `NoRicochet`

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Projectile id | Not present | Implicit current projectile. Suggested id: `BasicRicochet`. | `ProjectileCatalog` | Low as read-only, medium once wired. | Fire still creates the same projectile. |
| Behavior type | `WOBGameplayServer.server.luau` | Implicit ricochet behavior via `reflect` and bounce count. | `ProjectileCatalog` | High if wired: changes central mechanic. | Projectile still ricochets exactly as before. |
| Speed | `WOBGameplayServer.server.luau` | `PROJECTILE_SPEED = 160` | `ProjectileCatalog` | High: affects readability and collision feel. | Fire across arena; projectile speed remains visually identical. |
| Damage | `WOBGameplayServer.server.luau` | `PROJECTILE_DAMAGE = 35` | `ProjectileCatalog` | High: affects dummy HP and balance. | Hit dummy; HP reduction remains `35` before ricochet modifiers. |
| Max ricochets | `WOBGameplayServer.server.luau` | `PROJECTILE_MAX_BOUNCES = 3` | `ProjectileCatalog` | High: central MVP mechanic. | Fire into wall; projectile ricochets up to 3 times as before. |
| Lifetime | `WOBGameplayServer.server.luau` | `PROJECTILE_LIFETIME = 4` | `ProjectileCatalog` | Medium: affects cleanup and long shots. | Fire without hitting dummy; projectile disappears after same duration. |
| Damage multiplier per bounce | `WOBGameplayServer.server.luau` | `PROJECTILE_DAMAGE_MULTIPLIER = 0.75` | `ProjectileCatalog` | Medium/high: affects ricochet reward. | Ricochet-hit dummy; logged damage still follows current multiplier. |
| Collision/raycast settings | `WOBGameplayServer.server.luau` | Excludes `projectileFolder`, `vfxFolder`, `playerTank`; `IgnoreWater = true`. | Future projectile behavior config | Very high: can break collision or self-hit behavior. | Not a first extraction target. Verify all wall/dummy hits manually if changed later. |

Do not extract first:

- raycast execution;
- raycast filter;
- `reflect(direction, normal)` wiring;
- damage application;
- projectile state update loop.

## ProjectileVisualConfig

Responsibility: projectile readability and visual effects. It must not own projectile speed, damage, lifetime or behavior.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Projectile part size | `WOBGameplayServer.server.luau` | `Vector3.new(1.2, 1.2, 1.2)` | `ProjectileVisualConfig` | Low/medium: changes readability and perceived hit size. | Fired projectile remains equally readable. |
| Projectile material | `WOBGameplayServer.server.luau` | `Enum.Material.Neon` | `ProjectileVisualConfig` | Low visual risk. | Projectile still appears bright. |
| Projectile color | `WOBGameplayServer.server.luau` | `Color3.fromRGB(255, 230, 120)` | `ProjectileVisualConfig` | Low visual risk. | Projectile color remains unchanged. |
| Projectile light | `WOBGameplayServer.server.luau` | `PointLight.Brightness = 1`, `Range = 6` | `ProjectileVisualConfig` | Low/medium: affects readability. | Projectile glow remains unchanged. |
| Muzzle flash | `WOBGameplayServer.server.luau` | color `255,220,80`, size `3.2`, lifetime `0.08` | `ProjectileVisualConfig` | Low visual risk. | Muzzle flash still appears briefly on fire. |
| Impact flash | `WOBGameplayServer.server.luau` | color `255,130,40`, size `2.5`, lifetime `0.12` | `ProjectileVisualConfig` | Low visual risk. | Wall hit and dummy hit still flash. |
| Ricochet VFX | `WOBGameplayServer.server.luau` | Uses same impact flash on any non-dummy hit. | `ProjectileVisualConfig` | Low unless separated from hit VFX. | Wall ricochet still shows flash. |
| Spark count/shape/color | `WOBGameplayServer.server.luau` | `3` sparks, size `0.25,0.25,1.2`, color `255,200,90`, Debris `0.12` | `ProjectileVisualConfig` | Low visual risk. | Sparks still appear on impact. |
| Trail attachment offsets | `WOBProjectileVisualEnhancer.server.luau` | `TrailAttachment0 = (0,0,-0.45)`, `TrailAttachment1 = (0,0,0.45)` | `ProjectileVisualConfig` | Low visual risk. | Projectile trail remains centered. |
| Trail values | `WOBProjectileVisualEnhancer.server.luau` | `Lifetime = 0.18`, `MinLength = 0.1`, `LightEmission = 1`, `FaceCamera = true` | `ProjectileVisualConfig` | Low visual risk. | Trail length and brightness remain unchanged. |
| Trail color/transparency | `WOBProjectileVisualEnhancer.server.luau` | color `255,230,120 -> 255,120,40`, transparency `0.05 -> 1` | `ProjectileVisualConfig` | Low visual risk. | Trail color fade remains unchanged. |
| Death VFX if related | `WOBGameplayServer.server.luau` | Dummy death darkens all BaseParts to `30,30,30`. | `ProjectileVisualConfig` or future `TankVisualConfig` | Medium: overlaps with `DummyRespawnConfig` reset colors. | Destroy dummy; it still darkens, then reset restores colors. |

Visual config may reference projectile type ids, for example `BasicRicochet`, but must not define damage, speed, max ricochets or lifetime.

## DummyRespawnConfig

Responsibility: dummy health reset, respawn timing and reset visuals.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Max health | `WOBDummyRespawnServer.server.luau`, duplicated in HUD and gameplay default | `MAX_HEALTH = 100`, `MAX_DUMMY_HEALTH = 100`, default `100` in `damageDummy` | `DummyRespawnConfig` or future health config | Medium/high: affects damage/reset/HUD consistency. | Hit dummy; health display and reset return to `100`. |
| Respawn delay | `WOBDummyRespawnServer.server.luau` | `RESPAWN_DELAY = 2.25` | `DummyRespawnConfig` | Medium: affects test loop pacing. | Destroy dummy; it resets after same delay. |
| Reset body color | `WOBDummyRespawnServer.server.luau` | `Body = Color3.fromRGB(160, 65, 65)` | `DummyRespawnConfig` | Low visual risk. | Press `R`; body color returns as before. |
| Reset turret color | `WOBDummyRespawnServer.server.luau` | `Turret = Color3.fromRGB(45, 45, 50)` | `DummyRespawnConfig` | Low visual risk. | Press `R`; turret color returns as before. |
| Reset barrel color | `WOBDummyRespawnServer.server.luau` | `Barrel = Color3.fromRGB(30, 30, 35)` | `DummyRespawnConfig` | Low visual risk. | Press `R`; barrel color returns as before. |
| Reset shoot point color | `WOBDummyRespawnServer.server.luau` | `ShootPoint = Color3.fromRGB(255, 230, 80)` | `DummyRespawnConfig` | Low visual risk. | Press `R`; shoot point color returns as before. |
| Reset armor colors | `WOBDummyRespawnServer.server.luau` | Front `80,180,255`; rear `255,150,80`; side `180,255,120` | `DummyRespawnConfig` | Medium: future angle-damage readability depends on these colors. | Press `R`; armor colors return as before. |

Reset colors are gameplay readability support, not final art direction.

## CameraConfig

Responsibility: top-down camera and current client send cadence.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Camera height | `WOBClientController.client.luau` | `CAMERA_HEIGHT = 95` | `CameraConfig` | Medium: affects arena readability. | Play; arena framing matches current view. |
| Field of view | `WOBClientController.client.luau` | `CAMERA_FIELD_OF_VIEW = 42` | `CameraConfig` | Medium: affects scale/readability. | Play; tank and arena size appear unchanged. |
| Input send interval | `WOBClientController.client.luau` | `INPUT_SEND_INTERVAL = 0.05` | `CameraConfig` for first pass, future `InputConfig` if split | Medium/high: affects server input smoothness. | Move tank; control remains equally responsive. |

`INPUT_SEND_INTERVAL` is not a camera value by responsibility. It is listed here because no `InputConfig` is planned yet. If input grows, split it into `InputConfig`.

## HudConfig

Responsibility: HUD display formatting and feedback timing. HUD config must not own gameplay health or weapon cooldown rules.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Feedback time | `WOBHudController.client.luau` | `FEEDBACK_TIME = 0.8` | `HudConfig` | Low/medium: affects hit readability. | Hit dummy; feedback fades with same timing. |
| Reload display cooldown | `WOBHudController.client.luau`, duplicated with server | `SHOOT_COOLDOWN = 0.45` | `HudConfig` as display mirror, source should be `WeaponConfig` later | Medium: can desync display and server. | Click; reload bar reaches READY at same time as server cooldown. |
| Dummy health display max | `WOBHudController.client.luau` | `MAX_DUMMY_HEALTH = 100` | `HudConfig` display dependency, source should match `DummyRespawnConfig` | Medium: can desync bar and actual health. | Hit/reset dummy; label and bar remain correct. |
| Health text format | `WOBHudController.client.luau` | `"Dummy HP: " .. health .. " / " .. MAX_DUMMY_HEALTH` | `HudConfig` | Low. | Text remains unchanged. |
| Reload ready text | `WOBHudController.client.luau` | `"Reload: READY"` | `HudConfig` | Low. | Ready label remains unchanged. |
| Reload percent text | `WOBHudController.client.luau` | `"Reload: " .. percent .. "%"` | `HudConfig` | Low. | Percent label remains unchanged. |
| Feedback texts/colors | `WOBHudController.client.luau` | `HIT`, `TARGET DESTROYED`, `TARGET RESET` with current colors | `HudConfig` | Low/medium: readability. | Hit, destroy and reset feedback look unchanged. |

Server gameplay logic must not depend on `HudConfig`.

## PerformanceConfig

Responsibility: performance profile and lighting defaults for the prototype.

| Value | Current script | Current constant/name/value | Future module | Risk of change | Play Mode check |
| --- | --- | --- | --- | --- | --- |
| Global shadows | `WOBPerformanceServer.server.luau` | `Lighting.GlobalShadows = false` | `PerformanceConfig` | Medium visual/perf risk. | Play; shadows stay disabled. |
| Brightness | `WOBPerformanceServer.server.luau` | `Lighting.Brightness = 2` | `PerformanceConfig` | Medium visual risk. | Arena brightness remains unchanged. |
| Clock time | `WOBPerformanceServer.server.luau` | `Lighting.ClockTime = 14` | `PerformanceConfig` | Low/medium visual risk. | Lighting direction/feel remains unchanged. |
| Fog end | `WOBPerformanceServer.server.luau` | `Lighting.FogEnd = 100000` | `PerformanceConfig` | Low. | No unwanted fog appears. |
| Technology | `WOBPerformanceServer.server.luau` | `Enum.Technology.Compatibility` inside `pcall` | `PerformanceConfig` | Medium compatibility risk. | Play starts without lighting errors. |
| Cast shadows | `WOBPerformanceServer.server.luau`, `WOBGameplayServer.server.luau` | `part.CastShadow = false` for generated parts and characters | `PerformanceConfig` | Medium visual/perf risk. | Generated parts still have shadows disabled. |

Performance config must not own gameplay cleanup behavior.

## Do Not Extract Yet

Do not extract or wire these in the first config work:

- damage flow;
- projectile raycast logic;
- ricochet algorithm;
- tank movement behavior;
- RemoteEvent contracts;
- match loop;
- projectile update loop;
- `DummyTank.Health` authority;
- self-hit filtering;
- angle damage placeholders;
- runtime object lifecycle.

Reason: these are behavior surfaces. Moving them without tests or Play verification risks changing the prototype.

## Recommended First Implementation Step

1. First commit: create read-only ModuleScript configs in `src/ReplicatedStorage/Shared/Configs`.
2. Do not connect the new configs to `WOBGameplayServer`, `WOBClientController`, `WOBHudController` or other Studio scripts in that commit.
3. Use clear module names based on responsibility: `TankConfig`, `WeaponConfig`, `ProjectileCatalog`, `ProjectileVisualConfig`, `DummyRespawnConfig`, `CameraConfig`, `HudConfig`, `PerformanceConfig`.
4. Separate next commit: wire exactly one safe group of constants in the smallest possible slice.
5. Recommended first wiring slice: `ProjectileVisualConfig` trail values or `PerformanceConfig` lighting constants.
6. Do not wire projectile mechanics, tank movement or damage first.

## Verification Checklist For Future Wiring

After each wiring step:

- run `rojo serve`;
- open `RicochetTanksPrototype.rbxl`;
- connect Rojo plugin;
- press Play;
- verify Output has no errors;
- verify tank movement still works;
- verify turret aim still works;
- verify shooting still works;
- verify projectile ricochet count remains 3;
- verify dummy HP and reset still work;
- verify reload UI timing still matches current behavior;
- verify projectile visuals remain readable.
