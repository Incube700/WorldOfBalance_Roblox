# World of Balance: GDD Parity Audit

## 1. Цель

Этот документ сверяет исходный Unity GDD и текущую Roblox-версию, чтобы не потерять core mechanics при переносе.

## 2. Source of truth

- Unity GDD (`/Users/sergoburnheart/RiderProjects/2DPlatformer/WOBLearnUnity/docs/GDD_RU.md`) = source of original design intent.
- Unity `TECH_STATUS.md`, `ROADMAP.md`, `AI_CONTEXT_GRAPH.md`, `AI_IMPLEMENTATION_PROMPT.md` = implementation/status context for the Unity prototype.
- Roblox `docs/GDD.md` = active implementation target for the Roblox prototype.
- Если Unity design intent и Roblox target конфликтуют, решение нужно фиксировать явно, а не молча выкидывать механику.

## 3. Parity matrix

| Feature | Unity GDD intent | Roblox current status | Gap | Decision | Priority | Next task |
|---|---|---|---|---|---|---|
| Top-down camera | Strict orthographic top-down; gameplay on XZ plane. | Top-down camera exists through Roblox client/controller/config flow. | Need Play Mode parity check after recent changes. | Already implemented. | Core Now | Verify camera framing after current Rojo sync. |
| Separate hull and turret | Hull movement and turret aiming are separate. | Implemented: body yaw and turret yaw are separate in `WOBGameplayServer`. | None major. | Already implemented. | Core Now | Keep regression check in every combat sprint. |
| WASD desktop controls | W/S along hull, A/D rotate hull, mouse aims turret. | Implemented; reverse steering fix applied. | Unity has acceleration/brake/coast; Roblox is simpler. | Simplify for Roblox MVP. | Core Now | Keep controls stable before adding mobile. |
| Mobile arcade controls | Left joystick hull/movement, right joystick aim, fire button/tap. | Missing in Roblox. | Entire mobile input/UI layer absent. | Missing, add to backlog. | Soon | Implement mobile arcade controls after PC loop is stable. |
| Projectile visible and fast | Fast but readable projectile with trail/feedback. | Implemented with projectile Part plus readability overlays. | Visual tuning still manual. | Already implemented. | Core Now | Verify readability at top-down zoom. |
| Wall ricochets | Ricochet from walls/obstacles, stable reflection by normal. | Implemented in Rojo `WOBGameplayServer`. | Needs Play Mode regression after armor sprint. | Already implemented. | Core Now | Test walls/cover after tank ricochet changes. |
| Ricochet from tank armor | No-penetration/auto-ricochet bounces from tank armor. | Implemented in latest code-first sprint, not yet Play Mode verified. | Roblox GDD previously treated it as optional Future. | Keep as core. | Core Now | Play test front/glancing armor ricochet. |
| MaxRicochets = 3 | Max ricochets is 3; next contact destroys projectile. | Configured as `MaxRicochets = 3`. | Need confirm contact-after-limit semantics. | Already implemented. | Core Now | Verify destroy behavior after third bounce. |
| Damage decreases after ricochet | Current damage cap reduces after bounce. | Implemented via `DamageMultiplierPerBounce = 0.75`. | None major. | Already implemented. | Core Now | Verify damage after bounce in Play Mode. |
| Speed decreases after ricochet | Speed reduces after bounce; visual loss may need tuning. | Implemented via `BounceSpeedMultiplier = 0.78`. | Tuning/readability still uncertain. | Keep, tune later. | Soon | Tune visible speed loss only after Play check. |
| Projectile Penetration | Penetration decides if shell passes effective armor. | Implemented: `Penetration = 45`. | Needs Play Mode validation. | Already implemented. | Core Now | Test direct front/side/rear hits. |
| Projectile Max Damage | Max damage is cap, not guaranteed damage. | Implemented: `MaxDamage = 110`. | Older Roblox docs still mention fixed damage in places. | Keep as core. | Core Now | Keep docs/code aligned after tuning. |
| Armor zones: Front / Side / Rear | Front strongest, side medium, rear weak. | Implemented in `TankConfig.Armor` and `RicochetMath`. | No separate `TankArmorConfig`; acceptable short term. | Keep as core. | Core Now | Verify zone classification against model orientation. |
| Effective armor from hit angle | `armor / max(cos(angle), safeMinCos)`. | Implemented in `RicochetMath`. | Needs Play Mode/edge-case validation. | Already implemented. | Core Now | Add focused Play checklist for glancing hits. |
| Auto ricochet angle | Glancing angle can auto ricochet. | Implemented with `AutoRicochetAngleDegrees = 72`. | Unity current values differ: player 50.3, enemy 60. | Needs manual design decision. | Soon | Decide Roblox tuning value after feel test. |
| No penetration -> ricochet/no damage | No penetration produces no damage and can bounce. | Implemented. | Needs visible feedback, not only Output logs. | Keep as core. | Core Now | Add visible NO PEN/RICOCHET feedback. |
| Self-hit after ricochet | Direct self-shot blocked; returning projectile can hit owner. | Implemented through `CanHitOwner` after bounce. | Grace/safe-time is simpler than Unity. | Simplify for Roblox MVP. | Core Now | Verify owner damage after bounce. |
| Aim laser from muzzle | Player aim helper begins at muzzle. | Implemented as `WOBAimLaser.client.luau`. | Newly added; needs Play Mode check. | Keep as core readability helper. | Core Now | Verify origin and alignment with projectile. |
| Aim laser stops on obstacle | Laser must not lie by passing through obstacles/tanks. | Implemented with client raycast. | Needs obstacle/tank mask verification. | Keep as core readability helper. | Core Now | Test wall/tank stop behavior. |
| Player HP | Player has HP and death. | Implemented as attributes and HUD binding. | Roblox player HP is 100, matches Unity player. | Already implemented. | Core Now | Keep restart regression. |
| Enemy/Dummy HP | Unity current enemy HP is 300; early values had 100. | Roblox dummy HP is 100. | Balance parity mismatch. | Needs manual design decision. | Soon | Decide Roblox dummy/enemy HP target. |
| WIN / LOSE | Round result when player/enemy dies. | Implemented. | One-round only. | Already implemented. | Core Now | Verify after armor no-pen changes. |
| Restart round | Restart resets round without duplicate UI/listeners. | Implemented via existing reset event. | Needs duplicate/no stale projectile check. | Already implemented. | Core Now | Test R after Win/Lose. |
| Series to 3 wins | Unity has `RoundsToWin = 3`. | Missing. | Roblox only has one-round loop. | Missing, add to backlog. | Soon | Add first-to-3 local match flow. |
| Round break timer | Unity has `RoundBreakSeconds = 5`. | Missing. | No inter-round countdown. | Missing, add to backlog. | Soon | Add round break timer with HUD label. |
| Final match result | Unity final session result after 3 wins. | Missing. | Roblox only Win/Lose per round. | Missing, add to backlog. | Soon | Add final match state/result. |
| Statistics | Unity has local PlayerPrefs statistics/recent games. | Missing. | No Roblox stats/recent matches. | Keep but later. | Later | Design local/session stats for Roblox. |
| Main menu | Unity has MainMenu -> demo flow. | Missing in Roblox. | Roblox starts directly in scene/prototype. | Keep but later. | Later | Add simple main menu after combat loop stabilizes. |
| Enemy AI / state machine | Unity roadmap says enemy AI later; AI architecture rules exist. | Missing; Roblox uses DummyTank. | No enemy movement/aim/shoot/state display. | Keep but later. | Later | Add simple enemy AI milestone. |
| Wreck/death VFX | Unity expects smoke/wreck marker/death VFX. | Partial: tank darkens and impact flash exists. | No clear wreck/smoke marker. | Missing, add to backlog. | Soon | Add visual-only death/wreck marker. |
| World-space HP bars | Unity has world-space HP bars. | Missing; Roblox uses screen HUD. | Player/enemy HP not spatially attached. | Missing, add to backlog. | Soon | Add world-space HP bars as visual layer. |
| Floating hit text | Unity has floating damage / NO PEN / RICOCHET. | Missing; impact pulse exists but no text. | Player cannot read combat outcome in-world. | Missing, add to backlog. | Soon | Add floating hit/result text. |
| Combat feedback: DAMAGE / NO PEN / RICOCHET | Unity requires visible result explanation. | Partial: Output logs `[PEN]`, `[NO-PEN]`, `[ARMOR-RICOCHET]`; no visible labels. | Feedback is debug-only, not player-facing. | Missing, add to backlog. | Core Now | Add visible combat feedback overlay. |
| Three arena prefabs / random map per round | Unity has round-to-round map support but defaults reuse demo scene. | Missing; one Roblox arena. | No map list/randomization. | Keep but later. | Later | Add arena variants after match flow. |
| Android/mobile controls | Unity Android launches; mobile controls v1 work but need tester feedback. | Missing in Roblox. | No thumb UI or mobile input mode. | Missing, add to backlog. | Soon | Build Roblox mobile control layer. |
| Architecture rules: no God Object, separated UI/gameplay/configs/events | Unity requires feature modules/events/composition. | Partial: configs/client overlays split, but `WOBGameplayServer` is still a large monolith. | Roblox risks becoming a God Object. | Keep rule, refactor gradually. | Soon | Split combat/projectile/match modules after Play stability. |
| Config separation: WeaponConfig / ProjectileCatalog / ProjectileVisualConfig / TankArmorConfig | Unity separates projectile/weapon/visual/armor concerns. | Partial: `WeaponConfig`, `ProjectileCatalog`, `ProjectileVisualConfig`; armor lives in `TankConfig`. | `TankArmorConfig` missing, but current placement is acceptable for small MVP. | Simplify for Roblox MVP. | Soon | Decide whether to extract `TankArmorConfig`. |
| Debug logs prefixes | Unity wants filterable `[SHOT]`, `[BOUNCE]`, `[HIT]`, `[ARMOR]`, `[DAMAGE]`, `[ROUND]`, `[AI]`, `[FLOW]`. | Partial: `[WALL]`, `[BOUNCE]`, `[DAMAGE]`, `[DEAD]`, `[PEN]`, `[NO-PEN]`, `[ARMOR-RICOCHET]`, `[SELF-HIT]`, `[ROUND]`. | Prefix taxonomy differs; logs not toggleable. | Keep but later. | Later | Add small DebugConfig/log prefix cleanup. |

## 4. Critical gaps

- Roblox GDD previously described tank armor ricochet and angle armor as optional Future, while Unity design treats penetration/effective armor/no-penetration ricochet as core combat identity.
- Roblox has armor code now, but it still needs Play Mode validation: front no-pen, side/rear pen, glancing ricochet, self-hit after bounce.
- Roblox combat feedback is mostly Output logs and pulses; Unity expects player-facing `DAMAGE`, `NO PEN`, and `RICOCHET` feedback.
- Roblox has screen HUD, but Unity expects world-space HP bars and floating hit text as readability tools.
- Roblox has one-round restart; Unity has first-to-3 series, round break timer, final result, and stats/recent matches.
- Roblox has no main menu flow yet; Unity uses MainMenu -> RicochetTanks_Demo.
- Roblox is PC-first only; Unity includes Android/mobile arcade controls as an important product direction.
- Roblox still has a large `WOBGameplayServer`; Unity architecture intent explicitly avoids God Objects and separates projectile, armor, health, match, UI, and feedback.
- Roblox dummy HP is 100; Unity current enemy HP is 300. This is a balance/design decision, not an automatic bug.
- Roblox death feedback is minimal; Unity expects smoke/wreck/death marker direction.

## 5. Immediate correction to Roblox docs

Applied in this audit:

- `docs/GDD.md`: armor/penetration/effectiveArmor/tank armor ricochet are core combat direction, not optional forever.
- `docs/GDD.md`: aim laser must stop on obstacles if used.
- `docs/GDD.md`: first-to-3, round break, final result, statistics, and main menu are future milestones, not forgotten features.
- `docs/RICOCHET_RULES.md`: added parity notes for obstacle-stopping aim laser and future match/statistics flow.

## 6. Backlog from parity audit

1. Core combat parity:
   - penetration;
   - max damage;
   - armor zones;
   - effective armor;
   - tank armor ricochet.

2. Feedback parity:
   - `NO PEN` / `RICOCHET` / `DAMAGE` feedback;
   - floating hit text;
   - death/wreck feedback.

3. Match flow parity:
   - series to 3 wins;
   - round break timer;
   - final result.

4. Product loop parity:
   - main menu;
   - statistics;
   - recent matches.

5. AI parity:
   - enemy tank AI;
   - aim at player;
   - line of sight;
   - obstacle avoidance.

6. Mobile parity:
   - mobile arcade controls;
   - thumb UI.

## 7. Do not implement in this task

This task is audit/docs only:

- do not write gameplay code;
- do not change `src` logic;
- do not change `.rbxl`;
- do not create new UI elements;
- do not change `default.project.json`.
