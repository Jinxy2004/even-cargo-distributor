# Feasibility and release status

Updated: 2026-10-05 America/New_York. Inspected game: **40408 Windows 64-bit**.
Current prototype: **0.1.2-prototype**, revision 3, saved schema 2.

| Check | Status | Evidence / boundary |
|---|---|---|
| Lua source compiles | Passed | Lua 5.4 through Lupa 2.6; 95 assertions in two test cases |
| Quotas, allowlists, per-cargo overrides | Passed in unit tests | Actual core.lua |
| Snapshots, duplicate arrivals, concurrent bookkeeping, restore | Passed in mock | Actual probe.script.lua; native unloading is not simulated |
| Deterministic ZIP and member hash checks | Passed | dist/package-report.json |
| Mod installed in local user-data folder | Completed | 0.1.2 installed; all 12 source files hash-match; no saves modified |
| Game discovers mod | Passed | Native log found the new game script |
| Game loads corrected script | Passed | User reported clean load; native STARTUP confirms build 40408 |
| Native arrival handling | Crash found; code repaired | 0.1.0 issued a nested engine command; 0.1.1 defers it to update |
| Restricted update callback | Error found; code repaired | 0.1.1 callback rejected; 0.1.2 moves commands to serial postUpdate |
| Deferred target runs before transfers | Awaiting native retest | Timing guard rejects late commands; no native pass yet |
| Partial and mixed loads unload exactly | Failing in prior builds | 0.1.1 delivered 16 instead of 8 after target rejection; 0.1.2 retest pending |
| No pickup at custom stops | Not run | Required gate |
| Concurrent arrivals use independent targets | Not run | Required gate |
| Native save/reload and all carrier modes | Not run | Acceptance tests |
| Native staging validator | Not run | No report exists yet |
| Clean game installation of packaged ZIP | Not run | Archive integrity alone is insufficient |
| Public release | Blocked | Gate, validation, metadata and user publication request pending |

## Current technical uncertainty

`load` and `maxLoad` are line-stop fields. The experiment writes the amount to retain
divided by each arriving vehicle's cargo capacity. A later arrival can overwrite this
shared target while an earlier vehicle is still unloading. The exposed API does not
document whether transfer targets are snapshotted per vehicle. Only a real overlapping
arrival test can establish whether this technique works.

This is **unverified**, not a demonstrated engine impossibility. If either incorrect
unloading or new loading occurs, preserve the native traces and stop at the agreed
failure gate. The full GUI and release work have deliberately not started.

## Native smoke-test issue and fix

The first native load reported `function data() not defined` for probe.script@update,
followed by `Expected table at path` messages. The initial source returned a module
table; this build requires a `data()` resource entry point for .script.lua. Changed
the entry point, added assertions for native resource loading, rebuilt and reinstalled.
After restart/reload, the user reported no error. The log confirms STARTUP and a
catalog of 36 cargo resources. The user is now running the single-vehicle test.
No unloading result should be inferred from the successful startup.

## Arrival crash

The first real arrival captured 10 meat in a 25-capacity configuration, calculating
5 to unload. The immediate line command inside OnArriveAtStop triggered the engine's
`!m_betweenChanges` assertion. Version 0.1.1 persists a pending target and issues it
from update; it suspends instead if cargo changed before application. See
[ARRIVAL-CRASH.md](ARRIVAL-CRASH.md) and the retained regression/native logs.

The user should restart with the patched installation and load the ordinary test save
from before the crash (not the automatically generated crash save). Stop order has
been confirmed: meat pickup, first town, second town. No route changes are needed.

## Restricted callback error

The next run did not hit the original assertion. Version 0.1.1 instead failed with
`Callbacks are currently disallowed` during update and delivered all 16 meat at stop 2.
Version 0.1.2 registers the native serial postUpdate phase for commands and callbacks.
See [CALLBACK-ERROR.md](CALLBACK-ERROR.md). Uneven delivery remains unresolved in native
testing until a target is successfully applied and correct quantities are observed.
