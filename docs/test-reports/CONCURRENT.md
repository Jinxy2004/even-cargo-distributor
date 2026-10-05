# Concurrent-arrival test — 0.1.4-prototype (FAILED: shared target overwritten)

**Decision (user, 2026-10-05):** accept as a documented known limitation and continue
development; do not build the workaround now. User-facing wording for docs/mod page:
"If two vehicles on the same line unload at the same stop at the same time, the stop
follows the most recent arrival's percentage, so the earlier vehicle may unload more
or less than its own percentage. Cargo is never picked up or destroyed." 

Date 2026-10-05. Build 40408. Trace: `reports/native-0.1.4-concurrent.log`
(collected from crash_dump/stdout.txt before restart). Meat only, rule stop 2 = 50%.
Fresh line **81481** (two-platform town one), armed tick 4741. Old line 80160 retired.

| Vehicle | Arrival (tick) | Meat / compat. cap | Quota / retain | Target written | Unloaded | Departed with | Result |
|---|---|---|---|---|---|---|---|
| 82979 | 9314 | 43 / 50 | 22 / 21 | 0.42 @ 9315 | **19** | **24** | exact=false, safe=true, overlap=true |
| 82913 | 9343 | 25 / 25 | 13 / 12 | 0.48 @ 9344 | 13 | 12 | exact=true, safe=true, overlap=true |

Ordering: 82979 began unloading at 9325 and was still unloading (events to 9348)
when 82913 arrived (9343) and its target 0.48 was written (9344). 82979 then stopped
at 24 aboard = 0.48 x 50 exactly — the second vehicle's target, not its own 21.
No loading or destruction for either vehicle; both stop settings restored (9412).

Conclusion: the native line-stop `maxLoad` is a single shared target per cargo.
A later arrival overwrites an in-progress vehicle's target, and the change takes
effect **mid-dwell** on the vehicle already unloading. Per-vehicle arrival
percentages cannot be guaranteed by naive per-arrival writes. Instrumentation is
consistent (19 unload events = 43 - 24), so this is not a logger artifact.

Explained: the tick-9166 stop-2 arrival (0 unloaded, departed 9175) was the user
deliberately sending 82979 past the station and back to line up the overlap. Not a
mod fault. The "48" the user reported was a misread; the trace's 43 is correct.

Possible mitigation (untested, not implemented): "highest target first" — keep the
shared target at the maximum remaining target among dwelling vehicles; lower it as
each finishes. Lowering is safe; a later arrival with a HIGHER target than the
current one cannot be served without either over-unloading it or raising the target
(which, with load=true, risks pickup on the in-progress vehicle). Needs user decision.
