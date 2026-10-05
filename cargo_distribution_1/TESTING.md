# Native feasibility test protocol

Record build, mod version, vehicle ID/mode, capacity, arrival quantity, warehouse
space, expected unloaded quantity, actual unloaded quantity and departure amount.
Build inspected during development: **40408, Windows 64-bit**.

Use a disposable copy. Disable other mods that edit the same line's cargo filters.
The default probe name is **Cst CD PROBE**, with stop 2 = 50%, stop 3 = 100%.
Do not edit native Load settings during a probe run.

1. **Load smoke test:** enable this mod and load the test save. Let it run briefly.
   The log must contain STARTUP with build and cargo catalog and no script errors.
   For version 0.1.3, verify ARRIVAL is followed by TARGET_WRITTEN with
   `commandPhase=postUpdate` and `applied=true`. A TARGET_SKIPPED timing failure requires investigation; do
   not count that run as proof of working percentage unloading.
2. **Single vehicle:** source → accepting warehouse A → accepting warehouse B.
   Ensure enough free warehouse capacity. Record the vehicle amount immediately
   before A, immediately after A, and after B. Test full and partial loads.
   For 100 expect 50/50 deliveries; for 60 expect 30/30.
3. **No pickups:** ensure A has output cargo available as well as compatible input
   space. A must receive the quota without loading any new cargo. Verify TRANSFER
   event types; a correct net count can hide an unwanted unload/reload cycle.
4. **Mixed goods:** edit config.lua using the exact resource names printed in STARTUP.
   Use, for example, meat=50%, another allowed cargo=25%, and a third cargo excluded.
   All excluded goods must remain aboard. Repeat with multiple compartments.
5. **Concurrent arrivals:** two vehicles on the same line stop, on separate terminals
   if necessary. Give them different retained/capacity ratios (e.g. capacity 100,
   load 60 → retain 30; capacity 200, load 100 → retain 50). Make unloading overlap.
   RESULT entries for both must show `overlap=true`. Both must meet their own quota
   without loading. Merely running two vehicles without overlapping is insufficient.
6. **Boundaries:** empty vehicle, 1 and 3 units at 50%, then 0% and 100%.
7. **Warehouse limits:** full and incompatible warehouses must leave unaccepted cargo
   aboard with `destroyed=0`. These are allowed to be safe but not exact results.
8. **Persistence:** save/reload during unloading on a disposable save. The arrival
   quantity and sequence must remain the original values; no second quota calculation.
9. **Cleanup:** rename to Cst CD RESET, run two seconds, verify RESTORED and native
   Load settings. Check source/unmanaged loading and passenger lines still behave normally.

Any over-unloading, destruction or pickup fails the native approach. A shortage
at an accepting warehouse with ample capacity also fails exact unloading. Missing
events or mismatched conservation are instrumentation failures requiring diagnosis.
If the targets remain shared during overlap, do not ship an approximate substitute.
Stop development at this gate and retain the traces and limitation report.

After the gate passes: build the end-user GUI, route-edit recovery, native save
migrations and full regression suite; test trucks, trains, cargo trams if available,
ships and aircraft. Verify replacement, reset, disable and clean installation.

## Evidence capture

The developer can read the local `crash_dump/stdout.txt` directly; no upload is
necessary on this computer. Preserve the log before restarting the game, because
the game may replace it. Development tool:

```powershell
python tools/collect_log.py 'PATH_TO_USER_DATA/crash_dump/stdout.txt'
```

Native staging validation must also be run and its entire report retained before
release. Archive-integrity checks and mocked Lua tests do not replace it.
