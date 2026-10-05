# Changelog

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
