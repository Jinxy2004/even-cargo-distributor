-- Development-only opt-in. Stop numbers here are ONE-BASED, as in the UI.
-- Existing lines are untouched unless their name exactly matches lineName.
-- The Cst prefix also exempts the line from Auto Line Namer's automatic renaming.
return {
    version = "0.1.2-prototype",
    lineName = "Cst CD PROBE",
    resetName = "Cst CD RESET",
    maxLogEntries = 800,
    rules = {
        [2] = { percentage = 50, filter = "automatic", overrides = {} },
        [3] = { percentage = 100, filter = "automatic", overrides = {} },
    },
    -- For a mixed-cargo test replace a rule with e.g.:
    -- { percentage = 50, filter = "selected",
    --   goods = { ["EXACT RESOURCE NAME FROM CATALOG LOG"] = true },
    --   overrides = { ["EXACT RESOURCE NAME FROM CATALOG LOG"] = 25 } }
    -- Use resource names, never numeric cargo IDs. Reload after editing.
}
