# Arrival crash diagnosis and repair

Native run: build 40408, 2026-10-04 23:29:11 America/New_York.
Source: the game's crash_dump/stdout.txt and crash text log.
Faulty mod version: 0.1.0-prototype. Fix: 0.1.1-prototype (native revision 2).

## Observed evidence

- Line 79439, vehicle 32654, stop 2, probe sequence 1, tick 2688.
- Arrival loadState = 1 (Arrived). Meat aboard = 10; meat capacity = 25.
- Computed unload quota = 5; retained quantity = 5; native candidate fraction = 0.2.
- ARRIVAL was logged. No TARGET_WRITTEN or completed RESULT followed it.
- Fatal assertion: `!m_betweenChanges` in `ecs::Engine::BeginModification`, Engine.cpp:545.
- Stack: `sendCommand` → probe.script.lua `replaceStop` (old line 85) → `arrive`
  (old line 191) → `handleEvent` (old line 281).
- The user confirmed source → first town → second town order. This was not a stop-order error.

The arrival callback is invoked while the engine already has a component-change
transaction open. The synchronous line command attempted to begin a nested transaction.
This is a prototype scheduling bug; it does not yet prove or disprove native quota support.

## Repair

Arrival events snapshot quantities and persist `targetStatus=pending` without any
engine commands. `update` processes pending arrivals in event sequence order and
issues the native line update. Disable events likewise queue restoration for update.
Before issuing a target, recheck cargo counts, transfer events, capacity, line identity,
route and disable state. A late/invalid target is skipped and the rule suspended.
Never recalculate a new quota to hide transfers that occurred before the update.

Saved schema 2 persists the pending status. Schema 1 migration preserves old snapshots
but marks their command status unknown, preventing them from being replayed or treated
as verified results. The native command callback must confirm success.

## Verification limits

The regression mock rejects any command from an event callback. The old implementation
fails that check with the same offending call chain; see arrival-crash-regression-before.log.
The patched Lua suite passes, including the observed 10/25 meat case, saved pending
arrivals, concurrent ordering, cancellation and pre-command cargo transfer.

The fix still requires a native retest. In particular, it is not yet established that
the next update is early enough to control unloading. Required evidence: TARGET_WRITTEN
with applied=true, then a departure RESULT matching the original snapshot and quota.
If the engine transfers cargo before the safe update, TARGET_SKIPPED must be investigated
as a feasibility limitation. Do not ship an approximate workaround.
