-- Rules are set per stop in the game's stop window (Unload card). Nothing here opts
-- a line in. These are development settings only.
return {
    version = "0.2.0-prototype",
    -- Ring buffer kept in the saved state. The stop window reads this state, so keep it small.
    maxLogEntries = 100,
    -- Print every unload/load event to stdout.txt (needed for native test traces).
    verbose = true,
}
