# Per-cargo percentage override — 0.1.4-prototype (PASSED)

Date 2026-10-05. Build 40408. Trace: `reports/native-0.1.4-override.log`.
Line 81481, vehicle 82979. Rules: stop 2 = automatic 50%, override wool 25%;
stop 3 = automatic 100%. Single train at the stop (overlap=false).

| Stop | Arrival meat / wool | Quota (unload) | Target written | Unloaded | Departed | Result |
|---|---|---|---|---|---|---|
| 2 | 25 / 25 | 13 meat, 6 wool | meat 0.24, wool 0.38 | 13 / 6 | 12 / 19 | exact, safe |
| 3 | 12 / 19 | all | 0 / 0 | 12 / 19 | 0 / 0 | exact, safe |

loaded=0, destroyed=0, no failures, both stops restored. Two different per-cargo
fractions applied in one stop update in shared wagons. 25 x 25% = 6.25 -> 6 unloaded.
The second train was not recorded at town one in this run.
