# Project Folder Reconciliation

## Scope

This audit compares these two local folders:

- A: `/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox`
- B: `/Users/sergoburnheart/Documents/New project 2`

This is documentation/audit only. Do not copy scene files, do not replace A with B, do not apply B gameplay files wholesale, and do not change Git remotes from this reconciliation.

## Required Baseline Commands

Run from A before the audit:

```text
$ pwd
/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox

$ git status --short

$ git remote -v
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (fetch)
origin	https://github.com/Incube700/WorldOfBalance_Roblox.git (push)
```

`git status --short` printed no rows, so A started clean.

## Source Of Truth

A, `/Users/sergoburnheart/RobloxProjects/WorldOfBalanceRoblox`, is the real source of truth.

Reasons:

- A is the requested active workspace.
- A has the real Git remote: `https://github.com/Incube700/WorldOfBalance_Roblox.git`.
- A has real commit history on branch `main`.
- A contains current working gameplay, scene, HUD, match, combat feedback, and config-driven armor visual systems.
- A has the newer/larger `RicochetTanksPrototype.rbxl` scene file.

B, `/Users/sergoburnheart/Documents/New project 2`, is quarantine/old copy.

Reasons:

- B has no Git remote.
- B has no useful commit history; `git log --oneline -5` fails with `fatal: your current branch 'main' does not have any commits yet`.
- B's project files are all untracked in its local repository.
- B contains an experimental `WOBGameplayServer` with participant-like ideas, but it also removes or rolls back current systems from A.
- B's `RicochetTanksPrototype.rbxl` is older, smaller, and has a different hash. It must not be copied into A.

## Git State And Remotes

### A

- Branch: `main`
- Status: clean at audit start.
- Remote:
  - `origin https://github.com/Incube700/WorldOfBalance_Roblox.git (fetch)`
  - `origin https://github.com/Incube700/WorldOfBalance_Roblox.git (push)`
- Recent commits:
  - `a2f7c42 new scene`
  - `4ac9414 !`
  - `fddd1e4 hud`
  - `73bc49c Fix armor hitbox targeting and spawn placement`
  - `4856842 new gdd`

### B

- Branch: `main`
- Remote: none.
- Commit history: none.
- Status:

```text
?? .gitignore
?? RicochetTanksPrototype.rbxl
?? RicochetTanksPrototype_snapshot.rbxlx
?? default.project.json
?? docs/
?? src/
```

## default.project.json

`default.project.json` is identical in A and B.

- A SHA-256: `219b1865c7fd86e389fe83e2bcd83983af336fed0e9fe0fbc828adc161379475`
- B SHA-256: `219b1865c7fd86e389fe83e2bcd83983af336fed0e9fe0fbc828adc161379475`

No `default.project.json` changes are recommended.

## RicochetTanksPrototype.rbxl Metadata Only

Do not copy B's `.rbxl` into A.

| Folder | Size | Modified | SHA-256 |
| --- | ---: | --- | --- |
| A | 123139 bytes | May 7 22:10:38 2026 | `3d7ff82dd4867d2a526698c9cb190a792f4766a9c30a0e767d6ab9dc9a6b33bd` |
| B | 89270 bytes | May 6 09:58:41 2026 | `7582667963e53becaac87781828623c06820153871325c8d998470ae6328004c` |

The scene files differ. A is newer and is the scene source of truth.

## src/ Comparison

Summary: 9 `src/` files differ or exist only on one side.

### Files Only In A

- `src/ReplicatedStorage/Shared/Configs/MatchConfig.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBCombatFeedbackOverlay.client.luau`

These are current systems and must be preserved.

### Files Only In B

- `src/StarterPlayer/StarterPlayerScripts/Client/WOBRoundInputController.client.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBTankDirectionIndicator.client.luau`

These may be used only as reference. Do not copy them directly without checking compatibility with A's current HUD, remotes, and client script responsibilities.

### Files That Differ

- `src/ReplicatedStorage/Shared/Configs/ProjectileCatalog.luau`
  - B changes ricochet shell `Penetration` from A's `45` to `65`.
  - Treat as tuning reference only.
- `src/ReplicatedStorage/Shared/Configs/TankConfig.luau`
  - B increases armor hitbox padding/thickness, hides armor hitboxes, and lacks A's current armor hitbox transparency/material/color fields.
  - Do not copy B over A because it rolls back current config-driven armor visuals.
- `src/ServerScriptService/Server/Gameplay/WOBGameplayServer.server.luau`
  - B contains participant-style abstractions, but also removes current match/HUD/combat systems from A.
  - Do not apply wholesale.
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBAimLaser.client.luau`
  - A uses Beam/attachments and runtime muzzle lookup; B uses neon parts and a direction indicator-adjacent style.
  - Treat B's visual approach as reference only.
- `src/StarterPlayer/StarterPlayerScripts/Client/WOBRoundStatusOverlay.client.luau`
  - A supports the current modular HUD panels, enemy/player HP, reload bar, round result, series status, `TargetWins`, `RoundNumber`, `PlayerWins`, `DummyWins`, and current match result attributes.
  - B is older, more permissive around legacy HUD paths, and lacks A's current series attribute flow.

## docs/ Comparison

Summary: 5 `docs/` files differ or exist only on one side.

### Files Only In A

- `docs/patches/CLEAN_LEGACY_HUD_COMMAND.lua`
- `docs/patches/PRINT_VISIBLE_HUD_FRAMES_COMMAND.lua`

These are current helper/diagnostic docs for A and should remain in A.

### Files Only In B

None within `docs/`.

### Files That Differ

- `docs/CODEX_TASKS.md`
- `docs/RICOCHET_RULES.md`
- `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua`

Important differences:

- B's `CREATE_MODULAR_HUD_COMMAND.lua` is an older/narrower round-status setup and removes A's current enemy HP, weapon reload, player HP, and match series panel setup.
- B's `RICOCHET_RULES.md` adds direction indicators to the list of visual/readability objects, but removes A's note that wall ricochets are readable through motion/VFX/output and armor feedback is only on tank interactions.
- B's `CODEX_TASKS.md` differs from A and should not replace A's task context.

## Useful B Ideas As Reference

B's experimental `WOBGameplayServer` may be useful as a reference for a future small, deliberate refactor:

- `tankParticipants` registry.
- `tankParticipantsById` and `tankParticipantsByModel` lookup tables.
- `registerTankParticipant(...)`.
- Participant-based max health, health, death, and reset helpers.
- Participant-based damage helpers.
- Participant-based projectile owner metadata:
  - `OwnerTank`
  - `OwnerTankId`
  - `OwnerUserId`
  - `OwnerTeamId`
  - `OwnerIsBot`
  - `WeaponTypeId`
- Per-participant weapon state:
  - `LastShotTime`
  - `WeaponReadyAt`
- `getProjectileConfigForTank(participant)`.
- `TryShoot(participant, direction)`.
- Participant-aware projectile target filtering and armor hit resolution.

If these ideas are used, port them in small slices into A's current code while preserving current behavior and attributes.

## B Changes That Must NOT Be Copied

Do not copy B's `WOBGameplayServer.server.luau` wholesale.

It removes or rolls back current A systems, including:

- `MatchConfig`.
- Match series to `TargetWins`.
- Current round/match attributes such as `PlayerWins`, `DummyWins`, `RoundNumber`, `TargetWins`, `MatchEnded`, and current `MatchResult` values.
- `CombatFeedbackEvent` creation/use.
- `WOBCombatFeedbackOverlay` compatibility.
- Current HUD/match behavior.
- Current modular HUD expectations.
- Some current config-driven armor visual settings from `TankConfig`.

Do not copy B's `RicochetTanksPrototype.rbxl` into A.

Do not replace A's `docs/CODEX_TASKS.md`, `docs/patches/CREATE_MODULAR_HUD_COMMAND.lua`, or current HUD/match docs with B versions.

Do not treat B's projectile penetration or armor hitbox tuning as approved behavior. They are reference-only until separately designed and tested.

## Recommended Safe Next Steps

1. Keep A as the only active project folder.
2. Keep B as quarantine/reference only; do not rename or delete it automatically.
3. Add this reconciliation report to A and keep `docs/CODEX_TASKS.md` guardrails visible.
4. For any future TankParticipant work, create a new small task that ports only one concept at a time into A.
5. Before touching gameplay code, document the exact behavior that must remain unchanged:
   - one active `WOBGameplayServer`
   - match series first-to-`TargetWins`
   - current round/match attributes
   - player/enemy HP HUD
   - reload HUD
   - combat feedback overlay
   - config-driven armor hitbox visuals
6. After each small refactor slice, run Rojo build and Play Mode checks against A only.
7. Never use B's `.rbxl` or full `WOBGameplayServer` as a replacement for A.
