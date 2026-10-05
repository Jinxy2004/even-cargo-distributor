# Changelog

## 1.0.0

First public release.

- Unload card at the bottom of the stop window (line manager -> stop): turn on
  custom unloading, set a level for all cargo, and give individual cargo types their
  own level through the cargo icons, like the game's Load card. 0% keeps a cargo aboard.
- Percentages apply to the cargo each vehicle carries on arrival, rounded half up.
- Vehicles don't pick up cargo at a stop with custom unloading; cargo the station
  can't accept stays aboard; cargo is never destroyed.
- Rules are saved with the game, belong to the station, and follow it when stops are
  added, removed or reordered. Removing the station from the line removes its rule.
- If you change a stop's Load settings while a vehicle is unloading there, your change
  is kept.
- Known limitation: two vehicles on the same line unloading at the same stop at the
  same time both follow the most recent arrival.

Development history (0.1.x prototypes, 0.2.0 interface work) and the in-game test
reports are kept in the source repository.
