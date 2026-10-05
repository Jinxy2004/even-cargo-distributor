# Cargo Distribution — implementation handoff

## User requirements

Implement arrival-based percentage unloading per line stop, with a percentage per
cargo resource. Automatic/all-goods default; a selected allowlist retains excluded
goods. Custom stops must load nothing new. Ordinary stops retain native behavior.
For 100 meat: unload 50% at town 1, then 100% of the remainder at town 2. For a partial
60-unit load: 30/30. Quotas round half up: floor(arrival * percent / 100 + 0.5).
Full/incompatible warehouses retain cargo; never force destruction.

The user explicitly requires a **feasibility gate first**, including simultaneous
arrivals at the same stop with different capacities and loads. If supported APIs
cannot pass, stop and deliver the prototype plus a precise limitation report. Do
not substitute capacity-based semantics, cloned lines or executable modifications.

## Implemented

- Native mod manifest and content index, metadata, stable ID cargo_distribution_1.
- Pure Lua quota, allowlist, overrides and integrity checks.
- OnArriveAtStop snapshot; pending retained/capacity target applied in serial postUpdate.
- Original stop configuration backup and restoration, duplicate-event suppression.
- Saved state schema 2, quantities keyed by cargo resource names, runtime ID lookup.
  Migration from schema 1 preserves old snapshots without replaying unknown commands.
- Arrival/unload/load/departure logs, overlapping-arrival flags, destruction/pickup checks.
- Explicit opt-in line name Cst CD PROBE, stop 2=50%, stop 3=100%.
- Reset by renaming; console disable event; conservative route-change suspension.
- Lua and mock lifecycle checks, deterministic package builder, archive integrity check.
- Test protocol, compatibility notes, licensing placeholder, publication preparation notes.

This is a diagnostic prototype, not the finished mod. No end-user Unload Rules card
has been added. That work depends on the native gate. Do not claim zero pickups or
concurrency support based on unit tests.

## Local context and testing status

- Workspace: D:\TSF3Mod. User created Git baseline 5d2d3b3 on main and linked origin
  https://github.com/Jinxy2004/even-cargo-distributor.git. User authorizes branch/main
  commits and pushes. Current branch: codex/fix-deferred-command-confirmation.
- Installed game: D:\Games\Transport Fever 3, build 40408 Windows 64-bit.
- User-data folder observed in logs: C:\Users\Public\Documents\Steam\RUNE\3493540\local.
- User created a dedicated test save named ModTestFile. No saves have been modified or copied by us.
  Filesystem inspection shows its actual filename is ModTestGame.sav.
- Game was started by the user. User enabled Debug mode through Settings.
- Native automation clicks did not take effect; user said they had canceled computer
  control and offered to perform in-game testing. Leave control to the user.
- The initial combined install/save-copy request was declined. User instead created
  ModTestFile. A revised mod-only installation was then approved and completed in
  the user-data mods folder. User has been asked to enable it and report load status.
- Native loading passes after the entry-point fix. Staging validation and gameplay
  are still pending. Do not confuse mocked tests (FAKE ENGINE) with native evidence.
- First native load found the mod but reported `function data() not defined`.
  Fixed .script.lua to expose data() and reinstalled. Restart/reload succeeded:
  user reported no error, and the log confirms STARTUP on build 40408.
  Lua tests now contain 98 passing assertions, including resource entry-point and
  event-callback mutation regression checks.
- Git ownership was corrected by preserving the empty sandbox-created repository in
  .git.sandbox-backup (ignored), then initializing a new .git as the user's account.
  Normal git status works. User subsequently reinitialized/linked Git as described above.
- The first native arrival crashed in 0.1.0: sendCommand inside OnArriveAtStop caused
  `ecs::Engine::BeginModification` / `!m_betweenChanges`. Actual snapshot: vehicle
  32654, line 79439, stop 2, 10 meat aboard, meat capacity 25, planned quota 5.
  User confirmed the expected source/town A/town B order.
- Version 0.1.1 (revision 2) fixes scheduling by queueing targets and disable commands
  for update. Pending snapshots survive save/reload; commands are skipped if cargo
  already changed. Installed 0.1.1 and verified all 12 files match the source.
  Full native behavior requires retesting after restart.
  See reports/ARRIVAL-CRASH.md for evidence and verification boundaries.
- Exact installed meat resource name: ::/cargos/meat/meat.cargo.
- Next native run of 0.1.1 failed with `Callbacks are currently disallowed` in restricted
  update, so no target was applied: 16 meat arrived and all 16 unloaded instead of 8.
  Version 0.1.2 registers postUpdate and runs all commands there, following base script
  patterns. Timing guards and command confirmation remain. Installed 0.1.2 and
  hash-verified all 12 files. User is retesting from a pre-error save; result pending.
  See reports/CALLBACK-ERROR.md; do not infer native feasibility from the rejected command.
- Version 0.1.2 native retest: postUpdate command accepted without callback error.
  User and log show 16 meat retained at town one, all unloaded at town two. Logging
  revealed configured capacity 25 vs allCaps 225. Version 0.1.3 corrects the native
  fraction to retained/allCaps (8/225), while the quota remains 50% of arrival.
  Installed 0.1.3 and hash-verified all 12 files. User is replaying the same test;
  native result pending. See reports/CAPACITY-CONVERSION.md.
- Commit ea04854 with the command-phase fix was pushed to the fix branch. The capacity
  correction is a follow-up on that same branch.
- Capacity fix pushed as df68e49. Native 0.1.3 confirmed 16→8 at town one: eight
  unload events, eight aboard on departure; user answered "Half remains".
  Saved diagnostic counter showed only one event, revealing stale parallel-state writes.
  Version 0.1.4 moves persistent writes entirely to postUpdate/event handlers; 98
  assertions pass, including the reproduced interleaving. Installed 0.1.4 and verified
  all 12 source files match. Native retest and the full feasibility gate remain pending.

## Resume steps

1. Get the installed prototype enabled in a disposable save through the user's chosen
   installation route. First verify STARTUP and absence of native Lua/API errors.
2. Run the single-vehicle partial-load test from the packaged TESTING.md.
3. Diagnose real native results. Ensure event snapshot timing and capacity indexing
   match the installed engine. If a command fails or cargo cannot be attributed,
   repair instrumentation before deciding engine feasibility.
4. Run mixed goods, no-pickup, and overlapping-vehicle tests. A shared stop target
   changes from e.g. 0.30 for A to 0.25 for B; the engine would have to cache each
   arrival's own target for this to work. No such behavior is yet established.
5. On any proven native failure, stop feature development and write the exact trace,
   quantities, event ordering and limitation. If all pass, proceed to full GUI and
   acceptance suite. The prototype is not an approximate fallback product.

## Sources inspected

Installed definitions take precedence:

- api/tealdef/api/engine.d.tl: Line.StopConfig, TransportVehicle.LoadState/config.
- api/tealdef/api/cmd.d.tl: makeLineUpdateCmd; no supported per-vehicle unload quota.
- api/tealdef/api/engine/system.d.tl: simEntityAtVehicleSystem and transportVehicleSystem.
- base/tealdef/scripts/gamescript.d.tl: persistent state, subscriptions, arrival events.
- base/content/gui.zip: gui/line_vehicle_mgmt/cargofilter_window.tl and line_util.tl.
  The picker has dormant unload UI fields but only writes load/maxLoad; do not mistake
  those leftovers for a working unloading API.
- base/content/gui.zip: gui/entity_window/line/line_eow.script.tl and
  line_eow_basics.res.lua. The LineEowExtensionPoint supports a custom Unload Rules card.
- api/tealdef/api/type/modhub.d.tl: validator and native publisher.

No proprietary source/assets were copied into this repository or package.

## Full implementation still gated

Add original GUI using native cargo-picker conventions and game resources: stop
selector, enable toggle, 0–100% default, automatic/all-goods versus selection, and
per-cargo overrides. Persist user rules; treat repeated visits separately. Add route
reassignment confirmation and reliable reset/disable, safe save migrations, vehicle
replacement handling and no passenger regression. Validate every cargo transport mode,
odd counts, zero/full percentages, mixed compartments, full warehouses, save/reload
during unloading and simultaneous arrivals. Then run staging validation and clean install.

Prepare original cover/screenshots only after functioning gameplay can be shown.
The user will choose author credit and license. No mod.io account submission or public
release is authorized yet. Preserve cargo_distribution_1 across compatible updates.
