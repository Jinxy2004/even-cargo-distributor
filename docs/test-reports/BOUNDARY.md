# Boundary amounts — 0.1.4-prototype (PASSED)

Date 2026-10-05. Build 40408. Trace: `reports/native-0.1.4-boundary.log`.
Line 81481, vehicle 82979, stop 2 only (town one). Rules: meat 50%, wool 25%.
The user re-ran the train through town one repeatedly, so later arrivals carry what
the previous visit retained (13 -> 10 -> 7 wool; 3 -> 1 meat).

| Tick | Meat arr -> unloaded / kept | Wool arr -> unloaded / kept | Result |
|---|---|---|---|
| 31712 | 0 -> 0 / 0 | 13 -> 3 / 10 | exact, safe |
| 31852 | 0 -> 0 / 0 | 10 -> 3 / 7 | exact, safe |
| 32057 | 0 -> 0 / 0 | 7 -> 2 / 5 | exact, safe |
| 33824 | 3 -> 2 / 1 | 25 -> 6 / 19 | exact, safe |
| 33968 | 1 -> 1 / 0 | 19 -> 5 / 14 | exact, safe |

Covers zero (no errors, nothing unloaded), single unit (rounds up to 1), odd small
amounts, and several half-up wool cases (3.25->3, 2.5->3, 1.75->2, 4.75->5).
loaded=0 and destroyed=0 throughout; no failures; restored after every visit.
