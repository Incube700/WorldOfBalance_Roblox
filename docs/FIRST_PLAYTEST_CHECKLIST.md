# First Playtest Checklist

## Master Polish Setup

- Confirm `default.project.json` still has `$ignoreUnknownInstances = true` under `ReplicatedStorage.Shared.Assets.VFX`.
- Run `docs/patches/MUTE_BURNING_VFX_SOUNDS_COMMAND.lua` outside Play Mode if `TankBurningTemplate` exists.
- Run `docs/patches/CREATE_OR_REPAIR_TANK_HEALTH_BILLBOARD_TEMPLATE_COMMAND.lua` outside Play Mode.
- Run `docs/patches/CREATE_OR_REPAIR_LOBBY_SHOWCASES_COMMAND.lua` outside Play Mode.
- Run `docs/patches/CREATE_OR_REPAIR_LOBBY_GUIDANCE_COMMAND.lua` outside Play Mode.
- Confirm `ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard` exists and `default.project.json` keeps `ReplicatedStorage.Shared.Assets.UI` protected with `$ignoreUnknownInstances = true`.
- Confirm `TankHealthBillboard` has a green HP bar and a thin blue reload bar under it.
- Confirm lobby signs are readable: `BATTLE ARENA`, `DUEL`, `TRAINING`, Crystals tip, and coming soon showcases.
- Confirm showcases are visible but do not block ArenaPad, DuelPad, TrainingPad, spawn points, or the main driving route.
- Confirm no Robux/IAP/purchase prompt was added.
- Save the scene with `File -> Save to File`.

## Battle Arena v0.1 Setup

- If `Workspace.WOB_Generated.BattleArena` is missing, run `docs/patches/CREATE_OR_REPAIR_BATTLE_ARENA_COMMAND.lua` outside Play Mode. If the arena was manually moved already, start with the audit/repair steps below instead.
- Run `docs/patches/AUDIT_SCENE_SPACE_OVERLAPS_COMMAND.lua` outside Play Mode and confirm `Lobby/BattleArena overlap XZ = false`.
- If overlap is true, run `docs/patches/MOVE_BATTLE_ARENA_TO_SAFE_ZONE_COMMAND.lua`.
- Run `docs/patches/AUDIT_BATTLE_ARENA_COLLISION_COMMAND.lua` outside Play Mode.
- If there are collision warnings, run `docs/patches/REPAIR_BATTLE_ARENA_COLLISION_COMMAND.lua`, then audit again.
- Run `docs/patches/CLEAN_VFX_TEMPLATES_COMMAND.lua` outside Play Mode if any template/runtime VFX script errors appear.
- Run `docs/patches/REPAIR_ALL_LOBBY_PADS_COMMAND.lua` outside Play Mode.
- Run `docs/patches/AUDIT_LOBBY_PADS_COMMAND.lua` and confirm ArenaPad/DuelPad/TrainingPad warnings are resolved.
- Save the scene with `File -> Save to File`.
- Confirm `Workspace.WOB_Generated.Lobby.ArenaPad` exists and has `WOBPadType = "BattleArena"`, `RequiredPlayers = 1`.
- Confirm `ArenaPad.Trigger` is aligned with the visible pad, `CanTouch = true`, `CanQuery = true`, and `WOBPadTrigger = true`.
- Confirm `ArenaPad.Label` shows `BATTLE ARENA` and `Drive here`.
- Confirm `Workspace.WOB_Generated.BattleArena.SpawnPoints` has `ArenaSpawn1` through `ArenaSpawn8`.
- Confirm BattleArena boundaries, cover, and ricochet walls have `WOBMovementObstacle = true`; ricochet walls also have `WOBRicochetSurface = true`.

## 1-Player

- Spawn in lobby.
- DuelPad is still visible.
- ArenaPad is visible and visually distinct.
- Drive onto ArenaPad.
- Player mode becomes `InBattleArena`.
- Tank spawns at one of 8 arena spawns.
- Tank can drive and shoot in BattleArena.
- If `BotConfig.Enabled` and `BotConfig.BattleArena.Enabled` are true, one `ArenaBot_*` tank spawns for solo BattleArena.
- Bot tank moves, turns, aims, and shoots without taking over the player camera.
- Player shots can damage/no-pen/ricochet against bot armor.
- Bot shots can damage the player.
- Killing the bot gives existing BattleArena kill/score credit if attribution resolves through `ArenaCombatService`.
- Bot respawns after `BotConfig.BattleArena.RespawnDelay`.
- Desktop Arena HUD shows `Arena Score`, `Kills`, `Deaths`, `Streak`, and compact upgrades; tank HP/reload is readable above the active tank.
- Mobile Arena HUD shows compact score/status, a small `Menu`, and tank HP/reload above the active tank without crowding controls.
- Mobile `Menu` opens `Resume` and `Return to Lobby`; `Resume` closes the popup.
- Tank can cross the center area unless it is visibly blocked by cover/ricochet walls.
- Self-hit or forced death switches to `ArenaRespawning`.
- Controls are disabled while destroyed.
- Death overlay shows `Destroyed`, `Respawn in N...`, and `Return to Lobby`.
- Tank respawns after `BattleArenaConfig.RespawnDelay`.
- Return to Lobby returns to lobby spawn and resets arena score/upgrades.
- Return to Lobby deactivates/hides BattleArena bots when no players remain in the arena.
- DuelPad and Training still work after returning.

## Combat Readability Check

- Player tank has one world HP bar.
- DummyTank or enemy tank has one world HP bar.
- Each world bar has a green HP fill and a blue reload fill.
- Lobby and BattleArena do not show stale modular `Player HP`, `Enemy HP`, or `Reload` panels behind the active UI.
- Shooting `DummyTank` lowers the world HP bar.
- Shooting resets the blue reload fill, then it fills left-to-right until the next shot is ready.
- Successful damage flashes the damaged tank white-yellow.
- Ricochet/no-damage hits do not trigger damage flash.
- Lethal hit sets the bar to zero, flashes, then the bar hides after a short grace delay.
- Round reset creates fresh bars without duplicate old BillboardGui clones.
- BattleArena respawn replaces stale bars/highlights cleanly.
- BattleArena/mobile hides large top HP and Reload panels while score/result HUD remains usable.
- Desktop Training/Duel should hide legacy top HP/reload panels when world HP/reload bars are enabled.

## Crystals Reward Check

- Start a real Duel with 2 players.
- Win the final match, not only a round.
- Winner sees `+1 Crystal` during MatchEnd/result flow.
- Winner player attributes update: `Crystals`, `PersistentCrystals`, `UnsavedCrystals`, and `LastCrystalsRewardAmount`.
- Output includes `[REWARD] Duel win crystal +1 player=... total=...`.
- Loser receives no Crystal.
- Training victory receives no Crystal.
- BattleArena kill receives no Crystal.
- Leave/rejoin in a published server where DataStore is enabled and confirm Crystals persist.
- In Studio with DataStore unavailable, the game should warn gracefully and session Crystals should still display.

## 2-Player

- Both players can enter BattleArena independently.
- Both players can drive and shoot in the arena.
- A player kill gives killer `ArenaScore +1`, `ArenaKills +1`, and `ArenaXP +100`.
- Survival ticks add small `ArenaXP` while the player remains alive in BattleArena.
- Victim gets `ArenaDeaths +1` and respawns after delay.
- Self-hit death gives no kill score.
- `ArenaXP` reaches level thresholds: level 2 at 100, level 3 at 250, level 4 at 450, level 5 at 700.
- Level-up shows a 3-choice temporary upgrade offer; selecting one applies it server-side.
- Death resets current-run `ArenaXP`, `ArenaLevel`, temporary upgrades, temporary modifiers, and streak.
- Death keeps `ArenaScore`, kills/deaths, and already granted currencies.
- Optional POIs are safe when present:
  - `BattleArena.ControlZone` grants Control Zone XP ticks.
  - `BattleArena.Medkits` heals damaged arena participants and respawns pickups.
  - `BattleArena.SupplyCrates` grants crate XP, opens the same 3-choice upgrade flow, and respawns crates.
- DoubleShot/TripleSpread projectiles still damage the correct victim.
- Leaving arena resets upgrades.
- Duel mode remains separate: DuelPad queue/countdown, round end, match result, rematch, and return still work.

## BaseTankTemplate Lobby Checks

- In Play Mode, lobby does **not** show extra large visible tanks named `Startup_Player`, `Startup_Dummy`, or `Startup_Player2`.
- `PlayerTank_<UserId>` is visible and moves when the player drives.
- Select `PlayerTank_<UserId>` in Explorer → Attributes → `TemplateSourceName = "BaseTankTemplate"` (or legacy name if BaseTankTemplate is absent).
- `ArenaBot_*` uses `BaseTankTemplate` when present; verify `TemplateSourceName` attribute.
- Run `docs/patches/AUDIT_TANK_TEMPLATE_RIG_COMMAND.lua` in Play Mode and confirm no warnings about visible startup tanks or missing CanQuery parts.

## Projectile Collision Checklist

- Projectile server simulation uses swept raycast from previous position to next position.
- Active tank armor hitboxes have `CanQuery=true`.
- Front/side/rear armor zones are visible and readable.
- Enemy tank hitboxes are included in projectile raycast targets.
- Owner tank is ignored only before ricochet/self-hit is allowed.
- Direct front hit resolves to `NoPen` or penetration, not silent pass-through.
- Angled hit resolves to armor ricochet when threshold is met.
- Wall ricochet still works after the collision service split.
- If shells pass through: enable `DebugCombatConfig.ProjectileDebug = true` and check Output for `[PROJECTILE COLLISION]` and `[PROJECTILE HIT]` logs. Verify `participant.Hitboxes` resolves to `ArmorZones` (not `nil` or a stale `Hitboxes` folder).

## BaseTankTemplate Workflow Checklist

- If `BaseTankTemplate` exists in `Workspace.WOB_Generated.TestObjects`, TankFactory uses it for all roles (Player, Dummy, DuelOpponent, Bot, ArenaBot, ArenaPlayer, and the 3 startup static participants).
- If `BaseTankTemplate` does not exist, legacy prototypes (`PlayerTankPrototype` / `Player2TankPrototype` / `DummyTank`) are used as fallbacks — this is the expected state before the Studio workflow is run.
- Tank spawns correctly with either template source.
- Armor zones are visible with correct front/side/rear colors after spawn.
- Projectile raycasts register hits on armor zones.
- `Visuals` folder parts (if present) have `CanQuery=false` and do not block raycasts.
- Bot v0.1 still works regardless of which template source is active.
- Duel, BattleArena, and Training still function.
- No extra `Assets` / `UI` / `VFX` runtime folders created by template changes.

### Verifying the active template source

1. Enter Play Mode.
2. Run `docs/patches/AUDIT_TANK_TEMPLATE_RIG_COMMAND.lua` in the Studio Command Bar.
3. Each model in `TestObjects` reports `TemplateSourceName`.
   - `BaseTankTemplate` → editable template active ✓
   - `PlayerTankPrototype` (or other legacy name) → legacy fallback active
   - `reused` → factory returned an already-registered model (expected for dynamic player tanks on reconnect)
4. Alternatively: select any runtime tank model in Explorer → Properties → Attributes → check `TemplateSourceName` and `TemplateSourcePath`.

## Regression Checks

- Tank spawn path uses `TankFactory`: lobby player tanks, Training dummy, and Duel-compatible participants spawn/register without direct prototype clone warnings.
- BattleArena bots spawn through `TankFactory` as `ArenaBot` participants; no bot appears in Duel or Lobby free drive.
- Lobby shooting remains no-damage.
- TrainingPad/StartPad starts Training and logs `[TRAINING PAD] player entered ...`.
- Main Menu Play still starts quick Training.
- DuelPad still queues Duel and does not start Training/BattleArena.
- ArenaPad still starts BattleArena and does not start Training/Duel.
- Arena death never shows Match Result.
- Arena death never calls `RoundMatchService.endRound`.
- Duel death still ends only the duel round.
- Duel tanks spawn facing each other.
- Training player spawns facing DummyTank.
- BattleArena spawn/respawn orientation remains unchanged.
- Mobile `MOVE`, `AIM`, and `FIRE` controls appear in Lobby, QueuedForDuel, InMatch, and InBattleArena.
- Mobile right `AIM` stick rotates the turret/aim laser, and `FIRE` shoots in that direction.
- Mobile left `MOVE` and right `AIM` can be used simultaneously.
- Mobile BattleArena HUD is compact: world HP/reload bar on the tank, score/K-D/Crystals/Bolts fit across the top, Return to Lobby behind Menu, center mostly free.
- Mobile Duel/Training match stats fit screen width.
- Mobile Duel score panel is readable: round, score, and first-to target are visible without legacy HP/reload panels.
- Mobile BattleArena Menu popup Return works and Resume closes the popup.
- Mobile controls hide/disable during ArenaRespawning.
- Wallet HUD shows Bolts and Crystals in lobby/result, and does not crowd BattleArena combat HUD.
- Rotating turret/barrel does not move the world HP/reload bar around the tank.
- Armor zones are visible, welded to the body/hull, and do not drift behind the body.
- Armor hitboxes still resolve front `NoPen`, angled ricochet, and side/rear penetration.
- BattleArena bots still move, shoot, die, and respawn after armor hitbox setup.
- No VFX/UI/Rojo source-of-truth changes are required for this pass.
- No constant fire/campfire loop after death VFX.
- Shot audio still plays.
- Output has no red errors.
- If the tank gets stuck, set `BattleArenaConfig.DebugCollision = true` and check `[MOVE BLOCKED]` obstacle path.

## Mobile Performance Checklist

- Join from the published link on a real phone.
- Lobby FPS feels stable while driving near pads/showcases.
- BattleArena FPS feels stable while driving, shooting, and respawning.
- Shooting does not stutter badly.
- HP/reload world bars remain visible without covering the fight.
- No constant fire/campfire loop after death VFX.
- Studio Output has no repeated debug spam.
- No new orphan folders appear in Workspace or ReplicatedStorage.
- Respawn/reset does not create duplicate HP bars.
- Old HUD garbage does not appear over mobile combat HUD.
