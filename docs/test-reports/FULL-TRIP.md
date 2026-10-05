# Confirmed single-vehicle full trip

Recorded 2026-10-05. Native game build **40408 Windows 64-bit**, prototype
**0.1.4-prototype** (revision 5, saved schema 2). Test save: ModTestGame.
User confirmation: "alright done, it seems to be working fine."

Evidence: [native-0.1.4-full-trip.log](native-0.1.4-full-trip.log), 26 extracted
probe records from the local stdout.txt. This is a native trace, not the mock engine.
Line 80160, vehicle 80319; stop order: meat pickup, first town, second town.
Cargo resource: `::/cargos/meat/meat.cargo`.

| Observation | First town (stop 2) | Second town (stop 3) |
|---|---:|---:|
| Arrival tick | 3892 | 5091 |
| Meat aboard on arrival | 16 | 8 |
| Requested percentage | 50% | 100% |
| Requested unloading quantity | 8 | 8 |
| Compatible capacity (native denominator) | 225 | 225 |
| Native retained/capacity target | 8/225 | 0 |
| Target accepted in postUpdate | Tick 3893 | Tick 5092 |
| Unload event ticks | 3903–3926 | 5102–5147 |
| Unload event count / persisted count | 8 / 8 | 8 / 8 |
| Meat aboard on departure | 8 | 0 |
| RESULT and RESTORED tick | 3954 | 5178 |
| Exact / safe | true / true | true / true |
| Failures | none | none |
| Picked up / destroyed | 0 / 0 | 0 / 0 |

The complete run delivered eight meat to each town. The 0.1.4 state-write correction
also passes its first native check: every unload event is preserved in the final
counters, and both results conserve cargo. Original stop settings were restored.

## Scope of this result

This proves this one vehicle's partial-load meat trip. It does not establish mixed
cargo/filtering, full warehouse behavior, concurrent vehicles, save/reload during
unloading, all transport modes, or general no-pickup behavior when output cargo is
available. Both arrivals explicitly have overlap=false. The full feasibility gate
and release remain pending; no production GUI or public release is justified yet.

Next priority is two vehicles unloading at the same line stop simultaneously with
different retained/capacity ratios. Merely adding a second vehicle with no overlap
does not exercise the shared-target risk. Confirm platform/terminal availability
before asking the user to prepare that run.
