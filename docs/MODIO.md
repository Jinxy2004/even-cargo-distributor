# Publishing on mod.io

Transport Fever 3 publishes mods from the in-game mod manager: the mod folder goes in
the user-data `staging_area`, the game validates and cooks it, then uploads it to
mod.io under your account.

## Steps

1. `python tools/test.py` — all tests pass.
2. `python tools/build.py` — checks the release metadata (author, license, version,
   changelog, `verbose = false`, `_content.json`) and builds `dist/cargo_distribution-1.0.0.zip`.
3. Copy the mod to the staging area:
   `.\tools\install-local.ps1 -UserData 'C:\Users\Public\Documents\Steam\RUNE\3493540\local' -Staging`
4. Start the game -> Mod manager -> Staging area -> Cargo Distribution.
   Run **Validate**. Fix anything critical for PC; review warnings. Console-only
   findings can be noted (the mod is untested on console).
5. The cover image is `cargo_distribution_1/_metadata/0.png` (a copy of `media/logo.png`,
   1280x720); the publisher reports "No valid cover image found" without it. Add
   gallery screenshots (see below).
6. Fill in the listing from the text below, then **Publish**. Set it public when ready.
7. After publishing, subscribe from mod.io on a clean setup, start a fresh test save
   and repeat a quick 50% trip to confirm the published build works.

For updates: keep the mod ID, raise `version` in `config.lua`, `revision` in
`mod.json`, add a CHANGELOG entry, and add a saved-state migration in `core.migrate`
if the saved data changes.

## Screenshots

Gallery images go next to the cover as `_metadata/1.png`, `2.png`, ... (copies kept in
`media/`). Included: `1.png` = the stop window with the Unload card (All cargo 50%,
goods 50%, meat 25%).

Further ideas (in game, real results only):

2. A train at town one after unloading, showing about half its cargo still aboard.
3. The cargo picker (after clicking +).

## Listing

**Name:** Cargo Distribution

**Summary:** Split deliveries between stops: unload a set percentage of each vehicle's cargo at chosen stops, with per-cargo levels.

**Tags:** Script Mod

**Description:**

Split each delivery between the stops on a line instead of dropping everything at the first one.

**What it does**
- Adds an Unload card to the stop window (line manager → click a stop), below Load and Departure Configuration.
- Unload a set percentage of the cargo each vehicle carries when it arrives, e.g. 50% at the first town and the rest at the second.
- One level for all cargo, plus optional per-cargo levels: click + and pick a cargo, just like the Load card.
- 0% keeps a cargo aboard, so you can unload only meat and carry the wool on.
- Amounts round to the nearest whole unit (25 at 50% unloads 13).
- Works with mixed cargo in the same wagons.

**How to use**
1. Open the line manager, select a line and click a stop.
2. Tick "Custom unloading at this stop".
3. Set the All cargo level.
4. Optional: click + to give a cargo its own level. Click its icon later to change or remove it.

**Good to know**
- Vehicles don't pick up cargo at a stop with custom unloading.
- Cargo the station can't accept stays aboard. Cargo is never destroyed.
- Rules are saved with your game and stay with their station when you add, remove or reorder other stops.
- Stops without custom unloading behave exactly as normal.
- Passenger vehicles are not affected.
- Safe to add to existing saves.

**Caveats**
- Removing the mod from a save game can cause unwanted behavior.

Source code (MIT): https://github.com/Jinxy2004/even-cargo-distributor
