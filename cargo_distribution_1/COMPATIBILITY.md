# Compatibility

- Transport Fever 3, Windows. Developed and tested on build 40408. Other platforms
  have not been tested.
- Script mod only: no models, textures, game files or executables are replaced.
- Adds a section to the stop window through the game's documented interface
  replacement hook. Another mod that replaces the same stop-window popover content
  could conflict; whichever loads last wins.
- While a vehicle unloads at a managed stop, the mod temporarily changes that stop's
  load settings and restores them afterwards. Mods that rewrite the same line stops at
  the same moment may conflict.
- Passenger vehicles are never managed.
- Safe to add to an existing save. Before removing it from a save, untick custom
  unloading on each stop (or use the disable command in README.md) and let vehicles
  finish unloading, so every stop has its normal settings back.
