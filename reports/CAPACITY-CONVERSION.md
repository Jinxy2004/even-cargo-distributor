# Native target capacity conversion

Build 40408, 0.1.2-prototype, ModTestGame, 2026-10-05. The user observed no unloading
at town one, then all cargo unloading at town two. The native log confirms the first
target was accepted (`commandPhase=postUpdate`, `applied=true`), with no callback error.

First-town arrival: vehicle 80319, line 80160, stop 2. Meat aboard = 16.
Configured meat capacity = 25; **all compatible meat capacity = 225**. Eight units
should be unloaded and eight retained. Version 0.1.2 sent 8/25 = 0.32; applied to 225,
that permits retaining 72 units, more than the entire 16-unit load. The observed
departure retained all 16, with zero pickups and zero destruction. This is consistent
with using the wrong capacity denominator, rather than a rejected command.

Version 0.1.3 uses `TransportVehicle.config.allCaps[cargoId + 1]` for the capacity
translation and its pre-command consistency check. The quota still comes exclusively
from the arrival snapshot. Candidate native fraction is now 8/225 ≈ 0.035556.
Both configured and compatible capacities are retained in diagnostic output.

The installed StopConfig definition describes maxLoad as a fraction of total capacity;
the installed GUI uses allCaps to determine compatibility across vehicle configurations.
The native retest must confirm the corrected candidate delivers 8 and retains 8.
Mixed-cargo compartments, rounding, concurrent arrivals and all other acceptance
checks remain required. This report is not a claim that the full native gate passed.
