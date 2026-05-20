# Folder Hygiene Audit

Date: 2026-05-20

## Contract

| Purpose | Correct path |
| --- | --- |
| Final UI templates | `ReplicatedStorage.Shared.Assets.UI` |
| Final VFX templates | `ReplicatedStorage.Shared.Assets.VFX` |
| Runtime VFX | `Workspace.WOB_Runtime.VFX` |
| Client health anchors | `Workspace.WOB_Runtime.Client.HealthBarAnchors` |
| Client local visuals | `Workspace.WOB_Runtime.Client.Visuals` |
| Editor backups | `Workspace.WOB_EditorOnly_AssetDonors` |
| Orphan backups | `Workspace.WOB_EditorOnly_AssetDonors.OrphanBackups` |

## Audit Table

| File | Folder/path created | Current behavior | Correct path | Action | Safe |
| --- | --- | --- | --- | --- | --- |
| `default.project.json` | `ReplicatedStorage.Shared.Assets.UI/VFX` | Correct mapping with `$ignoreUnknownInstances`. | Same. | No change. | Yes |
| `WOBGameplayServer.server.luau` | `Workspace.WOB_Runtime.VFX` | Runtime VFX folder is correct. Projectiles still use existing `WOB_Generated.Runtime.Projectiles`. | Keep VFX in `WOB_Runtime.VFX`. | No projectile move in this pass. | Yes |
| `WOBTankWorldHealthBars.client.luau` | `Workspace.WOB_Runtime.Client.HealthBarAnchors` | Correct and clears stale anchors at client start. | Same. | No change. | Yes |
| `WOBTankDamageFlash.client.luau` | `Workspace.WOB_Runtime.Client.Visuals.DamageFlash` | Moved from direct `Client.DamageFlash` to `Client.Visuals.DamageFlash`. | Same. | Updated. | Yes |
| `WOBAimLaser.client.luau` | `Workspace.WOB_Runtime.Client.Visuals.AimLaser` | Previously used `Client.LocalVisuals`. | `Client.Visuals`. | Updated. | Yes |
| `WOBCombatFeedbackOverlay.client.luau` | `Workspace.WOB_Runtime.Client.Visuals.CombatFeedback` | Previously used `Client.LocalVisuals`. | `Client.Visuals`. | Updated. | Yes |
| `WOBImpactFeedbackOverlay.client.luau` | `Workspace.WOB_Runtime.Client.Visuals.ImpactFeedback` | Previously used `Client.LocalVisuals`. | `Client.Visuals`. | Updated. | Yes |
| `WOBProjectileReadabilityOverlay.client.luau` | `Workspace.WOB_Runtime.Client.Visuals.ProjectileReadabilityGlows` | Previously used `Client.LocalVisuals`. | `Client.Visuals`. | Updated. | Yes |
| `docs/patches/*CREATE*`, `*REPAIR*`, `*MOVE*`, `*CLEAN*`, `*INSTALL*`, `*RECOVER*`, `*ORGANIZE*` | Scene/assets/runtime folders | Can mutate Studio scene or assets. | Manual only after audit. | Disabled by default with `ENABLE_MUTATION=false`. | Safer |

## Runtime Folder Service Candidate

Multiple scripts still create or resolve `Workspace.WOB_Runtime` directly. A future low-risk cleanup can add:

- `src/ServerScriptService/Server/Gameplay/Runtime/ServerRuntimeFolders.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client/Runtime/ClientRuntimeFolders.luau`

Do not do this in the same pass as gameplay/session changes. Touching all visual scripts at once is broad even if behavior is simple.

## Known Legacy Paths To Audit

These should not be created by new code:

- `Workspace.WOB_ClientHealthBarAnchors`
- `Workspace.WOBLocalDamageFlash`
- `Workspace.WOB_LocalVisuals`
- `Workspace.WOB_Runtime.Client.LocalVisuals`
- `Workspace.WOB_Generated.Runtime.VFX`
- `ReplicatedStorage.Assets`
- `ReplicatedStorage.UI`
- `ReplicatedStorage.VFX`
- `ReplicatedStorage.UX`
- `Workspace.Assets`
- `Workspace.UI`
- `Workspace.VFX`
- `Workspace.UX`

Run `docs/patches/AUDIT_CURRENT_FOLDER_STRUCTURE_COMMAND.lua` in Studio to inspect the live DataModel.
