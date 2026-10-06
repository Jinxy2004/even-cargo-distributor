# Restricted-update callback error and uneven delivery

Observed run: 2026-10-05 09:07 America/New_York, build 40408, version 0.1.1-prototype.
Save: ModTestGame. User confirmed the route order: source, first town, second town.

The latest error differs from 0.1.0's nested engine assertion:

```text
Callbacks are currently disallowed
scope UseFunctionAndCallScriptCreateParamFn,
dynamic cargo_distribution_1::/cargo_distribution/probe.script@update
sendCommand -> replaceStop (old line 88) -> applyPending (237) -> update (331)
```

The mod attempted a command with a callback in a restricted parallel update.
That error prevented application and state persistence. Attempts repeated until
the vehicle began normal unloading, at which point the timing guard suspended it.

Native trace: vehicle 80319, line 80160, stop 2. Arrival = **16 meat**, configured
capacity = 25, requested unload = **8**, target fraction = 0.32. The target was
never confirmed. Actual unload = **16**, departure = **0**, pickups = 0, destruction = 0.
The result correctly reports over-unloading and `target_not_applied:skipped`.
This run does not establish whether an accepted native target would work.

## Version 0.1.2 repair

Register `postUpdateScript` in the .gs resource. Keep update free of commands;
perform targets, restorations and callback confirmation in serial postUpdate.
This follows the installed base scripts: game_mechanics/fun_elements/fireworks
and game_mechanics/company/company use postUpdate for operations needing callbacks.
No base script code or assets are redistributed.

Retain event snapshots, cargo-timing guards, versioned state and duplicate suppression.
Recoverable Lua command errors log COMMAND_ERROR and suspend instead of producing
repeated uncaught game errors. Log all-configuration capacity as additional diagnostic
data; the current native target calculation still uses configured capacity and
requires verification with mixed/reconfigurable compartments.

The new regression rejects callbacks in update and commands from arrival events.
The old implementation fails with the observed callback error (callback-regression-before.log).
The patched suite passes 95 assertions, including separate lifecycle phases, descriptor
registration, the 16→8 calculation, paused frames and duplicate postUpdate calls.

Native retest remains required: TARGET_WRITTEN must report commandPhase=postUpdate and
applied=true, followed by correct departure quantities. Full acceptance, especially
concurrent vehicles and no pickups, remains gated. Retest from a save before the failed
run; a save taken after the timing guard fired retains the line's suspended state.
