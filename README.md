# Cargo Distribution — Transport Fever 3 mod

Unload a set percentage of the cargo each vehicle carries at chosen line stops, so a
delivery can be split between towns (e.g. 50% at the first, the rest at the second).
Configured from a new **Unload** card in the game's stop window. Player documentation:
[cargo_distribution_1/README.md](cargo_distribution_1/README.md).

- Mod ID: `cargo_distribution_1` · Version: 1.0.0 · Author: bobbyhill1239 · License: [MIT](LICENSE)
- Tested on Transport Fever 3 build 40408, Windows.

## Repository layout

| Path | What it is |
|---|---|
| `cargo_distribution_1/` | The mod itself — exactly what gets installed and published |
| `cargo_distribution_1/content/cargo_distribution/` | Lua: `core.lua` (pure maths/rules), `runtime.script.lua` (game script), `unload_gui.*` (stop-window card) |
| `tests/` | Lua tests run against mocked engine/GUI APIs |
| `tools/` | Test runner, release build, local/staging install, log collector |
| `media/` | mod.io logo (original artwork) |
| `docs/MODIO.md` | Publishing steps and listing text |
| `docs/TESTING.md`, `docs/test-reports/` | In-game test protocol and the recorded results |
| `docs/HANDOFF.md` | Design notes and engine findings for future development |

## Development

```powershell
python -m pip install --target .tools/python lupa==2.6   # once; dev-only, never packaged
python tools/test.py                                      # runtime + GUI tests (Lua 5.4)
python tools/build.py                                     # checks metadata, builds dist/cargo_distribution-<version>.zip
.\tools\install-local.ps1 -UserData 'C:\Users\Public\Documents\Steam\RUNE\3493540\local'            # play/test
.\tools\install-local.ps1 -UserData 'C:\Users\Public\Documents\Steam\RUNE\3493540\local' -Staging   # for publishing
```

The tests run the real Lua source against mocks. They cannot prove the engine's cargo
transfer behaviour; that was verified in game (see `docs/test-reports/`).

For native traces, set `verbose = true` in `config.lua`, then collect the log before
restarting the game: `python tools/collect_log.py <user-data>\crash_dump\stdout.txt --output docs/test-reports/logs/<name>.log`.
Set it back to `false` before a release (the build refuses otherwise).
