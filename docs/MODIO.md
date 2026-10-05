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

## Screenshots to take (in game, real results only)

1. The stop window with the Unload card: All cargo 50% and one cargo icon with its own level.
2. A train at town one after unloading, showing about half its cargo still aboard.
3. The cargo picker (after clicking +).

## Listing

**Name:** Cargo Distribution

**Summary:** Unload a set percentage of each vehicle's cargo at chosen line stops, per
cargo type, from the stop window.

**Tags:** Script Mod

**Description:**

Split a delivery between the stops on a line instead of dumping everything at the first one.

**How to use**
- Open the line manager, select a line and click a stop to open its stop window.
- At the bottom, in the new **Unload** card, tick **Custom unloading at this stop**.
- Set **All cargo** to the share to unload. It applies to the cargo each vehicle
  carries when it arrives (25 at 50% unloads 13).
- To give one cargo its own level, click **+**, set the level and click the cargo.
  0% keeps that cargo aboard. Click a cargo icon to change it or remove it.

Example: a train loads 100 meat. With 50% at the first town and 100% at the second,
each town receives 50.

**Good to know**
- Vehicles don't pick up cargo at a stop with custom unloading.
- Cargo a station can't accept stays aboard. Cargo is never destroyed.
- Rules belong to the station and follow it when you add, remove or reorder other stops.
- Passenger vehicles are not affected.
- Safe to add to existing saves. Before removing the mod, untick custom unloading on
  your stops and let vehicles finish unloading.

**Known limitation:** the game keeps one unload setting per stop. If two vehicles on
the same line are unloading at the same stop at the same moment, both follow the most
recent arrival. Vehicles unloading one after another are unaffected.

Source code (MIT): https://github.com/Jinxy2004/even-cargo-distributor
