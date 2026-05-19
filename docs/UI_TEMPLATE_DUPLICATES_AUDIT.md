# UI Template Duplicates Audit

Date: 2026-05-20

## Finding

`src/ReplicatedStorage/Shared/Assets/UI` contained three competing `TankHealthBillboard` sources:

| Source | Risk | Action |
| --- | --- | --- |
| `TankHealthBillboard.rbxm` | Correct disk stem and internal source name. | Kept as canonical source. |
| `TankHealthBillboard.rbxmx` | XML root `BillboardGui` was named `Health`, not `TankHealthBillboard`. | Archived. |
| `TankHealthBillboard.rbxmx.rbxm` | Rojo can create an instance named `TankHealthBillboard.rbxmx`. | Archived. |

## Canonical Source

Use this source for the current build:

```text
src/ReplicatedStorage/Shared/Assets/UI/TankHealthBillboard.rbxm
```

Expected Studio path:

```text
ReplicatedStorage.Shared.Assets.UI.TankHealthBillboard
```

Expected `Instance.Name`:

```text
TankHealthBillboard
```

## Archive

Archived duplicate sources:

```text
docs/archive/ui-template-duplicates/2026-05-20/TankHealthBillboard.bad-internal-name-Health.rbxmx
docs/archive/ui-template-duplicates/2026-05-20/TankHealthBillboard.bad-file-stem-rbxmx.rbxm
```

These were not destroyed. They can be inspected or restored manually if a visual regression is found.

## Rule

Do not keep both a `.rbxm` and `.rbxmx` source with the same Rojo instance name in the same folder. Do not keep files with double stems like `.rbxmx.rbxm`.
