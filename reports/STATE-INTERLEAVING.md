# Successful partial delivery and persistent-counter repair

Build 40408, 0.1.3-prototype, ModTestGame, 2026-10-05.
The user confirmed that half the meat remained after the first town. The log shows:

- Arrival: 16 meat, compatible capacity 225, requested delivery 8.
- Native target 8/225 accepted in postUpdate on tick 3849.
- Eight distinct OnCargoUnloaded events, ticks 3859 through 3882, destroyed=false.
- Departure: 8 meat aboard on tick 3910; original stop settings restored.

That validates the 16→8 first-town split for this single vehicle. It does not validate
mixed cargo, all carrier modes, simultaneous arrivals, save/reload, or the whole gate.

The persisted RESULT counter incorrectly reported only one unload, despite eight
logged events and eight fewer units aboard. The parallel update phase still read and
wrote an entire state snapshot. Events could update transfer counters between those
operations, after which the older state replaced the newer event values. A mock
interleaving reproduces the lost event (state-interleave-regression-before.log).

Version 0.1.4 makes update read-only with respect to persistent script state. It returns
the next tick token; postUpdate reads the current state, advances the tick, applies
commands and saves. Event handlers retain their own updates. Percentages and the
native capacity conversion are unchanged from 0.1.3. The suite now has 98 assertions,
including an explicit rejection of state writes from parallel update.

Native 0.1.4 retest passed: both towns recorded all eight transfers, with exact=true,
safe=true and no conservation failures. See [FULL-TRIP.md](FULL-TRIP.md) and its saved
trace. Do not treat the older exact=false conservation warning as proof that only
one unit moved: the event trace and departure amount show eight.
