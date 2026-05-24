# World of Balance: Ricochet Tanks

Top-down Roblox arena game about small tanks where you win through position, hull angle, independent turret aiming, and ricochets — not big numbers.

> Walls are weapons. Armor angle matters. Your own shell can punish you. A clever ricochet feels amazing.

---

## Current Docs Entry Point

This README is a lightweight project overview and may lag behind the current playtest state. For the latest workflow and cleanup/refactor guardrails, start here:

- [Documentation Index](docs/DOCS_INDEX.md) — current docs map and status labels.
- [Current Project State](docs/CURRENT_PROJECT_STATE.md) — playable BattleArena/Duel/Training state to preserve.
- [Cleanup Candidates](docs/CLEANUP_CANDIDATES.md) — safe cleanup order and files that need confirmation before removal.
- [Battle Arena Progression v2](docs/BATTLE_ARENA_PROGRESSION_V2.md) — post-5 levels, paid revive, free respawn, branch prep.

Older sections below are retained as project context. Verify them against the current docs before using them as workflow instructions.

---

## Setup

**Requirements:**
- [Rojo](https://rojo.space/) (v7+)
- Roblox Studio

**Sync the project:**

```bash
rojo serve default.project.json
```

Open `WorldOfBalanceRoblox.rbxl` in Roblox Studio, then connect to the Rojo server via the Rojo Studio plugin. Press **Sync In** to pull all scripts.

**Play:**

Press Play (or Play Here) in Studio. The game boots directly into the arena/lobby. No separate launch step needed.

---

## Project structure

```
src/
  ReplicatedStorage/Shared/
    Configs/       — all game configs (weapons, tanks, bots, HUD, audio, VFX, economy)
    Utils/         — shared math utilities (RicochetMath, TankModelResolver)
    Assets/VFX/    — VFX template .rbxm files + VfxTemplateCatalog

  ServerScriptService/Server/
    Gameplay/
      Arena/       — BattleArena combat service
      Bots/        — BotBrain, BotController, BotService, BotSpawnPlanner, BotTargeting
      Combat/      — ArmorHitResolver, ProjectileCombatService
      Economy/     — KillRewardService, MatchRewardService, PlayerWalletService
      Lobby/       — LobbyService, LobbyPadResolver
      Movement/    — TankMovementService
      Players/     — PlayerPossessionService
      Projectiles/ — ProjectileService, ProjectileCollisionService
      Round/       — RoundMatchService
      Skins/       — SkinUnlockService, TankCustomizationService, TankSkinApplier
      Stats/       — MatchStatsService, PersistentPlayerStatsService
      Tanks/       — TankFactory, TankSpawnResetService, TankArmorPartsService, etc.
      VFX/         — CombatVfxService
    WOBGameplayServer.server.luau  — main server orchestrator
    WOBPvPBootstrap.server.luau    — PvP session bootstrap

  StarterPlayer/StarterPlayerScripts/Client/
    WOBAimLaser                    — aim laser from muzzle (stops on obstacles)
    WOBAudioController             — audio playback
    WOBBattleArenaOverlay          — BattleArena HUD
    WOBCombatFeedbackOverlay       — DAMAGE / NO PEN / RICOCHET labels
    WOBDuelHudOverlay              — main Duel HUD (HP, score, reload)
    WOBDuelPadVisual               — lobby duel pad UI
    WOBImpactFeedbackOverlay       — impact flash effects
    WOBMobileControls              — mobile joystick + fire button
    WOBProjectileReadabilityOverlay — projectile glow, trail, neon
    WOBRoundStatusOverlay          — round result text
    WOBTankDamageFlash             — damage flash on tank hit
    WOBTankInputController         — WASD + mouse input → server remotes
    WOBTankLocalTeamVisuals        — team color tinting per local perspective
    WOBTankPossessionCamera        — top-down camera following owned tank
    WOBTankVisualSmoothing         — smooth visual interpolation for network tanks
    WOBTankWorldHealthBars         — world-space HP/reload bars above tanks
    WOBWalletOverlay               — Bolts/Crystals wallet display
    WorldHealthBars/               — HP bar subsystem (factory, anchor, record, scanner)

docs/
  GDD.md                 — Game Design Document (primary reference)
  GDD_PARITY_AUDIT.md    — Unity vs Roblox parity matrix (historical)
  GAME_DIRECTION_ROADMAP.md — high-level direction notes
```

---

## Game modes

### Training
Solo player vs `DummyTank` (or a bot). Good for testing controls, ricochet rules, and armor angles. Default mode when only one player is present.

### Duel (PvP)
Two players, separate possession, separate cameras, separate HP and stats. Series of rounds, first to 3 wins. The core competitive mode.

### BattleArena
Multiplayer arena with bots. Bots spawn based on player count. Multiple players fight simultaneously. Foundation for the future survival/roguelite direction.

### Lobby
Players idle between matches. Duel pads let players join a duel session.

---

## Controls

| Action | PC |
|---|---|
| Move forward/backward | W / S |
| Steer body | A / D |
| Aim turret | Mouse |
| Shoot | Left Mouse Button |
| Next round / restart | R |

Mobile: left virtual joystick (move), right virtual joystick (aim), fire button.

---

## Key configs

All tuning lives in `src/ReplicatedStorage/Shared/Configs/`:

| File | What it controls |
|---|---|
| `WeaponConfig.luau` | Cooldown, projectile type |
| `ProjectileCatalog.luau` | Speed, damage, penetration, max ricochets, bounce multipliers |
| `TankArmorConfig.luau` | FrontArmor, SideArmor, RearArmor, AutoRicochetAngleDegrees |
| `TankConfig.luau` | HP, movement speed, turn speed |
| `MatchConfig.luau` | TargetWins, RoundResetDelay, MatchResultDelay |
| `BotConfig.luau` | Bot enabled, difficulty profiles, arena bounds |
| `HudConfig.luau` | HUD behavior flags (CompactReload, TrainingCompactHud, etc.) |
| `VfxConfig.luau` | All VFX parameters (visual only) |
| `AudioCatalog.luau` | Sound ID assignments per event |
| `CameraConfig.luau` | Camera height, FOV, follow behavior |
| `MobileControlsConfig.luau` | Mobile control layout |

---

## Current status (v0.3)

### Done
- Core combat: movement, aiming, shooting, ricochets, armor penetration, self-hit
- Match flow: series to 3 wins, round reset delay, match result
- HUD: HP bars, reload bars, score, round result, match result
- World-space HP/reload bars on all tanks (Attachment anchor, camera-space offset)
- Combat feedback: DAMAGE / NO PEN / RICOCHET labels, impact flash, damage flash
- VFX: muzzle flash, smoke, impact sparks, ricochet sparks, tank explosion, burning tank
- Audio controller wired up (2/10 SoundIds filled: shot, ricochet)
- Bots: BotBrain v0 with Easy/Normal difficulty, line-of-sight, anti-stuck
- BattleArena with bots
- Economy: Bolts and Crystals currencies, kill/match rewards
- Basic skins and cosmetics system
- Mobile controls
- Lobby with duel pads
- Persistent player stats (DataStore)

### Still needed (Phase B)
- **Audio**: 8/10 `AudioCatalog` entries have `SoundId = ""` — add asset IDs for hit, no-pen, explosion, win/lose, etc.
- **VFX templates**: `DamageHitTemplate`, `NoPenTemplate`, `SelfHitTemplate` `.rbxm` files missing — system uses procedural fallback
- **Main menu**: game boots directly to arena, no mode selection screen
- **Match result screen**: round result works, full match-end screen incomplete

---

## Design references

- [GDD](docs/GDD.md) — full game design document, architecture rules, phase roadmap
- [Game Direction Roadmap](docs/GAME_DIRECTION_ROADMAP.md) — high-level direction and mode priorities
- [GDD Parity Audit](docs/GDD_PARITY_AUDIT.md) — historical Unity vs Roblox parity matrix
