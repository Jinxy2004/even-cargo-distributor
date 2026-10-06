-- Registers the stop-window Unload card through the game's recipe replacement hook.
function data()
    return {
        type = "react-replacement-config",
        data = {
            filePath = "cargo_distribution_1::/cargo_distribution/unload_gui.script",
            doReplaceFn = "doReplace",
            order = 100,
        },
    }
end
