# HUD Template Workflow

## Purpose

UI templates are the editable Studio source of truth for HUD layout. Runtime code may clone, bind, populate, and show them, but a valid template owns its own positions and sizes.

UI templates live under:

```text
src/ReplicatedStorage/Shared/Assets/UI/
```

The Battle Arena upgrade HUD template lives at:

```text
src/ReplicatedStorage/Shared/Assets/UI/BattleArena/BattleArenaUpgradeBeltTemplate.rbxmx
```

Runtime path:

```text
ReplicatedStorage.Shared.Assets.UI.BattleArena.BattleArenaUpgradeBeltTemplate
```

## Battle Arena Upgrade Template

Required hierarchy:

```text
BattleArenaUpgradeBeltTemplate : Frame
  DesktopLayout : Frame
    ActiveIcons : Frame
      Overflow : TextLabel
      Slot1 : TextLabel
      Slot2 : TextLabel
      Slot3 : TextLabel
      Slot4 : TextLabel
      Slot5 : TextLabel
    UpgradeChoiceBelt : Frame
      Choices : Frame
        Choice1 : Frame or TextButton
          Button : TextButton
          Icon : TextLabel
          Title : TextLabel
          Effect : TextLabel optional
        Choice2 : Frame or TextButton
          Button : TextButton
          Icon : TextLabel
          Title : TextLabel
          Effect : TextLabel optional
        Choice3 : Frame or TextButton
          Button : TextButton
          Icon : TextLabel
          Title : TextLabel
          Effect : TextLabel optional
        PaidReflectChoice : Frame or TextButton optional
          Button : TextButton optional
          Icon : TextLabel optional
          Title : TextLabel optional
          CostLabel : TextLabel optional
      Subtitle : TextLabel
      TitleLabel : TextLabel
  MobileLayout : Frame
    same child names as DesktopLayout
```

Each choice may use either a child `Button` TextButton or make the `Choice1` / `Choice2` / `Choice3` object itself a TextButton. If both exist, code binds the child `Button`.

`PaidReflectChoice` is a prepared fourth utility slot for a future paid Reflect Shield purchase. It is not part of the normal random level-up choice list, and stays hidden/disabled until a later pass adds purchase server logic.

## Ownership

Template-owned:

- `Position`, `Size`, and `AnchorPoint` for the template root and all template children.
- Internal layout for `DesktopLayout`, `MobileLayout`, `UpgradeChoiceBelt`, `Choices`, `Choice1` / `Choice2` / `Choice3`, optional `PaidReflectChoice`, `Icon`, `Title`, `Button`, `CostLabel`, `ActiveIcons`, `Slot1`-`Slot5`, and `Overflow`.
- Visual styling such as corners, strokes, colors, spacing, and text sizes for template children.

Code-owned:

- Cloning the template into the runtime ScreenGui.
- Finding required children by name.
- Connecting `Button.Activated`.
- Setting title, subtitle, icon, effect, and overflow text.
- Setting `Visible`, `Active`, and `UpgradeId` attributes.
- Selecting the active template layout by showing either `DesktopLayout` or `MobileLayout`.
- Calling `OnChoiceSelected(upgradeId)`.
- Falling back to scripted UI if the template is missing or invalid.

Rule: if a HUD template exists and binds successfully, client code must not overwrite `Position`, `Size`, or `AnchorPoint` of the template root or template children unless a dedicated task explicitly says so.

## Editing in Studio

1. Open the Rojo-served place in Roblox Studio.
2. In Explorer, navigate to `ReplicatedStorage > Shared > Assets > UI > BattleArena`.
3. Edit `BattleArenaUpgradeBeltTemplate` directly. Move or resize `UpgradeChoiceBelt`, `ActiveIcons`, choices, labels, and buttons under both `DesktopLayout` and `MobileLayout`.
4. Keep the required child names stable. Renaming a critical child can make the runtime fall back to scripted UI.
5. Save the edited template back to `src/ReplicatedStorage/Shared/Assets/UI/BattleArena/BattleArenaUpgradeBeltTemplate.rbxmx`.
6. Run a Rojo build and test Battle Arena.

Validation checklist:

- Moving `UpgradeChoiceBelt` in the template changes its in-game position.
- Upgrade buttons still call the existing upgrade choice flow.
- Active upgrade icons still show when no offer is visible.
- Missing or invalid critical template children warn once and use scripted fallback.
- Mobile controls, Training, and Duel behavior are unchanged.
