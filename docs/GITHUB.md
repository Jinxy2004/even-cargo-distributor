# GitHub preparation

The user initialized and linked this repository to
https://github.com/Jinxy2004/even-cargo-distributor.git (`origin`), with baseline
commit `5d2d3b3` on `main`. The user authorized commits and pushes on a feature branch
or main; the current fix uses `codex/fix-deferred-command-confirmation`.
`.gitignore` excludes the local Lua test runtime, generated
ZIPs, saved games, temporary files and the unused sandbox-created Git backup.
`.gitattributes` defines text line endings.

Before publishing a finished release:

1. Choose creator credit and license. Do not publish the placeholder metadata as final.
2. Review native-test status and describe this accurately as a prototype while gated.
3. Review `git status` and the files to include. Source, tools, tests and documentation
   are intended for version control; game installation files and saves are not.
4. Keep fixes on reviewable branches until their native test results are known.
5. Commit under the configured Git identity and push to the selected remote branch.

The mod.io release and GitHub development pushes are separate actions. GitHub pushes
are authorized; mod.io account submission and public release still require the user's
explicit request. Code on the fix branch remains an unvalidated prototype.
