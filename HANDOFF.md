# Cargo Distribution — session handoff

Updated 2026-10-05, America/New_York. Read this file first in the next session.

## Resume here

The user requested this handoff so they can switch sessions. Do not restart the
project or repeat the successful single-vehicle test. Their latest test response
was: "alright done, it seems to be working fine."

**Current result:** native version **0.1.4-prototype** successfully delivered 16 meat
as **8 to town one and 8 to town two**. Its corrected persistent counters now agree
with every transfer. Both stops report `exact=true`, `safe=true`, `failures={}` and
restore their original settings. Evidence is in `reports/FULL-TRIP.md` and
`reports/native-0.1.4-full-trip.log`. This is only the single-vehicle result; the
full feasibility gate has NOT passed.

**Next step:** prepare a meat-only concurrent-arrival test before full GUI work.
The outstanding question to the user is: "Does the first-town station currently
allow two cargo vehicles on this same line to unload simultaneously?" Options were
yes/two usable platforms, no/one platform, or not sure. No answer had arrived when
this handoff was written. Ask for that information in the new session if necessary;
do not assume a two-platform setup. Mixed goods/filtering comes after this test.

**Update (next session):** user answered: trains; town one has ONE platform for this
line today. Plan given: keep the armed line untouched as evidence, rename it to
Cst CD RESET (verify RESTORED), then build a fresh line named Cst CD PROBE whose
town-one stop already has a second platform as an alternative terminal (and pickup
too), with two trains of different capacity. Fresh line ID = fresh record, so no
code change/rearm control is needed. Route setup must be finished BEFORE naming it.

**Concurrent result (later same session): FAILED gate.** See reports/CONCURRENT.md.
Second arrival's target (0.48) overwrote the first vehicle's (0.42) mid-unload:
82979 kept 24/43 instead of 21. **User decision: accept as a documented known limitation
(rare to need it) and continue.** Do not build the workaround unless asked. Next test:
mixed goods/filtering (meat + one other cargo), then dedicated no-pickup scenario.
Second concurrent run collected (reports/native-0.1.4-concurrent-2.log): one more
dwell overlap, both exact because the first train finished unloading 12 ticks before
the second arrived — limitation only bites when unloading itself overlaps.

**Mixed test prepared:** config stop 2 = selected {meat} 50% (wool kept aboard),
stop 3 = automatic 100%. Installed config.lua into user-data mod; all 12 files
hash-match workspace. Wagons accept wool (cap 50, shared wagon with meat). Run with
ONE train unloading at a time. Watch: does the per-cargo maxLoad fraction behave
per cargo in a shared wagon? Wool target uses load=true, so town one must not
supply wool (pickup risk). Unit tests can't run in the Linux device shell (Windows
lupa); config verified with texlua instead.

**Mixed test PASSED** (reports/MIXED.md): 25/25 and 22/24 meat/wool -> half meat,
no wool at town one; everything at town two; all exact, no pickup/destruction.
No-pickup: user reports town one has a warehouse holding meat and wool, and no run
ever picked any up (logs: loaded=0 throughout). Accepted, with the caveat that it is
unconfirmed whether warehouse cargo is offered for loading at that stop. By design,
loading could only trigger if cargo aboard fell below the target, which the targets
prevent except in the known concurrency case. Next: remaining acceptance items
(overrides, save/reload mid-unload, full warehouse, boundaries) or start the GUI.

**Save/reload PASSED** (reports/SAVE-RELOAD.md): saved after 5 of 13 meat, loaded,
resumed to exactly 13, wool kept, restored. Remaining edge cases: per-cargo
overrides, full/incompatible warehouse, boundary amounts (0/1/3), other carriers.

**Override test prepared:** stop 2 = automatic 50% with wool override 25%; stop 3
unchanged. Installed; all 12 files hash-match. Expected 25/25 -> unload 13 meat + 6
wool; 22/24 -> 11 meat + 6 wool. Needs a full game restart.

**Override test PASSED** (reports/OVERRIDE.md): 25/25 -> 13 meat + 6 wool unloaded,
12/19 left, all unloaded at town two; exact, no pickup. Remaining: full/incompatible
warehouse, boundary amounts (0/1/3), other carriers. Config still has the wool
override installed.

**Boundary test PASSED** (reports/BOUNDARY.md): 0, 1, 3 meat and several wool
rounding cases all exact. User deferred the full-warehouse test (low risk) and will
test trucks/other carriers informally in-game later. Native feasibility testing is
effectively complete; next major step is the Unload Rules GUI (LineEowExtensionPoint).

Give one test at a time and exact instructions. The user previously asked whether
they were testing just the split or the entire mixed/concurrent gate; make scope
explicit. They offered to perform all native in-game testing. Leave game control
to them: they canceled computer control earlier. Read local logs yourself.

## Workspace and Git

- Workspace: `D:\TSF3Mod`; shell: PowerShell.
- Installed game: `D:\Games\Transport Fever 3`; tested build **40408 Windows 64-bit**.
- Actual user data: `C:\Users\Public\Documents\Steam\RUNE\3493540\local`.
- Native log: that directory's `crash_dump\stdout.txt`; capture before game restart
  because it can be replaced. Only mod probe lines are retained in this repository.
- Installed mod: that directory's `mods\cargo_distribution_1`.
- User called the dedicated save ModTestFile; actual filename is **ModTestGame.sav**.
  Do not modify/copy saves without a new request. No saves were modified by us.
- Debug mode was enabled by the user in Settings. Game is user-controlled; inspect
  current state if needed rather than assuming it is still running.
- Current branch: `codex/fix-deferred-command-confirmation`, tracking origin/same name.
- Origin: `https://github.com/Jinxy2004/even-cargo-distributor.git`.
- The user explicitly authorized new branches or pushes to main, at our discretion.
  Continue the existing branch for this work. Do not force-push. No PR exists yet.
- Code commits pushed: `ea04854` serial command phase; `df68e49` compatible-capacity
  conversion; **`f0f2da6`** event-state persistence (current implementation).
  Later handoff/evidence commits may follow; use git status/log for current HEAD.
- The user initialized/reinitialized Git. `.git.sandbox-backup` is an ignored empty
  earlier repository; leave it alone. No AGENTS.md was found in this workspace.
- Workspace writes are allowed; `.git` writes and installation into user data need
  sandbox escalation. Prior task authorization still applies, but does not bypass
  the tool's sandbox. Git reads work without escalation.

## Accepted behavior and strict feasibility gate

Build a real mod controlling unloading **per line stop**, with percentages based
on **cargo aboard each vehicle on arrival**. Each cargo type can have its own rate.
Default filter is Automatic/all goods. A selected allowlist keeps excluded goods
aboard. A custom unloading stop must pick up no new cargo. Unmanaged stops retain
native behavior. Passenger behavior must not regress.

Quota: `floor(arrivalQuantity * percentage / 100 + 0.5)`. Examples: 100 meat ->
50 at first town, remaining 50 at second; 60 -> 30/30. Full or incompatible
warehouses retain undeliverable cargo; never enable destruction.

The prototype must pass partial loads, mixed cargo/filters and **two vehicles
unloading simultaneously at the same line stop with different capacities/loads**.
No pickup is also required. Native `load`/`maxLoad` fields are shared by line stop;
there is no exposed independent per-vehicle unload quota. It is still unknown
whether the engine captures a target separately for each vehicle. A second arrival
may overwrite the first vehicle's active target.

If correct instrumentation demonstrates that supported APIs cannot meet these
requirements, stop feature development and deliver the prototype plus a precise
limitation report. Do not replace arrival percentages with capacity percentages,
duplicate lines to work around concurrency, or modify the executable. Do not
mistake a broken logger or command error for a proven engine limitation.

## Current native evidence

Current version **0.1.4-prototype**, native revision **5**, saved state schema **2**.
All 12 installed source files were hash-verified against the workspace in the
previous implementation turn. This handoff turn only changes documentation/evidence;
no new install or version bump is needed.

The full-trip trace uses line **80160**, vehicle **80319**:

| Stop | Arrival | Applied target | Delivered | Departure | Result/restored |
|---|---|---|---|---|---|
| 2 / town one | 16 meat, tick 3892 | 8/225 in postUpdate, tick 3893 | 8 | 8 | tick 3954 |
| 3 / town two | 8 meat, tick 5091 | 0 in postUpdate, tick 5092 | 8 | 0 | tick 5178 |

Both results are exact and safe; all eight events at each stop match persisted
counts. No cargo was loaded or destroyed in this scenario. Both arrivals have
`overlap=false`. A separate scenario with output cargo available is still needed
to establish no-pickup behavior. This run does not validate concurrency, mixed
cargo, save/reload, full warehouses or every carrier mode.

## Implementation map

Installable source is `cargo_distribution_1/`:

- `mod.json`, `_metadata/modinfo.json`, `_content.json`: native package structure,
  stable ID **cargo_distribution_1**, creator/license placeholders.
- `content/cargo_distribution/config.lua`: prototype opt-in line name
  **Cst CD PROBE**; stop numbers are one-based: stop 1 meat pickup (unmanaged),
  stop 2 50%, stop 3 100%. Both managed rules use automatic/all goods. `Cst`
  exempts the line from the installed Auto Line Namer mod's renaming.
- `core.lua`: pure quota/filter calculations, snapshots, conservation and safety
  evaluation, deterministic logging, route fingerprint, state migrations.
- `probe.gs.lua`: registers update, postUpdate and handleEvent scripts.
- `probe.script.lua`: native adapter. The resource must expose `function data()`
  returning the method table, not just return a table at module level.

Arrival events snapshot quantities exactly once and save pending targets. Native
commands run only in serial **postUpdate**, before transfer, with callback
confirmation. If transfers already started, target application is skipped and the
rule is suspended; investigate that timing failure. No commands from arrivals or
parallel update.

The native target for each cargo is retained quantity / **config.allCaps**, with
`load=true` when retained > 0 and `maxLoad` set to that fraction. Current allocated
`config.capacities` is diagnostic only. A vehicle can have compatible capacity225
while its current meat allocation is25; dividing by25 previously retained all16.
All destruction flags stay false; load mode is LOAD_IF_AVAILABLE.

`update` subscribes to events and returns a tick/advance token. It must NEVER write
persistent state. `postUpdate` reads fresh state, performs departure/restore, line
watch and pending command work, then persists. Event handlers also persist their
updates. Writing stale state from parallel update previously erased transfer
counters. Saved snapshots/duplicate guards prevent re-quota; unknown legacy target
status is not replayed. Unit tests cover migration and interleaved callbacks.

Records are per line and active vehicle; original stop settings are restored when
the last tracked vehicle leaves that stop. Cargo is keyed by resource name, IDs
resolved at runtime. Exact meat name: `::/cargos/meat/meat.cargo`.

## Concurrent-test preparation: avoid a misleading run

1. Confirm first-town station can serve two vehicles on this same line at once.
   Use two platforms/terminals with genuinely overlapping unloading, ample storage,
   and different retained/capacity ratios. Different train lengths and different
   amounts aboard are useful. Two equally full vehicles can have identical ratios
   and miss the interference bug. Example: capacity100/load60 -> retain30 vs
   capacity200/load100 -> retain50.
2. Arrange the second arrival while the first is still transferring cargo. Merely
   having two vehicles on the line or parked at the station is insufficient. Use
   the trace to verify ordering as well as overlap=true for both RESULT entries.
3. For each vehicle record arrival meat and remaining meat after town one; expect
   half-up rounding for unloaded units. Inspect no pickup/destruction and each
   vehicle's distinct target. Keep this test meat-only; mixed goods follows.
4. **Route changes suspend the prototype permanently for that saved line record.**
   The fingerprint includes stop order, station/group, terminal, alternate terminals
   and waypoint details. Renaming away/reset also suspends it. Renaming back or
   restarting will NOT rearm that saved record. Adding alternate terminals can
   therefore invalidate a test on the already-armed line.
5. If setup needs route changes, use an appropriate disposable pre-armed save and
   finish the route/terminal setup before opting in. Do not promise a reload of an
   already-armed save clears state. If no suitable save exists, implement a narrow,
   explicit safe re-confirm/rearm control with restoration checks before asking for
   the test; do not silently clear saved state or use duplicate lines as a workaround.

## Reset, disable, and configuration caveats

Rename a managed line to **Cst CD RESET** and let simulation advance to restore
settings; any name differing from the opt-in also suspends the saved line record.
Verify RESTORED before removing the mod. This prototype reset is one-way; route
reconfirmation/rearming and the final GUI are not implemented.

Console disable event (queued restoration in serial phase):

```lua
api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd(
  "cargo_distribution_probe", "cargo_distribution_1",
  "CargoDistributionControl", {action="disable"}))
```

For mixed tests, config supports `filter="selected"`,
`goods={["exact resource name"]=true}`, and per-resource `overrides` percentages.
Make such changes deliberately, reinstall only mod files, and restart/reload.
Do not change rules midway through an active arrival. No end-user UI exists yet.

## Verification and tooling

- `python tools/test.py`: actual Lua5.4 via Lupa2.6 in `.tools/python`; 98 assertions
  in two unittest cases passed on current implementation. `tests/probe_test.lua`
  mocks lifecycle, not native transfer physics. No need to rerun for docs alone.
- `python tools/build.py`: deterministic mod-owned ZIP and SHA256 member report.
  Current archive: `dist/cargo_distribution-0.1.4-prototype.zip`.
- `python tools/build.py --release`: deliberately refuses while gate is pending.
- `tools/install-local.ps1 -UserData '...local'`: install only this mod. Do NOT add
  `-SaveName`; user declined automatic save copying and made their own test save.
- `python tools/collect_log.py '...crash_dump/stdout.txt' --output reports/name.log`:
  collect probe records before restart; inspect full stdout separately for errors.
- `reports/STATUS.md`: current validation matrix. `cargo_distribution_1/TESTING.md`:
  full native protocol. `docs/MODIO.md`: publication preparation and limitations.
- Ignored: `.tools/`, `dist/`, `local/`, saves, Python caches and `.git.sandbox-backup/`.
- PowerShell: do not test `$LASTEXITCODE -ne 0` after invoking a PowerShell script;
  it can be null and cause an unintended early exit. Use ErrorActionPreference Stop
  for that script; native python/git exit codes can be checked normally.

## Resolved failures — do not reintroduce

- 0.1.0 initial load: missing data() resource entry point; fixed.
- 0.1.0 arrival: command inside OnArriveAtStop crashed with BeginModification /
  !m_betweenChanges. See reports/ARRIVAL-CRASH.md.
- 0.1.1: moving commands to parallel update hit "Callbacks are currently disallowed".
  0.1.2 moved them to registered serial postUpdate. See CALLBACK-ERROR.md.
- 0.1.2: accepted target retained all meat because denominator was allocated capacity.
  0.1.3 uses allCaps and delivered16->8. See CAPACITY-CONVERSION.md.
- 0.1.3: eight native unload events but persisted count1 due to stale parallel state
  writes. 0.1.4 makes update read-only; full native trip now passes. See
  STATE-INTERLEAVING.md and FULL-TRIP.md.

## Installed API references and remaining work

Prefer installed definitions when online docs differ:

- `api/tealdef/api/engine.d.tl`: Line.StopConfig, TransportVehicle, configs.
- `api/tealdef/api/cmd.d.tl`: makeLineUpdateCmd and callback context.
- `api/tealdef/api/engine/system.d.tl`: vehicle cargo count/system methods.
- `base/tealdef/scripts/gamescript.d.tl`: events and persistent state.
- `base/content/gui.zip`: `gui/line_vehicle_mgmt/cargofilter_window.tl`, line_util.tl;
  cargo picker conventions. Dormant unload fields are not a working quota API.
- Same archive: line_eow.script.tl and line_eow_basics.res.lua; the native
  **LineEowExtensionPoint** can host a custom Unload Rules card after the gate.
- Native fireworks/company scripts demonstrate postUpdate command callbacks.
- `api/tealdef/api/type/modhub.d.tl`: validate(modId) is validation-only;
  publish(modId,settings) validates/cooks/uploads. No upload is authorized.

After the gate: implement original Unload Rules GUI, route reassignment confirmation,
reset/disable, resource-name rule persistence, saved-state migrations, and full
acceptance checks. Test odd/empty/zero/full loads, partial loads including100->50/50
and60->30/30, mixed compartments, all cargo modes, concurrent different vehicles,
full/incompatible warehouses, save/reload during unloading, replacement, route
edits and unmanaged/passenger behavior. Then run native staging validation, retain
its report, and verify a clean packaged installation.

Prepare a self-contained Windows release for mod.io using the native workflow,
semantic versions and the stable ID. Reference game resources but bundle no base
archives, proprietary assets, executables or saves. No cover/screenshots yet;
create original visuals once the demonstrated feature is ready. Author/creator
credit and licensing remain explicitly for the user to choose. Actual account
submission/public release requires their explicit request. No release license
has been assigned and no native staging validator report exists yet.
