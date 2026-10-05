# Changelog

## 0.2.0-prototype

- New Unload card at the bottom of the game's stop window (line manager -> stop).
  Added through the game's documented recipe-replacement hook; no game files are
  copied or modified. Settings: on/off, unload percentage, all or selected cargo,
  optional per-cargo percentage.
- Rules are stored in the save, per line, keyed by station, and follow the station
  when stops are added, removed or reordered. A rule is dropped (and logged) when its
  station leaves the line. The line-name opt-in and config.lua rules are gone.
- A stop the player edits while a temporary target is in place keeps the player's
  edit; the old settings are not written back over it.
- Skipped arrivals (e.g. cargo moved before the target could be set) no longer
  suspend the line permanently; only that arrival is left alone.
- Failed restores are retried. Saved-state schema 3; 0.1.x saves are converted and
  any still-applied 0.1.x target is restored.

## 0.1.4-prototype

- Keep persistent-state writes in serial postUpdate and event handlers. Parallel
  update no longer overwrites newer transfer counters with an older snapshot.
- Add an interleaved-event regression and prohibit state writes in the mock's
  parallel phase. No change to percentage calculations from 0.1.3.
- Native 0.1.3 test confirmed 16 meat arriving, 8 delivered, 8 retained at town one.
  Full acceptance remains pending; this is still a feasibility prototype.

## 0.1.3-prototype

- Correct native target conversion to use all compatible compartment capacity
  (allCaps), not only compartments currently configured for the cargo.
- Preserve arrival-based quotas: 16 meat at 50% still means 8 to unload; a train
  with 225 compatible capacity receives a retention fraction of 8/225, not 8/25.
- Add a regression case with different configured and compatible capacities.
- Native 0.1.2 verified successful serial commands, but the wrong denominator caused
  zero delivery at town one and full delivery at town two. Native 0.1.3 retest is pending.

## 0.1.2-prototype

- Register postUpdate and move native commands into that serial phase. Version
  0.1.1's parallel update callback was rejected, so the unload target never applied.
- Keep arrival snapshots and restricted updates free of native mutations; reject
  duplicate postUpdate calls and late targets.
- Log recoverable command errors and suspend affected rules without repeated error dialogs.
- Add regression coverage for the callback restriction and the observed 16→8 target.
- Log alternate-configuration cargo capacities to aid native capacity diagnostics.

## 0.1.1-prototype

- Fix native `ecs::Engine::BeginModification` assertion on arrival: queue the target
  in saved state and issue line commands only from the regular script update.
- Defer disable/restoration commands out of event callbacks as well.
- Reject late commands if cargo transfers, capacity changes, or the line is reset
  before the command runs. Preserve the original arrival quota and log the reason.
- Verify the native command callback and record application timing.
- Migrate saved schema 1 to 2 without replaying legacy active arrivals.
- Add regression coverage for event mutation, pending saves, cancellation and timing.

## 0.1.0-prototype

- Opt-in, instrumented native unloading feasibility experiment.
- Arrival-based integer quotas, all-goods default, resource-name allowlist and overrides.
- Persisted snapshots, duplicate suppression, concurrent-arrival traces and reset.
- All cargo-destruction options disabled on temporary native targets.
- Not yet approved for normal gameplay or public distribution.
