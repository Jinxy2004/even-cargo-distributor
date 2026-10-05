# Feasibility and release status

Updated: 2026-10-05 America/New_York. Inspected game: **40408 Windows 64-bit**.
Current prototype: **0.1.4-prototype**, revision 5, saved schema 2.

| Check | Status | Evidence / boundary |
|---|---|---|
| Lua source compiles | Passed | Lua 5.4 through Lupa 2.6; 98 assertions in two test cases |
| Quotas, allowlists, per-cargo overrides | Passed in unit tests | Actual core.lua |
| Snapshots, duplicate arrivals, concurrent bookkeeping, restore | Passed in mock | Actual probe.script.lua; native unloading is not simulated |
| Deterministic ZIP and member hash checks | Passed | dist/package-report.json |
| Mod installed in local user-data folder | Completed | 0.1.4 installed; all 12 source files hash-match; no saves modified |
| Game discovers mod | Passed | Native log found the new game script |
| Game loads corrected script | Passed | User reported clean load; native STARTUP confirms build 40408 |
| Native arrival handling | Crash found; code repaired | 0.1.0 issued a nested engine command; 0.1.1 defers it to update |
| Restricted update callback | Fixed in native run | 0.1.2 serial postUpdate command accepted; no callback error |
| Deferred target runs before transfers | Passed in recorded full trip | 0.1.4: both targets accepted in postUpdate before first transfer |
| Single-vehicle 50% partial load and full trip | Passed in native game | 0.1.4: 16 meat → 8 → 0; 8 delivered to each town; user confirmed |
| Persisted transfer counters | Passed in native full trip | Both stops count all 8 unload events; exact=true, safe=true, no failures |
| Mixed loads unload exactly | Pending | Required gate |
| No pickup at custom stops | None observed; dedicated test pending | Full trip had loaded=0; still test with pickup cargo available |
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
catalog of 36 cargo resources. The single-vehicle test subsequently passed (below).
No unloading result should be inferred from the successful startup.

## Arrival crash

The first real arrival captured 10 meat in a 25-capacity configuration, calculating
5 to unload. The immediate line command inside OnArriveAtStop triggered the engine's
`!m_betweenChanges` assertion. Version 0.1.1 persists a pending target and issues it
from update; it suspends instead if cargo changed before application. See
[ARRIVAL-CRASH.md](ARRIVAL-CRASH.md) and the retained regression/native logs.

The user replayed an ordinary pre-crash test save. Stop order was confirmed:
meat pickup, first town, second town.

## Restricted callback error

The next run did not hit the original assertion. Version 0.1.1 instead failed with
`Callbacks are currently disallowed` during update and delivered all 16 meat at stop 2.
Version 0.1.2 registers the native serial postUpdate phase for commands and callbacks.
See [CALLBACK-ERROR.md](CALLBACK-ERROR.md). Command acceptance alone did not establish
equal distribution; the capacity correction and later full-trip result did.

## Compatible-capacity correction

Version 0.1.2 accepted the command but retained all 16 meat at the first town and
unloaded all at the second, matching the user's report. Its native fraction used
configured capacity 25 instead of compatible capacity 225. Version 0.1.3 corrects
the denominator; see [CAPACITY-CONVERSION.md](CAPACITY-CONVERSION.md). Do not count
the earlier command's acceptance as a pass for equal distribution.

## First confirmed partial delivery

Version 0.1.3 delivered eight units and retained eight from a sixteen-unit arrival;
the user confirmed half remained. Eight unload events and the final amount agree.
The saved counter lagged behind the events, which 0.1.4 addresses by eliminating
parallel state writes. See [STATE-INTERLEAVING.md](STATE-INTERLEAVING.md). The full
feasibility gate remains pending, particularly concurrent vehicles and mixed goods.

## Confirmed full trip on 0.1.4

The user reported the complete run worked. The native trace confirms 16 meat arrived
at stop 2, 8 unloaded and 8 remained; at stop 3, those 8 unloaded and 0 remained.
Both RESULT records have exact=true, safe=true and no failures. Persisted counters
match all 16 transfer events; no pickups or destruction occurred in this scenario.
Both original stop configurations were restored. See [FULL-TRIP.md](FULL-TRIP.md)
and [native-0.1.4-full-trip.log](native-0.1.4-full-trip.log).

Next: overlapping arrivals with different retained/capacity ratios, followed by
mixed goods/filtering and a dedicated no-pickup scenario. The station's ability to
unload two vehicles concurrently is not yet known. Work is handing off to a fresh
session at the user's request; see [HANDOFF.md](../HANDOFF.md).
