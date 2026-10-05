# Changelog

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
