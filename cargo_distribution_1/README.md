# Cargo Distribution — feasibility probe

Version **0.1.3-prototype** · Mod ID **cargo_distribution_1** · Windows

This development build tests whether Transport Fever 3's native loading targets
can implement percentages of cargo aboard **on arrival**. Exact native behavior
has not yet been verified. Do not use this build in a save you intend to keep.
The Unload Rules GUI and public release are gated on these tests.

## Installation

Extract the archive into the game's **user data** `mods` directory. The resulting
layout must be `mods/cargo_distribution_1/mod.json`, with `_content.json`,
`_metadata/`, and `content/` beside it. Do not copy files over the base game.
Restart the game if the local mod list has already been cached.
Enable **Cargo Distribution — Feasibility Probe** when loading a disposable copy
of a save. The package never enables rules for existing lines automatically.

## First test

Use a cargo line with these ordered stops: source, town A, town B. Both towns must
accept the tested cargo and have room in their warehouses. Rename that line to
exactly **Cst CD PROBE**. Let the simulation run for two seconds before arrival.
Stop 1 keeps its existing loading settings. Stop 2 attempts 50% unloading;
stop 3 attempts 100% of what remains. Pause just before arrival, note the actual
quantity, then observe departure. For 60 units arriving, the expected sequence is
60 → 30 → 0, regardless of capacity.

The source of these percentages is `content/cargo_distribution/config.lua`.
Default filter: Automatic — all goods. Custom allowlists and per-cargo percentages
can be set there for subsequent tests using resource names from the startup log.
Editing this file requires leaving and reloading the save.

The probe logs `[CargoDistribution]` entries to the game's `stdout.txt`. It records
arrivals, targets, concurrent arrivals, each cargo transfer, departures and restores.
Arrival callbacks save a pending target; the serial `postUpdate` phase issues the native
command. If cargo transfers before that update, `TARGET_SKIPPED` records the timing
failure and suspends the line. The probe never recalculates its quota from the later load.
The log's `exact=true` is one arrival result, **not** a complete validation of the mod.
See TESTING.md for required evidence.

## Reset and removal

Finish the test, rename the line **Cst CD RESET**, and run the simulation for two
seconds. This restores saved stop settings and suspends that line's rules. Check
the log for `RESTORED`; then save the disposable test game if desired and disable
the mod in its mod list. Do this before removing the files. Reset is intentionally
one-way in this prototype; reload a fresh pre-test save to repeat from scratch.

Do not edit a test line's route while native targets are active. If its route changes,
the probe suspends the rule and reports `RESTORE_BLOCKED_ROUTE_CHANGED` instead of
guessing which edited stop owns the old settings. Discard that test save and reload
the untouched copy. An end-user route reassignment UI is not part of this prototype.

Console alternative to disable every probe (engine scripting event):

```lua
api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("cargo_distribution_probe", "cargo_distribution_1", "CargoDistributionControl", {action="disable"}))
```

## Scope and limitations

This build snapshots quantities, rounds half up, translates retained quantities
to native capacity fractions, and saves diagnostics/state schema 2. Version 0.1.2 moves
commands to the serial postUpdate phase, avoiding both nested arrival transactions
and callbacks forbidden during parallel update. It never sets
the native cargo-destruction flags. It cannot yet promise zero pickups, exact
unloading, or isolation between concurrent arrivals: those are the experiment.
Passengers aboard cause a probe arrival to be skipped. No passenger features are
implemented. No executables, base game assets, or modified copies of native GUI
code are included. Author credit and reuse licensing remain undecided.

Native targets use total compatible capacity (`allCaps`), including compartments
that can switch goods. The player's percentage always applies to arrival cargo:
16 aboard at 50% means 8 to unload, even if compatible capacity is 225.

After updating, restart the game and load the ordinary test save made
before the failed test. Do not use the automatically generated `crash_...` save for the
retest. Older saved snapshots are preserved but are never replayed as new arrivals.
