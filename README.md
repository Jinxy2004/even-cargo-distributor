# Cargo Distribution development workspace

**Current milestone:** feasibility prototype implemented; native gameplay gate pending.

Version 0.1.4 passed the single-vehicle native full trip: 16 meat → 8 → 0, delivering
8 to each town. Concurrent unloading at one stop failed and is accepted as a known limitation
(see reports/CONCURRENT.md). Mixed goods and the dedicated no-pickup test remain
unverified. See [reports/FULL-TRIP.md](reports/FULL-TRIP.md).

The accepted design is in [HANDOFF.md](HANDOFF.md). The installable source folder is
`cargo_distribution_1/`; the generated development ZIP is in `dist/`.
The user initialized Git and linked `origin` to
https://github.com/Jinxy2004/even-cargo-distributor.git. The command-phase fix is
being developed on `codex/fix-deferred-command-confirmation`.

Run from this directory:

```powershell
python -m pip install --target .tools/python lupa==2.6
python tools/test.py
python tools/build.py
```

The Python bridge runs the actual Lua source using Lua 5.4. It is a development-only
dependency and never enters the mod package. A mocked game checks lifecycle behavior;
it cannot prove the proprietary engine's cargo-transfer behavior.

`tools/install-local.ps1 -UserData 'YOUR GAME USER-DATA FOLDER'` copies only this mod.
An optional `-SaveName 'YOUR SAVE.sav'` also creates a separate disposable copy if absent.
It never overwrites the original save or an existing test copy. The prototype has
been installed into the local user-data mods folder with approval. The user created
the dedicated save **ModTestFile**; no saves were created or changed by this workspace.

`python tools/build.py --release` intentionally fails while the native gate is
pending. Prototype packaging uses only mod-owned files and verifies archive hashes.
See [reports/STATUS.md](reports/STATUS.md) and [docs/MODIO.md](docs/MODIO.md).
