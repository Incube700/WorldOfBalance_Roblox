# Currency Reward Plan

## Goal

Bolts are the first soft currency for World of Balance: Ricochet Tanks. v0 is intentionally tiny:

```text
kill tank -> +1 Bolt -> player sees reward/total -> Bolts persist
```

There is no shop, Robux purchase, inventory, skin purchase, or paid boost in this version.

## Currency

- `CurrencyId = "Bolts"`
- `DisplayName = "Bolts"`
- persistent store: `WOBPlayerWalletV1`
- player key: `Player_<UserId>`
- data shape: `{ Bolts = number }`

## Rewards v0

- Training kill: `+1 Bolt`
- PvP kill: `+1 Bolt`
- Self-kill: `0 Bolts`
- Match win: `0 Bolts`

The reward is granted to the player who owns the projectile's `OwnerParticipant`. If a tank dies to its own projectile/ricochet, no Bolts are awarded.

## No Reward Cases

No Bolts are granted for:

- self-kills;
- lobby/no-damage projectiles;
- debug/no active match kills;
- kills after the round already ended;
- kills outside the active Training/PvP match;
- bot-owned kills, because the bot has no `OwnerPlayer`;
- duplicate processing of the same victim death.

## Server Authority

Currency is granted only by server code:

- client UI never requests currency;
- no RemoteEvent grants Bolts;
- `KillRewardService.awardTankKill` runs from the server death flow;
- `PlayerWalletService.addBolts` is server-only gameplay code.

The client reads player attributes to display the wallet.

## Persistence

`PlayerWalletService` uses `DataStoreService:GetDataStore("WOBPlayerWalletV1")`.

On load:

- wallet attributes start at safe fallback values;
- stored data is sanitized;
- negative/nonnumeric values become `0`;
- DataStore failure does not crash gameplay.

On reward:

- `SessionBoltsEarned` increments;
- `UnsavedBolts` increments;
- `PersistentBolts` is updated immediately as visible total;
- `LastBoltsRewardAmount` and `LastBoltsRewardReason` update for UI.

On save:

- `UpdateAsync` adds the unsaved delta;
- `UnsavedBolts` clears only after successful save;
- failed saves keep the unsaved delta for retry.

## Double Reward Prevention

`KillRewardService` stores a death key on the victim participant:

```text
<MatchId>:<RoundNumber>:<VictimTankId>
```

If the same death key is processed again, the reward service does nothing.

## UI v0

`WOBWalletOverlay.client.luau` is display-only:

- shows `Bolts: X`;
- briefly shows `+1 Bolt` when a reward attribute changes;
- `WOBAudioController.client.luau` can play `BoltReward` when a reward attribute changes;
- has no buttons;
- sends no remotes.

## Future Spending

Bolts can later be used for cosmetic unlocks such as:

- tank skins;
- projectile trails;
- kill effects;
- turret cosmetic skins;
- barrel cosmetic skins.

Future systems should save IDs, not whole models.

## Not Implemented Now

- shop;
- Robux;
- inventory;
- daily quests;
- paid boosts;
- skin ownership;
- purchase UI.

## Manual Test

1. Start Training.
2. Kill `DummyTank`.
3. Player gets `+1 Bolt`.
4. Wallet overlay shows reward and total.
5. Kill again next round.
6. Confirm one reward per death.
7. Self-kill gives `0 Bolts`.
8. Lobby/no-damage shooting gives `0 Bolts`.
9. PvP kill gives `+1 Bolt` to the killer.
10. DataStore failure should warn but not crash the game.
