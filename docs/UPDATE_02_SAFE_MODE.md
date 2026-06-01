# Update 0.2 Safe Mode

Update 0.2 arena authoring is disabled by default.

The master flag is:

```lua
WeaponCatalog.Flags.Update02ArenaLayerEnabled = false
```

When this flag is false, the runtime arena layer is inert:

- `ArenaSessionLifecycle` does not spawn the maze, pickups, or breakables.
- Authored layout loading is not activated.
- Procedural maze fallback is not allowed.
- Pickup and breakable fraction fallbacks are not allowed.
- Missing authored templates or markers must no-op with a Studio warning.
- `Workspace/WOB_Runtime/ArenaMode` is destroyed on startup, Lobby/Menu transitions, BattleArena leave, and Duel/PvP start.

The older per-system flags (`MazeEnabled`, `PickupsEnabled`, `BreakablesEnabled`) are still present, but they are subordinate to `Update02ArenaLayerEnabled` and default off in safe mode.

Runtime visual polish is also opt-in only:

```lua
WeaponCatalog.Flags.RuntimeVisualPolishEnabled = false
```

With safe mode active there is no startup map recolor, no dark-theme mutation, and no generated neon geometry. Studio-authored map colors remain the source of truth.

What remains playable:

- Lobby free drive and Duel/PvP.
- Training with the existing normal gameplay loop.
- BattleArena's existing core loop, bots, XP, upgrades, wallet/reward flow, projectile behavior, HUD, FX, and audio.

To re-enable later safely:

1. Set `Update02ArenaLayerEnabled = true`.
2. Enable only the specific per-system flags needed.
3. Use an explicit authored template at `ReplicatedStorage/Assets/ArenaLayouts/<WeaponCatalog.ActiveLayoutName>`.
4. Use authored marker folders only: `PickupSpawns` and `BreakableSpawns`.
5. Do not reintroduce `WeaponCatalog.PickupLayout`, `MazeLayout`, or `BreakableLayout` as runtime fallbacks.

Future arena work should choose exact config paths and authored templates only. If a template or marker folder is missing, the safe behavior is no spawn plus a Studio warning.
