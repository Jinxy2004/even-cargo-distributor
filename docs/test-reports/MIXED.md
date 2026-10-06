# Mixed-cargo / filter test — 0.1.4-prototype (PASSED)

Date 2026-10-05. Build 40408. Trace: `reports/native-0.1.4-mixed.log`.
Line 81481. Pickup set by user to a 50% meat / 50% wool split (shared wagons).
Rules: stop 2 = selected {meat} 50% (wool kept aboard); stop 3 = automatic 100%.

| Vehicle | Stop | Arrival meat / wool | Expected unload | Unloaded | Departed with | Result |
|---|---|---|---|---|---|---|
| 82979 | 2 | 25 / 25 (cap 50) | 13 meat, 0 wool | 13 / 0 | 12 / 25 | exact, safe |
| 82913 | 2 | 22 / 24 (cap 47) | 11 meat, 0 wool | 11 / 0 | 11 / 24 | exact, safe |
| 82979 | 3 | 12 / 25 | all | 12 / 25 | 0 / 0 | exact, safe |
| 82913 | 3 | 11 / 24 | all | 11 / 24 | 0 / 0 | exact, safe |

loaded=0 and destroyed=0 for every cargo; no failures; settings restored at both
stops. Per-cargo targets in shared wagons work (meat 0.24 and wool 0.50 applied
together). Half-up rounding confirmed (25 -> 13 unloaded).

Note: both stops had overlapping dwells (overlap=true), but the two meat targets
were nearly identical (12/50 = 0.24 vs 11/47 = 0.234), so this run does NOT
contradict CONCURRENT.md — an overwrite would round to the same result.
Not covered: no-pickup with the excluded cargo available at the unload station,
per-cargo `overrides`, save/reload mid-unload, full/incompatible warehouses.
