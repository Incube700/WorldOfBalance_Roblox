# Lobby Onboarding v0.2

Use `docs/patches/CREATE_PLAYTEST_V02_LOBBY_GUIDANCE_COMMAND.lua` only after a scene backup and only outside Play Mode.

The command is disabled by default with `ENABLE_MUTATION = false`. When enabled manually, it creates or updates a small `Lobby.PlaytestV02Guidance` folder with four non-blocking signs:

- `DUEL`: `1v1 Ricochet Duel`
- `ARENA`: `Fight bots, earn bolts`
- `ARMOR`: `Angle your tank to bounce shots`
- `LOBBY`: `Drive into a pad to play`

Safety rules:

- It does not delete old objects.
- It does not move ArenaPad, DuelPad, TrainingPad, spawn points, templates, UI, or VFX.
- It creates only guidance sign parts and BillboardGui labels.
- Review positions in Studio before saving.
