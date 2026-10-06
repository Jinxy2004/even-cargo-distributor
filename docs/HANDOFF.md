# Development notes

State at 1.0.0 (2026-10-05). Game build 40408, Windows. Read this before changing the mod.

## Status

- All native in-game tests passed on the 0.1.4 engine logic: single-vehicle full trip,
  mixed cargo with filter, no pickup, save/reload mid-unload, per-cargo overrides,
  boundary amounts (0/1/3). See `test-reports/`.
- Accepted limitation: concurrent unloading at one stop shares a target
  (`test-reports/CONCURRENT.md`). User decided to document it, not work around it.
- Deferred by user: full/incompatible-warehouse test; trucks/ships/planes tested
  informally in normal play.
- 0.2.0 added the stop-window Unload card; the user verified it in game, including
  the icon UI and the all-cargo picker. 1.0.0 is the cleanup/release of that code.
- Publishing is done by the user from the in-game mod manager (see `MODIO.md`).

## How it works

- `core.lua`: pure Lua. Quota `floor(arrival * pct / 100 + 0.5)`; snapshot per cargo
  with `target = retained / allCaps` (compatible capacity across all configs, not the
  currently configured compartments — dividing by configured capacity retained all cargo).
  Station keys `"<stationGroup>#<visit>"` so rules follow the station.
- `runtime.script.lua` (game script `cargo_distribution.gs`):
  - `OnArriveAtStop` → snapshot cargo aboard, save as pending. No commands in events
    (nested transaction crash).
  - `postUpdate` (serial) → write the stop's load config: `load=true`, `maxLoad=target`
    for retained cargo, everything else 0; LOAD_IF_AVAILABLE; destroy flags off.
    Parallel `update` must never write state (it overwrote newer event counters) and
    may not use callbacks.
  - Departure → evaluate, restore the original stop config once no other tracked
    vehicle is at that station. If the player edited the stop meanwhile, keep their edit.
  - Rules are in saved state `rules[line][stationKey]`, set by the GUI through the
    script event `CargoDistributionControl {action="setRule", line, stopIndex, stationGroup, rule}`.
    Also `disable` / `enable`.
- `unload_gui.*`: the stop window (`gui/line_vehicle_mgmt/cargofilter_window.tl`) has no
  extension point. The mod uses the documented `react-replacement-config` hook to
  replace `popover_react_util.PopoverWindowContent`, and only when its recipe is named
  `CargoFilterContent` adds the card below the stock content. Native rule: any recipe
  placed in a layout must return a builtin layout ("Recipe child must be a layout").
  The game's styles are scoped to `R::CargoFilterContent`, so `unload_gui.css.lua`
  restyles the card under `R::CargoDistributionUnloadCard`.
  Gamepad: `CargoFilterContent` registers its own up/down focus traversal without
  bubble-up, so a card placed beside it can't be reached with a controller. Re-registering
  those actions later in the same component has no effect in game (first one wins), so the
  card goes inside the stock scroll list instead: the mod replaces
  `entity_window_util.ContentWidgetScrollContainer` with a plain function (it runs
  synchronously inside the caller's body) that, only when
  `react.getCurrentRecipeName() == "CargoFilterContent"`, appends the card to the children.
  The stop params come from the popover replacement (one stop popover at a time).
  The GUI reads saved state via `gameScriptSystem.getEntityForGameScript(".../cargo_distribution.gs")`.

## Gotchas

- `.script.lua` resources must define `function data()` returning the table.
- Renaming the `.gs.lua` file starts a fresh saved state (rules are lost for saves that
  used the old name). 1.0.0 renamed `probe.gs` → `cargo_distribution.gs`.
- Collect `crash_dump/stdout.txt` before restarting the game; it is replaced.
- With several copies of the mod installed, the game picks the `staging_area` one over
  `mods` (stdout: "Multiple (3) mods with same id found ... has been selected"). Update
  the copy it selects when testing. Don't mirror-install over staging: it holds
  `_metadata/mod.io_fileid.txt`, which the install script's mirror step would delete.
- Installed API definitions (`api/tealdef`, `base/content/gui.zip`) are the reference;
  online docs may differ.
