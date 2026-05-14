# Pad Contact Zone Contract

Дата: 2026-05-14.

## Цель

Все lobby pads должны иметь одинаковый contract: видимый pad можно двигать в Studio, а невидимая contact zone остается синхронизированной с ним. Сервер не полагается только на `Touched`; gameplay detection идет через polling/bounds check по trigger part.

## Structure

Каждый pad живет под:

```text
Workspace.WOB_Generated.Lobby.<PadName>
```

Root object может быть `Part`, `Model` или `Folder`, но должен иметь attributes:

- `WOBPadType = "BattleArena" | "Duel" | "Training"`
- `RequiredPlayers = number`
- `WOBPadEnabled = true`

Внутри root:

```text
<PadName>
  Trigger: Part
  Visual: Folder/Model/Parts
  Label: BillboardGui
```

## Trigger

`Trigger` это единственный authoritative contact object for server polling.

Attributes:

- `WOBPadType`: same as root.
- `RequiredPlayers`: same as root.
- `WOBPadEnabled = true`
- `WOBPadTrigger = true`

Properties:

- `Anchored = true`
- `CanCollide = false`
- `CanTouch = true`
- `CanQuery = true`
- `Transparency = 1`, unless debug visibility is intentionally enabled.
- Size must cover the tank body center comfortably, e.g. `Vector3.new(12, 4, 12)` or larger for wide pads.

## Visual

Visual parts are presentation only:

- They do not have to be triggers.
- They may be a root `Part`, child `Visual` folder/model, frame parts, or decorative parts.
- If a visual is moved manually, repair scripts must align `Trigger` to the visual/root position, not move the visual back to a default.

## Label

Each pad should have a simple `BillboardGui` above the pad:

- `AlwaysOnTop = true`
- `MaxDistance` large enough for lobby readability.
- Text examples:
  - ArenaPad: `BATTLE ARENA` and `Drive here`
  - DuelPad: `DUEL` and the live counter such as `0/2`
  - TrainingPad/StartPad: `TRAINING`

The DuelPad label must not break the existing live queue/counter. The live counter should remain in a `TextLabel` named `StatusText` or `DuelPadStatusText`.

## Server Detection

`LobbyService` polls pads on a short interval:

1. Resolve pad root by name or `WOBPadType`.
2. Resolve `Trigger` by direct child name or `WOBPadTrigger = true`.
3. Fallback to root if it is a `BasePart` for older scenes.
4. Check the owned tank body/focus position inside trigger bounds.
5. Run mode-specific action:
   - `BattleArena`: eligible lobby/queued player enters arena immediately.
   - `Duel`: eligible players join/cancel duel queue.
   - `Training`: eligible player starts training if a training/start pad exists.

## Acceptance

- Moving a pad visual in Studio, then running `REPAIR_ALL_LOBBY_PADS_COMMAND.lua`, preserves the visual/root position and moves the trigger/label to it.
- `AUDIT_LOBBY_PADS_COMMAND.lua` reports root, trigger, visual distance, attributes, query/touch flags, and label text.
- ArenaPad, DuelPad, TrainingPad/StartPad use the same trigger/bounds polling pattern.
