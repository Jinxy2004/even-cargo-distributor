# Cargo Distribution 1.0.0

Unload a set percentage of the cargo each vehicle carries when it arrives at a stop,
instead of unloading everything. Example: a train arrives at the first town with 100
meat; with 50% set there, it unloads 50 and carries the other 50 on to the next town.

By bobbyhill1239. MIT licensed (see LICENSE).

## How to use

1. Open the line manager, pick a line and click a stop to open its stop window
   (the one with Load and Departure Configuration).
2. At the bottom, in the **Unload** card, tick **Custom unloading at this stop**.
3. Set **All cargo** to the share to unload. It applies to the cargo each vehicle
   carries *when it arrives*, rounded half up (25 at 50% unloads 13).
4. To give one cargo its own level, click **+**, set the **Unload Level**, then click
   the cargo's icon. Its icon then shows its level; click it to change it, or use the
   bin to remove it. 0% keeps that cargo aboard.

Untick the box to return the stop to normal. Other stops and lines are unaffected.

## Behaviour

- Vehicles don't pick up cargo at a stop with custom unloading while it is in use.
- Cargo the station or warehouse can't accept stays aboard; cargo is never destroyed.
- Rules belong to the station. Adding, removing or reordering other stops keeps them.
  Removing the station from the line removes its rule.
- While a vehicle unloads, the mod temporarily changes that stop's load settings and
  puts them back when the vehicle leaves. If you change the stop yourself meanwhile,
  your change is kept.
- Passenger vehicles are skipped.

## Known limitation

The game has one unload setting per stop, shared by every vehicle there. If two
vehicles on the same line are unloading at the same stop *at the same time*, both
follow the most recent arrival's amount. Vehicles that unload one after another are
not affected.

## Switching it off

Untick custom unloading on each stop, let vehicles finish, then remove the mod. To stop
everything at once, run this in the debug console and let the game run a moment:

```lua
api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd(
  "cargo_distribution_console", "cargo_distribution_1",
  "CargoDistributionControl", {action="disable"}))
```

(`{action="enable"}` turns it back on.)
