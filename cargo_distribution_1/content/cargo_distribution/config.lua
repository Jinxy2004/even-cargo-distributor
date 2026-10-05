-- Rules are set per stop in the game's stop window (Unload card); nothing here opts
-- a line in. Developer settings only.
return {
    version = "1.0.0",
    -- Entries kept in the saved state's log ring buffer.
    maxLogEntries = 30,
    -- true: print every arrival, target, transfer and result to stdout.txt
    -- (used for native test traces). false for releases: only problems and rule changes.
    verbose = false,
}
