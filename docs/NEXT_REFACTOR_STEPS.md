# Next Refactor Steps

This is a prioritized list for future safe work. Do not treat it as permission to add features inside an architecture pass.

## P0

- Verify current build in Studio and on phone.
- Commit the safe refactor once verified.
- Do not touch VFX/UI templates without source-of-truth review.
- Do not run repair/organize/clean/move scripts.

## P1

- Verify the real `TankFactory` spawn migration in Studio with 1-player, 2-player, and BattleArena tests.
- Verify BattleArena Bot v0.1 through `TankFactory`: solo arena bot spawn, movement, shooting, death, respawn, and cleanup on return to Lobby.
- Projectile radius collision if pass-through repeats after current swept raycast hardening.
- Armor tuning with `DebugCombatConfig.ArmorDebug=true` in Studio only.
- Split `RoundMatchService` into pure helpers in a dedicated pass:
  - `RoundScoreTracker`
  - `RoundSpawnPlanner`
  - `RoundResultResolver`
- Extract `ProjectileVfxDispatcher` after projectile behavior is stable.

## P2

- Bot v0.1 polish: difficulty, better aim noise, simple obstacle avoidance, and visible bot kill attribution if needed.
- Mode/session abstraction for Duel/BattleArena/Training.
- Upgrade rules by mode.
- Practice/Training pad polish.
- Runtime folder helper modules.
- Future `ServerStorage.TankTemplates.BaseTankTemplate` migration after template source-of-truth review.
- Mobile controls experiment later, not during stability passes.

## P3

- Third-person lobby/open arena camera.
- Extraction prototype:
  - leave lobby;
  - collect/fight;
  - death loses unbanked run loot;
  - extraction saves loot.

## Guardrails

- No `.rbxl` edits from code.
- No scene movement from refactor passes.
- No `default.project.json` changes unless source-of-truth requires it.
- No new `ReplicatedStorage.Assets/UI/VFX/UX`.
- No new `Workspace.Assets/UI/VFX/UX`.
- No new weapons/upgrades/camera/modes in refactor passes.
