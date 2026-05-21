# Cosmetic Unlocks And Shop Plan

This is a roadmap document. The current pass does not implement shop UI, purchase logic, ownership persistence, or runtime cosmetic application.

## Purpose

`CosmeticCatalog` prepares stable data for future cosmetic unlocks. It lets future systems talk about tank skins, projectile trails, muzzle effects, ricochet impacts, death explosions, burning effects, aim laser styles, armor zone styles, and victory effects without hardcoding template names throughout gameplay services.

## Currency Direction

Bolts:

- common and uncommon cosmetic effects;
- basic tank skins;
- common projectile trails;
- low-stakes BattleArena unlocks.

Crystals:

- rare skins;
- rare VFX;
- premium-feeling aim laser styles;
- special weapon cosmetics or sidegrades;
- limited victory effects.

Neither currency should create permanent stat advantage in normalized Duel.

## Duel Rules

Duel should remain skill-based and normalized.

Cosmetic items may be allowed in Duel only if they preserve readability:

- no projectile trails that hide shell direction;
- no aim laser styles that mislead the player;
- no armor zone styles that obscure front/side/rear meaning;
- no VFX that hides tanks, walls, shells, or ricochet impacts;
- no audio cosmetics that mask important combat feedback.

Gameplay-readable upgrades such as Shell Research can exist in BattleArena and future Extraction, but in normalized Duel they should be disabled, equalized for both players, or reserved for casual/unranked rules later.

## Future Services

`CosmeticOwnershipService`:

- stores owned cosmetic item IDs;
- grants defaults;
- validates ownership;
- persists unlocks later.

`PlayerLoadoutService`:

- stores equipped cosmetic IDs per slot;
- validates slot compatibility;
- exposes loadout to spawn/apply services.

`CosmeticShopService`:

- reads `CosmeticCatalog`;
- validates currency and price;
- performs purchases later;
- does not directly apply visuals.

`CosmeticApplyService`:

- applies equipped tank skins, projectile trails, VFX profiles, armor zone styles, and aim laser styles;
- keeps gameplay readability rules centralized;
- should be called by TankFactory/projectile/VFX/client visual layers only after ownership/loadout exists.

## Non-Goals Now

- No shop UI.
- No purchase RemoteEvents.
- No DataStore ownership changes.
- No runtime cosmetic application.
- No VFX/UI template edits.
- No Duel power progression.
