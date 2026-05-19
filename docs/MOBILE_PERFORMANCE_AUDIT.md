# Mobile Performance Audit

Goal: keep the published phone loop stable while identifying likely hotspots. No aggressive scene optimization was made in this pass.

## Suspected Bottlenecks

| Area | Risk | Notes |
| --- | --- | --- |
| Transparent/Neon visuals | Medium | Aim laser, projectile readability, hit flash, and VFX can stack on mobile. |
| Particle/fire/smoke templates | Medium | Store VFX templates must not contain scripts, click detectors, or looping sounds. |
| BillboardGui world bars | Medium | HP/reload bars should keep `MaxDistance` reasonable and avoid duplicate anchors. |
| Highlight hit flash | Low/Medium | Short lifetime is okay; avoid output spam and duplicate highlights. |
| `GetDescendants` discovery scans | Medium | Keep discovery intervals throttled; avoid per-frame full-tree scans. |
| Runtime folder duplication | Low/Medium | Duplicate local visual folders can leave extra transient objects. |

## Safe Changes Made

- Client visuals now use `Workspace.WOB_Runtime.Client.Visuals`.
- Health anchors remain under `Workspace.WOB_Runtime.Client.HealthBarAnchors`.
- Fire sound source was sanitized to remove scripts/sounds from `TankBurningTemplate`.
- Dangerous scene/VFX/UI patch scripts are disabled by default.
- New audit commands report folder and fire-sound state without mutating.

## Risky Changes Requiring Visual Review

- Reducing VFX particle counts globally.
- Disabling shadows across arena geometry.
- Changing material/Neon/Transparency on tuned scene objects.
- Moving projectile runtime folders.
- Changing camera or mobile controls.

## Phone Test Checklist

1. Play Training on mobile.
2. Drive and shoot for 60 seconds.
3. Confirm HP/reload world bars stay readable.
4. Confirm no output spam.
5. Kill a tank and listen for any looping fire/campfire sound.
6. Confirm projectile trails and impact VFX still disappear through Debris cleanup.
7. Confirm no new `Workspace` root folders appear besides expected WOB folders.
