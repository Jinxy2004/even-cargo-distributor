# Save/reload during unloading — 0.1.4-prototype (PASSED)

Date 2026-10-05. Build 40408. Trace: `reports/native-0.1.4-reload.log`
(raw stdout snapshot kept in ignored local/). Line 81481, vehicle 82979, sequence 14.
Rules: stop 2 = selected {meat} 50%; stop 3 = automatic 100%.

Timeline (stdout):
- tick 20511 ARRIVAL stop 2: 25 meat / 25 wool; quota 13 meat, retain 12 meat + 25 wool.
- tick 20512 TARGET_WRITTEN (postUpdate). Unloads at 20522–20532: 5 meat.
- 14:32:27 game saved (user saved over ModTestGame.sav), 14:32:31 same save loaded.
- After load: unloads resume at 20535 (no duplicated or replayed events, no new
  ARRIVAL/quota, no re-sent target); 8 more meat to 20552.
- tick 20580 RESULT: unloaded 13 meat, 0 wool; departed with 12 meat / 25 wool;
  exact=true, safe=true, loaded=0, destroyed=0. RESTORED stop 2.
- Stop 3 (21686–21785): 12 meat + 25 wool unloaded, exact; RESTORED stop 3.

Conclusions: the persisted arrival snapshot, applied target and transfer counters
(5 before save + 8 after) survive save/load; the engine retained the applied stop
setting across the reload; restoration after reload works. The only tracebacks in
stdout are unrelated GUI warnings (selector_react_util "expired ReactRefWrap").
Not covered: quitting to desktop/restarting the game between save and load (should be
equivalent; state lives in the save), or saving before the target is written.
